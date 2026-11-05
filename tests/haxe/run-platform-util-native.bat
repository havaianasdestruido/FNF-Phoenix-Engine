@echo off
rem Port of run-platform-util-native.sh - keep in sync with the .sh / .ps1 versions.
rem Typecheck the native bridge without the Flixel/Lime dependency tree.
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0..\.."
if not defined HAXE set "HAXE=haxe"
set "TEST_SOURCE=%TEMP%\phoenix-platform-util-%RANDOM%-%RANDOM%"
mkdir "%TEST_SOURCE%\utils" "%TEST_SOURCE%\backend" "%TEST_SOURCE%\source\utils" || exit /b 1
copy /y "source\utils\PlatformUtilNative.hx" "%TEST_SOURCE%\utils\" >nul || goto fail
copy /y "source\utils\build.xml" "%TEST_SOURCE%\source\utils\" >nul || goto fail

> "%TEST_SOURCE%\backend\WindowNative.hx" echo package backend;
>> "%TEST_SOURCE%\backend\WindowNative.hx" echo class WindowNative {
>> "%TEST_SOURCE%\backend\WindowNative.hx" echo   public static function messageBox(message:String, title:String, yesNo:Bool, error:Bool):Int return 7;
>> "%TEST_SOURCE%\backend\WindowNative.hx" echo   public static function updateWallpaper():Dynamic return null;
>> "%TEST_SOURCE%\backend\WindowNative.hx" echo   public static function detectWine():Bool return false;
>> "%TEST_SOURCE%\backend\WindowNative.hx" echo   public static function getArch():String return '';
>> "%TEST_SOURCE%\backend\WindowNative.hx" echo }

> "%TEST_SOURCE%\backend\FlxTransWindow.hx" echo package backend;
>> "%TEST_SOURCE%\backend\FlxTransWindow.hx" echo class FlxTransWindow {
>> "%TEST_SOURCE%\backend\FlxTransWindow.hx" echo   public static function getWindowsTransparent(res:Int):Int return res;
>> "%TEST_SOURCE%\backend\FlxTransWindow.hx" echo   public static function getWindowsbackward(res:Int):Int return res;
>> "%TEST_SOURCE%\backend\FlxTransWindow.hx" echo }

for %%P in (windows android linux mac) do (
    call :run_platform %%P
    if errorlevel 1 goto fail
)
goto done

:run_platform
set "PLATFORM=%~1"
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -D %PLATFORM% -main PlatformUtilNativeSpec --interp
if errorlevel 1 exit /b 1
if /i "%PLATFORM%"=="linux" goto cpp_gen
if /i "%PLATFORM%"=="mac" goto cpp_gen
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -D %PLATFORM% -main PlatformUtilNativeSpec -cpp "%TEST_SOURCE%\out-%PLATFORM%" --no-output
exit /b %ERRORLEVEL%

:cpp_gen
rem @:cppFileCode blocks replace rather than supplement one another. Generate
rem the translation unit to ensure the dialog and uname declarations coexist.
set "OUTPUT=%TEST_SOURCE%\generated\%PLATFORM%\linux\obj"
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -D %PLATFORM% -D no-compilation -main PlatformUtilNativeSpec -cpp "%OUTPUT%"
if errorlevel 1 exit /b 1
findstr /l /c:"phoenix_desktop_dialog.h" "%OUTPUT%\src\utils\PlatformUtilNative.cpp" >nul
if errorlevel 1 exit /b 1
findstr /l /c:"sys/utsname.h" "%OUTPUT%\src\utils\PlatformUtilNative.cpp" >nul
exit /b %ERRORLEVEL%

:done
rd /s /q "%TEST_SOURCE%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%TEST_SOURCE%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
