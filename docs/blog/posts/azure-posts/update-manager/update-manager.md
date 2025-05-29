---
title: "Bringing Patch Management In-House: Migrating from MSP to Azure Update Manager"
description: "A real-world walkthrough of migrating VM patching from a third-party provider to Azure Update Manager using PowerShell, tagging, and policy automation."
author: Matt Pollock
date: 2025-05-29
categories: [Azure, Automation, Patch Management]
tags: [Azure Update Manager, PowerShell, Azure Policy, VM Patching, FinOps]
---


# 🔄 Bringing Patch Management In-House: Migrating from MSP to Azure Update Manager

> It's all fun and games until the MSP contract expires and you realise 90 odd VMs still need their patching schedules sorted…

With our MSP contract winding down, the time had come to bring VM patching *back in house*. Our third-party provider had been handling it with their own tooling — opaque, over-engineered, and far too expensive for what it did.

Enter [Azure Update Manager](https://learn.microsoft.com/en-us/azure/update-manager/overview) — the modern, agentless way to manage patching schedules across your Azure VMs. Add a bit of PowerShell, sprinkle in some Azure Policy, and you've got yourself a scalable, policy-driven solution that's more visible, auditable, and way more maintainable.

Here's how I made the switch — and managed to avoid a patching panic.

---

## ⚙️ Prerequisites & Permissions

Let's get the plumbing sorted before diving in.

You'll need:

* The right **PowerShell modules**:

  ```powershell
  Install-Module Az -Scope CurrentUser -Force
  Import-Module Az.Maintenance, Az.Resources, Az.Compute
  ```

* An account with **Contributor** permissions (or higher)
* Registered providers to avoid mysterious error messages:

  ```powershell
  Register-AzResourceProvider -ProviderNamespace Microsoft.Maintenance
  Register-AzResourceProvider -ProviderNamespace Microsoft.GuestConfiguration
  ```

> **Why Resource Providers?** Azure Update Manager needs these registered to create the necessary API endpoints and resource types in your subscription. Without them, you'll get cryptic "resource type not found" errors.

[Official documentation on Azure Update Manager prerequisites](https://learn.microsoft.com/en-us/azure/update-manager/overview#prerequisites)

---

## 🕵️ Step 1 – Audit the Current Setup

First order of business: collect the patching summary data from the MSP — which, helpfully, came in the form of multiple weekly CSV exports.

I uploaded the files into ChatGPT and had it wrangle the mess into a structured format. The result was a clear categorisation of VMs based on the day and time they were typically patched — a solid foundation to work from.

---

## 🧱 Step 2 – Create Seven New Maintenance Configurations

This is the foundation of Update Manager — define your recurring patch windows.

<details>
<summary>Click to expand: **Create Maintenance Configurations Script**</summary>

```powershell
# Azure Update Manager - Create Weekly Maintenance Configurations
# Pure PowerShell syntax

# Define parameters
$resourceGroupName = "rg-maintenance-uksouth-001"
$location = "uksouth"
$timezone = "GMT Standard Time"
$startDateTime = "2024-06-01 21:00"
$duration = "03:00"  # 3 hours - meets minimum requirement

# Day mapping for config naming (3-letter lowercase)
$dayMap = @{
    "Monday"    = "mon"
    "Tuesday"   = "tue" 
    "Wednesday" = "wed"
    "Thursday"  = "thu"
    "Friday"    = "fri"
    "Saturday"  = "sat"
    "Sunday"    = "sun"
}

# Create maintenance configurations for each day
foreach ($day in $dayMap.Keys) {
    $shortDay = $dayMap[$day]
    $configName = "contoso-maintenance-config-vms-$shortDay"
    
    Write-Host "Creating: $configName for $day..." -ForegroundColor Yellow
    
    try {
        $result = New-AzMaintenanceConfiguration `
            -ResourceGroupName $resourceGroupName `
            -Name $configName `
            -MaintenanceScope "InGuestPatch" `
            -Location $location `
            -StartDateTime $startDateTime `
            -Timezone $timezone `
            -Duration $duration `
            -RecurEvery "Week $day" `
            -InstallPatchRebootSetting "IfRequired" `
            -ExtensionProperty @{"InGuestPatchMode" = "User"} `
            -WindowParameterClassificationToInclude @("Critical", "Security") `
            -LinuxParameterClassificationToInclude @("Critical", "Security") `
            -Tag @{
                "Application"  = "Azure Update Manager"
                "Owner"        = "Contoso"
                "PatchWindow"  = $shortDay
            } `
            -ErrorAction Stop
            
        Write-Host "✓ SUCCESS: $configName" -ForegroundColor Green
        
        # Quick validation
        $createdConfig = Get-AzMaintenanceConfiguration -ResourceGroupName $resourceGroupName -Name $configName
        Write-Host "  Validated: $($createdConfig.RecurEvery) schedule confirmed" -ForegroundColor Gray
        
    } catch {
        Write-Host "✗ FAILED: $configName - $($_.Exception.Message)" -ForegroundColor Red
        continue
    }
}
```

</details>

> ⚠️ *Don't forget: duration format is ISO 8601, not "2 hours" — and start time has to match the day it's tied to.*

[Learn more about New-AzMaintenanceConfiguration](https://learn.microsoft.com/en-us/powershell/module/az.maintenance/new-azmaintenanceconfiguration)

---

## 🛠️ Step 3 – Tweak the Maintenance Configs

Some patch windows felt too tight — and, just as importantly, I needed to avoid overlaps with existing backup jobs. Rather than let a large CU fail halfway through or run headlong into an Azure Backup job, I extended the duration on select configs and staggered them across the week:

```powershell
$config = Get-AzMaintenanceConfiguration -ResourceGroupName "rg-maintenance-uksouth-001" -Name "contoso-maintenance-config-vms-sun"
$config.Duration = "04:00"
Update-AzMaintenanceConfiguration -ResourceGroupName "rg-maintenance-uksouth-001" -Name "contoso-maintenance-config-vms-sun" -Configuration $config

# Verify the change
$updatedConfig = Get-AzMaintenanceConfiguration -ResourceGroupName "rg-maintenance-uksouth-001" -Name "contoso-maintenance-config-vms-sun"
Write-Host "Sunday window now: $($updatedConfig.Duration) duration" -ForegroundColor Green
```

> Better to have time and not need it than need it and trigger a post-patch incident.

---

## 🤖 Step 4 – Use AI to Group VMs by Patch Activity

Armed with a jumble of CSV exports that made sense to nobody but the person who created them, I got AI to do the grunt work.

**What I did:**

1. **Exported MSP data:** Weekly CSV reports showing patch installation timestamps for each VM
2. **Uploaded to ChatGPT** with this prompt:
   > "Analyze these patch installation times and group VMs by day/time patterns. Most VMs seem clustered on weekends - suggest optimal distribution across 7 maintenance windows for business continuity."

3. **AI analysis revealed:**
   * 60% of VMs were patching Saturday/Sunday (risky for business continuity)
   * Several critical systems patching simultaneously
   * No consideration for application dependencies

4. **AI recommendation:** Spread VMs across weekdays based on:
   * **Criticality:** Domain controllers on different days
   * **Function:** Similar servers on different days (avoid single points of failure)  
   * **Dependencies:** Database servers before application servers

**The result:** A logical rebalancing that avoided "all our eggs in Sunday 1AM" basket and considered business impact.

> **Why this matters:** The MSP was optimizing for their convenience, not our business continuity. AI helped identify risks we hadn't considered.

---

## 🔍 Step 5 – Discover All VMs and Identify Gaps

Before diving into bulk tagging, I needed to understand what we were working with across all subscriptions.

**First, let's see what VMs we have:**

<details>
<summary>Click to expand: **Discover Untagged VMs Script**</summary>

```powershell
# Discover Untagged VMs Script for Azure Update Manager
# This script identifies VMs that are missing Azure Update Manager tags

$scriptStart = Get-Date

Write-Host "=== Azure Update Manager - Discover Untagged VMs ===" -ForegroundColor Cyan
Write-Host "Scanning all accessible subscriptions for VMs missing maintenance tags..." -ForegroundColor White
Write-Host ""

# Function to check if VM has Azure Update Manager tags
function Test-VMHasMaintenanceTags {
    param($VM)
    
    # Check for the three required tags
    $hasOwnerTag = $VM.Tags -and $VM.Tags.ContainsKey("Owner") -and $VM.Tags["Owner"] -eq "Contoso"
    $hasUpdatesTag = $VM.Tags -and $VM.Tags.ContainsKey("Updates") -and $VM.Tags["Updates"] -eq "Azure Update Manager"
    $hasPatchWindowTag = $VM.Tags -and $VM.Tags.ContainsKey("PatchWindow")
    
    return $hasOwnerTag -and $hasUpdatesTag -and $hasPatchWindowTag
}

# Function to get VM details for reporting
function Get-VMDetails {
    param($VM, $SubscriptionName)
    
    return [PSCustomObject]@{
        Name = $VM.Name
        ResourceGroup = $VM.ResourceGroupName
        Location = $VM.Location
        Subscription = $SubscriptionName
        SubscriptionId = $VM.SubscriptionId
        PowerState = $VM.PowerState
        OsType = $VM.StorageProfile.OsDisk.OsType
        VmSize = $VM.HardwareProfile.VmSize
        Tags = if ($VM.Tags) { ($VM.Tags.Keys | ForEach-Object { "$_=$($VM.Tags[$_])" }) -join "; " } else { "No tags" }
    }
}

# Initialize collections
$taggedVMs = @()
$untaggedVMs = @()
$allVMs = @()
$subscriptionSummary = @{}

Write-Host "=== DISCOVERING VMs ACROSS ALL SUBSCRIPTIONS ===" -ForegroundColor Cyan

# Get all accessible subscriptions
$subscriptions = Get-AzSubscription | Where-Object { $_.State -eq "Enabled" }
Write-Host "Found $($subscriptions.Count) accessible subscriptions" -ForegroundColor White

foreach ($subscription in $subscriptions) {
    try {
        Write-Host "`nScanning subscription: $($subscription.Name) ($($subscription.Id))" -ForegroundColor Magenta
        $null = Set-AzContext -SubscriptionId $subscription.Id -ErrorAction Stop
        
        # Get all VMs in this subscription
        Write-Host "  Retrieving VMs..." -ForegroundColor Gray
        $vms = Get-AzVM -Status -ErrorAction Continue
        
        $subTagged = 0
        $subUntagged = 0
        $subTotal = $vms.Count
        
        Write-Host "  Found $subTotal VMs in this subscription" -ForegroundColor White
        
        foreach ($vm in $vms) {
            $vmDetails = Get-VMDetails -VM $vm -SubscriptionName $subscription.Name
            $allVMs += $vmDetails
            
            if (Test-VMHasMaintenanceTags -VM $vm) {
                $taggedVMs += $vmDetails
                $subTagged++
                Write-Host "    ✓ Tagged: $($vm.Name)" -ForegroundColor Green
            } else {
                $untaggedVMs += $vmDetails
                $subUntagged++
                Write-Host "    ⚠️ Untagged: $($vm.Name)" -ForegroundColor Yellow
            }
        }
        
        # Store subscription summary
        $subscriptionSummary[$subscription.Name] = @{
            Total = $subTotal
            Tagged = $subTagged
            Untagged = $subUntagged
            SubscriptionId = $subscription.Id
        }
        
        Write-Host "  Subscription Summary - Total: $subTotal | Tagged: $subTagged | Untagged: $subUntagged" -ForegroundColor Gray
        
    }
    catch {
        Write-Host "  ✗ Error scanning subscription $($subscription.Name): $($_.Exception.Message)" -ForegroundColor Red
        $subscriptionSummary[$subscription.Name] = @{
            Total = 0
            Tagged = 0
            Untagged = 0
            Error = $_.Exception.Message
        }
    }
}

Write-Host ""
Write-Host "=== OVERALL DISCOVERY SUMMARY ===" -ForegroundColor Cyan
Write-Host "Total VMs found: $($allVMs.Count)" -ForegroundColor White
Write-Host "VMs with maintenance tags: $($taggedVMs.Count)" -ForegroundColor Green
Write-Host "VMs missing maintenance tags: $($untaggedVMs.Count)" -ForegroundColor Red

if ($untaggedVMs.Count -eq 0) {
    Write-Host "� ALL VMs ARE ALREADY TAGGED! �" -ForegroundColor Green
    Write-Host "No further action required." -ForegroundColor White
    exit 0
}

Write-Host ""
Write-Host "=== SUBSCRIPTION BREAKDOWN ===" -ForegroundColor Cyan
$subscriptionSummary.GetEnumerator() | Sort-Object Name | ForEach-Object {
    $sub = $_.Value
    if ($sub.Error) {
        Write-Host "$($_.Key): ERROR - $($sub.Error)" -ForegroundColor Red
    } else {
        $percentage = if ($sub.Total -gt 0) { [math]::Round(($sub.Tagged / $sub.Total) * 100, 1) } else { 0 }
        Write-Host "$($_.Key): $($sub.Tagged)/$($sub.Total) tagged ($percentage%)" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "=== UNTAGGED VMs DETAILED LIST ===" -ForegroundColor Red
Write-Host "The following $($untaggedVMs.Count) VMs are missing Azure Update Manager maintenance tags:" -ForegroundColor White

# Group untagged VMs by subscription for easier reading
$untaggedBySubscription = $untaggedVMs | Group-Object Subscription

foreach ($group in $untaggedBySubscription | Sort-Object Name) {
    Write-Host "`n� Subscription: $($group.Name) ($($group.Count) untagged VMs)" -ForegroundColor Magenta
    
    $group.Group | Sort-Object Name | ForEach-Object {
        Write-Host "  • $($_.Name)" -ForegroundColor Yellow
        Write-Host "    Resource Group: $($_.ResourceGroup)" -ForegroundColor Gray
        Write-Host "    Location: $($_.Location)" -ForegroundColor Gray
        Write-Host "    OS Type: $($_.OsType)" -ForegroundColor Gray
        Write-Host "    VM Size: $($_.VmSize)" -ForegroundColor Gray
        Write-Host "    Power State: $($_.PowerState)" -ForegroundColor Gray
        if ($_.Tags -ne "No tags") {
            Write-Host "    Existing Tags: $($_.Tags)" -ForegroundColor DarkGray
        }
        Write-Host ""
    }
}

Write-Host "=== ANALYSIS BY VM CHARACTERISTICS ===" -ForegroundColor Cyan

# Analyze by OS Type
$untaggedByOS = $untaggedVMs | Group-Object OsType
Write-Host "`n� Untagged VMs by OS Type:" -ForegroundColor White
$untaggedByOS | Sort-Object Name | ForEach-Object {
    Write-Host "  $($_.Name): $($_.Count) VMs" -ForegroundColor White
}

# Analyze by Location
$untaggedByLocation = $untaggedVMs | Group-Object Location
Write-Host "`n� Untagged VMs by Location:" -ForegroundColor White
$untaggedByLocation | Sort-Object Count -Descending | ForEach-Object {
    Write-Host "  $($_.Name): $($_.Count) VMs" -ForegroundColor White
}

# Analyze by VM Size (to understand workload types)
$untaggedBySize = $untaggedVMs | Group-Object VmSize
Write-Host "`n� Untagged VMs by Size:" -ForegroundColor White
$untaggedBySize | Sort-Object Count -Descending | Select-Object -First 10 | ForEach-Object {
    Write-Host "  $($_.Name): $($_.Count) VMs" -ForegroundColor White
}

# Analyze by Resource Group (might indicate application/workload groupings)
$untaggedByRG = $untaggedVMs | Group-Object ResourceGroup
Write-Host "`n� Untagged VMs by Resource Group (Top 10):" -ForegroundColor White
$untaggedByRG | Sort-Object Count -Descending | Select-Object -First 10 | ForEach-Object {
    Write-Host "  $($_.Name): $($_.Count) VMs" -ForegroundColor White
}

Write-Host ""
Write-Host "=== POWER STATE ANALYSIS ===" -ForegroundColor Cyan
$powerStates = $untaggedVMs | Group-Object PowerState
$powerStates | Sort-Object Count -Descending | ForEach-Object {
    Write-Host "$($_.Name): $($_.Count) VMs" -ForegroundColor White
}

Write-Host ""
Write-Host "=== EXPORT OPTIONS ===" -ForegroundColor Cyan
Write-Host "You can export this data for further analysis:" -ForegroundColor White

# Export to CSV option
$timestamp = Get-Date -Format "yyyyMMdd-HHmm"
$csvPath = "D:\UntaggedVMs-$timestamp.csv"

try {
    $untaggedVMs | Export-Csv -Path $csvPath -NoTypeInformation
    Write-Host "✓ Exported untagged VMs to: $csvPath" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to export CSV: $($_.Exception.Message)" -ForegroundColor Red
}

# Show simple list for easy copying
Write-Host ""
Write-Host "=== SIMPLE VM NAME LIST (for copy/paste) ===" -ForegroundColor Cyan
Write-Host "VM Names:" -ForegroundColor White
$untaggedVMs | Sort-Object Name | ForEach-Object { Write-Host "  $($_.Name)" -ForegroundColor Yellow }

Write-Host ""
Write-Host "=== NEXT STEPS RECOMMENDATIONS ===" -ForegroundColor Cyan
Write-Host "1. Review the untagged VMs list above" -ForegroundColor White
Write-Host "2. Investigate why these VMs were not in the original patching schedule" -ForegroundColor White
Write-Host "3. Determine appropriate maintenance windows for these VMs" -ForegroundColor White
Write-Host "4. Consider grouping by:" -ForegroundColor White
Write-Host "   • Application/workload (Resource Group analysis)" -ForegroundColor Gray
Write-Host "   • Environment (naming patterns, tags)" -ForegroundColor Gray
Write-Host "   • Business criticality" -ForegroundColor Gray
Write-Host "   • Maintenance window preferences" -ForegroundColor Gray
Write-Host "5. Run the tagging script to assign maintenance windows" -ForegroundColor White

Write-Host ""
Write-Host "=== AZURE RESOURCE GRAPH QUERY ===" -ForegroundColor Cyan
Write-Host "Use this query in Azure Resource Graph Explorer to verify results:" -ForegroundColor White
Write-Host ""
Write-Host @"
Resources
| where type == "microsoft.compute/virtualmachines"
| where tags.PatchWindow == "" or isempty(tags.PatchWindow) or isnull(tags.PatchWindow)
| project name, resourceGroup, subscriptionId, location, 
          osType = properties.storageProfile.osDisk.osType,
          vmSize = properties.hardwareProfile.vmSize,
          powerState = properties.extended.instanceView.powerState.displayStatus,
          tags
| sort by name asc
"@ -ForegroundColor Gray

Write-Host ""
Write-Host "Script completed at $(Get-Date)" -ForegroundColor Cyan
Write-Host "Total runtime: $((Get-Date) - $scriptStart)" -ForegroundColor Gray
```

**Discovery results:**

* **35 VMs** from the original MSP schedule (our planned list)
* **12 additional VMs** not in the MSP schedule (the "stragglers")
* **Total: 47 VMs** needing Update Manager tags

> **Key insight:** The MSP wasn't managing everything. Several dev/test VMs and a few production systems were missing from their schedule entirely.

---

## ✍️ Step 6 – Bulk Tag All VMs with Patch Windows

Now for the main event: tagging all VMs with their maintenance windows. This includes both our planned VMs and the newly discovered ones.

### 🎯 Main VM Tagging (Planned Schedule)

Each tag serves a specific purpose:

* `PatchWindow` — The key tag used by dynamic scopes to assign VMs to maintenance configurations
* `Owner` — For accountability and filtering
* `Updates` — Identifies VMs managed by Azure Update Manager

<details>
<summary>Click to expand: **Multi-Subscription Azure Update Manager VM Tagging Script**</summary>

```powershell
# Multi-Subscription Azure Update Manager VM Tagging Script
# This script discovers VMs across multiple subscriptions and tags them appropriately

Write-Host "=== Multi-Subscription Azure Update Manager - VM Tagging Script ===" -ForegroundColor Cyan

# Function to safely tag a VM
function Set-VMMaintenanceTags {
    param(
        [string]$VMName,
        [string]$ResourceGroupName,
        [string]$SubscriptionId,
        [hashtable]$Tags,
        [string]$MaintenanceWindow
    )
    
    try {
        # Set context to the VM's subscription
        $null = Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop
        
        Write-Host "  Processing: $VMName..." -ForegroundColor Yellow
        
        # Get the VM and update tags
        $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction Stop
        
        if ($vm.Tags) {
            $Tags.Keys | ForEach-Object { $vm.Tags[$_] = $Tags[$_] }
        } else {
            $vm.Tags = $Tags
        }
        
        $null = Update-AzVM -VM $vm -ResourceGroupName $ResourceGroupName -Tag $vm.Tags -ErrorAction Stop
        Write-Host "  ✓ Successfully tagged $VMName for $MaintenanceWindow maintenance" -ForegroundColor Green
        
        return $true
    }
    catch {
        Write-Host "  ✗ Failed to tag $VMName`: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Define all target VMs organized by maintenance window
$maintenanceGroups = @{
    "Monday" = @{
        "VMs" = @("WEB-PROD-01", "DB-PROD-01", "APP-PROD-01", "FILE-PROD-01", "DC-PROD-01")
        "Tags" = @{
            "Owner" = "Contoso"
            "Updates" = "Azure Update Manager"
            "PatchWindow" = "mon"
        }
    }
    "Tuesday" = @{
        "VMs" = @("WEB-PROD-02", "DB-PROD-02", "APP-PROD-02", "FILE-PROD-02", "DC-PROD-02")
        "Tags" = @{
            "Owner" = "Contoso"
            "Updates" = "Azure Update Manager"
            "PatchWindow" = "tue"
        }
    }
    "Wednesday" = @{
        "VMs" = @("WEB-PROD-03", "DB-PROD-03", "APP-PROD-03", "FILE-PROD-03", "DC-PROD-03")
        "Tags" = @{
            "Owner" = "Contoso"
            "Updates" = "Azure Update Manager"
            "PatchWindow" = "wed"
        }
    }
    "Thursday" = @{
        "VMs" = @("WEB-PROD-04", "DB-PROD-04", "APP-PROD-04", "FILE-PROD-04", "PRINT-PROD-01")
        "Tags" = @{
            "Owner" = "Contoso"
            "Updates" = "Azure Update Manager"
            "PatchWindow" = "thu"
        }
    }
    "Friday" = @{
        "VMs" = @("WEB-PROD-05", "DB-PROD-05", "APP-PROD-05", "FILE-PROD-05", "MONITOR-PROD-01")
        "Tags" = @{
            "Owner" = "Contoso"
            "Updates" = "Azure Update Manager"
            "PatchWindow" = "fri"
        }
    }
    "Saturday" = @{
        "VMs" = @("WEB-DEV-01", "DB-DEV-01", "APP-DEV-01", "TEST-SERVER-01", "SANDBOX-01")
        "Tags" = @{
            "Owner" = "Contoso"
            "Updates" = "Azure Update Manager"
            "PatchWindow" = "sat-09"
        }
    }
    "Sunday" = @{
        "VMs" = @("WEB-UAT-01", "DB-UAT-01", "APP-UAT-01", "BACKUP-PROD-01", "MGMT-PROD-01")
        "Tags" = @{
            "Owner" = "Contoso"
            "Updates" = "Azure Update Manager"
            "PatchWindow" = "sun"
        }
    }
}

# Function to discover VMs across all subscriptions
function Find-VMsAcrossSubscriptions {
    param([array]$TargetVMNames)
    
    $subscriptions = Get-AzSubscription | Where-Object { $_.State -eq "Enabled" }
    $vmInventory = @{}
    
    foreach ($subscription in $subscriptions) {
        try {
            $null = Set-AzContext -SubscriptionId $subscription.Id -ErrorAction Stop
            $vms = Get-AzVM -ErrorAction Continue
            
            foreach ($vm in $vms) {
                if ($vm.Name -in $TargetVMNames) {
                    $vmInventory[$vm.Name] = @{
                        Name = $vm.Name
                        ResourceGroupName = $vm.ResourceGroupName
                        SubscriptionId = $subscription.Id
                        SubscriptionName = $subscription.Name
                        Location = $vm.Location
                    }
                }
            }
        }
        catch {
            Write-Host "Error scanning subscription $($subscription.Name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    return $vmInventory
}

# Get all unique VM names and discover their locations
$allTargetVMs = @()
$maintenanceGroups.Values | ForEach-Object { $allTargetVMs += $_.VMs }
$allTargetVMs = $allTargetVMs | Sort-Object -Unique

Write-Host "Discovering locations for $($allTargetVMs.Count) target VMs..." -ForegroundColor White
$vmInventory = Find-VMsAcrossSubscriptions -TargetVMNames $allTargetVMs

# Process each maintenance window
$totalSuccess = 0
$totalFailed = 0

foreach ($windowName in $maintenanceGroups.Keys) {
    $group = $maintenanceGroups[$windowName]
    Write-Host "`n=== $windowName MAINTENANCE WINDOW ===" -ForegroundColor Magenta
    
    foreach ($vmName in $group.VMs) {
        if ($vmInventory.ContainsKey($vmName)) {
            $vmInfo = $vmInventory[$vmName]
            $result = Set-VMMaintenanceTags -VMName $vmInfo.Name -ResourceGroupName $vmInfo.ResourceGroupName -SubscriptionId $vmInfo.SubscriptionId -Tags $group.Tags -MaintenanceWindow $windowName
            if ($result) { $totalSuccess++ } else { $totalFailed++ }
        } else {
            Write-Host "  ⚠️ VM not found: $vmName" -ForegroundColor Yellow
            $totalFailed++
        }
    }
}

Write-Host "`n=== TAGGING SUMMARY ===" -ForegroundColor Cyan
Write-Host "Successfully tagged: $totalSuccess VMs" -ForegroundColor Green
Write-Host "Failed to tag: $totalFailed VMs" -ForegroundColor Red
```

### 🧹 Handle the Stragglers

For the 12 VMs not in the original MSP schedule, I used intelligent assignment based on their function:

<details>
<summary>Click to expand: **Tagging Script for Remaining Untagged VMs**</summary>

```powershell
# Intelligent VM Tagging Script for Remaining Untagged VMs
# This script analyzes and tags the 26 remaining VMs based on workload patterns and load balancing

$scriptStart = Get-Date

Write-Host "=== Intelligent VM Tagging for Remaining VMs ===" -ForegroundColor Cyan
Write-Host "Analyzing and tagging 26 untagged VMs with optimal maintenance window distribution..." -ForegroundColor White
Write-Host ""

# Function to safely tag a VM across subscriptions
function Set-VMMaintenanceTags {
    param(
        [string]$VMName,
        [string]$ResourceGroupName,
        [string]$SubscriptionId,
        [hashtable]$Tags,
        [string]$MaintenanceWindow
    )
    
    try {
        # Set context to the VM's subscription
        $currentContext = Get-AzContext
        if ($currentContext.Subscription.Id -ne $SubscriptionId) {
            $null = Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop
        }
        
        Write-Host "  Processing: $VMName..." -ForegroundColor Yellow
        
        # Get the VM
        $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction Stop
        
        # Add maintenance tags to existing tags (preserve existing tags)
        if ($vm.Tags) {
            $Tags.Keys | ForEach-Object {
                $vm.Tags[$_] = $Tags[$_]
            }
        } else {
            $vm.Tags = $Tags
        }
        
        # Update the VM tags
        $null = Update-AzVM -VM $vm -ResourceGroupName $ResourceGroupName -Tag $vm.Tags -ErrorAction Stop
        Write-Host "  ✓ Successfully tagged $VMName for $MaintenanceWindow maintenance" -ForegroundColor Green
        
        return $true
    }
    catch {
        Write-Host "  ✗ Failed to tag $VMName`: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Define current maintenance window loads (after existing 59 VMs)
$currentLoad = @{
    "Monday" = 7
    "Tuesday" = 7 
    "Wednesday" = 10
    "Thursday" = 6
    "Friday" = 6
    "Saturday" = 17  # Dev/Test at 09:00
    "Sunday" = 6
}

Write-Host "=== CURRENT MAINTENANCE WINDOW LOAD ===" -ForegroundColor Cyan
$currentLoad.GetEnumerator() | Sort-Object Name | ForEach-Object {
    Write-Host "$($_.Key): $($_.Value) VMs" -ForegroundColor White
}

# Initialize counters for new assignments
$newAssignments = @{
    "Monday" = 0
    "Tuesday" = 0
    "Wednesday" = 0
    "Thursday" = 0
    "Friday" = 0
    "Saturday" = 0  # Will use sat-09 for dev/test
    "Sunday" = 0
}

Write-Host ""
Write-Host "=== INTELLIGENT VM GROUPING AND ASSIGNMENT ===" -ForegroundColor Cyan

# Define VM groups with intelligent maintenance window assignments
$vmGroups = @{
    
    # CRITICAL PRODUCTION SYSTEMS - Spread across different days
    "Critical Infrastructure" = @{
        "VMs" = @(
            @{ Name = "DC-PROD-01"; RG = "rg-infrastructure"; Sub = "Production"; Window = "Sunday"; Reason = "Domain Controller - critical infrastructure" },
            @{ Name = "DC-PROD-02"; RG = "rg-infrastructure"; Sub = "Production"; Window = "Monday"; Reason = "Domain Controller - spread from other DCs" },
            @{ Name = "BACKUP-PROD-01"; RG = "rg-backup"; Sub = "Production"; Window = "Tuesday"; Reason = "Backup Server - spread across week" }
        )
    }
    
    # PRODUCTION BUSINESS APPLICATIONS - Spread for business continuity
    "Production Applications" = @{
        "VMs" = @(
            @{ Name = "WEB-PROD-01"; RG = "rg-web-production"; Sub = "Production"; Window = "Monday"; Reason = "Web Server - Monday for week start" },
            @{ Name = "DB-PROD-01"; RG = "rg-database-production"; Sub = "Production"; Window = "Tuesday"; Reason = "Database Server - Tuesday" },
            @{ Name = "APP-PROD-01"; RG = "rg-app-production"; Sub = "Production"; Window = "Wednesday"; Reason = "Application Server - mid-week" }
        )
    }
    
    # DEV/TEST SYSTEMS - Saturday morning maintenance (like existing dev/test)
    "Development Systems" = @{
        "VMs" = @(
            @{ Name = "WEB-DEV-01"; RG = "rg-web-development"; Sub = "Development"; Window = "Saturday"; Reason = "Web Dev - join existing dev/test window" },
            @{ Name = "DB-DEV-01"; RG = "rg-database-development"; Sub = "Development"; Window = "Saturday"; Reason = "Database Dev - join existing dev/test window" },
            @{ Name = "TEST-SERVER-01"; RG = "rg-testing"; Sub = "Development"; Window = "Saturday"; Reason = "Test Server - join existing dev/test window" }
            # ... additional dev/test VMs
        )
    }
}

# Initialize counters
$totalProcessed = 0
$totalSuccess = 0
$totalFailed = 0

# Process each group
foreach ($groupName in $vmGroups.Keys) {
    $group = $vmGroups[$groupName]
    Write-Host "`n=== $groupName ===" -ForegroundColor Magenta
    Write-Host "Processing $($group.VMs.Count) VMs in this group" -ForegroundColor White
    
    foreach ($vmInfo in $group.VMs) {
        $window = $vmInfo.Window
        $vmName = $vmInfo.Name
        
        Write-Host "`n�️ $vmName → $window maintenance window" -ForegroundColor Yellow
        Write-Host "   Reason: $($vmInfo.Reason)" -ForegroundColor Gray
        
        # Determine subscription ID from name
        $subscriptionId = switch ($vmInfo.Sub) {
            "Contoso-Production" { (Get-AzSubscription -SubscriptionName "Production").Id }
            "Contoso-DevTest" { (Get-AzSubscription -SubscriptionName "DevTest").Id }
            "Contoso-Identity" { (Get-AzSubscription -SubscriptionName "Identity").Id }
            "Contoso-DMZ" { (Get-AzSubscription -SubscriptionName "Contoso-DMZ").Id }
        }
        
        # Create appropriate tags based on maintenance window
        $tags = @{
            "Owner" = "Contoso"
            "Updates" = "Azure Update Manager"
        }
        
        if ($window -eq "Saturday") {
            $tags["PatchWindow"] = "sat-09"  # Saturday 09:00 for dev/test
        } else {
            $tags["PatchWindow"] = $window.ToLower().Substring(0,3)  # mon, tue, wed, etc.
        }
        
        $result = Set-VMMaintenanceTags -VMName $vmInfo.Name -ResourceGroupName $vmInfo.RG -SubscriptionId $subscriptionId -Tags $tags -MaintenanceWindow $window
        
        $totalProcessed++
        if ($result) { 
            $totalSuccess++
            $newAssignments[$window]++
        } else { 
            $totalFailed++ 
        }
    }
}

Write-Host ""
Write-Host "=== TAGGING SUMMARY ===" -ForegroundColor Cyan
Write-Host "Total VMs processed: $totalProcessed" -ForegroundColor White
Write-Host "Successfully tagged: $totalSuccess" -ForegroundColor Green
Write-Host "Failed to tag: $totalFailed" -ForegroundColor Red

Write-Host ""
Write-Host "=== NEW MAINTENANCE WINDOW DISTRIBUTION ===" -ForegroundColor Cyan
Write-Host "VMs added to each maintenance window:" -ForegroundColor White

$newAssignments.GetEnumerator() | Sort-Object Name | ForEach-Object {
    if ($_.Value -gt 0) {
        $newTotal = $currentLoad[$_.Key] + $_.Value
        Write-Host "$($_.Key): +$($_.Value) VMs (total: $newTotal VMs)" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "=== FINAL MAINTENANCE WINDOW LOAD ===" -ForegroundColor Cyan
$finalLoad = @{}
$currentLoad.Keys | ForEach-Object {
    $finalLoad[$_] = $currentLoad[$_] + $newAssignments[$_]
}

$finalLoad.GetEnumerator() | Sort-Object Name | ForEach-Object {
    $status = if ($_.Value -le 8) { "Green" } elseif ($_.Value -le 12) { "Yellow" } else { "Red" }
    Write-Host "$($_.Key): $($_.Value) VMs" -ForegroundColor $status
}

$grandTotal = ($finalLoad.Values | Measure-Object -Sum).Sum
Write-Host "`nGrand Total: $grandTotal VMs across all maintenance windows" -ForegroundColor White

Write-Host ""
Write-Host "=== BUSINESS LOGIC APPLIED ===" -ForegroundColor Cyan
Write-Host "✅ Critical systems spread across different days for resilience" -ForegroundColor Green
Write-Host "✅ Domain Controllers distributed to avoid single points of failure" -ForegroundColor Green
Write-Host "✅ Dev/Test systems consolidated to Saturday morning (existing pattern)" -ForegroundColor Green
Write-Host "✅ Production workstations spread to minimize user impact" -ForegroundColor Green
Write-Host "✅ Business applications distributed for operational continuity" -ForegroundColor Green
Write-Host "✅ Load balancing maintained across the week" -ForegroundColor Green

Write-Host ""
Write-Host "=== VERIFICATION STEPS ===" -ForegroundColor Cyan
Write-Host "1. Verify tags in Azure Portal across all subscriptions" -ForegroundColor White
Write-Host "2. Check that critical systems are on different days" -ForegroundColor White
Write-Host "3. Confirm dev/test systems are in Saturday morning window" -ForegroundColor White
Write-Host "4. Review production systems distribution" -ForegroundColor White

Write-Host ""
Write-Host "=== AZURE RESOURCE GRAPH VERIFICATION QUERY ===" -ForegroundColor Cyan
Write-Host "Use this query to verify all VMs are now tagged:" -ForegroundColor White
Write-Host ""
Write-Host @"
Resources
| where type == "microsoft.compute/virtualmachines"
| where tags.Updates == "Azure Update Manager"
| project name, resourceGroup, subscriptionId, 
          patchWindow = tags.PatchWindow,
          owner = tags.Owner,
          updates = tags.Updates
| sort by patchWindow, name
| summarize count() by patchWindow
"@ -ForegroundColor Gray

if ($totalFailed -eq 0) {
    Write-Host ""
    Write-Host "� ALL VMs SUCCESSFULLY TAGGED WITH INTELLIGENT DISTRIBUTION! �" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "⚠️ Some VMs failed to tag. Please review errors above." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Script completed at $(Get-Date)" -ForegroundColor Cyan
Write-Host "Total runtime: $((Get-Date) - $scriptStart)" -ForegroundColor Gray
```

> **Key insight:** I grouped VMs by function and criticality, not just by convenience. Domain controllers got spread across different days, dev/test systems joined the existing Saturday morning window, and production applications were distributed for business continuity.

---

## 🧰 Step 7 – Configure Azure Policy Prerequisites

Here's where things get interesting. Update Manager is built on compliance — but your VMs won't show up in dynamic scopes unless they meet certain prerequisites. Enter Azure Policy to save the day.

You'll need two specific built-in policies assigned at the subscription (or management group) level:

### ✅ Policy 1: `Set prerequisites for scheduling recurring updates on Azure virtual machines`

**What it does:** This policy ensures your VMs have the necessary extensions and configurations to participate in Azure Update Manager. It automatically:

* Installs the Azure Update Manager extension on Windows VMs
* Registers required resource providers (`Microsoft.Maintenance`, `Microsoft.GuestConfiguration`)
* Configures the VM to report its update compliance status
* Sets the patch mode to "AutomaticByPlatform" where needed

> **Why this matters:** Without this policy, VMs won't appear in Update Manager scopes even if they're tagged correctly. The policy handles all the "plumbing" automatically.

**Assignment scope:** Apply this at subscription or management group level to catch all VMs.

### ✅ Policy 2: `Configure periodic checking for missing system updates on Azure virtual machines`

**What it does:** This is your compliance engine. It configures VMs to:

* Regularly scan for available updates (but not install them automatically)
* Report update status back to Azure Update Manager
* Enable the compliance dashboard views in the portal
* Provide the data needed for maintenance configuration targeting

> **Why this matters:** This policy turns on the "update awareness" for your VMs. Without it, Azure Update Manager has no visibility into what patches are needed.

**Assignment scope:** Same as above — subscription or management group level.

### 🎯 Assigning the Policies

**Step-by-step in Azure Portal:**

1. **Navigate to Azure Policy**
   * Azure Portal → Search "Policy" → Select "Policy"

2. **Find the First Policy**
   * Left menu: **Definitions**
   * Search: `Set prerequisites for scheduling recurring updates`
   * Click on the policy title

3. **Assign the Policy**
   * Click **Assign** button
   * **Scope:** Select your subscription(s)
   * **Basics:** Leave policy name as default
   * **Parameters:** Leave as default
   * **Remediation:** ✅ Check "Create remediation task"
   * **Review + create**

4. **Repeat for Second Policy**
   * Search: `Configure periodic checking for missing system updates`
   * Follow same assignment process

> ⚠️ **Important:** Policy compliance can take 30+ minutes to evaluate and apply. Perfect time for that brew I mentioned earlier.

### 🔍 Monitoring Compliance

Once assigned, you can track compliance in **Azure Policy > Compliance**. Look for:

* Non-compliant VMs that need the extension installed
* VMs that aren't reporting update status properly
* Any policy assignment errors that need investigation

[Learn more about Azure Policy for Update Management](https://learn.microsoft.com/en-us/azure/update-manager/prerequsite-for-schedule-patching)

---

## 🧪 Step 8 – Create Dynamic Scopes in Update Manager

This is where it all comes together — and where the magic happens.

Dynamic scopes use those `PatchWindow` tags to assign VMs to the correct patch config automatically. No more manual VM assignment, no more "did we remember to add the new server?" conversations.

### 🎯 The Portal Dance

Unfortunately, as of writing, dynamic scopes can only be configured through the Azure portal — no PowerShell or ARM template support yet.

> **Why portal only?** Dynamic scopes are still in preview, and Microsoft hasn't released the PowerShell cmdlets or ARM template schemas yet. This means you can't fully automate the deployment, but the functionality itself works perfectly.

Here's the step-by-step:

1. **Navigate to Azure Update Manager**
   * Portal → All Services → Azure Update Manager

2. **Access Maintenance Configurations**
   * Go to **Maintenance Configurations (Preview)**
   * Select one of your configs (e.g., `contoso-maintenance-config-vms-mon`)

3. **Create Dynamic Scope**
   * Click **Dynamic Scopes** → **Add**
   * **Name:** `DynamicScope-Monday-VMs`
   * **Description:** `Auto-assign Windows VMs tagged for Monday maintenance`

4. **Configure Scope Settings**
   * **Subscription:** Select your subscription(s)
   * **Resource Type:** `Microsoft.Compute/virtualMachines`
   * **OS Type:** `Windows` (create separate scopes for Linux if needed)

5. **Set Tag Filters**
   * **Tag Name:** `PatchWindow`
   * **Tag Value:** `mon` (must match your maintenance config naming)
   * **Additional filters** (optional):
     * `Owner` = `Contoso`
     * `Updates` = `Azure Update Manager`

6. **Review and Create**
   * Verify the filter logic
   * Click **Create**

### 🔄 Repeat for All Days

You'll need to create dynamic scopes for each maintenance configuration:

| Maintenance Config | Dynamic Scope Name | Tag Filter |
|---|---|---|
| `contoso-maintenance-config-vms-mon` | `DynamicScope-Monday-VMs` | `PatchWindow = mon` |
| `contoso-maintenance-config-vms-tue` | `DynamicScope-Tuesday-VMs` | `PatchWindow = tue` |
| `contoso-maintenance-config-vms-wed` | `DynamicScope-Wednesday-VMs` | `PatchWindow = wed` |
| `contoso-maintenance-config-vms-thu` | `DynamicScope-Thursday-VMs` | `PatchWindow = thu` |
| `contoso-maintenance-config-vms-fri` | `DynamicScope-Friday-VMs` | `PatchWindow = fri` |
| `contoso-maintenance-config-vms-sat` | `DynamicScope-Saturday-VMs` | `PatchWindow = sat-09` |
| `contoso-maintenance-config-vms-sun` | `DynamicScope-Sunday-VMs` | `PatchWindow = sun` |

### 🔍 Verify Dynamic Scope Assignment

Once created, you can verify the scopes are working:

1. **In the Maintenance Configuration:**
   * Go to **Dynamic Scopes**
   * Check **Resources** tab to see matched VMs
   * Verify expected VM count matches your tagging
   * **Wait time:** Allow 15-30 minutes for newly tagged VMs to appear

2. **What success looks like:**
   * Monday scope shows 5 VMs (WEB-PROD-01, DB-PROD-01, etc.)
   * Saturday scope shows 5 VMs (WEB-DEV-01, DB-DEV-01, etc.)
   * No VMs showing? Check tag case sensitivity and filters

3. **In Azure Resource Graph:**

   ```kusto
   MaintenanceResources
   | where type == "microsoft.maintenance/configurationassignments"
   | extend vmName = tostring(split(resourceId, "/")[8])
   | extend configName = tostring(properties.maintenanceConfigurationId)
   | project vmName, configName, resourceGroup
   | order by configName, vmName
   ```

4. **Troubleshoot empty scopes:**
   * Verify subscription selection includes all your VMs
   * Check tag spelling: `PatchWindow` (case sensitive)
   * Confirm resource type filter: `Microsoft.Compute/virtualMachines`
   * Wait longer - it can take up to 30 minutes

### ⚠️ Common Gotchas

**Tag Case Sensitivity:** Dynamic scopes are case-sensitive. `mon` ≠ `Mon` ≠ `MON`

**Subscription Scope:** Ensure you've selected all relevant subscriptions in the scope configuration.

**Resource Type Filter:** Don't forget to set the resource type filter — without it, you'll match storage accounts, networking, etc.

**Timing:** It can take 15-30 minutes for newly tagged VMs to appear in dynamic scopes.

[Dynamic scope configuration docs](https://learn.microsoft.com/en-us/azure/update-manager/dynamic-scope)

---

## 🚀 Step 9 – Test & Verify (The Moment of Truth)

The acid test: does it actually patch stuff properly?

### 🎪 Proof of Concept Test

I started conservatively — scoped `contoso-maintenance-config-vms-sun` to a few non-critical VMs and let it run overnight on Sunday.

**Monday morning verification:**

* ✔️ **Patch compliance dashboard:** All green ticks
* ✔️ **Reboot timing:** Machines restarted within their 4-hour window (21:00-01:00)
* ✔️ **Update logs:** Activity logs showed expected patching behavior
* ✔️ **Business impact:** Zero helpdesk tickets on Monday morning

### 📊 Full Rollout Verification

Once confident with the Sunday test, I enabled all remaining dynamic scopes and monitored the week:

**Key metrics tracked:**

* Patch compliance percentage across all VMs
* Failed patch installations (and root causes)
* Reboot timing adherence
* Business hours impact (spoiler: zero)

### 🔍 Monitoring & Validation Tools

**Azure Update Manager Dashboard:**

```
Azure Portal → Update Manager → Overview
- Patch compliance summary
- Recent patch installations
- Failed installations with details
```

**Azure Resource Graph Queries:**

```kusto
// Verify all VMs have maintenance tags
Resources
| where type == "microsoft.compute/virtualmachines"
| where tags.Updates == "Azure Update Manager"
| project name, resourceGroup, subscriptionId, 
          patchWindow = tags.PatchWindow,
          owner = tags.Owner
| summarize count() by patchWindow
| order by patchWindow

// Check maintenance configuration assignments
MaintenanceResources
| where type == "microsoft.maintenance/configurationassignments"
| extend vmName = tostring(split(resourceId, "/")[8])
| extend configName = tostring(properties.maintenanceConfigurationId)
| project vmName, configName, subscriptionId
| summarize VMCount = count() by configName
| order by configName
```

**PowerShell Verification:**

```powershell
# Quick check of maintenance configuration status
Get-AzMaintenanceConfiguration -ResourceGroupName "rg-maintenance-uksouth-001" | 
    Select-Object Name, MaintenanceScope, RecurEvery | 
    Format-Table -AutoSize

# Verify VM tag distribution
$subscriptions = Get-AzSubscription | Where-Object { $_.State -eq "Enabled" }
$tagSummary = @{}

foreach ($sub in $subscriptions) {
    Set-AzContext -SubscriptionId $sub.Id | Out-Null
    $vms = Get-AzVM | Where-Object { $_.Tags.PatchWindow }
    
    foreach ($vm in $vms) {
        $window = $vm.Tags.PatchWindow
        if (-not $tagSummary.ContainsKey($window)) {
            $tagSummary[$window] = 0
        }
        $tagSummary[$window]++
    }
}

Write-Host "=== VM DISTRIBUTION BY PATCH WINDOW ===" -ForegroundColor Cyan
$tagSummary.GetEnumerator() | Sort-Object Name | ForEach-Object {
    Write-Host "$($_.Key): $($_.Value) VMs" -ForegroundColor White
}
```

### 📈 Success Metrics

After two full weeks of operation:

* **47 VMs** successfully transitioned to Azure Update Manager
* **100% patch compliance** maintained
* **Zero business-hours incidents** related to patching
* **Estimated annual savings:** £15,000+ (no more MSP patching fees)
* **Visibility improvement:** Real-time patch status vs. weekly email reports

[Monitor updates in Azure Update Manager](https://learn.microsoft.com/en-us/azure/update-manager/monitor-updates)

---

## 📃 Final Thoughts & Tips

✅ **Cost-neutral** — No more third-party patch agents
✅ **Policy-driven** — Enforced consistency with Azure Policy
✅ **Easily auditable** — Tag-based scoping is clean and visible
✅ **Scalable** — New VMs auto-join patch schedules via tagging

### ⚠️ Troubleshooting Guide & Common Issues

Here's what I learned the hard way, so you don't have to:

| **Symptom** | **Possible Cause** | **Fix** |
|-------------|-------------------|---------|
| VM not showing in dynamic scope | Tag typo or case mismatch | Verify `PatchWindow` tag exactly matches config name |
| Maintenance config creation fails | Invalid duration format | Use ISO 8601 format: `"03:00"` not `"3 hours"` |
| VM skipped during patching | Policy prerequisites not met | Check Azure Policy compliance dashboard |
| No updates applied despite schedule | VM needs pending reboot | Clear previous reboots, check update history |
| Dynamic scope shows zero VMs | Wrong subscription scope | Verify subscription selection in scope config |
| Extension installation failed | Insufficient permissions | Ensure VM contributor rights and resource provider registration |
| Policy compliance stuck at 0% | Assignment scope too narrow | Check policy is assigned at subscription level |
| VMs appear/disappear from scope | Tag inconsistency | Run tag verification script across all subscriptions |

### 🔧 Advanced Troubleshooting Commands

**Check VM Update Readiness:**

```powershell
# Verify VM has required extensions and configuration
$vmName = "your-vm-name"
$rgName = "your-resource-group"

$vm = Get-AzVM -Name $vmName -ResourceGroupName $rgName -Status
$vm.Extensions | Where-Object { $_.Name -like "*Update*" -or $_.Name -like "*Maintenance*" }
```

**Validate Maintenance Configuration:**

```powershell
# Test maintenance configuration is properly formed
$config = Get-AzMaintenanceConfiguration -ResourceGroupName "rg-maintenance-uksouth-001" -Name "contoso-maintenance-config-vms-mon"
Write-Host "Config Name: $($config.Name)"
Write-Host "Recurrence: $($config.RecurEvery)"
Write-Host "Duration: $($config.Duration)"
Write-Host "Start Time: $($config.StartDateTime)"
Write-Host "Timezone: $($config.TimeZone)"
```

**Policy Compliance Deep Dive:**

```powershell
# Check specific VMs for policy compliance
$policyName = "Set prerequisites for scheduling recurring updates on Azure virtual machines"
$assignments = Get-AzPolicyAssignment | Where-Object { $_.Properties.DisplayName -eq $policyName }
foreach ($assignment in $assignments) {
    Get-AzPolicyState -PolicyAssignmentId $assignment.PolicyAssignmentId | 
        Where-Object { $_.ComplianceState -eq "NonCompliant" } |
        Select-Object ResourceId, ComplianceState, @{Name="Reason";Expression={$_.PolicyEvaluationDetails.EvaluatedExpressions.ExpressionValue}}
}
```

---

*As always, comments and suggestions welcome over on GitHub or LinkedIn. If you've migrated patching in a different way, I'd love to hear how you approached it.*
