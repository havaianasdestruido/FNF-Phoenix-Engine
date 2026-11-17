@echo off
rem Port of run-freeplay-filter.sh - keep in sync with the .sh / .ps1 versions.
rem The Freeplay filter (sort by name/mod/accuracy/unplayed, show one mod, stars,
rem random song) in the Haxe interpreter, without any game haxelibs: only
rem backend/FreeplayFilter.hx is needed, it imports nothing but the standard
rem library.
setlocal EnableExtensions
cd /d "%~dp0..\.."
if not defined HAXE set "HAXE=haxe"
set "TEST_SOURCE=%TEMP%\phoenix-freeplay-filter-%RANDOM%-%RANDOM%"
mkdir "%TEST_SOURCE%\logic\backend" || exit /b 1

copy /y "source\backend\FreeplayFilter.hx" "%TEST_SOURCE%\logic\backend\" >nul || goto fail
%HAXE% -cp "%TEST_SOURCE%\logic" -cp tests/haxe -main FreeplayFilterSpec --interp || goto fail
rem The same module typechecked for C++, a static target (nothing is generated).
%HAXE% -cp "%TEST_SOURCE%\logic" -cp tests/haxe -main FreeplayFilterSpec -cpp "%TEST_SOURCE%\cpp" --no-output || goto fail
rd /s /q "%TEST_SOURCE%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%TEST_SOURCE%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
