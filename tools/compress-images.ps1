param(
    [string]$Root = "",
    [string]$Quality = "85-95",
    [int]$Colors = 256,
    [int]$JpegQuality = 85,
    [switch]$Lossless,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Default to the repository root (the folder that contains tools/) so the script
# works no matter which directory it is launched from.
if ([string]::IsNullOrWhiteSpace($Root)) {
    if ($PSScriptRoot) {
        $Root = Split-Path -Parent $PSScriptRoot
    }
    if ([string]::IsNullOrWhiteSpace($Root)) {
        $Root = (Get-Location).Path
    }
}

if (-not (Test-Path -LiteralPath $Root)) {
    Write-Host "ERROR: directory not found: $Root" -ForegroundColor Red
    exit 1
}

$Root = (Resolve-Path -LiteralPath $Root).Path

# ---- tool detection ---------------------------------------------------------

$PngQuant = (Get-Command pngquant -ErrorAction SilentlyContinue).Source
$Oxipng = (Get-Command oxipng -ErrorAction SilentlyContinue).Source
$Optipng = (Get-Command optipng -ErrorAction SilentlyContinue).Source
$Zopflipng = (Get-Command zopflipng -ErrorAction SilentlyContinue).Source
$Pngcrush = (Get-Command pngcrush -ErrorAction SilentlyContinue).Source
$Jpegoptim = (Get-Command jpegoptim -ErrorAction SilentlyContinue).Source

# ImageMagick: prefer `magick` (IM7). Accept `convert` only when it really is
# ImageMagick - on Windows convert.exe is the filesystem converter.
$Magick = (Get-Command magick -ErrorAction SilentlyContinue).Source
if (-not $Magick) {
    $convertCmd = Get-Command convert -ErrorAction SilentlyContinue
    if ($convertCmd) {
        $ver = & $convertCmd.Source -version 2>$null | Out-String
        if ($ver -match "ImageMagick") {
            $Magick = $convertCmd.Source
        }
    }
}

# Pick the lossless PNG optimizer to use (best first).
$PngLossless = $null
$PngLosslessKind = $null
if ($Oxipng) { $PngLossless = $Oxipng; $PngLosslessKind = "oxipng" }
elseif ($Optipng) { $PngLossless = $Optipng; $PngLosslessKind = "optipng" }
elseif ($Zopflipng) { $PngLossless = $Zopflipng; $PngLosslessKind = "zopflipng" }
elseif ($Pngcrush) { $PngLossless = $Pngcrush; $PngLosslessKind = "pngcrush" }
elseif ($Magick) { $PngLossless = $Magick; $PngLosslessKind = "magick" }

$JpegTool = $null
$JpegToolKind = $null
if ($Jpegoptim) { $JpegTool = $Jpegoptim; $JpegToolKind = "jpegoptim" }
elseif ($Magick) { $JpegTool = $Magick; $JpegToolKind = "magick" }

if (-not $PngQuant -and -not $PngLossless -and -not $JpegTool) {
    Write-Host "ERROR: no image tools found in PATH (need pngquant/oxipng/optipng/zopflipng/pngcrush/jpegoptim or ImageMagick)." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Image Compressor" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Root: $Root"

if ($PngQuant) {
    Write-Host "PNG quantizer : pngquant"
}
else {
    Write-Host "PNG quantizer : none (lossless only; install pngquant for smaller files)" -ForegroundColor Yellow
}
if ($PngLosslessKind) {
    Write-Host "PNG optimizer : $PngLosslessKind"
}
else {
    Write-Host "PNG optimizer : none (install oxipng, optipng, zopflipng, pngcrush or ImageMagick)" -ForegroundColor Yellow
}
if ($JpegToolKind) {
    Write-Host "JPEG tool     : $JpegToolKind"
}
else {
    Write-Host "JPEG tool     : none (install jpegoptim or ImageMagick)" -ForegroundColor Yellow
}

if ($DryRun) {
    Write-Host "Mode: DRY RUN - files are compressed to a temp copy and measured, nothing is replaced." -ForegroundColor Magenta
}
if ($Lossless) {
    Write-Host "Mode: LOSSLESS - the lossy palette step is skipped."
}

Write-Host ""

# Recursively find every PNG/JPEG/WebP/GIF/BMP (skipping .git)
$files = @(Get-ChildItem -LiteralPath $Root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {
        ($_.Extension -eq ".png" -or $_.Extension -eq ".jpg" -or $_.Extension -eq ".jpeg" -or
         $_.Extension -eq ".webp" -or $_.Extension -eq ".gif" -or $_.Extension -eq ".bmp") -and
        $_.FullName -notmatch '(\\|/)\.git(\\|/)'
    })

if ($files.Count -eq 0) {
    Write-Host "No image files found under: $Root" -ForegroundColor Yellow
    Write-Host "Pass a different folder with -Root, e.g.: .\compress-images.ps1 -Root assets" -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($files.Count) image files." -ForegroundColor Green
Write-Host ""

function Get-ImageFormat {
    param([byte[]]$Head)

    if ($Head.Length -ge 4 -and $Head[0] -eq 0x89 -and $Head[1] -eq 0x50 -and $Head[2] -eq 0x4E -and $Head[3] -eq 0x47) { return "png" }
    if ($Head.Length -ge 3 -and $Head[0] -eq 0xFF -and $Head[1] -eq 0xD8 -and $Head[2] -eq 0xFF) { return "jpg" }
    if ($Head.Length -ge 12 -and $Head[0] -eq 0x52 -and $Head[1] -eq 0x49 -and $Head[2] -eq 0x46 -and $Head[3] -eq 0x46 -and
        $Head[8] -eq 0x57 -and $Head[9] -eq 0x45 -and $Head[10] -eq 0x42 -and $Head[11] -eq 0x50) { return "webp" }
    if ($Head.Length -ge 4 -and $Head[0] -eq 0x47 -and $Head[1] -eq 0x49 -and $Head[2] -eq 0x46 -and $Head[3] -eq 0x38) { return "gif" }
    if ($Head.Length -ge 2 -and $Head[0] -eq 0x42 -and $Head[1] -eq 0x4D) { return "bmp" }
    return "unknown"
}

function Test-IsApng {
    param([string]$Path)

    # acTL always appears near the start of an animated PNG (right after IHDR).
    $fs = [System.IO.File]::OpenRead($Path)
    try {
        $len = [Math]::Min(2048, $fs.Length)
        $buf = New-Object byte[] $len
        $read = $fs.Read($buf, 0, $len)
        $text = [System.Text.Encoding]::ASCII.GetString($buf, 0, $read)
        return $text.Contains("acTL")
    }
    finally {
        $fs.Close()
    }
}

$totalOriginal = 0
$totalFinal = 0
$processed = 0
$replaced = 0
$planned = 0
$skipped = 0
$ignored = 0
$failed = 0

foreach ($file in $files) {

    $processed++

    $relative = $file.FullName.Substring($Root.Length).TrimStart('\', '/')

    Write-Host "[$processed/$($files.Count)] $relative" -ForegroundColor Cyan

    $originalSize = [int64]$file.Length
    $totalOriginal += $originalSize

    # Identify the real format by content; extension may lie (this repo has a
    # JPEG named .png and a WebP named .png).
    $fs = [System.IO.File]::OpenRead($file.FullName)
    try {
        $head = New-Object byte[] 12
        $read = $fs.Read($head, 0, 12)
    }
    finally {
        $fs.Close()
    }
    if ($read -le 0) {
        $fmt = "unknown"
    }
    else {
        $fmt = Get-ImageFormat -Head $head[0..($read - 1)]
    }

    if ($fmt -eq "png") {
        if (-not $PngQuant -and -not $PngLossless) {
            $ignored++
            $totalFinal += $originalSize
            Write-Host "  Ignored: no PNG tool available." -ForegroundColor Yellow
            Write-Host ""
            continue
        }
    }
    elseif ($fmt -eq "jpg") {
        if (-not $JpegTool) {
            $ignored++
            $totalFinal += $originalSize
            Write-Host "  Ignored: no JPEG tool available." -ForegroundColor Yellow
            Write-Host ""
            continue
        }
    }
    else {
        $ignored++
        $totalFinal += $originalSize
        switch ($fmt) {
            "webp" { Write-Host "  Ignored: WebP content is left untouched." -ForegroundColor Yellow }
            "gif" { Write-Host "  Ignored: GIF content is left untouched." -ForegroundColor Yellow }
            "bmp" { Write-Host "  Ignored: BMP content is left untouched." -ForegroundColor Yellow }
            default { Write-Host "  Ignored: unrecognized image data." -ForegroundColor Yellow }
        }
        Write-Host ""
        continue
    }

    $tempFile = "$($file.FullName).compress.$([Guid]::NewGuid()).$fmt"
    $extraTemp = @()

    try {

        Copy-Item -LiteralPath $file.FullName -Destination $tempFile -Force

        $ok = $true

        if ($fmt -eq "png") {

            # Animated PNGs must never be quantized (that would flatten them).
            $isApng = Test-IsApng -Path $file.FullName

            if (-not $Lossless -and $PngQuant -and -not $isApng) {

                $qout = "$tempFile.quantized.png"
                $extraTemp += $qout

                & $PngQuant --quality="$Quality" --skip-if-larger --strip --force --output "$qout" "$Colors" -- "$tempFile" | Out-Null

                # pngquant exits 98 (not smaller) / 99 (below the quality floor)
                # without writing output; either way the input is kept as-is.
                if ((Test-Path -LiteralPath $qout) -and ((Get-Item -LiteralPath $qout).Length -gt 0)) {
                    Move-Item -LiteralPath $qout -Destination $tempFile -Force
                    Write-Host "  Quantized: pngquant ($Colors colors, quality $Quality)" -ForegroundColor DarkGray
                }
                else {
                    Write-Host "  Quantize skipped: would not improve size/quality." -ForegroundColor DarkGray
                }
            }

            if ($PngLosslessKind) {
                switch ($PngLosslessKind) {
                    "oxipng" {
                        & $PngLossless -o 4 --strip safe --quiet "$tempFile" | Out-Null
                    }
                    "optipng" {
                        & $PngLossless -o2 -strip -quiet -clobber "$tempFile" | Out-Null
                    }
                    "zopflipng" {
                        $zout = "$tempFile.zopfli"
                        $extraTemp += $zout
                        & $PngLossless -y "$tempFile" "$zout" | Out-Null
                        if (Test-Path -LiteralPath $zout) {
                            Move-Item -LiteralPath $zout -Destination $tempFile -Force
                        }
                    }
                    "pngcrush" {
                        & $PngLossless -q -ow -reduce "$tempFile" | Out-Null
                    }
                    "magick" {
                        $mout = "$tempFile.im.png"
                        $extraTemp += $mout
                        & $PngLossless "$tempFile" -strip +repage `
                            "-define" "png:compression-level=9" `
                            "-define" "png:compression-strategy=1" `
                            "-define" "png:compression-filter=5" `
                            "$mout" | Out-Null
                        if (Test-Path -LiteralPath $mout) {
                            Move-Item -LiteralPath $mout -Destination $tempFile -Force
                        }
                    }
                }
                Write-Host "  Optimized: $PngLosslessKind" -ForegroundColor DarkGray
            }
        }
        else {

            if ($JpegToolKind -eq "jpegoptim") {
                & $JpegTool --strip-all --all-progressive --max="$JpegQuality" --quiet "$tempFile" | Out-Null
            }
            else {
                $mout = "$tempFile.im.jpg"
                $extraTemp += $mout
                & $JpegTool "$tempFile" -strip -interlace Plane -quality "$JpegQuality" "$mout" | Out-Null
                if (Test-Path -LiteralPath $mout) {
                    Move-Item -LiteralPath $mout -Destination $tempFile -Force
                }
                else {
                    $ok = $false
                }
            }
            if ($ok) {
                Write-Host "  Re-encoded: $JpegToolKind (quality $JpegQuality)" -ForegroundColor DarkGray
            }
        }

        if ($ok -and (Test-Path -LiteralPath $tempFile)) {

            $compressedSize = [int64](Get-Item -LiteralPath $tempFile).Length

            if ($compressedSize -lt $originalSize) {

                $saved = $originalSize - $compressedSize
                $percent = ($saved / $originalSize) * 100

                $oldMB = $originalSize / 1MB
                $newMB = $compressedSize / 1MB

                if ($DryRun) {

                    $totalFinal += $compressedSize
                    $planned++

                    Write-Host ("  {0:N2} MB -> {1:N2} MB (would save {2:N2}%)" -f $oldMB, $newMB, $percent) -ForegroundColor Magenta
                }
                else {

                    $oldCreation = $file.CreationTime
                    $oldWrite = $file.LastWriteTime
                    $oldAccess = $file.LastAccessTime
                    $wasReadOnly = $file.IsReadOnly

                    [System.IO.File]::SetCreationTime($tempFile, $oldCreation)
                    [System.IO.File]::SetLastWriteTime($tempFile, $oldWrite)
                    [System.IO.File]::SetLastAccessTime($tempFile, $oldAccess)

                    if ($wasReadOnly) {
                        $file.IsReadOnly = $false
                    }

                    try {

                        # File.Replace() must be given a real backup path (same
                        # trick as compress-audio.ps1: Windows PowerShell hands
                        # .NET an empty string for a $null string argument).
                        # The backup lives in the same directory (same volume)
                        # and is deleted right after the swap. Its name is unique
                        # so a .bak left behind by an interrupted earlier run -
                        # which may hold the only copy of the original image - is
                        # never overwritten here or removed by the cleanup below.
                        $backupFile = "$($file.FullName).replacing.$([Guid]::NewGuid()).bak"

                        while (Test-Path -LiteralPath $backupFile) {
                            $backupFile = "$($file.FullName).replacing.$([Guid]::NewGuid()).bak"
                        }

                        try {
                            [System.IO.File]::Replace($tempFile, $file.FullName, $backupFile)
                        }
                        catch {
                            # ReplaceFile() is not available on every filesystem
                            # (network shares, FAT/exFAT), so fall back to renames
                            # in the same folder.
                            if (-not (Test-Path -LiteralPath $file.FullName)) {
                                # Should be impossible; never leave the original missing.
                                if (Test-Path -LiteralPath $backupFile) {
                                    Move-Item -LiteralPath $backupFile -Destination $file.FullName -Force
                                }
                                throw "Could not replace $($file.Name); the original file was restored."
                            }

                            Move-Item -LiteralPath $file.FullName -Destination $backupFile -Force

                            try {
                                Move-Item -LiteralPath $tempFile -Destination $file.FullName -Force
                            }
                            catch {
                                Move-Item -LiteralPath $backupFile -Destination $file.FullName -Force
                                throw
                            }
                        }

                        if (Test-Path -LiteralPath $backupFile) {
                            Remove-Item -LiteralPath $backupFile -Force
                        }
                    }
                    finally {
                        # Restore the attribute even when both the Replace and
                        # the fallback failed, so a file we could not compress is
                        # left exactly as found.
                        if ($wasReadOnly -and (Test-Path -LiteralPath $file.FullName)) {
                            $currentItem = Get-Item -LiteralPath $file.FullName
                            $currentItem.IsReadOnly = $true
                        }
                    }

                    $totalFinal += $compressedSize
                    $replaced++

                    Write-Host ("  {0:N2} MB -> {1:N2} MB" -f $oldMB, $newMB) -ForegroundColor Green
                    Write-Host ("  Saved {0:N2}%" -f $percent) -ForegroundColor Green
                }
            }
            else {

                $totalFinal += $originalSize
                $skipped++

                Write-Host "  Skipped: compressed file was not smaller." -ForegroundColor Yellow
            }
        }
        else {

            $totalFinal += $originalSize
            $failed++

            Write-Host "  FAILED: could not compress this file." -ForegroundColor Red
        }
    }
    catch {

        $totalFinal += $originalSize
        $failed++

        Write-Host "  FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {

        if (Test-Path -LiteralPath $tempFile) {
            Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
        }
        foreach ($extra in $extraTemp) {
            if (Test-Path -LiteralPath $extra) {
                Remove-Item -LiteralPath $extra -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Write-Host ""
}

$totalSaved = $totalOriginal - $totalFinal

Write-Host "========================================" -ForegroundColor Cyan
if ($DryRun) {
    Write-Host " Dry run complete (no files were modified)" -ForegroundColor Cyan
}
else {
    Write-Host " Compression complete" -ForegroundColor Cyan
}
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "Files processed : $processed"

if ($DryRun) {
    Write-Host "Would replace   : $planned"
}
else {
    Write-Host "Files replaced  : $replaced"
}

Write-Host "Files skipped   : $skipped"
Write-Host "Files ignored   : $ignored"
Write-Host "Files failed    : $failed"
Write-Host ""

if ($DryRun) {
    Write-Host ("Current size    : {0:N2} MB" -f ($totalOriginal / 1MB))
    Write-Host ("Projected size  : {0:N2} MB" -f ($totalFinal / 1MB))
    Write-Host ("Projected saving: {0:N2} MB" -f ($totalSaved / 1MB))
}
else {
    Write-Host ("Original size   : {0:N2} MB" -f ($totalOriginal / 1MB))
    Write-Host ("Final size      : {0:N2} MB" -f ($totalFinal / 1MB))
    Write-Host ("Space saved     : {0:N2} MB" -f ($totalSaved / 1MB))
}

if ($totalOriginal -gt 0) {
    $reduction = ($totalSaved / $totalOriginal) * 100
    Write-Host ("Reduction       : {0:N2}%" -f $reduction)
}

if ($DryRun) {
    Write-Host ""
    Write-Host "Re-run without -DryRun to apply these changes." -ForegroundColor Magenta
}
