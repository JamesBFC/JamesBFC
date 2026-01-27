# 1. Get the username of the person currently logged into the console
$loggedOnUser = (Get-WmiObject -Class Win32_ComputerSystem).UserName

if ($null -ne $loggedOnUser) {
    # The username comes back as "DOMAIN\Username" or "PCNAME\Username"
    # We split it to get just the "Username" part
    $userName = $loggedOnUser.Split("\")[1]
    
    # 2. Construct the path to that user's desktop
    $shortcutPath = "C:\Users\$userName\Desktop\BFI Replay.url"
    $newUrl = "https://replay.bfi.org.uk"

    if (Test-Path $shortcutPath) {
        # 3. Use the COM object to update the shortcut
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $newUrl
        $shortcut.Save()
        
        Write-Output "Successfully updated shortcut for user: $userName"
    } else {
        Write-Error "Shortcut not found at: $shortcutPath"
    }
} else {
    Write-Error "No user currently logged on to the console."
}