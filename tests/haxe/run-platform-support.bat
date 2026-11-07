@echo off
rem Port of run-platform-support.sh - keep in sync with the .sh / .ps1 versions.
rem Platform gating contract: tags, requirement lists, aliases and registries.
setlocal EnableExtensions
cd /d "%~dp0..\.."
if not defined HAXE set "HAXE=haxe"
set "TEST_SOURCE=%TEMP%\phoenix-platform-support-%RANDOM%-%RANDOM%"
mkdir "%TEST_SOURCE%\backend" || exit /b 1
copy /y "source\backend\PlatformIcons.hx" "%TEST_SOURCE%\backend\" >nul || goto fail
copy /y "source\backend\PlatformSupport.hx" "%TEST_SOURCE%\backend\" >nul || goto fail

rem No define: the `sys`/host fallback.
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main PlatformSupportSpec --interp || goto fail

for %%P in (windows mac linux android ios html5 air) do (
    %HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main PlatformSupportSpec -D %%P --interp || goto fail
)

rem `flash` is a reserved compiler flag: compile for the real target instead.
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main PlatformSupportSpec --swf "%TEST_SOURCE%\spec.swf" --no-output || goto fail

rem A real AIR build is the Flash target plus `air`.
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main PlatformSupportSpec -D air --swf "%TEST_SOURCE%\spec.swf" --no-output || goto fail

rd /s /q "%TEST_SOURCE%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%TEST_SOURCE%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
