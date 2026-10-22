<#
.SYNOPSIS
    Downloads library icons from GitHub, extracts to ProgramData, and deploys 
    custom-icon web shortcuts to the active user's desktop via Deep Freeze Cloud.
#>

# 1. Configuration & URLs
$ZipDownloadUrl = "https://github.com/JamesBFC/JamesBFC/raw/refs/heads/main/Icons.zip"
$IconStorageDir = "C:\ProgramData\LibraryIcons"

# 2. Target shortcuts and corresponding .ico files
$Shortcuts = @(
    @{ Name = "BorrowBox";         Icon = "borrowbox.ico";         Url = "https://bracknell-forest.borrowbox.com/" },
    @{ Name = "CollectionHQ";      Icon = "collectionhq.ico";      Url = "https://login.collectionhq.com/login" },
    @{ Name = "Fantastic Fiction"; Icon = "fantasticfiction.ico";  Url = "http://www.fantasticfiction.co.uk/" },
    @{ Name = "Press Reader";      Icon = "pressreader.ico";       Url = "https://www.pressreader.com/catalog" },
    @{ Name = "Princh Admin";      Icon = "princh.ico";            Url = "https://admp.princh.com/dashboard/history" },
    @{ Name = "Prism";             Icon = "prism.ico";             Url = "https://prism.librarymanagementcloud.co.uk/bracknellforest/" },
    @{ Name = "Soprano";           Icon = "soprano.ico";           Url = "https://soprano.librarymanagementcloud.co.uk/bracknellforest/login?referer=https%3A%2F%2Fsoprano.librarymanagementcloud.co.uk%2Fbracknellforest%2Ftasks" }
)

try {
    # 3. Force modern TLS protocols for GitHub downloads
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

    if (-not (Test-Path -Path $IconStorageDir)) {
        New-Item -ItemType Directory -Path $IconStorageDir -Force | Out-Null
    }

    $TempZipPath = Join-Path -Path $env:TEMP -ChildPath "Icons_$([guid]::NewGuid().ToString('N')).zip"

    # 4. Download and extract icon assets
    Write-Host "Downloading icon package from GitHub..."
    Invoke-WebRequest -Uri $ZipDownloadUrl -OutFile $TempZipPath -UseBasicParsing

    if (-not (Test-Path -Path $TempZipPath)) {
        throw "Failed to download icon package to $TempZipPath"
    }

    Write-Host "Extracting icons to $IconStorageDir..."
    Expand-Archive -Path $TempZipPath -DestinationPath $IconStorageDir -Force
    Remove-Item -Path $TempZipPath -Force -ErrorAction SilentlyContinue

    # 5. Resolve active console user session
    $CurrentConsoleUser = (Get-CimInstance -ClassName Win32_ComputerSystem).UserName

    if ([string]::IsNullOrWhiteSpace($CurrentConsoleUser)) {
        Write-Warning "Icons extracted successfully, but no active console user session was detected. Exiting."
        exit 0
    }

    Write-Host "Active console user: $CurrentConsoleUser"

    # 6. Resolve user SID and real Desktop directory (works with standard or redirected profiles)
    $AccountObj = New-Object System.Security.Principal.NTAccount($CurrentConsoleUser)
    $UserSID = ($AccountObj.Translate([System.Security.Principal.SecurityIdentifier])).Value

    $UserShellFoldersPath = "Registry::HKEY_USERS\$UserSID\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
    $RawDesktopPath = (Get-ItemProperty -Path $UserShellFoldersPath -Name "Desktop" -ErrorAction Stop).Desktop

    $ProfilePath = (Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$UserSID").ProfileImagePath
    $DesktopPath = $RawDesktopPath -replace '(?i)%USERPROFILE%', $ProfilePath
    $DesktopPath = [System.Environment]::ExpandEnvironmentVariables($DesktopPath)

    if (-not (Test-Path -Path $DesktopPath)) {
        throw "Resolved desktop path does not exist: $DesktopPath"
    }

    Write-Host "Target Desktop: $DesktopPath"

    # 7. Write standard .url files with icon pointers
    foreach ($item in $Shortcuts) {
        $ShortcutFile = Join-Path -Path $DesktopPath -ChildPath "$($item.Name).url"
        
        # Test direct filename or case-insensitive search if extracted with different casing
        $IconFullPath = Join-Path -Path $IconStorageDir -ChildPath $item.Icon
        if (-not (Test-Path -Path $IconFullPath)) {
            $MatchedFile = Get-ChildItem -Path $IconStorageDir -Filter "*.ico" -Recurse | Where-Object { $_.BaseName -like "*$($item.Name.Split(' ')[0])*" } | Select-Object -First 1
            if ($MatchedFile) { $IconFullPath = $MatchedFile.FullName }
        }

        if (Test-Path -Path $IconFullPath) {
            $UrlContent = @"
[InternetShortcut]
URL=$($item.Url)
IconFile=$IconFullPath
IconIndex=0
"@
        } else {
            Write-Warning "Icon not found for $($item.Name). Defaulting to standard URL shortcut."
            $UrlContent = @"
[InternetShortcut]
URL=$($item.Url)
"@
        }

        Set-Content -Path $ShortcutFile -Value $UrlContent -Encoding ASCII -Force
        Write-Host "Created: $($item.Name).url"
    }

    # 8. Trigger shell icon cache refresh to display icons immediately
    $ShellNotificationCode = @'
    [System.Runtime.InteropServices.DllImport("shell32.dll")]
    public static extern void SHChangeNotify(int wEventId, int uFlags, IntPtr dwItem1, IntPtr dwItem2);
'@
    $Type = Add-Type -MemberDefinition $ShellNotificationCode -Name "ShellNotification" -Namespace "Win32Utils" -PassThru
    $Type::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero) # SHCNE_ASSOCCHANGED

    Write-Host "All shortcuts deployed and shell cache refreshed."

} catch {
    Write-Error "Execution error: $_"
    exit 1
}