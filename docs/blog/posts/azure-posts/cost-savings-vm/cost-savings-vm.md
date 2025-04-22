---
title: "Saving Azure Costs with Scheduled VM Start/Stop using Custom Azure Automation Runbooks"
date:
  created: 2025-04-22
  updated: 2025-04-22
authors:
  - matthew
description: "Implement cost-saving automation in Azure using lightweight, tag-driven runbooks to start and stop virtual machines on a daily schedule. This post walks through an end-to-end setup using Azure Automation and PowerShell."
categories:
  - Azure
  - Automation
  - FinOps
  - PowerShell
tags:
  - azure automation
  - vm schedule
  - cost optimisation
  - powershell
  - finops
  - azure vm
---

# 💰 Saving Azure Costs with Scheduled VM Start/Stop using Custom Azure Automation Runbooks

As part of my ongoing commitment to FinOps practices, I've implemented several strategies to embed cost-efficiency into the way we manage cloud infrastructure. One proven tactic is scheduling virtual machines to shut down during idle periods, avoiding unnecessary spend.

In this post, I’ll share how I’ve built out **custom Azure Automation jobs** to schedule VM start and stop operations. Rather than relying on Microsoft’s pre-packaged solution, I’ve developed a **streamlined, purpose-built PowerShell implementation** that provides maximum flexibility, transparency, and control.

---

## ✍️ Why I Chose Custom Runbooks Over the Prebuilt Solution

Microsoft provides a ready-made “Start/Stop VMs during off-hours” solution via the Automation gallery. While functional, it’s:

- A bit over-engineered for simple needs,
- Relatively opaque under the hood, and
- Not ideal for environments where control and transparency are priorities.

My custom jobs:

- Use native PowerShell modules within Azure Automation,
- Are scoped to exactly the VMs I want via **tags**,
- Provide clean logging and alerting, and
- Keep things simple, predictable, and auditable.

---

## 🛠️ Step 1: Set Up the Azure Automation Account

> 🔗 [Official docs: Create and manage an Azure Automation Account](https://learn.microsoft.com/en-us/azure/automation/automation-create-standalone-account)

1. Go to the **Azure Portal** and search for **Automation Accounts**.
2. Click **+ Create**.
3. Fill out the basics:
   - **Name**: e.g. `vm-scheduler`
   - **Resource Group**: Create new or select existing
   - **Region**: Preferably where your VMs are located
   - Enable **System-Assigned Managed Identity**
4. Once created, go to the Automation Account and ensure the following modules are imported using the **Modules** blade in the Azure Portal:
   - `Az.Accounts`
   - `Az.Compute`

> ✅ Tip: These modules can be added from the gallery in just a few clicks via the UI—no scripting required.

> 💡 Prefer scripting? You can also install them using PowerShell:
>
> ```powershell
> Install-Module -Name Az.Accounts -Force
> Install-Module -Name Az.Compute -Force
> ```

5. Assign the **Virtual Machine Contributor** role to the Automation Account's managed identity at the resource group or subscription level.

### ⚙️ CLI or PowerShell alternatives

```bash
# Azure CLI example to create the automation account
az automation account create \
  --name vm-scheduler \
  --resource-group MyResourceGroup \
  --location uksouth \
  --assign-identity
```

---

## 📅 Step 2: Add VM Tags for Scheduling

Apply consistent tags to any VM you want the runbooks to manage.

| Key            | Value      |
|----------------|------------|
| `AutoStartStop` | `devserver` |

You can use the Azure Portal or PowerShell to apply these tags.

### ⚙️ Tag VMs via PowerShell

```powershell
$vm = Get-AzVM -ResourceGroupName "MyRG" -Name "myVM"
$vm.Tags["AutoStartStop"] = "devserver"
Update-AzVM -VM $vm -ResourceGroupName "MyRG"
```

---

## 📂 Step 3: Create the Runbooks

> 🔗 [Official docs: Create a runbook in Azure Automation](https://learn.microsoft.com/en-us/azure/automation/automation-runbook-create)

### ▶️ Create a New Runbook

1. In your Automation Account, go to **Process Automation** > **Runbooks**.
2. Click **+ Create a runbook**.
3. Name it something like `Stop-TaggedVMs`.
4. Choose **PowerShell** as the type.
5. Paste in the code below (repeat this process for the start runbook later).

### 🔹 Runbook Code: Auto-Stop Based on Tags

```powershell
Param
(    
    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()]
    [String]
    $AzureVMName = "All",

    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]
    [String]
    $AzureSubscriptionID = "<your-subscription-id>"
)

try {
    "Logging in to Azure..."
    # Authenticate using the system-assigned managed identity of the Automation Account
    Connect-AzAccount -Identity -AccountId "<managed-identity-client-id>"
} catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}

$TagName  = "AutoStartStop"
$TagValue = "devserver"

Set-AzContext -Subscription $AzureSubscriptionID

if ($AzureVMName -ne "All") {
    $VMs = Get-AzResource -TagName $TagName -TagValue $TagValue | Where-Object {
        $_.ResourceType -like 'Microsoft.Compute/virtualMachines' -and $_.Name -like $AzureVMName
    }
} else {
    $VMs = Get-AzResource -TagName $TagName -TagValue $TagValue | Where-Object {
        $_.ResourceType -like 'Microsoft.Compute/virtualMachines'
    }
}

foreach ($VM in $VMs) {
    Stop-AzVM -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name -Verbose -Force
}
```

> 🔗 [Docs: Connect-AzAccount with Managed Identity](https://learn.microsoft.com/en-us/powershell/module/az.accounts/connect-azaccount)

### 🔹 Create the Start Runbook

Duplicate the above, replacing `Stop-AzVM` with `Start-AzVM`.

> 🔗 [Docs: Start-AzVM](https://learn.microsoft.com/en-us/powershell/module/az.compute/start-azvm)

---

## ⏰ Step 4: Create and Link Schedules

> 🔗 [Docs: Create schedules in Azure Automation](https://learn.microsoft.com/en-us/azure/automation/automation-schedules)

1. Go to the Automation Account > **Schedules** > **+ Add a schedule**.
2. Create two schedules:
   - `DailyStartWeekdays` — Recurs every weekday at 07:30
   - `DailyStopWeekdays` — Recurs every weekday at 18:30
3. Go to each runbook > **Link to schedule** > Choose the matching schedule.

> 📊 You can get creative here: separate schedules for dev vs UAT, or different times for different departments.

---

## 🧪 Testing Your Runbooks

You can test each runbook directly in the portal:

- Open the runbook
- Click **Edit** > **Test Pane**
- Provide test parameters if needed
- Click **Start** and monitor output

This is also a good time to validate:

- The identity has permission
- The tags are applied correctly
- The VMs are in a stopped or running state as expected

---

## 📊 The Results

Even this lightweight automation has produced major savings in our environment. Non-prod VMs are now automatically turned off outside office hours, resulting in monthly compute savings of up to **60%** without sacrificing availability during working hours.

---

## 🧠 Ideas for Further Enhancement

- Pull tag values from a central config (e.g. Key Vault or Storage Table)
- Add logic to check for active RDP sessions or Azure Monitor heartbeats
- Alert via email or Teams on job success/failure
- Track savings over time and visualize them

---

## 💭 Final Thoughts

If you’re looking for a practical, immediate way to implement FinOps principles in Azure, VM scheduling is a great place to start. With minimal setup and maximum flexibility, custom runbooks give you control without the complexity of the canned solutions.

Have you built something similar or extended this idea further? I’d love to hear about it—drop me a comment or reach out on LinkedIn.

Stay tuned for more FinOps tips coming soon!
