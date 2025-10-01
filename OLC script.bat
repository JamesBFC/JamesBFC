@echo off
setlocal

:: Define variables
set "ShortcutPath=C:\Users\Public\Desktop\OneAdvanced Online Learning.url"
set "TargetURL=https://bracknellforestcouncil.bksblive2.co.uk/bksbLive2/Login.aspx?ReturnUrl"

:: Create the .url file
(
echo [InternetShortcut]
echo URL=%TargetURL%
echo IconFile=%SystemRoot%\System32\shell32.dll
echo IconIndex=220
) > "%ShortcutPath%"

echo Shortcut created at %ShortcutPath%
endlocal
