# ==============================================================================
# Script: Install-AptosFont.ps1
# Context: Run as SYSTEM
# Purpose: Downloads and installs the Microsoft Aptos font family system-wide.
# ==============================================================================

$ErrorActionPreference = "Stop"

# We use a reliable GitHub mirror of the official TTF files. 
# Microsoft's official download center links (.aspx) require a browser session 
# or token and will fail when downloaded via Invoke-WebRequest in a headless context.
$ZipUrl = "https://github.com/ironveil/ttf-aptos/archive/refs/heads/main.zip"
$TempDir = Join-Path $env:TEMP "AptosFonts_Deployment"
$ZipPath = Join-Path $env:TEMP "AptosFonts.zip"
$FontsDir = "$env:windir\Fonts"
$RegKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"

# Load Windows APIs to register the font and broadcast the change without a reboot
$PInvoke = @'
using System;
using System.Runtime.InteropServices;
public class FontAPI {
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode)]
    public static extern int AddFontResource(string lpszFilename);
    
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
}
'@
Add-Type -TypeDefinition $PInvoke -Language CSharp

try {
    Write-Output "Downloading Aptos fonts..."
    Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath -UseBasicParsing
    
    Write-Output "Extracting archive..."
    if (Test-Path $TempDir) { Remove-Item -Path $TempDir -Recurse -Force }
    Expand-Archive -Path $ZipPath -DestinationPath $TempDir -Force

    $FontFiles = Get-ChildItem -Path $TempDir -Include *.ttf,*.otf -Recurse

    if ($FontFiles.Count -eq 0) {
        throw "No font files found in the downloaded archive."
    }

    foreach ($Font in $FontFiles) {
        $TargetFile = Join-Path $FontsDir $Font.Name
        
        # Determine Font Type for the Registry entry
        $FontType = if ($Font.Extension -match "\.ttf") { "(TrueType)" } else { "(OpenType)" }
        
        # Clean up the file name to use as the Registry value name (e.g., "Aptos-Bold" -> "Aptos Bold")
        $CleanName = $Font.BaseName -replace "-", " "
        $RegName = "$CleanName $FontType"

        Write-Output "Installing: $CleanName"

        # 1. Copy the file directly to the Windows Fonts directory
        Copy-Item -Path $Font.FullName -Destination $TargetFile -Force

        # 2. Add the registry key to register the font system-wide
        New-ItemProperty -Path $RegKeyPath -Name $RegName -Value $Font.Name -PropertyType String -Force | Out-Null
        
        # 3. Register the font with the active Windows session
        [FontAPI]::AddFontResource($TargetFile) | Out-Null
    }

    # 4. Broadcast a message to all active windows that the font cache has changed
    $HWND_BROADCAST = [IntPtr]0xFFFF
    $WM_FONTCHANGE = 0x001D
    [FontAPI]::PostMessage($HWND_BROADCAST, $WM_FONTCHANGE, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null

    Write-Output "Aptos fonts installed successfully."

} catch {
    Write-Error "Font deployment failed: $_"
    exit 1
} finally {
    # Cleanup temporary data
    Write-Output "Cleaning up temporary files..."
    if (Test-Path $ZipPath) { Remove-Item -Path $ZipPath -Force }
    if (Test-Path $TempDir) { Remove-Item -Path $TempDir -Recurse -Force }
}