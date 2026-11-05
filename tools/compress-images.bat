@echo off
rem Port of compress-images.ps1 / compress-images.sh - keep the three in sync.
rem Re-compress PNG and JPEG images in place when the result is smaller.
rem PNG: optional palette quantization (pngquant) then lossless optimization
rem (oxipng/optipng/zopflipng/pngcrush/ImageMagick). JPEG: jpegoptim or
rem ImageMagick. WebP/GIF/BMP are reported and left untouched.
rem cmd.exe cannot sniff binary magic the way the .ps1/.sh versions do, so
rem files are classified by extension here; animated PNGs are protected by
rem searching for the acTL chunk before quantizing.
rem cmd.exe arithmetic is 32-bit: byte totals can overflow on huge roots.
setlocal EnableExtensions EnableDelayedExpansion

set "ROOT="
set "QUALITY=85-95"
set "COLORS=256"
set "JPEG_QUALITY=85"
set "LOSSLESS=0"
set "DRY_RUN=0"

for %%I in ("%~dp0..") do set "DEFAULT_ROOT=%%~fI"

:parse
if "%~1"=="" goto parsed
if /i "%~1"=="--root" goto arg_root
if /i "%~1"=="--quality" goto arg_quality
if /i "%~1"=="--colors" goto arg_colors
if /i "%~1"=="--jpeg-quality" goto arg_jpeg_quality
if /i "%~1"=="--lossless" goto arg_lossless
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

:arg_quality
set "QUALITY=%~2"
shift
shift
goto parse

:arg_colors
set "COLORS=%~2"
shift
shift
goto parse

:arg_jpeg_quality
set "JPEG_QUALITY=%~2"
shift
shift
goto parse

:arg_lossless
set "LOSSLESS=1"
shift
goto parse

:arg_dry
set "DRY_RUN=1"
shift
goto parse

:usage_ok
echo Usage: %~nx0 [--root DIR] [--quality MIN-MAX] [--colors N] [--jpeg-quality N] [--lossless] [--dry-run]
echo Defaults: root=repository root (%DEFAULT_ROOT%), quality=85-95, colors=256, jpeg-quality=85
exit /b 0

:usage_err
echo Usage: %~nx0 [--root DIR] [--quality MIN-MAX] [--colors N] [--jpeg-quality N] [--lossless] [--dry-run] 1>&2
exit /b 2

:parsed
if not defined ROOT set "ROOT=%DEFAULT_ROOT%"
if not exist "%ROOT%\" (
    echo ERROR: directory not found: %ROOT% 1>&2
    exit /b 1
)
for %%I in ("%ROOT%") do set "ROOT=%%~fI"

rem ---- tool detection -------------------------------------------------------
set "PNGQUANT=" & set "OXIPNG=" & set "OPTIPNG=" & set "ZOPFLIPNG=" & set "PNGCRUSH=" & set "JPEGOPTIM=" & set "MAGICK="
for /f "delims=" %%P in ('where pngquant 2^>nul') do if not defined PNGQUANT set "PNGQUANT=%%P"
for /f "delims=" %%P in ('where oxipng 2^>nul') do if not defined OXIPNG set "OXIPNG=%%P"
for /f "delims=" %%P in ('where optipng 2^>nul') do if not defined OPTIPNG set "OPTIPNG=%%P"
for /f "delims=" %%P in ('where zopflipng 2^>nul') do if not defined ZOPFLIPNG set "ZOPFLIPNG=%%P"
for /f "delims=" %%P in ('where pngcrush 2^>nul') do if not defined PNGCRUSH set "PNGCRUSH=%%P"
for /f "delims=" %%P in ('where jpegoptim 2^>nul') do if not defined JPEGOPTIM set "JPEGOPTIM=%%P"
for /f "delims=" %%P in ('where magick 2^>nul') do if not defined MAGICK set "MAGICK=%%P"
if not defined MAGICK (
    for /f "delims=" %%P in ('where convert 2^>nul') do if not defined MAGICK (
        convert -version 2>nul | findstr /c:"ImageMagick" >nul && set "MAGICK=%%P"
    )
)

set "PNG_LOSSLESS_KIND="
if defined OXIPNG (set "PNG_LOSSLESS_KIND=oxipng") else if defined OPTIPNG (set "PNG_LOSSLESS_KIND=optipng") else if defined ZOPFLIPNG (set "PNG_LOSSLESS_KIND=zopflipng") else if defined PNGCRUSH (set "PNG_LOSSLESS_KIND=pngcrush") else if defined MAGICK (set "PNG_LOSSLESS_KIND=magick")
set "JPEG_TOOL_KIND="
if defined JPEGOPTIM (set "JPEG_TOOL_KIND=jpegoptim") else if defined MAGICK (set "JPEG_TOOL_KIND=magick")

