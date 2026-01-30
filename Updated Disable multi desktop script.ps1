# --- 1. PREP: Ensure Policy Paths Exist ---
$policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
$advancedPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
$keyboardPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout"

if (-not (Test-Path $policyPath)) { New-Item -Path $policyPath -Force | Out-Null }
if (-not (Test-Path $advancedPath)) { New-Item -Path $advancedPath -Force | Out-Null }

# --- 2. HARDWARE BLOCK: Scancode Map (The "Nuclear" Fix) ---
# This disables the Left Windows Key and Right Windows Key at the driver level.
# This is the only way to 100% stop Win+Tab if registry policies are ignored.
$scancodeValue = ([byte[]](
    0x00, 0x00, 0x00, 0x00, # Header
    0x00, 0x00, 0x00, 0x00, # Flags
    0x03, 0x00, 0x00, 0x00, # 2 keys + 1 terminator
    0x00, 0x00, 0x5b, 0xe0, # Left Win
    0x00, 0x00, 0x5c, 0xe0, # Right Win
    0x00, 0x00, 0x00, 0x00  # Terminator
))
Set-ItemProperty -Path $keyboardPath -Name "Scancode Map" -Value $scancodeValue -Type Binary

# --- 3. FEATURE BLOCK: Disable Virtual Desktop Creation & Task View Button ---
Set-ItemProperty -Path $policyPath -Name "NoDesktopCreation" -Value 1 -Type DWord
Set-ItemProperty -Path $policyPath -Name "HideTaskViewButton" -Value 1 -Type DWord

# --- 4. APP BLOCK: Disable Legacy On-Screen Keyboard (osk.exe) ---
$oskBlockPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\osk.exe"
if (-not (Test-Path $oskBlockPath)) { New-Item -Path $oskBlockPath -Force | Out-Null }
Set-ItemProperty -Path $oskBlockPath -Name "Debugger" -Value "ntsd -d" -Type String

# --- 5. DEFAULT PROFILE: Apply to all future user logins ---
reg load "HKU\DefaultUser" "C:\Users\Default\NTUSER.DAT"
reg add "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ShowTaskViewButton" /t REG_DWORD /d 0 /f
# We keep the soft-block here as a secondary layer
reg add "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "DisabledHotkeys" /t REG_SZ /d "Tab" /f
reg unload "HKU\DefaultUser"

Write-Host "Master Hardware & Software Lockdown Complete." -ForegroundColor Green
Write-Host "IMPORTANT: A REBOOT IS REQUIRED for the hardware key block to activate." -ForegroundColor Yellow
