<#
.SYNOPSIS
    Downloads image assets, converts them into valid Windows .ico binary files,
    and creates custom-icon web shortcuts on the active console user's desktop.
#>

Add-Type -AssemblyName System.Drawing

# 1. Configuration & URLs
$ZipDownloadUrl = "https://github.com/JamesBFC/JamesBFC/raw/refs/heads/main/Icons.zip"
$IconStorageDir = "C:\ProgramData\LibraryIcons"

# 2. Target shortcuts and mappings
$Shortcuts = @(
    @{ Name = "BorrowBox";         IconBase = "borrowbox";         Url = "https://bracknell-forest.borrowbox.com/" },
    @{ Name = "CollectionHQ";      IconBase = "collectionhq";      Url = "https://login.collectionhq.com/login" },
    @{ Name = "Fantastic Fiction"; IconBase = "fantasticfiction";  Url = "http://www.fantasticfiction.co.uk/" },
    @{ Name = "Press Reader";      IconBase = "pressreader";       Url = "https://www.pressreader.com/catalog" },
    @{ Name = "Princh Admin";      IconBase = "princh";            Url = "https://admp.princh.com/dashboard/history" },
    @{ Name = "Prism";             IconBase = "prism";             Url = "https://prism.librarymanagementcloud.co.uk/bracknellforest/" },
    @{ Name = "Soprano";           IconBase = "soprano";           Url = "https://soprano.librarymanagementcloud.co.uk/bracknellforest/login?referer=https%3A%2F%2Fsoprano.librarymanagementcloud.co.uk%2Fbracknellforest%2Ftasks" }
)

