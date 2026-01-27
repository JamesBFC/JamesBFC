# 1. Block the Virtual Desktop Feature entirely
$policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
if (-not (Test-Path $policyPath)) { New-Item -Path $policyPath -Force }

# This is the "Nuclear Option" for Virtual Desktops
Set-ItemProperty -Path $policyPath -Name "NoDesktopCreation" -Value 1 -Type DWord
Set-ItemProperty -Path $policyPath -Name "HideTaskViewButton" -Value 1 -Type DWord

# 2. Block the Hotkey for physical keyboards
$advancedPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-ItemProperty -Path $advancedPath -Name "DisabledHotkeys" -Value "Tab" -Type String

# 3. Disable the Touch Keyboard/Handwriting service (The OSK Backdoor)
# This prevents the touch-style keyboard from appearing in the tray
Set-Service -Name "TabletInputService" -StartupType Disabled
Stop-Service -Name "TabletInputService" -Force -ErrorAction SilentlyContinue

# 4. Force Registry to Disk for Deep Freeze
[Microsoft.Win32.Registry]::SetValue("HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Explorer", "NoDesktopCreation", 1)

Write-Host "Multi-desktop creation and OSK-backdoor disabled." -ForegroundColor Green
