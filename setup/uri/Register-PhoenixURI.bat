@echo off
rem Port of Register-PhoenixURI.ps1 - keep in sync with the .ps1 / .sh versions.
rem Per-user registration: no administrator rights required.
rem Usage: Register-PhoenixURI.bat [path-to-FNF-Phoenix-Engine.exe]
setlocal EnableExtensions EnableDelayedExpansion

set "EXE=%~1"
if not defined EXE set "EXE=%~dp0..\FNF-Phoenix-Engine.exe"
for %%I in ("%EXE%") do set "EXE=%%~fI"

if not exist "%EXE%" (
    echo Select the Phoenix Engine executable: "%EXE%" not found. 1>&2
    exit /b 1
)
if /i not "!EXE:~-4!"==".exe" (
    echo Select the Phoenix Engine executable. 1>&2
    exit /b 1
)

set "KEY=HKCU\Software\Classes\phoenix"
set "EXPECTED=\"%EXE%\" \"%%1\""

rem Check before writing: never clobber another copy's handler.
for /f "tokens=2,*" %%A in ('reg query "%KEY%\shell\open\command" /ve 2^>nul') do set "EXISTING=%%B"
if not defined EXISTING goto register_keys
if "!EXISTING!"=="%EXPECTED%" goto register_keys
echo Another installation owns phoenix://; refusing to overwrite its registration. 1>&2
exit /b 1

:register_keys

reg add "%KEY%" /ve /d "URL:Phoenix Engine Protocol" /f >nul || exit /b 1
reg add "%KEY%" /v "URL Protocol" /d "" /f >nul || exit /b 1
reg add "%KEY%\DefaultIcon" /ve /d "\"%EXE%\",0" /f >nul || exit /b 1
rem Direct invocation, never cmd.exe/PowerShell and never an unquoted URI.
reg add "%KEY%\shell\open\command" /ve /d "%EXPECTED%" /f >nul || exit /b 1

echo Registered phoenix:// for %EXE%. Re-run after moving the game.
endlocal
