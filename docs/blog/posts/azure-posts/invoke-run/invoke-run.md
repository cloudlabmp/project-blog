---
title: "How I Used Claude Code to Deploy a Security Scan Across Many Azure VMs"
description: "When GPO deployment failed and Intune wasn't an option, I turned to Claude Code and Invoke-AzVMRunCommand to roll out a security scanning agent across multiple Azure subscriptions."
date:
  created: 2026-03-11
  updated: 2026-03-11
authors:
  - matthew
categories:
  - Azure
  - AI
  - Automation
tags:
  - azure
  - azure vm
  - invoke-azvmruncommand
  - run command
  - powershell
  - powershell 7
  - foreach-object parallel
  - automation
  - bulk deployment
  - scripting
  - claude code
  - ai
  - ai assisted development
  - ai automation
  - ai ops
  - llm
  - security
  - vulnerability scanning
  - gpo
  - intune
  - managed identity
  - azure guest agent
  - infrastructure
  - devops
  - sysadmin
  - windows server
reading_time: "10 min"
---

# 🔧 How I Used Claude Code to Deploy a Security Scan Across Many Azure VMs

> Sometimes the best way to learn a new Azure feature is to have an AI agent explain it to you while you're under pressure to deliver.

I'd been asked to deploy a third-party security scanning agent across our Azure VM estate. Should have been straightforward — except the usual deployment routes, GPO and Intune, both fell flat for different reasons. I was left without an obvious path forward. Rather than spend hours trawling through documentation for something I might not even find, I opened Claude Code and described the problem. What came back was an Azure feature I'd barely touched before, and within half a day the whole thing was done.

<!-- more -->

---

## 🎯 The Problem

The organisation had commissioned a security assessment that required a scanning agent to be deployed and executed on every Windows Server VM in Azure. The scan script itself was fairly simple — download the agent, run it, and upload the results. It worked perfectly when run manually under an admin account in PowerShell ISE.

The challenge was scale. We had many Windows Server VMs spread across multiple Azure subscriptions and resource groups. Running the script manually on each one was not an option.

---

## ❌ What Didn't Work

### GPO Startup Script

The first approach — suggested by the vendor's consultant — was a Group Policy computer startup script. Deploy the script via GPO, target the right OUs, wait for the servers to pick it up.

It didn't work. No log files were created on any of the target servers, confirming the script never executed. The most likely culprit was the SYSTEM context — the scan script needed to download files from external URLs, and SYSTEM context on these VMs didn't have the proxy configuration needed to reach the internet.

### Intune

The next thought was Intune. But our servers are enrolled in Microsoft Defender for Endpoint only — they're not MDM-managed. Intune showed them as "Managed by: MDE" with ownership "Unknown", which means we had no ability to push scripts or configurations through Intune.

So that was a dead end too.

---

## 🤖 Enter Claude Code

At this point I knew I needed an alternative approach — something that could target both domain-joined and non-domain-joined VMs, didn't rely on GPO or Intune, and could scale across subscriptions.

I've been using [Claude Code](https://claude.ai/code) as my go-to AI assistant for a while now, and I'd previously set up specialised agents for different workloads. One of these is an "IT Ops" agent with general Azure operational context — nothing sensitive, just enough to steer it towards relevant services and patterns. I fired up Claude Code and described the problem — what had been tried, what failed, and what constraints I was working within.

Within minutes, Claude Code came back with a recommendation I hadn't considered: **`Invoke-AzVMRunCommand`**.

### What is Invoke-AzVMRunCommand?

I'll be honest — I'd used the "Run Command" feature in the Azure portal before for quick one-off tasks, like adding a registry key or checking a service status on a handful of VMs. But I'd never considered it as a bulk deployment mechanism, and I certainly hadn't used its PowerShell cmdlet equivalent.

Here's the key thing Claude Code helped me understand: [`Invoke-AzVMRunCommand`](https://learn.microsoft.com/powershell/module/az.compute/invoke-azvmruncommand?view=azps-15.4.0) reads a script from your *local* machine and sends it to the target VM via the Azure fabric. The VM's guest agent receives the script, executes it under SYSTEM context, and returns stdout/stderr back to your session. No network connectivity between your workstation and the VM is needed — it all goes through Azure's [management plane](https://learn.microsoft.com/azure/virtual-machines/windows/run-command).

