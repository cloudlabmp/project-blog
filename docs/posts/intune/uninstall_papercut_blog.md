---
title: "Uninstalling PaperCut MF Client via Intune – A Step-by-Step Guide"
date:
  created: 2025-03-11
  updated: 2025-03-11
authors:
  - matthew
description: "A guide to unistalling software using Powershell and Intune"
categories:
  - Intune
  - Automation
  - Scripting
tags:
  - intune
  - powershell
  - automation

---

# 📢 Uninstalling PaperCut MF Client via Intune – A Step-by-Step Guide 🚀

## **🔍 Scenario Overview**

Managing software across an enterprise can be a headache, especially when it comes to **removing outdated applications**. Recently, I needed to **uninstall the PaperCut MF Client from multiple Windows PCs** in my environment. The challenge? Ensuring a clean removal **without user intervention** and **no leftover files**.

Rather than relying on manual uninstallation, we used **Microsoft Intune** to deploy a **PowerShell script** that handles the removal automatically. This blog post details the full process, from **script development to deployment and testing**.

---

## **🎯 The Goal**

✅ Uninstall the PaperCut MF Client **silently**  
✅ Ensure **no residual files** are left behind  
✅ Deploy the solution **via Intune** as a PowerShell script (NOT as a Win32 app)  
✅ Test both **locally** and **remotely** before large-scale deployment  

---

## **🛠 Step 1: Writing the Uninstall Script**

We first created a **PowerShell script** to:

1. **Stop PaperCut-related processes**
2. **Run the built-in uninstaller (`unins000.exe`)** if present
3. **Use MSIEXEC to remove the MSI-based install**
4. **Forcefully delete any remaining files and registry entries**

### **📝 The Uninstall Script**

```powershell
# Define variables
$UninstallExePath = "C:\Program Files (x86)\PaperCut MF Client\unins000.exe"
$MsiProductCode = "{5B4B80DE-34C4-11E9-9CA9-F53BB8A68831}"  # Replace with actual Product Code
$LogFile = "C:\ProgramData\AXA-Custom-Intune-Scripts\Papercut-Uninstall.log"
$InstallPath = "C:\Program Files (x86)\PaperCut MF Client"

# Function to log output
Function Write-Log {
    param ([string]$Message)
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$TimeStamp - $Message" | Out-File -Append -FilePath $LogFile
}

Write-Log "Starting PaperCut MF Client uninstallation process."

# Stop any running PaperCut processes before uninstalling
$Processes = @("pc-client", "pc-client-java", "pc-client-local-cache")  # Common PaperCut processes
foreach ($Process in $Processes) {
    if (Get-Process -Name $Process -ErrorAction SilentlyContinue) {
        Write-Log "Stopping process: $Process"
        Stop-Process -Name $Process -Force -ErrorAction SilentlyContinue
    }
}

# Check if unins000.exe exists
if (Test-Path $UninstallExePath) {
    Write-Log "Found unins000.exe at $UninstallExePath. Initiating uninstallation."
    Start-Process -FilePath $UninstallExePath -ArgumentList "/SILENT" -NoNewWindow -Wait
    Write-Log "Uninstallation process completed using unins000.exe."
} else {
    Write-Log "unins000.exe not found. Attempting MSI uninstallation using Product Code $MsiProductCode."
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $MsiProductCode /qn /norestart" -NoNewWindow -Wait
}

# Forcefully delete the remaining installation folder
if (Test-Path $InstallPath) {
    Write-Log "Residual files found at $InstallPath. Attempting to remove forcefully."
    takeown /F "$InstallPath" /R /D Y | Out-Null
    icacls "$InstallPath" /grant Administrators:F /T /C /Q | Out-Null
    Remove-Item -Path $InstallPath -Recurse -Force -ErrorAction SilentlyContinue
    if (-not (Test-Path $InstallPath)) {
        Write-Log "SUCCESS: Residual files successfully removed."
    } else {
        Write-Log "ERROR: Failed to remove residual files. Manual intervention may be required."
    }
} else {
    Write-Log "No residual files found."
}

Write-Log "PaperCut MF Client uninstallation script execution finished."
```

---

## **🧪 Step 2: Testing the Script Locally**

Before deploying via Intune, it's best to **test locally**:

1. **Open PowerShell as Administrator**
2. **Run the script manually**:

   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File "C:\Path\To\Script.ps1"
   ```

3. **Verify**:
   - Check `C:\Program Files (x86)\PaperCut MF Client` to confirm deletion
   - Check `C:\ProgramData\AXA-Custom-Intune-Scripts\Papercut-Uninstall.log` for success logs

---

## **🌍 Step 3: Running the Script on a Remote PC**

If you need to test the script remotely before deploying via Intune:

```powershell
$RemotePC = "COMPUTER-NAME"  # Change this to the target PC name
Invoke-Command -ComputerName $RemotePC -FilePath "C:\Path\To\Script.ps1" -Credential (Get-Credential)
```

---

## **📡 Step 4: Deploying via Intune**

Instead of packaging the script as a `.intunewin` file, we will deploy it **as a PowerShell script in Intune**.

### **🎯 Steps to Deploy in Intune**

1. **Go to** Microsoft Endpoint Manager admin center (**endpoint.microsoft.com**)
2. Navigate to **Devices > Scripts**
3. Click **Add > Windows 10 and later**
4. **Upload the PowerShell script** (`Papercut-Uninstall.ps1`)
5. Configure settings:
   - **Run script using the logged-on credentials?** → **No** (runs as SYSTEM)
   - **Enforce script signature check?** → **No**
   - **Run script in 64-bit PowerShell Host?** → **Yes**
6. **Assign the script to device groups** (not users)
7. **Monitor deployment logs** in Intune

---

## **📌 Final Thoughts**

By using **Intune and PowerShell**, we successfully automated the **silent uninstallation** of PaperCut MF Client. This approach ensures a **zero-touch removal** with **no residual files**, keeping endpoints clean and manageable. 🚀

Got questions or need enhancements? Drop them in the comments! 😊
