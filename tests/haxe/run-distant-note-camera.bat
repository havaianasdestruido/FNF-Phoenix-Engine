@echo off
rem Port of run-distant-note-camera.sh - keep in sync with the .sh / .ps1 versions.
setlocal EnableExtensions
cd /d "%~dp0..\.."
if not defined HAXE set "HAXE=haxe"
set "TEST_SOURCE=%TEMP%\phoenix-distant-notes-%RANDOM%-%RANDOM%"
mkdir "%TEST_SOURCE%" || exit /b 1
xcopy /e /i /y /q "tests\haxe\stubs\distant-notes" "%TEST_SOURCE%" >nul || goto fail
mkdir "%TEST_SOURCE%\play\helpers" 2>nul
copy /y "source\play\helpers\PlayStateDistantNotes.hx" "%TEST_SOURCE%\play\helpers\" >nul || goto fail
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -D SHADERS_ALLOWED -main DistantNotesSpec --interp || goto fail
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main DistantNotesFallbackSpec --interp || goto fail
rd /s /q "%TEST_SOURCE%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%TEST_SOURCE%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
