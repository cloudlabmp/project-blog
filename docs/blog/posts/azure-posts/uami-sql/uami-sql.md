---
title: "Replacing SQL Credentials with User Assigned Managed Identity (UAMI) in Azure SQL Managed Instance"
date:
  created: 2025-03-27
  updated: 2025-03-27
authors:
  - matthew
description: "A step-by-step guide to replacing hardcoded SQL credentials with User Assigned Managed Identity (UAMI) authentication in Azure SQL Managed Instance."
categories:
  - Azure
  - SQL
  - Security
tags:
  - azure
  - sql
  - managed identity
  - uami
  - security
  - identity
---
# Replacing SQL Credentials with User Assigned Managed Identity (UAMI) in Azure SQL Managed Instance

Storing SQL usernames and passwords in application configuration files is still common practice — but it poses a significant security risk. As part of improving our cloud security posture, I recently completed a project to eliminate plain text credentials from our app connection strings by switching to **Azure User Assigned Managed Identity (UAMI)** authentication for our **SQL Managed Instance**.

In this post, I’ll walk through how to:

- Securely connect to Azure SQL Managed Instance without using usernames or passwords
- Use a **User Assigned Managed Identity (UAMI)** for authentication
- Test this connection using the new Go-based `sqlcmd` CLI

---

## 🔐 Why Replace SQL Credentials?

Hardcoded SQL credentials come with several downsides:

- **Security risk**: Stored secrets can be compromised if not properly secured
- **Maintenance overhead**: Rotating passwords across environments is cumbersome
- **Audit concerns**: Plain text credentials often trigger compliance red flags

Azure Managed Identity solves this by providing a token-based, identity-first way to connect to services — no secrets required.

---

## ⚙️ What is a User Assigned Managed Identity?

There are two types of Managed Identities in Azure:

- **System-assigned**: Tied to the lifecycle of a specific resource (like a VM or App Service)
- **User-assigned**: Standalone identity that can be attached to one or more resources

For this project, we used a **User Assigned Managed Identity (UAMI)** to allow our applications to authenticate against SQL without managing secrets.

---

## 🌟 Project Objective

> Replace plain text SQL credentials in application connection strings with **User Assigned Managed Identity (UAMI)** for secure, best-practice authentication to Azure SQL Managed Instances.

---

## ✅ Prerequisites

To follow this guide, you’ll need:

- An **Azure SQL Managed Instance** with AAD authentication enabled
- A **User Assigned Managed Identity** (UAMI)
- An **Azure VM or App Service** to host your app (or test client)
- The **Go-based `sqlcmd` CLI** installed  
  → [Install guide](https://learn.microsoft.com/sql/tools/sqlcmd-utility?view=sql-server-ver16)

---

## 🔧 Setting Up the User Assigned Managed Identity (UAMI)

Before you can connect to Azure SQL using UAMI, you'll need to:

- Create the identity
- Assign it to the correct VM(s)
- Grant it access in Azure SQL

You can do this via **Azure CLI** or the **Azure Portal** — both options are shown below.

---

### 🛠️ Step 1: Create the User Assigned Managed Identity (UAMI)

#### ✅ Option 1: Using Azure CLI

```bash
az identity create \
  --name my-sql-uami \
  --resource-group my-rg \
  --location <region>
```

Save the **Client ID** and **Object ID** from the output — you'll need them later.

#### ✅ Option 2: Using Azure Portal

1. Go to **Azure Portal** → Search for **Managed Identities**
2. Click **+ Create**
3. Select the **Subscription** and **Resource Group**
4. Enter a **Name** (e.g., `my-sql-uami`)
5. Choose a **Region** (same as your workload VM ideally)
6. Click **Review + Create** → **Create**

After it's created, click into the identity to view the **Client ID** and **Object ID** under the **Overview** blade.

---

### 📜 Step 2: (Optional) Assign Azure Role to the UAMI

> ✅ *This step is only optional if you're using the UAMI strictly for Azure SQL access. However, if your SQL client or tooling (e.g., Azure CLI running on a VM) needs to retrieve tokens via the Azure Instance Metadata Service, the UAMI must have at least Reader access on the resource it's authenticating against — typically the SQL Managed Instance.*

#### ✅ CLI

```bash
az role assignment create \
  --assignee-object-id <uami-object-id> \
  --role "Reader" \
  --scope /subscriptions/<sub-id>/resourceGroups/<rg-name>
```

#### ✅ Portal

1. Go to **Managed Identities** → Select your UAMI
2. Go to **Azure role assignments** → **+ Add role assignment**
3. Choose **Role** (e.g., Reader)
4. Scope to the correct **Subscription / Resource Group**
5. Click **Save**

---

### 🖇️ Step 3: Assign the UAMI to a Virtual Machine

Attach the UAMI to:

- The VM(s) running your application code
- The VM you’ll use to test the connection with `sqlcmd`

#### ✅ CLI

```bash
az vm identity assign \
  --identities my-sql-uami \
  --name my-vm-name \
  --resource-group my-rg
```

#### ✅ Portal

1. Go to **Virtual Machines** → Select your VM
2. In the **Settings** section, click **Identity**
3. Switch to the **User assigned** tab
4. Click **+ Add** → Select your **Managed Identity**
5. Click **Add**

Once assigned, the identity will appear in the list on the VM’s identity blade. You can now use it from that VM to authenticate to Azure SQL using `sqlcmd` or your application code.

---

## 🔑 Step 4: Grant SQL Access to the UAMI

Connect to your SQL Managed Instance using SSMS or `sqlcmd` with an admin account, then run:

```sql
CREATE USER [<client-id>] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [<client-id>];
```

You can also use a friendly name (recommended):

```sql
CREATE USER [my-app-identity] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [my-app-identity];
```

---

## 🧪 Step 5: Test the Connection Using `sqlcmd`

With the UAMI assigned to your VM, test the connection like this:

```bash
sqlcmd \
  -S <your-sql-mi>.database.windows.net \
  -d <database-name> \
  --authentication-method ActiveDirectoryManagedIdentity \
  -U <client-id-of-uami>
```

Replace:

- `<your-sql-mi>` with the FQDN of your SQL Managed Instance
- `<client-id-of-uami>` with your UAMI’s Azure **Client ID**

### ✅ Example

```bash
sqlcmd \
  -S <your-sql-mi-name>.database.windows.net \
  -d <your-database-name> \
  --authentication-method ActiveDirectoryManagedIdentity \
  -U <your-uami-client-id>
```

If successful, you’ll see the `1>` prompt where you can run SQL queries.

---

## 📊 Step 6: Update Application Code or Connection Logic

Depending on your app platform (VM, App Service, container, etc.), the app will now use the attached UAMI when connecting to SQL.

> Important: Your database client must support **AAD access tokens** or **MSI authentication**.

For example, in .NET Core, use `DefaultAzureCredential()` from the Azure Identity library to acquire a token automatically from the UAMI.

---

## 🔒 Security Benefits

By moving to Managed Identity authentication:

- 🔐 **No credentials stored** in config files or secret stores
- 🔁 **No password rotation** or key vault integration required
- 🛡️ **Stronger alignment** with zero trust and cloud-first security models

---

## ✅ Summary

We successfully replaced legacy SQL credentials with a secure, identity-based approach using **User Assigned Managed Identity** — improving both the security and maintainability of our app connections to Azure SQL.

---

Let me know if you'd like the full testing script or CI/CD steps to roll this into your pipeline. Comments or feedback welcome!
