$url = "https://bracknellforestcouncil.bksblive2.co.uk/bksbLive2/Login.aspx?ReturnUrl"
$name = "OneAdvanced Online Learning.url"
$shell = New-Object -ComObject WScript.Shell

# Get the path to the Public Desktop
# Environment.SpecialFolder::CommonDesktop is the .NET way to get the Public Desktop path
$publicDesktop = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::CommonDesktopDirectory)

$shortcutPath = "$publicDesktop\$name"

# Create a basic internet shortcut file
# Note: For internet shortcuts (.url), the file is a simple text file, 
# but using the Shell object is a reliable way to create it.
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $url
$shortcut.Save()

Write-Host "Web link shortcut created on Public Desktop: $shortcutPath"