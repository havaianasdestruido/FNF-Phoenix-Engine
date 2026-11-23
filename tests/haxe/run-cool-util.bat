@echo off
rem Port of run-cool-util.sh - keep in sync with the .sh / .ps1 versions.
setlocal EnableExtensions
cd /d "%~dp0..\.."
set "REPO=%CD%"
if not defined HAXE set "HAXE=haxe"
set "WORK=%TEMP%\phoenix-cool-util-%RANDOM%-%RANDOM%"
mkdir "%WORK%\backend" "%WORK%\data" "%WORK%\objects" "%WORK%\play" "%WORK%\shaders" "%WORK%\lime\system" "%WORK%\utils" || exit /b 1
copy /y "source\backend\CoolUtil.hx" "%WORK%\backend\" >nul || goto fail
copy /y "source\backend\Conductor.hx" "%WORK%\backend\" >nul || goto fail
copy /y "source\backend\PhoenixVersion.hx" "%WORK%\backend\" >nul || goto fail
copy /y "tests\haxe\stubs\cool-util\import.hx" "%WORK%\" >nul || goto fail
copy /y "tests\haxe\stubs\cool-util\Main.hx" "%WORK%\" >nul || goto fail
for %%f in ("tests\haxe\stubs\cool-util\backend\*.hx") do copy /y "%%f" "%WORK%\backend\" >nul || goto fail
xcopy /y /e /i /q "tests\haxe\stubs\cool-util\flixel" "%WORK%\flixel\" >nul || goto fail
for %%f in ("tests\haxe\stubs\cool-util\objects\*.hx") do copy /y "%%f" "%WORK%\objects\" >nul || goto fail
xcopy /y /e /i /q "tests\haxe\stubs\cool-util\shaders" "%WORK%\shaders\" >nul || goto fail
xcopy /y /e /i /q "tests\haxe\stubs\cool-util\lime" "%WORK%\lime\" >nul || goto fail
xcopy /y /e /i /q "tests\haxe\stubs\cool-util\openfl" "%WORK%\openfl\" >nul || goto fail
copy /y "tests\haxe\stubs\cool-util\utils\CoolSystemStuff.hx" "%WORK%\utils\" >nul || goto fail
copy /y "tests\haxe\stubs\backend\ClientPrefs.hx" "%WORK%\backend\" >nul || goto fail
copy /y "tests\haxe\stubs\data\Song.hx" "%WORK%\data\" >nul || goto fail
copy /y "tests\haxe\stubs\data\Section.hx" "%WORK%\data\" >nul || goto fail
copy /y "tests\haxe\stubs\objects\Note.hx" "%WORK%\objects\" >nul || goto fail
copy /y "tests\haxe\stubs\objects\NoteSplash.hx" "%WORK%\objects\" >nul || goto fail
copy /y "tests\haxe\stubs\play\PlayState.hx" "%WORK%\play\" >nul || goto fail
%HAXE% -cp "%WORK%" -cp "%REPO%\tests\haxe" -main CoolUtilSpec --interp || goto fail
rd /s /q "%WORK%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%WORK%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