> **Important:** The script executes under SYSTEM context on the remote VM — the same context that failed with the GPO approach. But this time, if it failed, I'd actually get error output back. That visibility alone was worth the switch.

---

## 🛠️ Building the Script

This is where working with Claude Code really paid off. Rather than me spending hours reading documentation and building something from scratch, I described what I needed and Claude Code produced a working script — then iteratively refined it as I asked questions and raised edge cases.

### The Initial Draft

I started with a rough outline of what I wanted — loop through subscriptions, get VMs, run the scan script against each one, capture results. Claude Code took that and immediately flagged several issues I hadn't considered:

| Issue | What Claude Code Caught |
|-------|------------------------|
| **Parallel runspace context** | `Set-AzContext` only applies to the current runspace — parallel scriptblocks run in isolated runspaces with no Az context |
| **No power state check** | Deallocated VMs would timeout and waste execution time |
| **No OS filter** | Any Linux VMs in the subscriptions would fail against `RunPowerShellScript` |
| **Incomplete exclusions** | Some VMs needed excluding by name, not just by resource group |
| **No dry-run capability** | Running against production without a preview mechanism is asking for trouble |
| **No error capture** | The original approach only captured stdout, missing stderr entirely |

Every single one of those would have bitten me in production. That table alone probably saved me a couple of hours of debugging.

### The Refined Version

The final script included all of the above fixes, plus a few extras I hadn't thought to ask for — a stopwatch for timing, a `-WhatIf` parameter for dry runs, an `-IncludeVMs` parameter for targeting specific VMs, and a summary report with colour-coded status output.

