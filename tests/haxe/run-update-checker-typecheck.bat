@echo off
rem Port of run-update-checker-typecheck.sh - keep in sync with the .sh / .ps1 versions.
rem Typecheck the threaded C++ update path using Lime's onUpdate signature.
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0..\.."
if not defined HAXE set "HAXE=haxe"
set "TEST_SOURCE=%TEMP%\phoenix-update-checker-%RANDOM%-%RANDOM%"
mkdir "%TEST_SOURCE%\backend" "%TEST_SOURCE%\lime\app" "%TEST_SOURCE%\openfl" || exit /b 1
copy /y "source\backend\PhoenixVersion.hx" "%TEST_SOURCE%\backend\" >nul || goto fail
copy /y "source\backend\PhoenixReleases.hx" "%TEST_SOURCE%\backend\" >nul || goto fail
copy /y "source\backend\UpdateChecker.hx" "%TEST_SOURCE%\backend\" >nul || goto fail
copy /y "source\backend\RuntimeFlags.hx" "%TEST_SOURCE%\backend\" >nul || goto fail

rem RuntimeFlags (used by UpdateChecker since #198) reads flags.ini through Assets.
> "%TEST_SOURCE%\openfl\Assets.hx" echo package openfl;
>> "%TEST_SOURCE%\openfl\Assets.hx" echo class Assets {
>> "%TEST_SOURCE%\openfl\Assets.hx" echo   public static function exists(id:String, ?type:Dynamic):Bool return false;
>> "%TEST_SOURCE%\openfl\Assets.hx" echo   public static function getText(id:String):String return "";
>> "%TEST_SOURCE%\openfl\Assets.hx" echo }

> "%TEST_SOURCE%\backend\ClientPrefs.hx" echo package backend;
>> "%TEST_SOURCE%\backend\ClientPrefs.hx" echo class ClientPrefs { public static var enablePreReleaseUpdates:Bool = false; }

> "%TEST_SOURCE%\lime\app\Application.hx" echo package lime.app;
>> "%TEST_SOURCE%\lime\app\Application.hx" echo // Lime Application.onUpdate is Event^<Float-^>Void^>.
>> "%TEST_SOURCE%\lime\app\Application.hx" echo class UpdateEvent {
>> "%TEST_SOURCE%\lime\app\Application.hx" echo   public function new() {}
>> "%TEST_SOURCE%\lime\app\Application.hx" echo   public function add(listener:Float-^>Void):Void {}
>> "%TEST_SOURCE%\lime\app\Application.hx" echo   public function remove(listener:Float-^>Void):Void {}
>> "%TEST_SOURCE%\lime\app\Application.hx" echo }
>> "%TEST_SOURCE%\lime\app\Application.hx" echo class Application {
>> "%TEST_SOURCE%\lime\app\Application.hx" echo   public static var current:Application;
>> "%TEST_SOURCE%\lime\app\Application.hx" echo   public var onUpdate:UpdateEvent;
>> "%TEST_SOURCE%\lime\app\Application.hx" echo   public var meta:Map^<String, String^>;
>> "%TEST_SOURCE%\lime\app\Application.hx" echo }

for %%P in (windows android) do (
    %HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -D lime -D %%P -main UpdateCheckerTypecheck -cpp "%TEST_SOURCE%\out" --no-output || goto fail
)

rd /s /q "%TEST_SOURCE%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%TEST_SOURCE%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
