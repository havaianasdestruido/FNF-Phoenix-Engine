@echo off
rem Port of Unregister-PhoenixURI.ps1 - keep in sync with the .ps1 / .sh versions.
rem Usage: Unregister-PhoenixURI.bat [path-to-FNF-Phoenix-Engine.exe]
setlocal EnableExtensions EnableDelayedExpansion

set "EXE=%~1"
if not defined EXE set "EXE=%~dp0..\FNF-Phoenix-Engine.exe"
for %%I in ("%EXE%") do set "EXE=%%~fI"

set "KEY=HKCU\Software\Classes\phoenix"
set "EXPECTED=\"%EXE%\" \"%%1\""

for /f "tokens=2,*" %%A in ('reg query "%KEY%\shell\open\command" /ve 2^>nul') do set "EXISTING=%%B"
if not defined EXISTING goto done
if "!EXISTING!"=="%EXPECTED%" goto remove_key
echo Another installation owns phoenix://; refusing to remove its registration. 1>&2
exit /b 1

:remove_key
reg delete "%KEY%" /f >nul || exit /b 1
echo Removed Phoenix URI registration.

:done
endlocal
