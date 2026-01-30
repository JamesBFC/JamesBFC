# --- 1. PREP: Ensure Policy Paths Exist ---
$policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
$advancedPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

if (-not (Test-Path $policyPath)) { New-Item -Path $policyPath -Force | Out-Null }
if (-not (Test-Path $advancedPath)) { New-Item -Path $advancedPath -Force | Out-Null }

# --- 2. FEATURE BLOCK: Disable Virtual Desktop Creation & Task View Button ---
# This prevents the OS from allowing new desktops even if they find a way into the UI
Set-ItemProperty -Path $policyPath -Name "NoDesktopCreation" -Value 1 -Type DWord
Set-ItemProperty -Path $policyPath -Name "HideTaskViewButton" -Value 1 -Type DWord

# --- 3. SHORTCUT BLOCK: Disable Win+Tab Hotkey ---
# This tells the shell to ignore 'Tab' when combined with the Windows Key
Set-ItemProperty -Path $advancedPath -Name "DisabledHotkeys" -Value "Tab" -Type String

# --- 4. ACCESSIBILITY BLOCK: Disable Modern Touch Keyboard Service ---
# This stops the 'Touch Keyboard' tray icon and functionality
Set-Service -Name "TabletInputService" -StartupType Disabled
Stop-Service -Name "TabletInputService" -Force -ErrorAction SilentlyContinue

# --- 5. APP BLOCK: Disable Legacy On-Screen Keyboard (osk.exe) ---
# This prevents the old-school OSK from launching if they search for it
$oskBlockPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\osk.exe"
if (-not (Test-Path $oskBlockPath)) { New-Item -Path $oskBlockPath -Force | Out-Null }
Set-ItemProperty -Path $oskBlockPath -Name "Debugger" -Value "ntsd -d" -Type String

# --- 6. DEFAULT PROFILE: Apply to all future user logins ---
# We load the default user hive to ensure the Task View button is hidden by default for everyone
reg load "HKU\DefaultUser" "C:\Users\Default\NTUSER.DAT"
reg add "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ShowTaskViewButton" /t REG_DWORD /d 0 /f
reg add "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "DisabledHotkeys" /t REG_SZ /d "Tab" /f
reg unload "HKU\DefaultUser"

Write-Host "Master Lockdown Complete. Machine is ready for Deep Freeze reboot." -ForegroundColor Cyan