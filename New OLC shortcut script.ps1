# Define the target application and shortcut details
$TargetPath = "https://bracknellforestcouncil.bksblive2.co.uk/bksbLive2/Login.aspx?ReturnUrl"
$ShortcutName = "OneAdvanced Online Learning.url"                  # Name of the shortcut
$PublicDesktop = "$env:PUBLIC\Desktop"       # Public Desktop folder path
$ShortcutPath = Join-Path $PublicDesktop $ShortcutName

# Create WScript.Shell COM object
$WshShell = New-Object -ComObject WScript.Shell

# Create the shortcut
$Shortcut = $WshShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = $TargetPath
$Shortcut.WorkingDirectory = Split-Path $TargetPath
$Shortcut.IconLocation = $TargetPath
$Shortcut.Save()

Write-Host "Shortcut created at $ShortcutPath"