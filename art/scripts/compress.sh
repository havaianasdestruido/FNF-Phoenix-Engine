#!/bin/sh
# Port of compress.ps1 - keep in sync with compress.ps1 / compress.bat.
# Re-encodes every MP3/OGG under the root in place when the result is smaller.
# Usage: compress.sh [root] [mp3-bitrate] [ogg-bitrate]
#   Defaults: root=current directory, MP3=128 kbps, OGG=96 kbps.
set -u

ROOT=${1:-$(pwd)}
MP3_BITRATE=${2:-128}
OGG_BITRATE=${3:-96}

command -v ffmpeg >/dev/null 2>&1 || { echo "ERROR: ffmpeg was not found in PATH." >&2; exit 1; }
[ -d "$ROOT" ] || { echo "ERROR: directory not found: $ROOT" >&2; exit 1; }
ROOT=$(CDPATH= cd -- "$ROOT" && pwd)

echo ""
echo "========================================"
echo " Audio Compressor"
echo "========================================"
echo "Root: $ROOT"
echo ""

tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/audio-compress.XXXXXX")
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM
filelist="$tmpdir/files"
find "$ROOT" -type f \( -iname '*.mp3' -o -iname '*.ogg' \) -print > "$filelist"
count=$(wc -l < "$filelist" | tr -d ' ')

if [ "$count" -eq 0 ]; then
    echo "No MP3 or OGG files found."
    exit 0
fi

echo "Found $count audio files."
echo ""

total_original=0; total_final=0; processed=0; replaced=0; skipped=0; failed=0

while IFS= read -r file; do
    processed=$((processed + 1))
    relative=${file#"$ROOT"/}
    echo "[$processed/$count] $relative"
    original=$(wc -c < "$file" | tr -d ' ')
    total_original=$((total_original + original))
    ext=$(printf '%s' "${file##*.}" | tr '[:upper:]' '[:lower:]')
    tmpfile="$tmpdir/out.$ext"

    if [ "$ext" = "mp3" ]; then
        echo "  MP3 -> MP3 ($MP3_BITRATE kbps)"
        codec=libmp3lame; bitrate=$MP3_BITRATE
    else
        echo "  OGG Vorbis -> OGG Vorbis ($OGG_BITRATE kbps)"
        codec=libvorbis; bitrate=$OGG_BITRATE
    fi

    if ffmpeg -hide_banner -loglevel error -y -i "$file" -map 0:a:0 -vn \
            -c:a "$codec" -b:a "${bitrate}k" -ar 44100 -ac 2 "$tmpfile" </dev/null \
            && [ -f "$tmpfile" ]; then
        compressed=$(wc -c < "$tmpfile" | tr -d ' ')
        if [ "$compressed" -lt "$original" ]; then
            # Preserve timestamps as closely as POSIX allows.
            touch -r "$file" "$tmpfile" 2>/dev/null || true
            mv -f "$tmpfile" "$file"
            total_final=$((total_final + compressed)); replaced=$((replaced + 1))
            awk -v o="$original" -v n="$compressed" 'BEGIN { printf "  %.2f MB -> %.2f MB\n  Saved %.2f%%\n", o/1048576, n/1048576, (o-n)/o*100 }'
        else
            rm -f "$tmpfile"
            total_final=$((total_final + original)); skipped=$((skipped + 1))
            echo "  Skipped: compressed file was not smaller."
        fi
    else
        rm -f "$tmpfile"
        total_final=$((total_final + original)); failed=$((failed + 1))
        echo "  FAILED: ffmpeg could not encode this file" >&2
    fi
    echo ""
done < "$filelist"

total_saved=$((total_original - total_final))
echo "========================================"
echo " Compression complete"
echo "========================================"
echo "Files processed : $processed"
echo "Files replaced  : $replaced"
echo "Files skipped   : $skipped"
echo "Files failed    : $failed"
echo ""
awk -v o="$total_original" -v f="$total_final" -v s="$total_saved" 'BEGIN {
    printf "Original size   : %.2f MB\nFinal size      : %.2f MB\nSpace saved     : %.2f MB\n", o/1048576, f/1048576, s/1048576
    if (o > 0) printf "Reduction       : %.2f%%\n", s/o*100
}'
