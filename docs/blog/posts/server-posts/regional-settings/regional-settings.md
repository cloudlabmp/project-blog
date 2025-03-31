---
title: "Configuring UK Regional Settings on Windows Servers with PowerShell"
date:
  created: 2025-03-31
  updated: 2025-03-31
authors:
  - matthew
description: "A PowerShell-based guide to applying consistent UK regional settings to Windows Server systems, especially in cloud or automated environments."
categories:
  - Windows
  - PowerShell
  - Automation
  - Regional Settings
tags:
  - powershell
  - windows server
  - locale
  - automation
  - regional settings
  - uk
---

# Configuring UK Regional Settings on Windows Servers with PowerShell

When building out cloud-hosted or automated deployments of Windows Servers, especially for UK-based organisations, it’s easy to overlook **regional settings**. But these seemingly small configurations — like date/time formats, currency symbols, or keyboard layouts — can have a big impact on usability, application compatibility, and user experience.

In this post, I’ll show how I automate this using a simple PowerShell script that sets all relevant UK regional settings in one go.

---

## 🔍 Why Regional Settings Matter

Out-of-the-box, Windows often defaults to **en-US** settings:

- Date format becomes `MM/DD/YYYY`
- Decimal separators switch to `.` instead of `,`
- Currency symbols use `$`
- Time zones default to US-based settings
- Keyboard layout defaults to US (which can be infuriating!)

For UK-based organisations, this can:

- Cause confusion in logs or spreadsheets
- Break date parsing in scripts or apps expecting `DD/MM/YYYY`
- Result in the wrong characters being typed (e.g., `@` vs `"`)
- Require manual fixing after deployment

Automating this ensures **consistency across environments**, saves time, and avoids annoying regional mismatches.

---

## 🔧 Script Overview

I created a PowerShell script that:

- Sets the system locale and input methods
- Configures UK date/time formats
- Applies the British English language pack (if needed)
- Sets the time zone to GMT Standard Time (London)

The script can be run manually, included in provisioning pipelines, or dropped into automation tools like Task Scheduler or cloud-init processes.

---

## ✅ Prerequisites

To run this script, you should have:

- Administrator privileges
- PowerShell 5.1+ (default on most supported Windows Server versions)
- Optional: Internet access (if language pack needs to be added)

---

## 🔹 The Script: `Set-UKRegionalSettings.ps1`

```powershell
# Set system locale and formats to English (United Kingdom)
Set-WinSystemLocale -SystemLocale en-GB
Set-WinUserLanguageList -LanguageList en-GB -Force
Set-Culture en-GB
Set-WinHomeLocation -GeoId 242
Set-TimeZone -Id "GMT Standard Time"

# Optional reboot prompt
Write-Host "UK regional settings applied. A reboot is recommended for all changes to take effect."
```

---

## 🚀 How to Use It

### ✈️ Option 1: Manual Execution

1. Open **PowerShell as Administrator**
2. Run the script:

```powershell
.\Set-UKRegionalSettings.ps1
```

---

### 🔢 Option 2: Include in Build Pipeline or Image

For Azure VMs or cloud images, consider running this as part of your deployment process via:

- **Custom Script Extension** in ARM/Bicep
- **cloud-init** or **Terraform provisioners**
- **Group Policy Startup Script**

---

## ⚡ Quick Tips

- Reboot after running to ensure all settings apply across UI and system processes.
- For non-UK keyboards (like US physical hardware), you may also want to explicitly set `InputLocale`.
- Want to validate the settings? Use:

```powershell
Get-WinSystemLocale
Get-Culture
Get-WinUserLanguageList
Get-TimeZone
```

---

## 📂 Registry Verification: Per-User and Default Settings

![Registry Editor Screenshot](registry-editor.png)

If you're troubleshooting or validating the configuration for specific users, regional settings are stored in the **Windows Registry** under:

### 👤 For Each User Profile

```
HKEY_USERS\<SID>\Control Panel\International
```

You can find the user SIDs by looking under `HKEY_USERS` or using:

```powershell
Get-ChildItem Registry::HKEY_USERS
```

### 🧵 For New Users (Default Profile)

```
HKEY_USERS\.DEFAULT\Control Panel\International
```

This determines what settings new user profiles inherit on first logon.

You can script changes here if needed, but always test carefully to avoid corrupting profile defaults.

---

## 🌟 Final Thoughts

Small tweaks like regional settings might seem minor, but they go a long way in making your Windows Server environments feel localised and ready for your users.

Automating them early in your build pipeline means one less thing to worry about during post-deployment configuration.

Let me know if you want a version of this that handles **multi-user scenarios** or works across **multiple OS versions**!
