@echo off
rem Port of compress-audio.ps1 / compress-audio.sh - keep the three in sync.
rem Re-encode MP3 and OGG files in place when the result is smaller.
rem Requires ffmpeg with libmp3lame and libvorbis.
rem Note: cmd.exe arithmetic is 32-bit, so the byte totals in the summary can
rem overflow on multi-GB roots; per-file decisions use full file sizes via
rem %%~z and are unaffected in practice for individual audio files.
setlocal EnableExtensions EnableDelayedExpansion

set "ROOT="
set "MP3_BITRATE=128"
set "OGG_BITRATE=96"
set "DRY_RUN=0"

for %%I in ("%~dp0..") do set "DEFAULT_ROOT=%%~fI"

:parse
if "%~1"=="" goto parsed
if /i "%~1"=="--root" goto arg_root
if /i "%~1"=="--mp3-bitrate" goto arg_mp3
if /i "%~1"=="--ogg-bitrate" goto arg_ogg
if /i "%~1"=="--dry-run" goto arg_dry
if /i "%~1"=="-h" goto usage_ok
if /i "%~1"=="--help" goto usage_ok
echo Unknown option: %~1 1>&2
goto usage_err

:arg_root
set "ROOT=%~2"
shift
shift
goto parse

:arg_mp3
set "MP3_BITRATE=%~2"
shift
shift
goto parse

:arg_ogg
set "OGG_BITRATE=%~2"
shift
shift
goto parse

:arg_dry
set "DRY_RUN=1"
shift
goto parse

:usage_ok
echo Usage: %~nx0 [--root DIR] [--mp3-bitrate KBPS] [--ogg-bitrate KBPS] [--dry-run]
echo Defaults: root=repository root (%DEFAULT_ROOT%), MP3=128 kbps, OGG=96 kbps
echo --dry-run encodes and reports savings without replacing any file.
exit /b 0

:usage_err
echo Usage: %~nx0 [--root DIR] [--mp3-bitrate KBPS] [--ogg-bitrate KBPS] [--dry-run] 1>&2
exit /b 2

:parsed
if not defined ROOT set "ROOT=%DEFAULT_ROOT%"
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
if "%DRY_RUN%"=="1" echo Mode: DRY RUN - files are encoded to a temp copy and measured, nothing is replaced.
echo.

set /a TOTAL=0
for /r "%ROOT%" %%F in (*.mp3 *.ogg) do call :count "%%~fF"
if %TOTAL%==0 (
    echo No MP3 or OGG files found under: %ROOT%
    echo Pass a different folder with --root, e.g.: %~nx0 --root assets
    exit /b 0
)
echo Found %TOTAL% audio files.
echo.

set /a PROCESSED=0, REPLACED=0, PLANNED=0, SKIPPED=0, FAILED=0
set /a TOTAL_ORIGINAL=0, TOTAL_FINAL=0

for /r "%ROOT%" %%F in (*.mp3 *.ogg) do call :process "%%~fF"
goto summary

:count
set "CF=%~1"
if not "!CF:\.git\=!"=="!CF!" exit /b 0
set /a TOTAL+=1
exit /b 0

:process
set "FILE=%~1"
if not "!FILE:\.git\=!"=="!FILE!" exit /b 0
set /a PROCESSED+=1
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
if "%DRY_RUN%"=="1" (
    set "OUT=%TEMP%\phoenix-audio-probe-%RANDOM%-%RANDOM%%EXT%"
) else (
    set "OUT=%FILE%.compress.%RANDOM%%EXT%"
)
ffmpeg -hide_banner -loglevel error -y -i "%FILE%" -map 0:a:0 -map_metadata 0 -vn -c:a !CODEC! -b:a !BITRATE!k -ar 44100 -ac 2 "!OUT!" <nul
if errorlevel 1 goto failed
if not exist "!OUT!" goto failed
for %%O in ("!OUT!") do set /a COMPRESSED=%%~zO
if !COMPRESSED! LSS %ORIGINAL% (
    set /a "PCT=(ORIGINAL-COMPRESSED)*100/ORIGINAL" 2>nul
    set /a TOTAL_FINAL+=COMPRESSED
    if "%DRY_RUN%"=="1" (
        set /a PLANNED+=1
        echo   Would replace: %ORIGINAL% -^> !COMPRESSED! bytes ^(save !PCT!%%^)
        del /q "!OUT!" 2>nul
    ) else (
        move /y "!OUT!" "%FILE%" >nul
        set /a REPLACED+=1
        echo   %ORIGINAL% -^> !COMPRESSED! bytes
        echo   Saved !PCT!%%
    )
) else (
    del /q "!OUT!" 2>nul
    set /a TOTAL_FINAL+=ORIGINAL, SKIPPED+=1
    echo   Skipped: compressed file was not smaller.
)
echo.
exit /b 0

:failed
if not defined OUT goto failed_count
if exist "!OUT!" del /q "!OUT!" 2>nul
:failed_count
set /a TOTAL_FINAL+=ORIGINAL, FAILED+=1
echo   FAILED: ffmpeg could not encode this file 1>&2
echo.
exit /b 0

:summary
set /a TOTAL_SAVED=TOTAL_ORIGINAL-TOTAL_FINAL
echo ========================================
if "%DRY_RUN%"=="1" (echo  Dry run complete ^(no files were modified^)) else (echo  Compression complete)
echo ========================================
echo Files processed : %PROCESSED%
if "%DRY_RUN%"=="1" (echo Would replace   : %PLANNED%) else (echo Files replaced  : %REPLACED%)
echo Files skipped   : %SKIPPED%
echo Files failed    : %FAILED%
echo.
echo Original size ^(bytes^) : %TOTAL_ORIGINAL%
echo Final size    ^(bytes^) : %TOTAL_FINAL%
echo Space saved   ^(bytes^) : %TOTAL_SAVED%
if "%DRY_RUN%"=="1" echo Re-run without --dry-run to apply these changes.
endlocal
