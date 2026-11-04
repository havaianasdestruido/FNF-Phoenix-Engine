@echo off
rem Port of compress.ps1 - keep in sync with compress.ps1 / compress.sh.
rem Re-encodes every MP3/OGG under the root in place when the result is smaller.
rem Usage: compress.bat [root] [mp3-bitrate] [ogg-bitrate]
rem   Defaults: root=current directory, MP3=128 kbps, OGG=96 kbps.
setlocal EnableExtensions EnableDelayedExpansion

set "ROOT=%~1"
if not defined ROOT set "ROOT=%CD%"
set "MP3_BITRATE=%~2"
if not defined MP3_BITRATE set "MP3_BITRATE=128"
set "OGG_BITRATE=%~3"
if not defined OGG_BITRATE set "OGG_BITRATE=96"

where ffmpeg >nul 2>&1
if errorlevel 1 (
    echo ERROR: ffmpeg was not found in PATH. 1>&2
    exit /b 1
)
if not exist "%ROOT%\" (
    echo ERROR: directory not found: %ROOT% 1>&2
    exit /b 1
)
for %%I in ("%ROOT%") do set "ROOT=%%~fI"

echo.
echo ========================================
echo  Audio Compressor
echo ========================================
echo Root: %ROOT%
echo.

set /a TOTAL=0
for /r "%ROOT%" %%F in (*.mp3 *.ogg) do set /a TOTAL+=1
if %TOTAL%==0 (
    echo No MP3 or OGG files found.
    exit /b 0
)
echo Found %TOTAL% audio files.
echo.

set "TMPFILE=%TEMP%\audio-compress-%RANDOM%-%RANDOM%"
set /a PROCESSED=0, REPLACED=0, SKIPPED=0, FAILED=0
set /a TOTAL_ORIGINAL=0, TOTAL_FINAL=0

for /r "%ROOT%" %%F in (*.mp3 *.ogg) do call :process "%%~fF"
goto summary

:process
set /a PROCESSED+=1
set "FILE=%~1"
set "EXT=%~x1"
set /a ORIGINAL=%~z1
set /a TOTAL_ORIGINAL+=ORIGINAL
echo [!PROCESSED!/%TOTAL%] %FILE%
if /i "%EXT%"==".mp3" (
    echo   MP3 -^> MP3 (%MP3_BITRATE% kbps)
    set "CODEC=libmp3lame"
    set "BITRATE=%MP3_BITRATE%"
) else (
    echo   OGG Vorbis -^> OGG Vorbis (%OGG_BITRATE% kbps)
    set "CODEC=libvorbis"
    set "BITRATE=%OGG_BITRATE%"
)
set "OUT=%TMPFILE%%EXT%"
ffmpeg -hide_banner -loglevel error -y -i "%FILE%" -map 0:a:0 -vn -c:a !CODEC! -b:a !BITRATE!k -ar 44100 -ac 2 "%OUT%" <nul
if errorlevel 1 goto failed
if not exist "%OUT%" goto failed
for %%O in ("%OUT%") do set /a COMPRESSED=%%~zO
if !COMPRESSED! LSS %ORIGINAL% (
    rem Keep the original timestamps where cmd allows (copy /y preserves the
    rem source file's write time only approximately; this matches the .bat
    rem idiom used elsewhere in this repository).
    move /y "%OUT%" "%FILE%" >nul
    set /a TOTAL_FINAL+=COMPRESSED, REPLACED+=1
    echo   Replaced: %ORIGINAL% -^> !COMPRESSED! bytes
) else (
    del /q "%OUT%" 2>nul
    set /a TOTAL_FINAL+=ORIGINAL, SKIPPED+=1
    echo   Skipped: compressed file was not smaller.
)
echo.
exit /b 0

:failed
if exist "%OUT%" del /q "%OUT%" 2>nul
set /a TOTAL_FINAL+=ORIGINAL, FAILED+=1
echo   FAILED: ffmpeg could not encode this file 1>&2
echo.
exit /b 0

:summary
set /a TOTAL_SAVED=TOTAL_ORIGINAL-TOTAL_FINAL
echo ========================================
echo  Compression complete
echo ========================================
echo Files processed : %PROCESSED%
echo Files replaced  : %REPLACED%
echo Files skipped   : %SKIPPED%
echo Files failed    : %FAILED%
echo.
echo Original size ^(bytes^) : %TOTAL_ORIGINAL%
echo Final size    ^(bytes^) : %TOTAL_FINAL%
echo Space saved   ^(bytes^) : %TOTAL_SAVED%
endlocal
