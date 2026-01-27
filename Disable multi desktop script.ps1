# 1. Target the Global Policies (Machine-Wide)
$registryPaths = @(
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
)

foreach ($path in $registryPaths) {
    if (-not (Test-Path $path)) {
        New-Item -Path $path -Force | Out-Null
    }
}

# 2. Apply Restrictions
# Disable Virtual Desktop creation
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "NoDesktopCreation" -Value 1 -Type DWord

# Hide the Task View button from the Taskbar for all users
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "HideTaskViewButton" -Value 1 -Type DWord

# Kill the Win+Tab hotkey (adding 'Tab' to DisabledHotkeys)
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "DisabledHotkeys" -Value "Tab" -Type String

# 3. Apply to the Default User Profile (for all future logins)
# We load the Default User hive, modify it, then unload it.
reg load "HKU\DefaultUser" "C:\Users\Default\NTUSER.DAT"
reg add "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ShowTaskViewButton" /t REG_DWORD /d 0 /f
reg add "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "DisabledHotkeys" /t REG_SZ /d "Tab" /f
reg unload "HKU\DefaultUser"

Write-Host "System-level restrictions applied for Multi-Desktop and Win+Tab."