echo.
echo ========================================
echo  Image Compressor
echo ========================================
echo Root: %ROOT%
if defined PNGQUANT (echo PNG quantizer : pngquant) else (echo PNG quantizer : none ^(lossless only; install pngquant for smaller files^))
if defined PNG_LOSSLESS_KIND (echo PNG optimizer : %PNG_LOSSLESS_KIND%) else (echo PNG optimizer : none)
if defined JPEG_TOOL_KIND (echo JPEG tool     : %JPEG_TOOL_KIND%) else (echo JPEG tool     : none)
if defined PNGQUANT goto tools_ok
if defined PNG_LOSSLESS_KIND goto tools_ok
if defined JPEG_TOOL_KIND goto tools_ok
echo ERROR: no image tools found in PATH ^(need pngquant/oxipng/optipng/zopflipng/pngcrush/jpegoptim or ImageMagick^). 1>&2
exit /b 1
:tools_ok
if "%DRY_RUN%"=="1" echo Mode: DRY RUN - nothing is replaced.
if "%LOSSLESS%"=="1" echo Mode: LOSSLESS - the lossy palette step is skipped.
echo.

set /a TOTAL=0
for /r "%ROOT%" %%F in (*.png *.jpg *.jpeg *.webp *.gif *.bmp) do call :count "%%~fF"
if %TOTAL%==0 (
    echo No image files found under: %ROOT%
    echo Pass a different folder with --root, e.g.: %~nx0 --root assets
    exit /b 0
)
echo Found %TOTAL% image files.
echo.

set /a PROCESSED=0, REPLACED=0, PLANNED=0, SKIPPED=0, IGNORED=0, FAILED=0
set /a TOTAL_ORIGINAL=0, TOTAL_FINAL=0

for /r "%ROOT%" %%F in (*.png *.jpg *.jpeg *.webp *.gif *.bmp) do call :process "%%~fF"
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

if /i "%EXT%"==".webp" goto ignored_webp
if /i "%EXT%"==".gif" goto ignored_gif
if /i "%EXT%"==".bmp" goto ignored_bmp
if /i "%EXT%"==".png" goto do_png
if /i "%EXT%"==".jpg" goto do_jpeg
if /i "%EXT%"==".jpeg" goto do_jpeg
echo   Ignored: unrecognized image data
set /a IGNORED+=1, TOTAL_FINAL+=ORIGINAL
echo.
exit /b 0

:ignored_webp
echo   Ignored: WebP content is left untouched
set /a IGNORED+=1, TOTAL_FINAL+=ORIGINAL
echo.
exit /b 0

:ignored_gif
echo   Ignored: GIF content is left untouched
set /a IGNORED+=1, TOTAL_FINAL+=ORIGINAL
echo.
exit /b 0

:ignored_bmp
echo   Ignored: BMP content is left untouched
set /a IGNORED+=1, TOTAL_FINAL+=ORIGINAL
echo.
exit /b 0

:do_png
if defined PNGQUANT goto png_stage
if defined PNG_LOSSLESS_KIND goto png_stage
echo   Ignored: no PNG tool available
set /a IGNORED+=1, TOTAL_FINAL+=ORIGINAL
echo.
exit /b 0
:png_stage
set "STAGE=%FILE%.compress.%RANDOM%.png"
if "%DRY_RUN%"=="1" set "STAGE=%TEMP%\phoenix-image-stage-%RANDOM%-%RANDOM%.png"
copy /y "%FILE%" "!STAGE!" >nul
set "OK=1"
rem Animated PNGs must never be quantized (that would flatten them).
set "IS_APNG=0"
findstr /m /c:"acTL" "%FILE%" >nul 2>&1 && set "IS_APNG=1"
if not "%LOSSLESS%"=="0" goto quant_done
if not defined PNGQUANT goto quant_done
if not "!IS_APNG!"=="0" goto quant_done
set "QOUT=%TEMP%\phoenix-quant-%RANDOM%-%RANDOM%.png"
del /q "!QOUT!" 2>nul
pngquant --quality="%QUALITY%" --skip-if-larger --strip --force --output "!QOUT!" %COLORS% -- "!STAGE!" <nul
if exist "!QOUT!" (
    move /y "!QOUT!" "!STAGE!" >nul
    echo   Quantized: pngquant ^(%COLORS% colors, quality %QUALITY%^)
) else (
    echo   Quantize skipped: would not improve size/quality.
)
:quant_done
if defined PNG_LOSSLESS_KIND call :optimize_png "!STAGE!"
goto finish_stage

