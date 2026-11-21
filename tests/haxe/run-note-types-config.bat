@echo off
rem Port of run-note-types-config.sh - keep in sync with the .sh / .ps1 versions.
setlocal EnableExtensions
cd /d "%~dp0..\.."
set "REPO=%CD%"
if not defined HAXE set "HAXE=haxe"
set "WORK=%TEMP%\phoenix-note-types-%RANDOM%-%RANDOM%"
mkdir "%WORK%\backend" "%WORK%\objects" "%WORK%\custom_notetypes" || exit /b 1
copy /y "source\backend\NoteTypesConfig.hx" "%WORK%\backend\" >nul || goto fail
copy /y "tests\haxe\stubs\note-types\import.hx" "%WORK%\import.hx" >nul || goto fail
copy /y "tests\haxe\stubs\note-types\backend\CoolUtil.hx" "%WORK%\backend\" >nul || goto fail
copy /y "tests\haxe\stubs\note-types\backend\Paths.hx" "%WORK%\backend\" >nul || goto fail
copy /y "tests\haxe\stubs\note-types\objects\Note.hx" "%WORK%\objects\" >nul || goto fail
copy /y "tests\haxe\fixtures\note-types\custom_notetypes\*.txt" "%WORK%\custom_notetypes\" >nul || goto fail
pushd "%WORK%"
%HAXE% -cp "%WORK%" -cp "%REPO%\tests\haxe" -main NoteTypesConfigSpec --interp
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
