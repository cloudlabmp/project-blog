---
title: "Replacing SAS Tokens with User Assigned Managed Identity (UAMI) in AzCopy for Blob Uploads"
date:
  created: 2025-03-28
  updated: 2025-03-28
authors:
  - matthew
description: "A step-by-step guide to replacing AzCopy SAS token authentication with User Assigned Managed Identity (UAMI) for uploading files to Azure Blob Storage."
categories:
  - Azure
  - Storage
  - Identity
  - Automation
tags:
  - azure
  - azcopy
  - blob storage
  - uami
  - identity
  - sas
  - powershell
---

# Replacing SAS Tokens with User Assigned Managed Identity (UAMI) in AzCopy for Blob Uploads

Using Shared Access Signature (SAS) tokens with `azcopy` is common — but rotating tokens and handling them securely can be a hassle. To improve security and simplify our automation, I recently replaced SAS-based authentication in our scheduled AzCopy jobs with **Azure User Assigned Managed Identity (UAMI)**.

In this post, I’ll walk through how to:

- Replace AzCopy SAS tokens with managed identity authentication
- Assign the right roles to the UAMI
- Use `azcopy login` to authenticate non-interactively
- Automate the whole process in PowerShell

---

## 🔍 Why Remove SAS Tokens?

SAS tokens are useful, but:

- 🔑 They’re still secrets — and secrets can be leaked
- 📅 They expire — which breaks automation when not rotated
- 🔐 They grant broad access — unless scoped very carefully

Managed Identity is a much better approach when the copy job is running from within Azure (like an Azure VM or Automation account).

---

## 🌟 Project Goal

> Replace the use of SAS tokens in an AzCopy job that uploads files from a local UNC share to Azure Blob Storage — by using a **User Assigned Managed Identity**.

---

## ✅ Prerequisites

To follow along, you’ll need:

- A **User Assigned Managed Identity** (UAMI)
- A **Windows Server or Azure VM** to run the copy job
- Access to a **local source folder or UNC share** (e.g., `\\fileserver\\data\\export\\`)
- **AzCopy v10.7+** installed on the machine
- Azure RBAC permissions to assign roles

> ℹ️ **Check AzCopy Version:**
> Run `azcopy --version` to ensure you're using **v10.7.0 or later**, which is required for `--identity-client-id` support.

---

## 🔧 Step-by-Step Setup

### 🛠️ Step 1: Create the UAMI

#### ✅ CLI

```bash
az identity create \
  --name my-azcopy-uami \
  --resource-group my-resource-group \
  --location <region>
```

#### ✅ Portal

1. Go to **Managed Identities** in the Azure Portal
2. Click **+ Create** and follow the wizard

---

### 🖇️ Step 2: Assign the UAMI to the Azure VM

AzCopy running on a VM must be able to assume the identity. Assign the UAMI to your VM:

#### ✅ CLI

```bash
az vm identity assign \
  --name my-vm-name \
  --resource-group my-resource-group \
  --identities my-azcopy-uami
```

#### ✅ Portal

1. Navigate to the **Virtual Machines** blade
2. Select the VM running your AzCopy script
3. Under **Settings**, click **Identity**
4. Go to the **User assigned** tab
5. Click **+ Add**, select your UAMI, then click **Add**

---

### 🔐 Step 3: Assign RBAC Permissions to UAMI

For AzCopy to function correctly with a UAMI, the following role assignments are recommended:

- **Storage Blob Data Contributor**: Required for read/write blob operations
- **Storage Blob Data Reader**: (Optional) For read-only scenarios or validation scripts
- **Reader**: (Optional) For browsing or metadata-only permissions on the storage account

> ⏳ **RBAC Tip**: It may take up to 5 minutes for role assignments to propagate fully. If access fails initially, wait and retry.

#### ✅ CLI

```bash
az role assignment create \
  --assignee <client-id-or-object-id> \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Storage/storageAccounts/<storage-account>/blobServices/default/containers/<container-name>"

az role assignment create \
  --assignee <client-id-or-object-id> \
  --role "Storage Blob Data Reader" \
  --scope "/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Storage/storageAccounts/<storage-account>"

az role assignment create \
  --assignee <client-id-or-object-id> \
  --role "Reader" \
  --scope "/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Storage/storageAccounts/<storage-account>"
```

#### ✅ Portal

1. Go to your **Storage Account** in the Azure Portal
2. Click on the relevant **container** (or stay at the account level for broader scope)
3. Open **Access Control (IAM)**
4. Click **+ Add role assignment**
5. Repeat this for each role:
   - Select **Storage Blob Data Contributor**, assign to your UAMI, and click **Save**
   - Select **Storage Blob Data Reader**, assign to your UAMI, and click **Save**
   - Select **Reader**, assign to your UAMI, and click **Save**

---

### 🧪 Step 4: Test AzCopy Login Using UAMI

```powershell
$clientId = "<your-uami-client-id>"
& "C:\azcopy\azcopy.exe" login --identity --identity-client-id $clientId
```

You should see a confirmation message that AzCopy has successfully logged in.

> 🔍 To verify AzCopy is authenticated with the correct identity, you can run:
>
> ```
> azcopy env
> ```
>
> This will show the login type and confirm whether the token is being sourced from the Managed Identity.

---

### 📁 Step 5: Upload Files Using AzCopy + UAMI

Here's the PowerShell script that copies all files from a local share to the Blob container:

```powershell
$clientId = "<your-uami-client-id>"

# Login with Managed Identity
& "C:\azcopy\azcopy.exe" login --identity --identity-client-id $clientId

# Run the copy job
& "C:\azcopy\azcopy.exe" copy \
  "\\\\fileserver\\data\\export\\" \
  "https://<your-storage-account>.blob.core.windows.net/<container-name>" \
  --overwrite=true \
  --from-to=LocalBlob \
  --blob-type=Detect \
  --put-md5 \
  --recursive \
  --log-level=INFO
```

> 💡 **UNC Note**: Double backslashes are used in PowerShell to represent UNC paths properly.

This script can be scheduled using Task Scheduler or run on demand.

---

### ⏱️ Automate with Task Scheduler (Optional)

To automate the job:

1. Open **Task Scheduler** on your VM
2. Create a **New Task** (not a Basic Task)
3. Under **General**, select "Run whether user is logged on or not"
4. Under **Actions**, add a new action to run `powershell.exe`
5. Set the arguments to point to your `.ps1` script
6. Ensure the AzCopy path is hardcoded in your script

---

### 🚑 Troubleshooting Common Errors

#### ❌ 403 AuthorizationPermissionMismatch

- Usually means the identity doesn’t have the correct role or the role hasn’t propagated yet
- Double-check:
  - UAMI is assigned to the VM
  - UAMI has `Storage Blob Data Contributor` on the correct container
  - Wait 2–5 minutes and try again

#### ❌ azcopy : The term 'azcopy' is not recognized

- AzCopy is not in the system PATH
- Solution: Use the full path to `azcopy.exe`, like `C:\azcopy\azcopy.exe`

---

## 🛡️ Benefits of Switching to UAMI

- ✅ No secrets or keys stored on disk
- ✅ No manual token expiry issues
- ✅ Access controlled via Azure RBAC
- ✅ Easily scoped and auditable

---

## 🧼 Final Thoughts

Replacing AzCopy SAS tokens with UAMI is one of those small wins that pays dividends over time. Once set up, it's secure, robust, and hands-off.

Let me know if you'd like a variant of this that works from Azure Automation or a hybrid worker!

---
