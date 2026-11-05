@echo off
rem Port of run-platform-icons.sh - keep in sync with the .sh / .ps1 versions.
rem Platform badge contract: target detection, density math and glyph bounds.
setlocal EnableExtensions
cd /d "%~dp0..\.."
if not defined HAXE set "HAXE=haxe"
set "TEST_SOURCE=%TEMP%\phoenix-platform-icons-%RANDOM%-%RANDOM%"
mkdir "%TEST_SOURCE%\backend" || exit /b 1
copy /y "source\backend\PlatformIcons.hx" "%TEST_SOURCE%\backend\" >nul || goto fail

rem No define: the runtime system name decides.
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main PlatformIconSpec --interp || goto fail

for %%P in (windows mac linux android ios html5 air) do (
    %HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main PlatformIconSpec -D %%P --interp || goto fail
)

rem `flash` is a reserved compiler flag: compile for the real target instead.
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main PlatformIconSpec --swf "%TEST_SOURCE%\spec.swf" --no-output || goto fail

rem A real AIR build is the Flash target plus `air`.
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main PlatformIconSpec -D air --swf "%TEST_SOURCE%\spec.swf" --no-output || goto fail

rd /s /q "%TEST_SOURCE%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%TEST_SOURCE%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
