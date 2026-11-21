@echo off
rem Port of run-conductor.sh - keep in sync with the .sh / .ps1 versions.
setlocal EnableExtensions
cd /d "%~dp0..\.."
set "REPO=%CD%"
if not defined HAXE set "HAXE=haxe"
set "WORK=%TEMP%\phoenix-conductor-%RANDOM%-%RANDOM%"
mkdir "%WORK%\backend" "%WORK%\data" "%WORK%\objects" "%WORK%\play" || exit /b 1
copy /y "source\backend\Conductor.hx" "%WORK%\backend\" >nul || goto fail
copy /y "tests\haxe\stubs\backend\ClientPrefs.hx" "%WORK%\backend\" >nul || goto fail
copy /y "tests\haxe\stubs\data\Song.hx" "%WORK%\data\" >nul || goto fail
copy /y "tests\haxe\stubs\data\Section.hx" "%WORK%\data\" >nul || goto fail
copy /y "tests\haxe\stubs\objects\Note.hx" "%WORK%\objects\" >nul || goto fail
copy /y "tests\haxe\stubs\objects\NoteSplash.hx" "%WORK%\objects\" >nul || goto fail
copy /y "tests\haxe\stubs\play\PlayState.hx" "%WORK%\play\" >nul || goto fail
%HAXE% -cp "%WORK%" -cp "%REPO%\tests\haxe" -main ConductorSpec --interp || goto fail
rd /s /q "%WORK%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%WORK%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
