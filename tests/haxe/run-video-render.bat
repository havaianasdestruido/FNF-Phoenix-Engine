@echo off
rem Port of run-video-render.sh - keep in sync with the .sh / .ps1 versions.
rem Rendering Mode folders (nested creation, Windows path anchoring) and the
rem FFmpeg lookup (game folder, PATH, PHOENIX_FFMPEG, package managers).
setlocal EnableExtensions
set "REPO_ROOT=%~dp0..\.."
set "SPEC_DIR=%~dp0"
cd /d "%REPO_ROOT%" || exit /b 1
if not defined HAXE set "HAXE=haxe"
set "TEST_SOURCE=%TEMP%\phoenix-video-render-%RANDOM%-%RANDOM%"
mkdir "%TEST_SOURCE%\backend" "%TEST_SOURCE%\work" || goto fail
copy /y "source\backend\RenderPaths.hx" "%TEST_SOURCE%\backend\" >nul || goto fail
copy /y "source\backend\FFmpegLocator.hx" "%TEST_SOURCE%\backend\" >nul || goto fail
cd /d "%TEST_SOURCE%\work" || goto fail
%HAXE% -cp "%TEST_SOURCE%" -cp "%SPEC_DIR%" -main VideoRenderSpec --interp || goto fail
cd /d "%REPO_ROOT%" 2>nul
rd /s /q "%TEST_SOURCE%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
cd /d "%REPO_ROOT%" 2>nul
rd /s /q "%TEST_SOURCE%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
