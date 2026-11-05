@echo off
rem Port of run-project-build-cache.sh; keep the shell variants in sync.
setlocal EnableExtensions
cd /d "%~dp0..\.." || exit /b 1
if not defined HAXE set "HAXE=haxe"
set "WORK=%TEMP%\phoenix-project-cache-%RANDOM%-%RANDOM%"
mkdir "%WORK%" || exit /b 1
copy /y "project.hxp" "%WORK%\Project.hx" >nul || goto fail
"%HAXE%" -lib lime -lib hxp -cp "%WORK%" -cp tests/haxe -main ProjectBuildCacheSpec --interp || goto fail
rd /s /q "%WORK%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%WORK%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