:optimize_png
if "%PNG_LOSSLESS_KIND%"=="oxipng" "%OXIPNG%" -o 4 --strip safe --quiet "%~1" <nul
if "%PNG_LOSSLESS_KIND%"=="optipng" "%OPTIPNG%" -o2 -strip -quiet -clobber "%~1" <nul
if "%PNG_LOSSLESS_KIND%"=="zopflipng" (
    "%ZOPFLIPNG%" -y "%~1" "%~1.zopfli" >nul <nul
    if exist "%~1.zopfli" move /y "%~1.zopfli" "%~1" >nul
)
if "%PNG_LOSSLESS_KIND%"=="pngcrush" "%PNGCRUSH%" -q -ow -reduce "%~1" >nul <nul
if "%PNG_LOSSLESS_KIND%"=="magick" (
    "%MAGICK%" "%~1" -strip +repage -define png:compression-level=9 -define png:compression-strategy=1 -define png:compression-filter=5 "%~1.im.png" <nul
    if exist "%~1.im.png" move /y "%~1.im.png" "%~1" >nul
)
echo   Optimized: %PNG_LOSSLESS_KIND%
exit /b 0

:do_jpeg
if not defined JPEG_TOOL_KIND (
    echo   Ignored: no JPEG tool available
    set /a IGNORED+=1, TOTAL_FINAL+=ORIGINAL
    echo.
    exit /b 0
)
set "STAGE=%FILE%.compress.%RANDOM%.jpg"
if "%DRY_RUN%"=="1" set "STAGE=%TEMP%\phoenix-image-stage-%RANDOM%-%RANDOM%.jpg"
copy /y "%FILE%" "!STAGE!" >nul
set "OK=1"
if "%JPEG_TOOL_KIND%"=="jpegoptim" (
    "%JPEGOPTIM%" --strip-all --all-progressive --max="%JPEG_QUALITY%" --quiet "!STAGE!" <nul
    if errorlevel 1 set "OK=0"
    if "!OK!"=="1" echo   Re-encoded: jpegoptim ^(quality %JPEG_QUALITY%^)
) else (
    "%MAGICK%" "!STAGE!" -strip -interlace Plane -quality "%JPEG_QUALITY%" "!STAGE!.im.jpg" <nul
    if exist "!STAGE!.im.jpg" (
        move /y "!STAGE!.im.jpg" "!STAGE!" >nul
        echo   Re-encoded: ImageMagick ^(quality %JPEG_QUALITY%^)
    ) else (
        set "OK=0"
    )
)
goto finish_stage

:finish_stage
if not "!OK!"=="1" goto stage_failed
if not exist "!STAGE!" goto stage_failed
for %%O in ("!STAGE!") do set /a COMPRESSED=%%~zO
if !COMPRESSED! LSS %ORIGINAL% (
    set /a "PCT=(ORIGINAL-COMPRESSED)*100/ORIGINAL" 2>nul
    set /a TOTAL_FINAL+=COMPRESSED
    if "%DRY_RUN%"=="1" (
        set /a PLANNED+=1
        echo   Would replace: %ORIGINAL% -^> !COMPRESSED! bytes ^(save !PCT!%%^)
        del /q "!STAGE!" 2>nul
    ) else (
        move /y "!STAGE!" "%FILE%" >nul
        set /a REPLACED+=1
        echo   %ORIGINAL% -^> !COMPRESSED! bytes
        echo   Saved !PCT!%%
    )
) else (
    del /q "!STAGE!" 2>nul
    set /a TOTAL_FINAL+=ORIGINAL, SKIPPED+=1
    echo   Skipped: compressed file was not smaller.
)
echo.
exit /b 0

:stage_failed
if not defined STAGE goto stage_failed_count
if exist "!STAGE!" del /q "!STAGE!" 2>nul
:stage_failed_count
set /a TOTAL_FINAL+=ORIGINAL, FAILED+=1
echo   FAILED: could not compress this file 1>&2
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
echo Files ignored   : %IGNORED%
echo Files failed    : %FAILED%
echo.
echo Original size ^(bytes^) : %TOTAL_ORIGINAL%
echo Final size    ^(bytes^) : %TOTAL_FINAL%
echo Space saved   ^(bytes^) : %TOTAL_SAVED%
if "%DRY_RUN%"=="1" echo Re-run without --dry-run to apply these changes.
endlocal
