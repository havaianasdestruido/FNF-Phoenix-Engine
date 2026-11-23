@echo off
rem Port of run-highscore.sh - keep in sync with the .sh / .ps1 versions.
setlocal EnableExtensions
cd /d "%~dp0..\.."
set "REPO=%CD%"
if not defined HAXE set "HAXE=haxe"
set "WORK=%TEMP%\phoenix-highscore-%RANDOM%-%RANDOM%"
mkdir "%WORK%\backend" "%WORK%\data" "%WORK%\flixel" || exit /b 1
copy /y "source\backend\Highscore.hx" "%WORK%\backend\" >nul || goto fail
copy /y "tests\haxe\stubs\highscore\import.hx" "%WORK%\import.hx" >nul || goto fail
copy /y "tests\haxe\stubs\highscore\backend\Paths.hx" "%WORK%\backend\" >nul || goto fail
copy /y "tests\haxe\stubs\highscore\backend\CoolUtil.hx" "%WORK%\backend\" >nul || goto fail
copy /y "tests\haxe\stubs\highscore\flixel\FlxG.hx" "%WORK%\flixel\" >nul || goto fail
copy /y "tests\haxe\stubs\data\Song.hx" "%WORK%\data\" >nul || goto fail
copy /y "tests\haxe\stubs\data\Section.hx" "%WORK%\data\" >nul || goto fail
%HAXE% -cp "%WORK%" -cp "%REPO%\tests\haxe" -main HighscoreSpec --interp || goto fail
rd /s /q "%WORK%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%WORK%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
