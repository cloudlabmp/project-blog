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
- Update real application code to remove SQL credentials

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

- An **Azure SQL Managed Instance** with Microsoft Entra (AAD) authentication enabled
- A **User Assigned Managed Identity** (UAMI)
- An **Azure VM or App Service** to host your app (or test client)
- The **Go-based `sqlcmd` CLI** installed  
  → [Install guide](https://learn.microsoft.com/sql/tools/sqlcmd-utility?view=sql-server-ver16)

---

## 🔧 Setting Up the User Assigned Managed Identity (UAMI)

Before connecting to Azure SQL using UAMI, ensure the following steps are completed:

- Create the UAMI
- Assign the UAMI to the Virtual Machine(s)
- Configure Microsoft Entra authentication on the SQL Managed Instance
- Grant SQL access to the UAMI

These steps can be completed via **Azure CLI**, **PowerShell**, or the **Azure Portal**.

---

### 🛠️ Step 1: Create the User Assigned Managed Identity (UAMI)

#### ✅ CLI

```bash
az identity create \
  --name my-sql-uami \
  --resource-group my-rg \
  --location <region>
```

Save the **Client ID** and **Object ID** — you’ll need them later.

#### ✅ Portal

1. Go to **Azure Portal** → Search **Managed Identities**
2. Click **+ Create**
3. Choose Subscription, Resource Group, and Region
4. Name the identity (e.g., `my-sql-uami`)
5. Click **Review + Create**

---

### 🖇️ Step 2: Assign the UAMI to a Virtual Machine

Attach the UAMI to:

- The VM(s) running your application code
- The VM used to test the connection

#### ✅ CLI

```bash
az vm identity assign \
  --name my-vm-name \
  --resource-group my-rg \
  --identities my-sql-uami
```

#### ✅ Portal

1. Go to **Virtual Machines** → Select your VM
2. Click **Identity** under **Settings**
3. Go to the **User assigned** tab
4. Click **+ Add** → Select the UAMI
5. Click **Add**

---

### 🔑 Step 3: Configure SQL Managed Instance for Microsoft Entra Authentication

1. **Set an Entra Admin**:
   - Go to your SQL MI → **Azure AD admin** blade
   - Click **Set admin** and choose a user or group
   - Save changes

2. **Ensure Directory Reader permissions**:
   - Your SQL MI’s managed identity needs **Directory Reader** access
   - You can assign this role via Entra ID > Roles and administrators > Directory Readers

More details: [Configure Entra authentication](https://learn.microsoft.com/azure/azure-sql/database/authentication-aad-configure)

---

### 📜 Step 4: (Optional) Assign Azure Role to the UAMI

> This may be needed if the identity needs to access Azure resource metadata or use Azure CLI from the VM.

#### ✅ CLI

```bash
az role assignment create \
  --assignee-object-id <uami-object-id> \
  --role "Reader" \
  --scope /subscriptions/<sub-id>/resourceGroups/<rg-name>
```

#### ✅ Portal

1. Go to the UAMI → **Azure role assignments**
2. Click **+ Add role assignment**
3. Choose role (e.g., Reader)
4. Set scope
5. Click **Save**

---

## 🔑 Step 5: Grant SQL Access to the UAMI

Once the UAMI is assigned to the VM and Entra auth is enabled on SQL MI, log in with an admin and run:

```sql
CREATE USER [<client-id>] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [<client-id>];
ALTER ROLE db_datawriter ADD MEMBER [<client-id>];
```

Or use a friendly name:

```sql
CREATE USER [my-app-identity] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [my-app-identity];
```

---

## 🧪 Step 6: Test the Connection Using `sqlcmd`

```bash
sqlcmd \
  -S <your-sql-mi>.database.windows.net \
  -d <database-name> \
  --authentication-method ActiveDirectoryManagedIdentity \
  -U <client-id-of-uami>
```

If successful, you’ll see the `1>` prompt where you can execute SQL queries.

---

## 📊 Step 7: Update Application Code

Update your app to use the UAMI for authentication.

Example connection string for UAMI in C#:

```csharp
string connectionString = @"Server=tcp:<your-sql-mi>.database.windows.net;" +
                          "Authentication=Active Directory Managed Identity;" +
                          "Encrypt=True;" +
                          "User Id=<your-uami-client-id>;" +
                          "Database=<your-db-name>;";
```

> Make sure your code uses `Microsoft.Data.SqlClient` with AAD token support.

Or retrieve and assign the token programmatically:

```csharp
var credential = new DefaultAzureCredential();
var token = await credential.GetTokenAsync(new TokenRequestContext(
    new[] { "https://database.windows.net/" }));

var connection = new SqlConnection("Server=<your-sql-mi>; Database=<your-db-name>; Encrypt=True;");
connection.AccessToken = token.Token;
```

---

## 🔒 Security Benefits

- 🔐 No credentials stored
- 🔁 No password rotation
- 🛡️ Entra-integrated access control and auditing

---

## ✅ Summary

By switching to User Assigned Managed Identity, we removed credentials from connection strings and aligned SQL access with best practices for cloud identity and security.

Comments and feedback welcome!
