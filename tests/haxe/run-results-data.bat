@echo off
rem Port of run-results-data.sh - keep in sync with the .sh / .ps1 versions.
setlocal EnableExtensions
cd /d "%~dp0..\.."
set "REPO=%CD%"
if not defined HAXE set "HAXE=haxe"
set "WORK=%TEMP%\phoenix-results-data-%RANDOM%-%RANDOM%"
mkdir "%WORK%\states" "%WORK%\backend" "%WORK%\play" || exit /b 1
copy /y "source\states\ResultsData.hx" "%WORK%\states\" >nul || goto fail
copy /y "tests\haxe\stubs\results-data\backend\CoolUtil.hx" "%WORK%\backend\" >nul || goto fail
copy /y "tests\haxe\stubs\results-data\play\PlayState.hx" "%WORK%\play\" >nul || goto fail
%HAXE% -cp "%WORK%" -cp "%REPO%\tests\haxe" -main ResultsDataSpec --interp || goto fail
rd /s /q "%WORK%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%WORK%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
