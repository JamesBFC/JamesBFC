# 1. Define Registry Paths
$policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
$advancedPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

# Create Policy key if it doesn't exist
if (-not (Test-Path $policyPath)) {
    New-Item -Path $policyPath -Force | Out-Null
}

# 2. Apply the Restrictions
# Disables Virtual Desktop creation and hides the Task View button
Set-ItemProperty -Path $policyPath -Name "NoDesktopCreation" -Value 1 -Type DWord
Set-ItemProperty -Path $policyPath -Name "HideTaskViewButton" -Value 1 -Type DWord

# Disables the Win+Tab Hotkey combination
Set-ItemProperty -Path $advancedPath -Name "DisabledHotkeys" -Value "Tab" -Type String

# 3. Force Registry to save to disk immediately
# This is crucial for Deep Freeze to "see" the change before a potential state change
[void][Microsoft.Win32.Registry]::SetValue("HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Explorer", "NoDesktopCreation", 1)

Write-Host "Multi-Desktop and Win+Tab disabled successfully."