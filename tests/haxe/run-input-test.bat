@echo off
rem Port of run-input-test.sh - keep in sync with the .sh / .ps1 versions.
rem The input tester (phoenix://input) in the Haxe interpreter, without any game
rem haxelibs: the renderer-free model first, then the page against the stubs in
rem tests/haxe/stubs/input-test.
setlocal EnableExtensions
cd /d "%~dp0..\.."
if not defined HAXE set "HAXE=haxe"
set "TEST_SOURCE=%TEMP%\phoenix-input-test-%RANDOM%-%RANDOM%"
mkdir "%TEST_SOURCE%\logic\backend" || exit /b 1

copy /y "source\backend\InputTestLogic.hx" "%TEST_SOURCE%\logic\backend\" >nul || goto fail
%HAXE% -cp "%TEST_SOURCE%\logic" -cp tests/haxe -main InputTestLogicSpec --interp || goto fail
rem The same module typechecked for C++, a static target (nothing is generated).
%HAXE% -cp "%TEST_SOURCE%\logic" -cp tests/haxe -main InputTestLogicSpec -cpp "%TEST_SOURCE%\cpp" --no-output || goto fail

xcopy /e /i /y "tests\haxe\stubs\input-test" "%TEST_SOURCE%\page" >nul || goto fail
mkdir "%TEST_SOURCE%\page\backend" 2>nul
mkdir "%TEST_SOURCE%\page\states" 2>nul
copy /y "source\states\InputTestState.hx" "%TEST_SOURCE%\page\states\" >nul || goto fail
for %%M in (InputTestLogic InputFormatter HardwareKeys HoldToConfirmLogic ScreenLayout TouchlessUI AndroidTVPolicy) do (
    copy /y "source\backend\%%M.hx" "%TEST_SOURCE%\page\backend\" >nul
    if errorlevel 1 goto fail
)
rem Flixel defines FLX_TOUCH and FLX_MOUSE unless a project opts out (Phoenix does
rem not), and the page compiles its touch and mouse reads behind them.
%HAXE% -cp "%TEST_SOURCE%\page" -cp tests/haxe -D FLX_TOUCH -D FLX_MOUSE -main InputTestStateSpec --interp || goto fail
%HAXE% -cp "%TEST_SOURCE%\page" -cp tests/haxe -D FLX_TOUCH -D FLX_MOUSE -main InputTestStateSpec -cpp "%TEST_SOURCE%\cpp" --no-output || goto fail
rd /s /q "%TEST_SOURCE%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%TEST_SOURCE%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
