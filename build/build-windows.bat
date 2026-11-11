@echo off
rem Phoenix Engine - Windows release build.
rem
rem Modding level 2 (Lua + Python) is the default for every native target in
rem project.hxp, so this build script does not pass -DMODDING_LEVEL: a plain
rem `lime build windows` already includes both script languages. Pass extra
rem flags straight through to override it, for example:
rem
rem   build-windows.bat -DMODDING_LEVEL=0
rem   build-windows.bat -DMODDING_LEVEL=1
rem   build-windows.bat -DFREEPLAY -DNO_BUILTIN_CONTENT
rem
rem Do NOT pass -cpp to force Lua: that is Lime's optional target flag, not
rem the check project.hxp uses, and it is not needed.
setlocal EnableExtensions
cd /d "%~dp0.." || exit /b 1

echo [Phoenix Engine] Building Windows (Release)...
haxelib run lime build windows -release %*
set "ERR=%ERRORLEVEL%"
echo.
if not "%ERR%"=="0" (
  echo [Phoenix Engine] Build failed with exit code %ERR%.
  exit /b %ERR%
)
echo [Phoenix Engine] Done. Output: build\release\windows\bin
exit /b 0
