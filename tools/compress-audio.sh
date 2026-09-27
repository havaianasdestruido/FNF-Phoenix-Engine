#!/usr/bin/env sh
# Re-encode MP3 and OGG files in place when the result is smaller.
# Requires ffmpeg with libmp3lame and libvorbis.
set -eu

ROOT=""
MP3_BITRATE=128
OGG_BITRATE=96

# Default root: the repository root (parent of the directory holding this script),
# so the tool behaves the same no matter where it is run from.
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DEFAULT_ROOT=$(CDPATH= cd -- "$script_dir/.." && pwd)

usage() {
    printf '%s\n' "Usage: $0 [--root DIR] [--mp3-bitrate KBPS] [--ogg-bitrate KBPS]"
    printf '%s\n' "Defaults: root=repository root ($DEFAULT_ROOT), MP3=128 kbps, OGG=96 kbps"
}
while [ "$#" -gt 0 ]; do
    case "$1" in
        --root) ROOT=${2:?Missing value for --root}; shift 2 ;;
        --mp3-bitrate) MP3_BITRATE=${2:?Missing value for --mp3-bitrate}; shift 2 ;;
        --ogg-bitrate) OGG_BITRATE=${2:?Missing value for --ogg-bitrate}; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
done

[ -n "$ROOT" ] || ROOT=$DEFAULT_ROOT

command -v ffmpeg >/dev/null 2>&1 || { echo 'ERROR: ffmpeg was not found in PATH.' >&2; exit 1; }
[ -d "$ROOT" ] || { echo "ERROR: directory not found: $ROOT" >&2; exit 1; }

tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/phoenix-audio.XXXXXX")
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM
filelist="$tmpdir/files"
find "$ROOT" -type d -name .git -prune -o -type f \( -iname '*.mp3' -o -iname '*.ogg' \) -print > "$filelist"

if [ ! -s "$filelist" ]; then
    echo "No MP3 or OGG files found under: $ROOT"
    echo "Pass a different folder with --root, e.g.: $0 --root assets"
    exit 0
fi

processed=0; replaced=0; skipped=0; failed=0; saved=0
while IFS= read -r file; do
    processed=$((processed + 1))
    ext=${file##*.}; ext=$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')
    original=$(wc -c < "$file" | tr -d ' ')
    out="${file}.compress.$$.$ext"
    printf '[%s] %s\n' "$processed" "$file"

    if [ "$ext" = mp3 ]; then codec=libmp3lame; bitrate=$MP3_BITRATE
    else codec=libvorbis; bitrate=$OGG_BITRATE
    fi

    if ffmpeg -hide_banner -loglevel error -y -i "$file" -map 0:a:0 -vn \
        -map_metadata 0 -c:a "$codec" -b:a "${bitrate}k" -ar 44100 -ac 2 "$out" </dev/null; then
        compressed=$(wc -c < "$out" | tr -d ' ')
        if [ "$compressed" -lt "$original" ]; then
            # Keep the source timestamp; the replacement is atomic on the same filesystem.
            touch -r "$file" "$out" 2>/dev/null || true
            mv -f "$out" "$file"
            replaced=$((replaced + 1)); saved=$((saved + original - compressed))
            printf '  replaced (saved %.1f%%)\n' "$(awk "BEGIN { print (1 - $compressed / $original) * 100 }")"
        else
            skipped=$((skipped + 1)); rm -f "$out"
            echo '  skipped: output was not smaller'
        fi
    else
        failed=$((failed + 1)); rm -f "$out"; echo '  FAILED: ffmpeg could not encode this file' >&2
    fi
done < "$filelist"
printf '\nProcessed: %s | replaced: %s | skipped: %s | failed: %s\n' "$processed" "$replaced" "$skipped" "$failed"
printf 'Space saved: %s bytes\n' "$saved"