# Helper function to convert any image format into a valid Windows .ico binary
function Convert-ToTrueIco {
    param(
        [Parameter(Mandatory=$true)][string]$SourcePath,
        [Parameter(Mandatory=$true)][string]$DestinationIcoPath
    )

    try {
        $SrcBitmap = [System.Drawing.Bitmap]::FromFile($SourcePath)
        
        # Standard desktop icon dimensions (multi-frame 256x256 high-res + 48x48)
        $Sizes = @(256, 48, 32, 16)
        $Frames = [System.Collections.Generic.List[byte[]]]::new()

        foreach ($Size in $Sizes) {
            $TargetBmp = New-Object System.Drawing.Bitmap($Size, $Size)
            $Graphics = [System.Drawing.Graphics]::FromImage($TargetBmp)
            $Graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            $Graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $Graphics.Clear([System.Drawing.Color]::Transparent)
            $Graphics.DrawImage($SrcBitmap, 0, 0, $Size, $Size)
            $Graphics.Dispose()

            $Ms = New-Object System.IO.MemoryStream
            $TargetBmp.Save($Ms, [System.Drawing.Imaging.ImageFormat]::Png)
            $Frames.Add($Ms.ToArray())
            $Ms.Dispose()
            $TargetBmp.Dispose()
        }
        $SrcBitmap.Dispose()

        # Build ICO Header (ICONDIR)
        $Fs = [System.IO.File]::Create($DestinationIcoPath)
        $Bw = New-Object System.IO.BinaryWriter($Fs)

        $Bw.Write([UInt16]0)              # Reserved
        $Bw.Write([UInt16]1)              # 1 = ICO
        $Bw.Write([UInt16]$Frames.Count)  # Image count

        # Calculate offsets
        $HeaderSize = 6 + ($Frames.Count * 16)
        $CurrentOffset = $HeaderSize

        # Build Directory Entries (ICONDIRENTRY)
        for ($i = 0; $i -lt $Frames.Count; $i++) {
            $Dim = $Sizes[$i]
            $Bw.Write([byte]$(if ($Dim -ge 256) { 0 } else { $Dim })) # Width (0 = 256)
            $Bw.Write([byte]$(if ($Dim -ge 256) { 0 } else { $Dim })) # Height
            $Bw.Write([byte]0)            # Color count (0 = >=8bpp)
            $Bw.Write([byte]0)            # Reserved
            $Bw.Write([UInt16]1)          # Color planes
            $Bw.Write([UInt16]32)         # Bit depth
            $Bw.Write([UInt32]$Frames[$i].Length) # Image size in bytes
            $Bw.Write([UInt32]$CurrentOffset)     # Offset to image data
            $CurrentOffset += $Frames[$i].Length
        }

        # Write Raw PNG data chunks for each frame
        foreach ($FrameData in $Frames) {
            $Bw.Write($FrameData)
        }

        $Bw.Flush()
        $Bw.Close()
        $Fs.Close()
        return $true
    } catch {
        Write-Warning "Could not convert $SourcePath to ICO: $_"
        return $false
    }
}

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

    if (-not (Test-Path -Path $IconStorageDir)) {
        New-Item -ItemType Directory -Path $IconStorageDir -Force | Out-Null
    }

    $TempZipPath = Join-Path -Path $env:TEMP -ChildPath "Icons_$([guid]::NewGuid().ToString('N')).zip"
    $ExtractStaging = Join-Path -Path $env:TEMP -ChildPath "ExtractedIcons_$([guid]::NewGuid().ToString('N'))"

    # 3. Download & extract to temp staging
    Write-Host "Downloading icon package from GitHub..."
    Invoke-WebRequest -Uri $ZipDownloadUrl -OutFile $TempZipPath -UseBasicParsing

    Expand-Archive -Path $TempZipPath -DestinationPath $ExtractStaging -Force
    Remove-Item -Path $TempZipPath -Force -ErrorAction SilentlyContinue

    # 4. Convert every extracted image into a genuine .ico inside C:\ProgramData\LibraryIcons
    Write-Host "Converting images to true Windows ICO format..."
    $ExtractedFiles = Get-ChildItem -Path $ExtractStaging -File -Recurse

    foreach ($file in $ExtractedFiles) {
        $CleanName = $file.BaseName.ToLower()
        $DestIco = Join-Path -Path $IconStorageDir -ChildPath "$CleanName.ico"
        
        Write-Host "Processing: $($file.Name) -> $DestIco"
        Convert-ToTrueIco -SourcePath $file.FullName -DestinationIcoPath $DestIco | Out-Null
    }

    Remove-Item -Path $ExtractStaging -Recurse -Force -ErrorAction SilentlyContinue

    # 5. Grant Users read access to the icon folder
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

    # 6. Identify logged-in user via Explorer process
    $ExplorerProcess = Get-CimInstance Win32_Process -Filter "Name = 'explorer.exe'" | Select-Object -First 1
    if (-not $ExplorerProcess) {
        Write-Warning "No active user explorer session found. Exiting."
        exit 0
    }

    $OwnerInfo = Invoke-CimMethod -InputObject $ExplorerProcess -MethodName GetOwner
    $FullAccount = "$($OwnerInfo.Domain)\$($OwnerInfo.User)"
    $AccountObj = New-Object System.Security.Principal.NTAccount($FullAccount)
    $UserSID = ($AccountObj.Translate([System.Security.Principal.SecurityIdentifier])).Value

    $ProfileRegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$UserSID"
    $UserProfileDir = (Get-ItemProperty -Path $ProfileRegPath -Name "ProfileImagePath" -ErrorAction Stop).ProfileImagePath

    # Check OneDrive vs standard Desktop
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
    }

    Write-Host "Target Desktop: $DesktopPath"

    # 7. Write .url files pointing to newly generated ICO files
    foreach ($item in $Shortcuts) {
        $ShortcutFile = Join-Path -Path $DesktopPath -ChildPath "$($item.Name).url"
        
        # Match icon by base name
        $TargetIcon = Join-Path -Path $IconStorageDir -ChildPath "$($item.IconBase).ico"
        if (-not (Test-Path -Path $TargetIcon)) {
            $Matched = Get-ChildItem -Path $IconStorageDir -Filter "*.ico" | Where-Object { 
                $_.BaseName -like "*$($item.IconBase)*" 
            } | Select-Object -First 1
            if ($Matched) { $TargetIcon = $Matched.FullName }
        }

        if (Test-Path -Path $TargetIcon) {
            $UrlContent = @"
[InternetShortcut]
URL=$($item.Url)
IconFile=$TargetIcon
IconIndex=0
"@
        } else {
            $UrlContent = @"
[InternetShortcut]
URL=$($item.Url)
"@
        }

        Set-Content -Path $ShortcutFile -Value $UrlContent -Encoding ASCII -Force
        Write-Host "Configured shortcut: $($item.Name).url"
    }

    # 8. Refresh Explorer icon cache
    $ShellNotificationCode = @'
    [System.Runtime.InteropServices.DllImport("shell32.dll")]
    public static extern void SHChangeNotify(int wEventId, int uFlags, IntPtr dwItem1, IntPtr dwItem2);
'@
    $Type = Add-Type -MemberDefinition $ShellNotificationCode -Name "ShellNotification" -Namespace "Win32Utils" -PassThru
    $Type::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero) # SHCNE_ASSOCCHANGED

    Get-ChildItem -Path $DesktopPath -Filter "*.url" | ForEach-Object { $_.LastWriteTime = (Get-Date) }

    Write-Host "Done. Genuine icons compiled and deployed."

} catch {
    Write-Error "Execution error: $_"
    exit 1
}
