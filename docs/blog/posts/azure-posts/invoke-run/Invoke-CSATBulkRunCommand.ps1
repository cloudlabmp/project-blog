<#
.SYNOPSIS
    Deploys CSAT security scan to Windows Server VMs across Azure subscriptions
    using Invoke-AzVMRunCommand in parallel.

.DESCRIPTION
    Iterates target subscriptions, filters to running Windows VMs, excludes
    specified resource groups and VM names, then invokes the CSAT scan script
    via Run Command with a throttle limit of 10. Results are captured to CSV.

.NOTES
    Requires: PowerShell 7+, Az module, active Connect-AzAccount session.
    The -ScriptPath file must exist on the LOCAL machine running this script.
    Run from Windows PowerShell (not WSL) to use C:\temp paths, or adjust OutputPath.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ScriptPath = "C:\temp\IME_Device_CSATCloudScan.ps1",
    [string]$OutputPath = "C:\temp\CSAT_RunResults.csv",
    [int]$ThrottleLimit = 10,
    [string[]]$IncludeVMs = @()
)

# ── Prerequisites ──────────────────────────────────────────────────────────────
if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw "PowerShell 7+ required for ForEach-Object -Parallel. Current: $($PSVersionTable.PSVersion)"
}

if (-not (Test-Path $ScriptPath)) {
    throw "CSAT script not found at '$ScriptPath'. This must exist on the local machine."
}

# ── Configuration ──────────────────────────────────────────────────────────────
# Add target subscription IDs below. The script iterates all subscriptions,
# filtering to running Windows VMs and applying RG/VM exclusions.
$subscriptions = @(
    # "d65a1c72-9ea5-47e7-b273-46f7cc4f4efd"  # AX-Production
    # "b1aef2a3-888b-4ba2-9a51-03f6fd0f1882"  # AX-DevTest
    # "c7b85071-c007-48c2-8cdf-7cf61c6711c2"  # AX-DMZ
)

# Resource groups to exclude entirely (e.g., ASR replica RGs)
$excludeRGs = @(
    # "rg-asr-ukwest"
)

# Specific VM names to exclude (e.g., identity-critical servers)
$excludeVMs = @(
    # "AXAZEXCHMGMT01"  # Exchange 2019 management server
    # AAD Connect and Exchange VMs should typically be excluded
)

# ── Gather target VMs ─────────────────────────────────────────────────────────
$allTargetVMs = [System.Collections.Generic.List[object]]::new()

foreach ($subId in $subscriptions) {
    Write-Host "── Subscription: $subId ──"
    $ctx = Set-AzContext -SubscriptionId $subId -ErrorAction Stop
    Write-Host "  Context: $($ctx.Subscription.Name)"

    # Get Windows VMs only, apply RG and name exclusions
    $vms = Get-AzVM -Status | Where-Object {
        $_.StorageProfile.OSDisk.OSType -eq 'Windows' -and
        $_.ResourceGroupName -notin $excludeRGs -and
        $_.Name -notin $excludeVMs
    }

    # If -IncludeVMs specified, filter to only those VMs
    if ($IncludeVMs.Count -gt 0) {
        $vms = $vms | Where-Object { $_.Name -in $IncludeVMs }
    }

    # Separate running from non-running for reporting
    $running = $vms | Where-Object { $_.PowerState -eq 'VM running' }
    $notRunning = $vms | Where-Object { $_.PowerState -ne 'VM running' }

    Write-Host "  Windows VMs found: $($vms.Count) | Running: $($running.Count) | Skipped (not running): $($notRunning.Count)"

    if ($notRunning.Count -gt 0) {
        Write-Host "  Non-running VMs:" -ForegroundColor Yellow
        $notRunning | ForEach-Object { Write-Host "    - $($_.Name) [$($_.PowerState)]" -ForegroundColor Yellow }
    }

    # Tag each VM with its subscription ID for the parallel block
    foreach ($vm in $running) {
        $allTargetVMs.Add([PSCustomObject]@{
            SubscriptionId    = $subId
            SubscriptionName  = $ctx.Subscription.Name
            VMName            = $vm.Name
            ResourceGroupName = $vm.ResourceGroupName
        })
    }
}

