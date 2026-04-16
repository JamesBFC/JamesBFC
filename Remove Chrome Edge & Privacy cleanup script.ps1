# Requires Run as Administrator / SYSTEM context

Write-Output "Starting public PC privacy & maintenance script..."

# ---------------------------------------------------------
# 1. UNINSTALL MOZILLA FIREFOX
# ---------------------------------------------------------
Write-Output "Checking for Mozilla Firefox..."
$ffPaths = @(
    "${env:ProgramFiles}\Mozilla Firefox\uninstall\helper.exe",
    "${env:ProgramFiles(x86)}\Mozilla Firefox\uninstall\helper.exe"
)

foreach ($path in $ffPaths) {
    if (Test-Path $path) {
        Write-Output "Found Firefox uninstaller at $path. Uninstalling silently..."
        Start-Process -FilePath $path -ArgumentList "/S" -Wait -NoNewWindow
    }
}

# ---------------------------------------------------------
# 2. UNINSTALL GOOGLE CHROME
# ---------------------------------------------------------
Write-Output "Checking for Google Chrome..."

# Check for Chrome Enterprise MSI Installation
$chromeMsi = Get-CimInstance -Class Win32_Product | Where-Object { $_.Name -match "Google Chrome" }
if ($chromeMsi) {
    Write-Output "Found Chrome MSI. Uninstalling..."
    $chromeMsi.Uninstall() | Out-Null
}

# Check for System-Level EXE Installation
$chromeRegPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Google Chrome",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Google Chrome"
)

foreach ($regPath in $chromeRegPaths) {
    if (Test-Path $regPath) {
        $chromeReg = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
        if ($chromeReg.UninstallString) {
            $uninstallExe = $chromeReg.UninstallString -replace '"', ''
            if ($uninstallExe -match "setup\.exe") {
                Write-Output "Found Chrome EXE installer. Uninstalling silently..."
                $chromeArgs = "--uninstall --system-level --force-uninstall"
                Start-Process -FilePath $uninstallExe -ArgumentList $chromeArgs -Wait -NoNewWindow
            }
        }
    }
}

# ---------------------------------------------------------
# 3. CONFIGURE MICROSOFT EDGE TO CLEAR DATA ON EXIT
# ---------------------------------------------------------
Write-Output "Configuring Microsoft Edge Enterprise Policies..."

$edgePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
$clearDataListPath = "$edgePolicyPath\ClearBrowsingDataOnExitList"

if (!(Test-Path $edgePolicyPath)) { New-Item -Path $edgePolicyPath -Force | Out-Null }
if (!(Test-Path $clearDataListPath)) { New-Item -Path $clearDataListPath -Force | Out-Null }

$dataTypesToClear = @(
    "browsing_history", "download_history", "cookies_and_other_site_data",
    "cached_images_and_files", "passwords", "autofill", "site_settings", "hosted_app_data"
)

for ($i = 0; $i -lt $dataTypesToClear.Count; $i++) {
    $valueName = ($i + 1).ToString()
    $valueData = $dataTypesToClear[$i]
    Set-ItemProperty -Path $clearDataListPath -Name $valueName -Value $valueData -Type String
}

# ---------------------------------------------------------
# 4. WINDOWS EXPLORER (WIN 11) - DISABLE RECENT FILES
# ---------------------------------------------------------
Write-Output "Disabling Windows 11 Explorer recent file tracking..."

$explorerPolicyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
if (!(Test-Path $explorerPolicyPath)) { New-Item -Path $explorerPolicyPath -Force | Out-Null }

# Disables history of recently opened documents and hides them from Quick Access/Home
Set-ItemProperty -Path $explorerPolicyPath -Name "NoRecentDocsHistory" -Value 1 -Type DWord
# Clears whatever might currently be lingering in the recent docs list on exit
Set-ItemProperty -Path $explorerPolicyPath -Name "ClearRecentDocsOnExit" -Value 1 -Type DWord


# ---------------------------------------------------------
# 5. MICROSOFT OFFICE - DISABLE RECENT FILES
# ---------------------------------------------------------
Write-Output "Disabling Microsoft Office recent files..."
# Note: Version '16.0' applies to Office 2016, 2019, 2021, and Microsoft 365 Apps.

# Method A: Apply to Local Machine (HKLM)
$officeMachinePolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Common\General"
if (!(Test-Path $officeMachinePolicy)) { New-Item -Path $officeMachinePolicy -Force | Out-Null }
Set-ItemProperty -Path $officeMachinePolicy -Name "MaxDisplay" -Value 0 -Type DWord
Set-ItemProperty -Path $officeMachinePolicy -Name "RecentFolders" -Value 0 -Type DWord

# Method B: Apply to all currently loaded User Hives (HKU)
# Because SYSTEM doesn't touch logged-in user settings directly, we loop through all active profiles.
$userHives = Get-ChildItem -Path "Registry::HKEY_USERS" | Where-Object { $_.Name -notmatch "_Classes$" }

foreach ($hive in $userHives) {
    $officeUserPolicy = "Registry::HKEY_USERS\$($hive.PSChildName)\SOFTWARE\Policies\Microsoft\Office\16.0\Common\General"
    if (!(Test-Path $officeUserPolicy)) { 
        New-Item -Path $officeUserPolicy -Force | Out-Null 
    }
    Set-ItemProperty -Path $officeUserPolicy -Name "MaxDisplay" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $officeUserPolicy -Name "RecentFolders" -Value 0 -Type DWord -ErrorAction SilentlyContinue
}

Write-Output "Script execution completed successfully."