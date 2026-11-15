@echo off
rem Port of run-haptic-feedback.sh - keep in sync with the .sh / .ps1 versions.
rem Automatic note haptics, duration sanitization and Lua/Python vibrate() parity.
setlocal EnableExtensions
cd /d "%~dp0..\.."
if not defined HAXE set "HAXE=haxe"
set "TEST_SOURCE=%TEMP%\phoenix-haptic-feedback-%RANDOM%-%RANDOM%"
mkdir "%TEST_SOURCE%\backend" || exit /b 1
mkdir "%TEST_SOURCE%\play\helpers" || goto fail
mkdir "%TEST_SOURCE%\psychlua\callbacks" || goto fail
mkdir "%TEST_SOURCE%\psychlua\pystdlib" || goto fail
copy /y "source\backend\HapticFeedback.hx" "%TEST_SOURCE%\backend\" >nul || goto fail
copy /y "source\backend\PlatformIcons.hx" "%TEST_SOURCE%\backend\" >nul || goto fail
copy /y "source\backend\PlatformSupport.hx" "%TEST_SOURCE%\backend\" >nul || goto fail
copy /y "source\play\helpers\PlayStateHaptics.hx" "%TEST_SOURCE%\play\helpers\" >nul || goto fail
copy /y "source\psychlua\callbacks\HardwareCallbacks.hx" "%TEST_SOURCE%\psychlua\callbacks\" >nul || goto fail
copy /y "source\psychlua\pystdlib\PyHardwareLib.hx" "%TEST_SOURCE%\psychlua\pystdlib\" >nul || goto fail
xcopy /e /i /y "tests\haxe\stubs\haptics" "%TEST_SOURCE%" >nul || goto fail

%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main HapticFeedbackSpec --interp || goto fail
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main HapticFeedbackSpec -D android --interp || goto fail

rd /s /q "%TEST_SOURCE%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%TEST_SOURCE%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