Write-Host "`n══ Total target VMs: $($allTargetVMs.Count) ══`n"

if ($allTargetVMs.Count -eq 0) {
    Write-Warning "No target VMs found. Exiting."
    return
}

# ── Dry-run gate ───────────────────────────────────────────────────────────────
if (-not $PSCmdlet.ShouldProcess("$($allTargetVMs.Count) VMs", "Invoke CSAT Run Command")) {
    Write-Host "Dry run complete. VM list above shows what would be targeted."
    # Export the target list even in dry-run mode for review
    $allTargetVMs | Export-Csv ($OutputPath -replace '\.csv$', '_DryRun.csv') -NoTypeInformation
    Write-Host "Target list exported to $($OutputPath -replace '\.csv$', '_DryRun.csv')"
    return
}

# ── Read script content once (avoids file I/O in each parallel runspace) ──────
$scriptContent = Get-Content $ScriptPath -Raw

# ── Execute in parallel ───────────────────────────────────────────────────────
$results = [System.Collections.Concurrent.ConcurrentBag[object]]::new()
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

$allTargetVMs | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
    $target = $_
    $bag = $using:results
    $script = $using:scriptContent

    try {
        # Each parallel runspace needs its own Az context
        Set-AzContext -SubscriptionId $target.SubscriptionId -ErrorAction Stop | Out-Null

        $output = Invoke-AzVMRunCommand `
            -ResourceGroupName $target.ResourceGroupName `
            -VMName $target.VMName `
            -CommandId 'RunPowerShellScript' `
            -ScriptString $script `
            -ErrorAction Stop

        # Run Command returns StdOut in Value[0] and StdErr in Value[1]
        $stdout = if ($output.Value -and $output.Value.Count -gt 0) { $output.Value[0].Message } else { "" }
        $stderr = if ($output.Value -and $output.Value.Count -gt 1) { $output.Value[1].Message } else { "" }

        $bag.Add([PSCustomObject]@{
            Subscription    = $target.SubscriptionName
            VMName          = $target.VMName
            ResourceGroup   = $target.ResourceGroupName
            Status          = if ($stderr) { "CompletedWithErrors" } else { "Success" }
            StdOut          = $stdout.Substring(0, [Math]::Min($stdout.Length, 2000))
            StdErr          = $stderr.Substring(0, [Math]::Min($stderr.Length, 2000))
            Timestamp       = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        })

        Write-Host "  [OK] $($target.VMName)" -ForegroundColor Green
    }
    catch {
        $bag.Add([PSCustomObject]@{
            Subscription    = $target.SubscriptionName
            VMName          = $target.VMName
            ResourceGroup   = $target.ResourceGroupName
            Status          = "Failed"
            StdOut          = ""
            StdErr          = $_.Exception.Message.Substring(0, [Math]::Min($_.Exception.Message.Length, 2000))
            Timestamp       = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        })

        Write-Host "  [FAIL] $($target.VMName): $($_.Exception.Message)" -ForegroundColor Red
    }
}

$stopwatch.Stop()

# ── Report ─────────────────────────────────────────────────────────────────────
Write-Host "`n══ Results ══"
Write-Host "Total: $($results.Count) | Elapsed: $($stopwatch.Elapsed.ToString('hh\:mm\:ss'))"

$grouped = $results | Group-Object Status
foreach ($g in $grouped) {
    $colour = switch ($g.Name) {
        'Success'             { 'Green' }
        'CompletedWithErrors' { 'Yellow' }
        'Failed'              { 'Red' }
        default               { 'White' }
    }
    Write-Host "  $($g.Name): $($g.Count)" -ForegroundColor $colour
}

$results | Sort-Object Status, VMName | Format-Table Subscription, VMName, ResourceGroup, Status, Timestamp -AutoSize

$results | Export-Csv $OutputPath -NoTypeInformation
Write-Host "`nResults exported to $OutputPath"

# Show failures summary if any
$failures = $results | Where-Object Status -eq 'Failed'
if ($failures.Count -gt 0) {
    Write-Host "`n── Failed VMs ──" -ForegroundColor Red
    $failures | Format-Table VMName, ResourceGroup, StdErr -AutoSize -Wrap
}
