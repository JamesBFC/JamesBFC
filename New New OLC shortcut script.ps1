# Run as SYSTEM / Admin

$ErrorActionPreference = 'Stop'

# === Config ===
$TargetUrl     = 'https://bracknellforestcouncil.bksblive2.co.uk/bksbLive2/Login.aspx?ReturnUrl'
$ShortcutName  = 'OneAdvanced Online Learning.url'
$PublicDesktop = [Environment]::GetFolderPath('CommonDesktopDirectory')  # Typically C:\Users\Public\Desktop
$ShortcutPath  = Join-Path $PublicDesktop $ShortcutName

# Optional icon (local and reliable)
$IconFile  = "$env:SystemRoot\System32\shell32.dll"
$IconIndex = 220

# Desired .url (INI) content — keep CRLF line endings
$desired = @"
[InternetShortcut]
URL=$TargetUrl
IconFile=$IconFile
IconIndex=$IconIndex
"@

# Ensure the Public Desktop exists (usually does)
if (-not (Test-Path -LiteralPath $PublicDesktop)) {
    New-Item -Path $PublicDesktop -ItemType Directory -Force | Out-Null
}

# If shortcut exists and content already matches, exit successfully
if (Test-Path -LiteralPath $ShortcutPath) {
    $existing = [System.IO.File]::ReadAllText($ShortcutPath)

    # Normalize line endings for comparison
    $normalize = { param($s) ($s -replace "`r`n","`n" -replace "`r","`n").Trim() }
    if (& $normalize $existing -eq & $normalize $desired) {
        Write-Host "Shortcut already present and up-to-date: $ShortcutPath"
        exit 0
    }
}

# Write the .url file as ANSI/ASCII to avoid encoding quirks
$desired | Set-Content -Path $ShortcutPath -Encoding ASCII

# Verify basic integrity
$verify = [System.IO.File]::ReadAllText($ShortcutPath)
if (-not $verify.Contains("URL=$TargetUrl")) {
    throw "Verification failed: URL not found in written shortcut."
}

Write-Host "Shortcut created/updated at: $ShortcutPath"
exit 0