@echo off
rem Port of run-mod-zip.sh - keep in sync with the .sh / .ps1 versions.
setlocal EnableExtensions
cd /d "%~dp0..\.."
set "REPO=%CD%"
if not defined HAXE set "HAXE=haxe"
set "WORK=%TEMP%\phoenix-mod-zip-%RANDOM%-%RANDOM%"
mkdir "%WORK%\backend" "%WORK%\mobile\files" || exit /b 1
copy /y "source\backend\ModPathPolicy.hx" "%WORK%\backend\" >nul || goto fail
copy /y "source\mobile\files\ModZipInstaller.hx" "%WORK%\mobile\files\" >nul || goto fail
pushd "%WORK%"
%HAXE% -cp "%WORK%" -cp "%REPO%\tests\haxe" -main ModZipImportSpec --interp
if not errorlevel 1 goto haxe_ok
popd
goto fail
:haxe_ok
popd
rd /s /q "%WORK%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%WORK%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
