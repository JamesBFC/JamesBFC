$url = "https://bracknellforestcouncil.bksblive2.co.uk/bksbLive2/Login.aspx?ReturnUrl"
$name = "OneAdvanced Online Learning.url"
$shell = New-Object -ComObject WScript.Shell
$desktop = [System.Environment]::GetFolderPath("Desktop")
$shortcutPath = "$desktop\$name"

# Create a basic internet shortcut file
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $url
$shortcut.Save()

Write-Host "Web link shortcut created: $shortcutPath"