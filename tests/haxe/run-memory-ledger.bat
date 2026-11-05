@echo off
rem Port of run-memory-ledger.sh - keep in sync with the .sh / .ps1 versions.
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0..\.."
if not defined HAXE set "HAXE=haxe"
set "TEST_SOURCE=%TEMP%\phoenix-memory-ledger-%RANDOM%-%RANDOM%"
mkdir "%TEST_SOURCE%\backend" "%TEST_SOURCE%\utils" "%TEST_SOURCE%\openfl\display" "%TEST_SOURCE%\openfl\media" "%TEST_SOURCE%\lime\media" "%TEST_SOURCE%\lime\utils" || exit /b 1
copy /y "source\backend\MemoryLedger.hx" "%TEST_SOURCE%\backend\" >nul || goto fail
copy /y "source\utils\MemoryUtil.hx" "%TEST_SOURCE%\utils\" >nul || goto fail

> "%TEST_SOURCE%\backend\VLog.hx" echo package backend;
>> "%TEST_SOURCE%\backend\VLog.hx" echo class VLog
>> "%TEST_SOURCE%\backend\VLog.hx" echo {
>> "%TEST_SOURCE%\backend\VLog.hx" echo   public static var fakeHeap:Float = 1000000;
>> "%TEST_SOURCE%\backend\VLog.hx" echo   public static function heapUsedBytes():Float return fakeHeap;
>> "%TEST_SOURCE%\backend\VLog.hx" echo }

> "%TEST_SOURCE%\backend\Mods.hx" echo package backend;
>> "%TEST_SOURCE%\backend\Mods.hx" echo class Mods
>> "%TEST_SOURCE%\backend\Mods.hx" echo {
>> "%TEST_SOURCE%\backend\Mods.hx" echo   public static var ignoreModFolders:Array^<String^> =
>> "%TEST_SOURCE%\backend\Mods.hx" echo     ['images', 'data', 'songs', 'sounds', 'fonts', 'videos', 'weeks', 'scripts', 'stages', 'characters'];
>> "%TEST_SOURCE%\backend\Mods.hx" echo }

> "%TEST_SOURCE%\openfl\display\BitmapData.hx" echo package openfl.display;
>> "%TEST_SOURCE%\openfl\display\BitmapData.hx" echo class BitmapData
>> "%TEST_SOURCE%\openfl\display\BitmapData.hx" echo {
>> "%TEST_SOURCE%\openfl\display\BitmapData.hx" echo   public var width:Int;
>> "%TEST_SOURCE%\openfl\display\BitmapData.hx" echo   public var height:Int;
>> "%TEST_SOURCE%\openfl\display\BitmapData.hx" echo   public function new(width:Int, height:Int)
>> "%TEST_SOURCE%\openfl\display\BitmapData.hx" echo   {
>> "%TEST_SOURCE%\openfl\display\BitmapData.hx" echo     this.width = width;
>> "%TEST_SOURCE%\openfl\display\BitmapData.hx" echo     this.height = height;
>> "%TEST_SOURCE%\openfl\display\BitmapData.hx" echo   }
>> "%TEST_SOURCE%\openfl\display\BitmapData.hx" echo }

> "%TEST_SOURCE%\lime\utils\UInt8Array.hx" echo package lime.utils;
>> "%TEST_SOURCE%\lime\utils\UInt8Array.hx" echo class UInt8Array
>> "%TEST_SOURCE%\lime\utils\UInt8Array.hx" echo {
>> "%TEST_SOURCE%\lime\utils\UInt8Array.hx" echo   public var length:Int;
>> "%TEST_SOURCE%\lime\utils\UInt8Array.hx" echo   public function new(length:Int) this.length = length;
>> "%TEST_SOURCE%\lime\utils\UInt8Array.hx" echo }

> "%TEST_SOURCE%\lime\media\AudioBuffer.hx" echo package lime.media;
>> "%TEST_SOURCE%\lime\media\AudioBuffer.hx" echo class AudioBuffer
>> "%TEST_SOURCE%\lime\media\AudioBuffer.hx" echo {
>> "%TEST_SOURCE%\lime\media\AudioBuffer.hx" echo   public var data:lime.utils.UInt8Array;
>> "%TEST_SOURCE%\lime\media\AudioBuffer.hx" echo   public function new() {}
>> "%TEST_SOURCE%\lime\media\AudioBuffer.hx" echo }

> "%TEST_SOURCE%\openfl\media\Sound.hx" echo package openfl.media;
>> "%TEST_SOURCE%\openfl\media\Sound.hx" echo class Sound
>> "%TEST_SOURCE%\openfl\media\Sound.hx" echo {
>> "%TEST_SOURCE%\openfl\media\Sound.hx" echo   public var bytesTotal:Int = 0;
>> "%TEST_SOURCE%\openfl\media\Sound.hx" echo   public var __buffer:lime.media.AudioBuffer;
>> "%TEST_SOURCE%\openfl\media\Sound.hx" echo   public function new() {}
>> "%TEST_SOURCE%\openfl\media\Sound.hx" echo }

%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main MemoryLedgerSpec --interp -D MODS_ALLOWED || goto fail

mkdir "%TEST_SOURCE%\cpp\vm" 2>nul
> "%TEST_SOURCE%\cpp\vm\Gc.hx" echo package cpp.vm;
>> "%TEST_SOURCE%\cpp\vm\Gc.hx" echo class Gc
>> "%TEST_SOURCE%\cpp\vm\Gc.hx" echo {
>> "%TEST_SOURCE%\cpp\vm\Gc.hx" echo   public static inline var MEM_INFO_USAGE:Int = 0;
>> "%TEST_SOURCE%\cpp\vm\Gc.hx" echo   public static inline var MEM_INFO_RESERVED:Int = 1;
>> "%TEST_SOURCE%\cpp\vm\Gc.hx" echo   public static function memInfo64(kind:Int):Float return 0;
>> "%TEST_SOURCE%\cpp\vm\Gc.hx" echo }

for %%P in (windows android) do (
    %HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main MemoryLedgerSpec -D MODS_ALLOWED -D %%P -cpp "%TEST_SOURCE%\out-%%P" --no-output || goto fail
)

rd /s /q "%TEST_SOURCE%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%TEST_SOURCE%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
