@echo off
set SCRIPT="%TEMP%\Office2024Shortcuts.vbs"
set PUBLIC_DESKTOP=%PUBLIC%\Desktop

:: Create the VBScript wrapper
echo Set oWS = WScript.CreateObject("WScript.Shell") > %SCRIPT%

:: Word 2024 Shortcut
echo sLinkFile = "%PUBLIC_DESKTOP%\Word.lnk" >> %SCRIPT%
echo Set oLink = oWS.CreateShortcut(sLinkFile) >> %SCRIPT%
echo oLink.TargetPath = "C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE" >> %SCRIPT%
echo oLink.Description = "Microsoft Word 2024" >> %SCRIPT%
echo oLink.Save >> %SCRIPT%

:: Excel 2024 Shortcut
echo sLinkFile = "%PUBLIC_DESKTOP%\Excel.lnk" >> %SCRIPT%
echo Set oLink = oWS.CreateShortcut(sLinkFile) >> %SCRIPT%
echo oLink.TargetPath = "C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE" >> %SCRIPT%
echo oLink.Description = "Microsoft Excel 2024" >> %SCRIPT%
echo oLink.Save >> %SCRIPT%

:: Execute and Clean up
cscript /nologo %SCRIPT%
del %SCRIPT%

exit