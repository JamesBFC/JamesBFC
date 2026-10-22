<#
.SYNOPSIS
    Downloads library icons from GitHub, grants standard users Read access,
    and deploys custom-icon web shortcuts to the active user's desktop via Deep Freeze Cloud.
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
    # 3. Force TLS 1.2+
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

    # 5. Fix NTFS permissions so the logged-in user can actually read the icons
    Write-Host "Setting Read & Execute permissions for Users on $IconStorageDir..."
    $Acl = Get-Acl -Path $IconStorageDir
    $Rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        "BUILTIN\Users",
        "ReadAndExecute",
        "ContainerInherit,ObjectInherit",
        "None",
        "Allow"
    )
    $Acl.AddAccessRule($Rule)
    Set-Acl -Path $IconStorageDir -AclObject $Acl

    # 6. Resolve logged-in interactive user via the explorer.exe process
    $ExplorerProcess = Get-CimInstance Win32_Process -Filter "Name = 'explorer.exe'" | Select-Object -First 1

    if (-not $ExplorerProcess) {
        Write-Warning "No active explorer.exe session found. Exiting."
        exit 0
    }

    $OwnerInfo = Invoke-CimMethod -InputObject $ExplorerProcess -MethodName GetOwner
    $CleanUserName = $OwnerInfo.User
    $CleanDomain   = $OwnerInfo.Domain
    $FullAccount   = "$CleanDomain\$CleanUserName"

    Write-Host "Active session detected: $FullAccount"

    # 7. Resolve user SID from account name
    $AccountObj = New-Object System.Security.Principal.NTAccount($FullAccount)
    $UserSID = ($AccountObj.Translate([System.Security.Principal.SecurityIdentifier])).Value

    # 8. Get Profile Path from HKLM ProfileList
    $ProfileRegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$UserSID"
    $UserProfileDir = (Get-ItemProperty -Path $ProfileRegPath -Name "ProfileImagePath" -ErrorAction Stop).ProfileImagePath

    if (-not (Test-Path -Path $UserProfileDir)) {
        throw "User profile folder does not exist at: $UserProfileDir"
    }

    # 9. Check for Desktop location (OneDrive vs Standard)
    $DesktopCandidates = @(
        (Join-Path -Path $UserProfileDir -ChildPath "OneDrive - Bracknell Forest Council\Desktop"),
        (Join-Path -Path $UserProfileDir -ChildPath "OneDrive\Desktop"),
        (Join-Path -Path $UserProfileDir -ChildPath "Desktop")
    )

    $DesktopPath = $null
    foreach ($Candidate in $DesktopCandidates) {
        if (Test-Path -Path $Candidate) {
            $DesktopPath = $Candidate
            break
        }
    }

    if (-not $DesktopPath) {
        $DesktopPath = Join-Path -Path $UserProfileDir -ChildPath "Desktop"
        New-Item -ItemType Directory -Path $DesktopPath -Force | Out-Null
    }

    Write-Host "Resolved Target Desktop: $DesktopPath"

    # 10. Generate .url files
    foreach ($item in $Shortcuts) {
        $ShortcutFile = Join-Path -Path $DesktopPath -ChildPath "$($item.Name).url"

        # Locate matching icon file
        $IconFullPath = Join-Path -Path $IconStorageDir -ChildPath $item.Icon
        if (-not (Test-Path -Path $IconFullPath)) {
            $MatchedFile = Get-ChildItem -Path $IconStorageDir -Filter "*.ico" -Recurse | Where-Object { 
                $_.BaseName -like "*$($item.Name.Split(' ')[0])*" 
            } | Select-Object -First 1
            if ($MatchedFile) { $IconFullPath = $MatchedFile.FullName }
        }

        if (Test-Path -Path $IconFullPath) {
            # Normalize path slashes for Windows INI parsing
            $SanitizedIconPath = $IconFullPath.Replace("/", "\")
            
            # Grant explicit read access on the specific file
            $FileAcl = Get-Acl -Path $SanitizedIconPath
            $FileRule = New-Object System.Security.AccessControl.FileSystemAccessRule("BUILTIN\Users", "Read", "Allow")
            $FileAcl.AddAccessRule($FileRule)
            Set-Acl -Path $SanitizedIconPath -AclObject $FileAcl

            $UrlContent = @"
[InternetShortcut]
URL=$($item.Url)
IconFile=$SanitizedIconPath
IconIndex=0
"@
        } else {
            Write-Warning "Icon not found for $($item.Name). Falling back to default URL shortcut."
            $UrlContent = @"
[InternetShortcut]
URL=$($item.Url)
"@
        }

        Set-Content -Path $ShortcutFile -Value $UrlContent -Encoding ASCII -Force
        Write-Host "Configured shortcut: $($item.Name).url with Icon: $SanitizedIconPath"
    }

    # 11. Clear icon cache and notify shell
    $ShellNotificationCode = @'
    [System.Runtime.InteropServices.DllImport("shell32.dll")]
    public static extern void SHChangeNotify(int wEventId, int uFlags, IntPtr dwItem1, IntPtr dwItem2);
'@
    $Type = Add-Type -MemberDefinition $ShellNotificationCode -Name "ShellNotification" -Namespace "Win32Utils" -PassThru
    $Type::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero) # SHCNE_ASSOCCHANGED

    # Touch each .url file's LastWriteTime to force the client Explorer view to redraw
    Get-ChildItem -Path $DesktopPath -Filter "*.url" | ForEach-Object {
        $_.LastWriteTime = (Get-Date)
    }

    Write-Host "Shortcuts updated and ACLs applied successfully."

} catch {
    Write-Error "Execution error: $_"
    exit 1
}
