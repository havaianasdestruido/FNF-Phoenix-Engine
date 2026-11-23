@echo off
rem Port of run-benchmark.sh - keep in sync with the .sh / .ps1 versions.
setlocal EnableExtensions
cd /d "%~dp0..\.."
if not defined HAXE set "HAXE=haxe"
set "TEST_SOURCE=%TEMP%\phoenix-benchmark-%RANDOM%-%RANDOM%"
mkdir "%TEST_SOURCE%\backend" || exit /b 1
mkdir "%TEST_SOURCE%\lime\system" || exit /b 1
copy /y "source\backend\BenchmarkChart.hx" "%TEST_SOURCE%\backend\" >nul || goto fail
copy /y "source\backend\RecoveryBoot.hx" "%TEST_SOURCE%\backend\" >nul || goto fail
>"%TEST_SOURCE%\lime\system\System.hx" echo package lime.system;
>>"%TEST_SOURCE%\lime\system\System.hx" echo class System { public static var applicationStorageDirectory:String = 'C:\\Windows\\Temp\\'; }
>"%TEST_SOURCE%\backend\Benchmark.hx" echo package backend;
>>"%TEST_SOURCE%\backend\Benchmark.hx" echo class Benchmark { public static var active:Bool = false; }
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main BenchmarkSpec --interp || goto fail
rd /s /q "%TEST_SOURCE%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%TEST_SOURCE%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
