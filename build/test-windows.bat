@echo off
rem Phoenix Engine - Windows debug build + run.
rem
rem Modding level 2 (Lua + Python) is the default for every native target in
rem project.hxp, so -DMODDING_LEVEL is not needed. Extra arguments are passed
rem through to Lime.
setlocal EnableExtensions
cd /d "%~dp0.." || exit /b 1

echo [Phoenix Engine] Building and running Windows (Debug)...
haxelib run lime test windows -debug %*
set "ERR=%ERRORLEVEL%"
if not "%ERR%"=="0" (
  echo [Phoenix Engine] Build/run failed with exit code %ERR%.
  exit /b %ERR%
)
exit /b 0
