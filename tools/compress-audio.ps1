param(
    [string]$Root = "",
    [int]$Mp3Bitrate = 128,
    [int]$OggBitrate = 96,
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

if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: ffmpeg was not found in PATH." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Audio Compressor" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Root: $Root"

if ($DryRun) {
    Write-Host "Mode: DRY RUN - files are encoded to a temp copy and measured, nothing is replaced." -ForegroundColor Magenta
}

Write-Host ""

# Recursively find every MP3 and OGG (skipping .git)
$files = @(Get-ChildItem -Path $Root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {
        ($_.Extension -eq ".mp3" -or $_.Extension -eq ".ogg") -and
        $_.FullName -notmatch '\\\.git\\'
    })

if ($files.Count -eq 0) {
    Write-Host "No MP3 or OGG files found under: $Root" -ForegroundColor Yellow
    Write-Host "Pass a different folder with -Root, e.g.: .\compress-audio.ps1 -Root assets" -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($files.Count) audio files." -ForegroundColor Green
Write-Host ""

$totalOriginal = 0
$totalFinal = 0
$processed = 0
$replaced = 0
$planned = 0
$skipped = 0
$failed = 0


foreach ($file in $files) {

    $processed++

    $relative = $file.FullName.Substring($Root.Length).TrimStart('\')

    Write-Host "[$processed/$($files.Count)] $relative" -ForegroundColor Cyan

    $originalSize = [int64]$file.Length
    $totalOriginal += $originalSize

    $tempFile = "$($file.FullName).compress.$([Guid]::NewGuid())$($file.Extension)"

    try {

        if ($file.Extension -eq ".mp3") {

            Write-Host "  MP3 -> MP3 ($Mp3Bitrate kbps)" -ForegroundColor DarkGray

            & ffmpeg -hide_banner -loglevel error -y `
                -i "$($file.FullName)" `
                -map 0:a:0 `
                -map_metadata 0 `
                -vn `
                -c:a libmp3lame `
                -b:a "${Mp3Bitrate}k" `
                -ar 44100 `
                -ac 2 `
                "$tempFile"
        }
        else {

            Write-Host "  OGG Vorbis -> OGG Vorbis ($OggBitrate kbps)" -ForegroundColor DarkGray

            & ffmpeg -hide_banner -loglevel error -y `
                -i "$($file.FullName)" `
                -map 0:a:0 `
                -map_metadata 0 `
                -vn `
                -c:a libvorbis `
                -b:a "${OggBitrate}k" `
                -ar 44100 `
                -ac 2 `
                "$tempFile"
        }

        if ($LASTEXITCODE -ne 0) {
            throw "FFmpeg returned exit code $LASTEXITCODE"
        }

        if (-not (Test-Path -LiteralPath $tempFile)) {
            throw "FFmpeg did not create an output file."
        }

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

                # File.Replace() must be given a real backup path. Windows PowerShell
                # hands .NET an empty string for a $null string argument, and .NET then
                # fails with "The path is not of a legal form." The backup lives in the
                # same directory (same volume) and is deleted right after the swap.
                $backupFile = "$($file.FullName).replacing.bak"

                try {
                    [System.IO.File]::Replace($tempFile, $file.FullName, $backupFile)
                }
                catch {
                    # ReplaceFile() is not available on every filesystem (network
                    # shares, FAT/exFAT), so fall back to renames in the same folder.
                    if (-not (Test-Path -LiteralPath $file.FullName)) {
                        # Should be impossible; never leave the original audio missing.
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

                if ($wasReadOnly) {
                    $newItem = Get-Item -LiteralPath $file.FullName
                    $newItem.IsReadOnly = $true
                }

                $totalFinal += $compressedSize
                $replaced++

                Write-Host ("  {0:N2} MB -> {1:N2} MB" -f $oldMB, $newMB) -ForegroundColor Green
                Write-Host ("  Saved {0:N2}%" -f $percent) -ForegroundColor Green
            }
        }
        else {

            Remove-Item -LiteralPath $tempFile -Force

            $totalFinal += $originalSize
            $skipped++

            Write-Host "  Skipped: compressed file was not smaller." -ForegroundColor Yellow
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