> **Prerequisites:** This script requires [PowerShell 7+](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) (for `ForEach-Object -Parallel`) and the [Az PowerShell module](https://learn.microsoft.com/powershell/azure/install-azure-powershell) with an authenticated session (`Connect-AzAccount`).

Here's a sanitised version showing the pattern:

??? example "Full script — click to expand"

    ```powershell
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$ScriptPath = "C:\temp\ScanScript.ps1",
        [string]$OutputPath = "C:\temp\ScanResults.csv",
        [int]$ThrottleLimit = 10,
        [string[]]$IncludeVMs = @()
    )

    # ── Prerequisites ──────────────────────────────────────────
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        throw "PowerShell 7+ required for ForEach-Object -Parallel."
    }

    if (-not (Test-Path $ScriptPath)) {
        throw "Scan script not found at '$ScriptPath'."
    }

    # ── Configuration ──────────────────────────────────────────
    $subscriptions = @(
        "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"  # Subscription 1
        "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"  # Subscription 2
    )

    $excludeRGs = @(
        "rg-asr-replica-001"  # ASR replica VMs
    )

    $excludeVMs = @(
        "VM-YOURDC01"    # Domain controller
        "VM-YOURMGMT01"  # Management server
    )

    # ── Gather target VMs ─────────────────────────────────────
    $allTargetVMs = [System.Collections.Generic.List[object]]::new()

    foreach ($subId in $subscriptions) {
        Write-Host "── Subscription: $subId ──"
        $ctx = Set-AzContext -SubscriptionId $subId -ErrorAction Stop

        $vms = Get-AzVM -Status | Where-Object {
            $_.StorageProfile.OSDisk.OSType -eq 'Windows' -and
            $_.ResourceGroupName -notin $excludeRGs -and
            $_.Name -notin $excludeVMs
        }

        # Optional: target only specific VMs (useful for batch 2 runs)
        if ($IncludeVMs.Count -gt 0) {
            $vms = $vms | Where-Object { $_.Name -in $IncludeVMs }
        }

        $running = $vms | Where-Object { $_.PowerState -eq 'VM running' }
        $notRunning = $vms | Where-Object { $_.PowerState -ne 'VM running' }

        Write-Host "  Windows VMs: $($vms.Count) | Running: $($running.Count) | Skipped: $($notRunning.Count)"

        foreach ($vm in $running) {
            $allTargetVMs.Add([PSCustomObject]@{
                SubscriptionId   = $subId
                SubscriptionName = $ctx.Subscription.Name
                VMName           = $vm.Name
                ResourceGroupName = $vm.ResourceGroupName
            })
        }
    }

    # ── Dry-run gate ───────────────────────────────────────────
    if (-not $PSCmdlet.ShouldProcess("$($allTargetVMs.Count) VMs", "Invoke Run Command")) {
        Write-Host "Dry run complete. Target list above."
        $allTargetVMs | Export-Csv ($OutputPath -replace '\.csv$', '_DryRun.csv') -NoTypeInformation
        return
    }

    # ── Read script once, execute in parallel ──────────────────
    $scriptContent = Get-Content $ScriptPath -Raw
    $results = [System.Collections.Concurrent.ConcurrentBag[object]]::new()
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    $allTargetVMs | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
        $target = $_
        $bag = $using:results
        $script = $using:scriptContent

        try {
            Set-AzContext -SubscriptionId $target.SubscriptionId -ErrorAction Stop | Out-Null

            $output = Invoke-AzVMRunCommand `
                -ResourceGroupName $target.ResourceGroupName `
                -VMName $target.VMName `
                -CommandId 'RunPowerShellScript' `
                -ScriptString $script `
                -ErrorAction Stop

            $stdout = if ($output.Value.Count -gt 0) { $output.Value[0].Message } else { "" }
            $stderr = if ($output.Value.Count -gt 1) { $output.Value[1].Message } else { "" }

            $bag.Add([PSCustomObject]@{
                Subscription  = $target.SubscriptionName
                VMName        = $target.VMName
                ResourceGroup = $target.ResourceGroupName
                Status        = if ($stderr) { "CompletedWithErrors" } else { "Success" }
                StdOut        = $stdout
                StdErr        = $stderr
                Timestamp     = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            })

            Write-Host "  [OK] $($target.VMName)" -ForegroundColor Green
        }
        catch {
            $bag.Add([PSCustomObject]@{
                Subscription  = $target.SubscriptionName
                VMName        = $target.VMName
                ResourceGroup = $target.ResourceGroupName
                Status        = "Failed"
                StdOut        = ""
                StdErr        = $_.Exception.Message
                Timestamp     = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            })

            Write-Host "  [FAIL] $($target.VMName): $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    $stopwatch.Stop()

    # ── Report ─────────────────────────────────────────────────
    Write-Host "`n══ Results ══"
    Write-Host "Total: $($results.Count) | Elapsed: $($stopwatch.Elapsed.ToString('hh\:mm\:ss'))"

    $results | Sort-Object Status, VMName | Format-Table Subscription, VMName, ResourceGroup, Status -AutoSize
    $results | Export-Csv $OutputPath -NoTypeInformation
    Write-Host "Results exported to $OutputPath"
    ```

### Key Design Decisions

A few things worth highlighting about how the script was built:

- **`-ScriptString` instead of `-ScriptPath`**: The script content is read once locally with `Get-Content -Raw` and passed via `-ScriptString`. This avoids file I/O issues in parallel runspaces and means you only need the scan script on your workstation, not on every target VM.

- **[`ForEach-Object -Parallel`](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/foreach-object?view=powershell-7.5) with `-ThrottleLimit 10`**: PowerShell 7's parallel foreach with a throttle keeps things moving without overwhelming the Azure API. Each runspace gets its own `Set-AzContext` call because Az context isn't inherited across runspaces. This is a PowerShell 7+ feature — it doesn't exist in Windows PowerShell 5.1.

- **`ConcurrentBag`**: Thread-safe collection for gathering results from parallel runspaces. Standard arrays would cause race conditions.

- **`-WhatIf` support**: Running with `-WhatIf` lists all target VMs and exports a dry-run CSV without executing anything. Essential for production confidence.

---

## 🚀 The Rollout

### Test Run First

I started with the smallest subscription — a dev/test environment. The `-WhatIf` flag showed me exactly which VMs would be targeted, the deallocated VMs that would be skipped, and confirmed the exclusion lists were working.

The first live run against the test subscription completed successfully. Every running VM came back with `[OK]`. At that point I knew the pattern worked.

### Scaling to Production

The script was amended for each subscription — updating the subscription IDs, exclusion lists, and output paths. The approach was subscription-by-subscription rather than all-at-once, which gave me a natural checkpoint between runs.

One thing that came up during the test run: several VMs in the test subscription were deallocated. Rather than skip them entirely, I wanted to scan those too. Claude Code added the `-IncludeVMs` parameter on the spot, so I could start those VMs, then target just the ones that had been powered on — without rescanning the ones already completed.

```powershell
# Target only the previously-deallocated VMs after starting them
.\Invoke-BulkRunCommand.ps1 `
    -IncludeVMs @("VM-001","VM-002","VM-003","VM-004") `
    -OutputPath "C:\temp\ScanResults_Batch2.csv"
```

Claude Code even offered to start the deallocated VMs from the CLI on my behalf, looked up the resource groups for each one, and issued the `az vm start` commands — all from within the same session. To be clear, Claude Code prompts for approval before executing any command, so I was reviewing and confirming each action before it ran. It's not running wild in your environment — you stay in control.

### Results

Across all subscriptions:

- **All targeted VMs scanned successfully**
- **Only 2 failures** — both were VMs with unresponsive guest agents
- The 2 failures were handled by running the scan script manually via the Azure portal's Run Command GUI
- Total execution time across all subscriptions was well under an hour

---

## 💡 What I Learned

### About Invoke-AzVMRunCommand

- It works through the **Azure VM Guest Agent** — no additional extensions or network rules needed (that's Run Command v1; v2 uses a separate extension)
- The script runs under **SYSTEM context** on the target VM, which has implications for proxy settings, network access, and permissions
- There's **no built-in timeout parameter** — the command waits for the guest agent to respond, which can be up to 90 minutes on unresponsive VMs
- The throttle limit of 10 kept things manageable without hitting Azure API rate limits
- It genuinely runs in **parallel** — even though the console output appears one VM at a time as each completes, the elapsed time confirms concurrent execution

### About Working with AI as an Orchestration Tool

This is the bit I really want to emphasise. I went into this task with zero knowledge of `Invoke-AzVMRunCommand` as a bulk deployment mechanism. I knew the portal Run Command feature existed, but I'd never have thought to wrap it in a parallelised PowerShell 7 script with dry-run support, error capture, and per-subscription targeting.

Claude Code didn't just give me the answer — it walked me through *why* the original approach had issues, flagged edge cases I hadn't considered, iteratively refined the script as new requirements emerged, and even helped with the operational execution (starting VMs, looking up resource groups, verifying target lists).

The whole process — from "I have a problem" to "all VMs scanned" — took about half a day. Without AI assistance, I'd estimate this would have taken a couple of days at minimum between researching the approach, building the script, testing, and debugging the inevitable parallel runspace issues.

> **The key takeaway:** I wasn't replaced by AI here. I was the decision-maker, the one with the context about the environment, the one who knew which VMs to exclude and why. Claude Code was the knowledge source and the builder. That combination is genuinely powerful.

---

## 🔑 Tips If You're Doing Something Similar

- **Always use `-WhatIf` first.** Seeing the target list before execution is non-negotiable for production workloads.
- **Run subscription by subscription**, not all at once. It gives you natural checkpoints and makes troubleshooting easier.
- **Check VM power states.** Deallocated VMs will timeout and waste parallel slots. Filter them out and handle them in a separate batch.
- **Capture stderr, not just stdout.** Run Command returns both — if you only capture stdout, you'll miss the errors that tell you what actually went wrong.
- **Remember SYSTEM context.** Whatever script you're pushing will run as SYSTEM on the target VM. If your script needs internet access, proxy settings, or specific permissions, test under SYSTEM first.
- **Use `-ScriptString` over `-ScriptPath` in parallel blocks.** Read the file once, pass the content. Avoids file locking issues across runspaces.

---

## 💭 Final Thoughts

What started as a "this should be simple" GPO deployment ended up being a proper learning experience. I now have a reusable pattern for pushing scripts to Azure VMs at scale — something I'll definitely reach for again. And honestly, if I hadn't had Claude Code to lean on, I'd probably still be refreshing GPO results on those servers wondering why nothing was happening.

The combination of knowing your environment deeply and having an AI that can fill in the technical gaps you don't have — that's where the real value is. I didn't need Claude Code to tell me which VMs to exclude or which subscriptions to target. I needed it to show me a capability I didn't know existed and help me build something production-ready in a fraction of the time.

*Have you used Invoke-AzVMRunCommand for bulk deployments, or found other creative uses for the Run Command feature? I'd love to hear how others are tackling similar challenges — especially if you've hit the SYSTEM context proxy issue and found a clean workaround.*
