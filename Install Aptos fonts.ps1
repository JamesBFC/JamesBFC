# ==============================================================================
# Script: Install-AptosFont-DeepFreeze.ps1
# Context: Run as SYSTEM (32-bit or 64-bit safe)
# Purpose: Downloads and installs the Microsoft Aptos font family system-wide,
#          bypassing 32-bit File System Redirection (for Faronics/RMM agents).
# ==============================================================================

$ErrorActionPreference = "Stop"

# Reliable GitHub mirror for headless SYSTEM downloads
$ZipUrl = "https://github.com/ironveil/ttf-aptos/archive/refs/heads/main.zip"
$TempDir = Join-Path $env:TEMP "AptosFonts_Deployment"
$ZipPath = Join-Path $env:TEMP "AptosFonts.zip"

# We explicitly target the native SystemRoot to avoid WOW64 redirection
$FontsDir = "$env:windir\Fonts"
$RegKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"

# Load Windows APIs to register the font and broadcast the change
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

        # 1. Bypass PowerShell's File Provider and 32-bit Redirection using raw .NET
        try {
            [System.IO.File]::Copy($Font.FullName, $TargetFile, $true)
        } catch {
            Write-Warning "Could not copy $($Font.Name). It may already be locked by the OS."
        }

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
