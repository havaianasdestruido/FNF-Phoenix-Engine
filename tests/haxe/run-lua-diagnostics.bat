@echo off
rem Port of run-lua-diagnostics.sh - keep in sync with the .sh / .ps1 versions.
rem Contract tests for backend.LuaDiagnostics (docs/LUA_SCRIPT_DEBUGGING.md).
rem Set LUAJIT to a LuaJIT binary to add the checks against the real runtime.
setlocal EnableExtensions
cd /d "%~dp0..\.."
if not defined HAXE set "HAXE=haxe"
set "TEST_SOURCE=%TEMP%\phoenix-lua-diagnostics-%RANDOM%-%RANDOM%"
mkdir "%TEST_SOURCE%\backend" || exit /b 1
copy /y "source\backend\LuaDiagnostics.hx" "%TEST_SOURCE%\backend\" >nul || goto fail
set "LUA_DIAGNOSTICS_TMP=%TEST_SOURCE%"

rem No define: a target that cannot include Lua (mobile, web).
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main LuaDiagnosticsSpec --interp || goto fail

rem A desktop build without the Lua VM: .lua files are found but cannot run.
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main LuaDiagnosticsSpec -D desktop --interp || goto fail

rem A desktop build with the Lua VM.
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main LuaDiagnosticsSpec -D desktop -D LUA_ALLOWED --interp || goto fail

rd /s /q "%TEST_SOURCE%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%TEST_SOURCE%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
