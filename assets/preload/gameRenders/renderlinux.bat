@echo off
rem Port of renderlinux.sh - keep in sync with renderlinux.sh / renderlinux.ps1.
rem This is the same renderer as renderlol.bat; renderlol.* is the port of the
rem pre-existing Windows script and renderlinux.* is the port of the Linux one.

echo hello there!
echo PS: this will only work if you have ffmpeg installed and are using the classic rendering mode.

set /p "renderFolder=enter the name of the song you'd like to render! (this is the folder that you'll use): "

set /p "renderName=what would you like to name your rendered video?: "

set /p "vidFPS=what is the framerate of your images/video? (defaults to 60): "

if "%vidFPS%"=="" set "vidFPS=60"

set /p "useLossless=lastly, are you rendering your video in a lossless format? (y/n, default n, makes the renderer find pngs instead of jpgs): "
if "%useLossless%"=="" set "useLossless=n"

if /i "%useLossless%"=="y" (
    set "fExt=png"
) else (
    set "fExt=jpg"
)

echo.
echo Starting...
echo.

ffmpeg -r %vidFPS% -i "%~dp0%renderFolder%\%%07d.%fExt%" "%renderName%.mp4"

pause
