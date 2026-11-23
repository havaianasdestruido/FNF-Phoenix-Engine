@echo off
rem Port of run-state-scripts.sh - keep in sync with the .sh / .ps1 versions.
setlocal EnableExtensions
cd /d "%~dp0..\.."
set "REPO=%CD%"
if not defined HAXE set "HAXE=haxe"
set "WORK=%TEMP%\phoenix-state-scripts-%RANDOM%-%RANDOM%"
mkdir "%WORK%\psychlua" "%WORK%\backend" "%WORK%\lime\utils" "%WORK%\openfl\utils" || exit /b 1
copy /y "source\psychlua\StateScripts.hx" "%WORK%\psychlua\" >nul || goto fail
copy /y "tests\haxe\stubs\state-scripts\import.hx" "%WORK%\import.hx" >nul || goto fail
copy /y "tests\haxe\stubs\state-scripts\backend\Paths.hx" "%WORK%\backend\" >nul || goto fail
copy /y "tests\haxe\stubs\state-scripts\backend\RuntimeFlags.hx" "%WORK%\backend\" >nul || goto fail
copy /y "tests\haxe\stubs\state-scripts\backend\Mods.hx" "%WORK%\backend\" >nul || goto fail
copy /y "tests\haxe\stubs\state-scripts\lime\utils\Assets.hx" "%WORK%\lime\utils\" >nul || goto fail
copy /y "tests\haxe\stubs\state-scripts\openfl\utils\Assets.hx" "%WORK%\openfl\utils\" >nul || goto fail
copy /y "tests\haxe\stubs\state-scripts\psychlua\HaxeScript.hx" "%WORK%\psychlua\" >nul || goto fail
mkdir "%WORK%\flixel\addons\transition" "%WORK%\states\substates" || exit /b 1
copy /y "tests\haxe\stubs\state-scripts\flixel\FlxG.hx" "%WORK%\flixel\" >nul || goto fail
copy /y "tests\haxe\stubs\state-scripts\flixel\addons\transition\FlxTransitionableState.hx" "%WORK%\flixel\addons\transition\" >nul || goto fail
copy /y "tests\haxe\stubs\state-scripts\states\ModState.hx" "%WORK%\states\" >nul || goto fail
copy /y "tests\haxe\stubs\state-scripts\states\substates\ModSubState.hx" "%WORK%\states\substates\" >nul || goto fail
mkdir "%WORK%\states" || exit /b 1
copy /y "tests\haxe\stubs\state-scripts\fixtures\states\NestedFixture.hx" "%WORK%\states\" >nul || goto fail
pushd "%WORK%"
%HAXE% -cp "%WORK%" -cp "%REPO%\tests\haxe" -D MODS_ALLOWED -D HSCRIPT_ALLOWED -main StateScriptsSpec --interp
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
