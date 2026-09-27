#!/usr/bin/env sh
# Re-compress PNG and JPEG images in place when the result is smaller.
# PNG: optional high-quality palette quantization (pngquant) followed by
#      lossless re-optimization (oxipng/optipng/zopflipng/pngcrush/ImageMagick).
# JPEG: re-encode at a conservative quality (jpegoptim or ImageMagick).
# A file is replaced only when the compressed output is smaller AND the
# measured quality of the quantization stays above the --quality floor.
set -eu

ROOT=""
QUALITY="85-95"
COLORS=256
JPEG_QUALITY=85
LOSSLESS=0
DRY_RUN=0

# Default root: the repository root (parent of the directory holding this script),
# so the tool behaves the same no matter where it is run from.
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DEFAULT_ROOT=$(CDPATH= cd -- "$script_dir/.." && pwd)

usage() {
    printf '%s\n' "Usage: $0 [--root DIR] [--quality MIN-MAX] [--colors N] [--jpeg-quality N] [--lossless] [--dry-run]"
    printf '%s\n' "Defaults: root=repository root ($DEFAULT_ROOT), quality=85-95, colors=256, jpeg-quality=85"
    printf '%s\n' "  --quality    pngquant-style quality window for the lossy palette step."
    printf '%s\n' "  --colors     maximum palette size for PNG quantization (256 keeps a full palette)."
    printf '%s\n' "  --lossless   skip the lossy step; only re-optimize compression."
    printf '%s\n' "  --dry-run    compress to a temp copy and report savings without replacing any file."
    printf '%s\n' "Needs at least one PNG tool (pngquant + oxipng/optipng/zopflipng/pngcrush/ImageMagick)"
    printf '%s\n' "and one JPEG tool (jpegoptim or ImageMagick). The more of them are installed, the"
    printf '%s\n' "smaller the result. Files are identified by content, so a JPEG named .png is still"
    printf '%s\n' "processed as JPEG. WebP/GIF/BMP files are reported and left untouched."
}
while [ "$#" -gt 0 ]; do
    case "$1" in
        --root) ROOT=${2:?Missing value for --root}; shift 2 ;;
        --quality) QUALITY=${2:?Missing value for --quality}; shift 2 ;;
        --colors) COLORS=${2:?Missing value for --colors}; shift 2 ;;
        --jpeg-quality) JPEG_QUALITY=${2:?Missing value for --jpeg-quality}; shift 2 ;;
        --lossless) LOSSLESS=1; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
done

[ -n "$ROOT" ] || ROOT=$DEFAULT_ROOT
[ -d "$ROOT" ] || { echo "ERROR: directory not found: $ROOT" >&2; exit 1; }

# ---- tool detection ---------------------------------------------------------
PNGQUANT=$(command -v pngquant 2>/dev/null || true)
OXIPNG=$(command -v oxipng 2>/dev/null || true)
OPTIPNG=$(command -v optipng 2>/dev/null || true)
ZOPFLIPNG=$(command -v zopflipng 2>/dev/null || true)
PNGCRUSH=$(command -v pngcrush 2>/dev/null || true)
JPEGOPTIM=$(command -v jpegoptim 2>/dev/null || true)

# ImageMagick: prefer `magick` (IM7); accept `convert` only when it really is
# ImageMagick (on Windows convert.exe is the filesystem tool).
MAGICK=""
if command -v magick >/dev/null 2>&1; then
    MAGICK=$(command -v magick)
elif command -v convert >/dev/null 2>&1 && convert -version 2>/dev/null | grep -q 'ImageMagick'; then
    MAGICK=$(command -v convert)
fi

# Pick the lossless PNG optimizer to use (best first).
PNG_LOSSLESS=""
PNG_LOSSLESS_KIND=""
if [ -n "$OXIPNG" ]; then PNG_LOSSLESS=$OXIPNG; PNG_LOSSLESS_KIND=oxipng
elif [ -n "$OPTIPNG" ]; then PNG_LOSSLESS=$OPTIPNG; PNG_LOSSLESS_KIND=optipng
elif [ -n "$ZOPFLIPNG" ]; then PNG_LOSSLESS=$ZOPFLIPNG; PNG_LOSSLESS_KIND=zopflipng
elif [ -n "$PNGCRUSH" ]; then PNG_LOSSLESS=$PNGCRUSH; PNG_LOSSLESS_KIND=pngcrush
elif [ -n "$MAGICK" ]; then PNG_LOSSLESS=$MAGICK; PNG_LOSSLESS_KIND=magick
fi

JPEG_TOOL=""
JPEG_TOOL_KIND=""
if [ -n "$JPEGOPTIM" ]; then JPEG_TOOL=$JPEGOPTIM; JPEG_TOOL_KIND=jpegoptim
elif [ -n "$MAGICK" ]; then JPEG_TOOL=$MAGICK; JPEG_TOOL_KIND=magick
fi

echo "Root: $ROOT"
[ -n "$PNGQUANT" ] && echo "PNG quantizer : pngquant" || echo "PNG quantizer : none (lossless only; install pngquant for smaller files)"
case "$PNG_LOSSLESS_KIND" in
    '') echo "PNG optimizer : none (install oxipng, optipng, zopflipng, pngcrush or ImageMagick)" ;;
    *)  echo "PNG optimizer : $PNG_LOSSLESS_KIND" ;;
esac
case "$JPEG_TOOL_KIND" in
    '') echo "JPEG tool     : none (install jpegoptim or ImageMagick)" ;;
    *)  echo "JPEG tool     : $JPEG_TOOL_KIND" ;;
esac

if [ -z "$PNGQUANT" ] && [ -z "$PNG_LOSSLESS" ] && [ -z "$JPEG_TOOL" ]; then
    echo 'ERROR: no image tools found in PATH (need pngquant/oxipng/optipng/zopflipng/pngcrush/jpegoptim or ImageMagick).' >&2
    exit 1
fi

tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/phoenix-images.XXXXXX")
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM
filelist="$tmpdir/files"
find "$ROOT" -type d -name .git -prune -o -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.bmp' \) \
    -print > "$filelist"

if [ ! -s "$filelist" ]; then
    echo "No image files found under: $ROOT"
    echo "Pass a different folder with --root, e.g.: $0 --root assets"
    exit 0
fi

processed=0; replaced=0; planned=0; skipped=0; ignored=0; failed=0; saved=0
total_original=0; total_final=0

if [ "$DRY_RUN" = 1 ]; then
    echo "Mode: DRY RUN - nothing will be replaced."
fi

# Optimize the PNG staged at $1 in place using the available lossless tool.
optimize_png() {
    stage=$1
    case "$PNG_LOSSLESS_KIND" in
        oxipng)
            oxipng -o 4 --strip safe --quiet "$stage" ;;
        optipng)
            optipng -o2 -strip -quiet -clobber "$stage" ;;
        zopflipng)
            zopflipng -y "$stage" "$stage.zopfli" >/dev/null && mv -f "$stage.zopfli" "$stage" ;;
        pngcrush)
            pngcrush -q -ow -reduce "$stage" >/dev/null ;;
        magick)
            "$MAGICK" "$stage" -strip +repage \
                -define png:compression-level=9 \
                -define png:compression-strategy=1 \
                -define png:compression-filter=5 \
                "$stage.im" && mv -f "$stage.im" "$stage" ;;
        *) return 1 ;;
    esac
}

while IFS= read -r file; do
    processed=$((processed + 1))
    original=$(wc -c < "$file" | tr -d ' ')
    total_original=$((total_original + original))
    printf '[%s] %s\n' "$processed" "$file"

    # Identify the real format by content; extension may lie (this repo has a
    # JPEG named .png and a WebP named .png).
    head_hex=$(od -An -tx1 -N12 "$file" 2>/dev/null | tr -d ' \n')
    h4=$(printf '%s' "$head_hex" | cut -c1-8)
    h12b=$(printf '%s' "$head_hex" | cut -c17-24)

    fmt=""
    case "$h4" in
        89504e47) fmt=png ;;
        ffd8ff*)  fmt=jpg ;;
        47494638) fmt=gif ;;
        424d*)    fmt=bmp ;;
        52494646)
            [ "$h12b" = "57454250" ] && fmt=webp || fmt=unknown ;;
        *) fmt=unknown ;;
    esac

    case "$fmt" in
        png)
            if [ -z "$PNGQUANT" ] && [ -z "$PNG_LOSSLESS" ]; then
                ignored=$((ignored + 1)); total_final=$((total_final + original))
                echo '  ignored: no PNG tool available'
                continue
            fi
            ;;
        jpg)
            if [ -z "$JPEG_TOOL" ]; then
                ignored=$((ignored + 1)); total_final=$((total_final + original))
                echo '  ignored: no JPEG tool available'
                continue
            fi
            ;;
        webp) ignored=$((ignored + 1)); total_final=$((total_final + original))
            echo '  ignored: WebP content is left untouched'; continue ;;
        gif)  ignored=$((ignored + 1)); total_final=$((total_final + original))
            echo '  ignored: GIF content is left untouched'; continue ;;
        bmp)  ignored=$((ignored + 1)); total_final=$((total_final + original))
            echo '  ignored: BMP content is left untouched'; continue ;;
        *)    ignored=$((ignored + 1)); total_final=$((total_final + original))
            echo '  ignored: unrecognized image data'; continue ;;
    esac

    if [ "$DRY_RUN" = 1 ]; then stage="$tmpdir/stage.$fmt"; else stage="${file}.compress.$$.$fmt"; fi
    cp "$file" "$stage"

    ok=1
    case "$fmt" in
        png)
            # Animated PNGs must never be quantized (that would flatten them).
            is_apng=0
            if head -c 2048 "$file" | grep -q 'acTL'; then is_apng=1; fi

            if [ "$LOSSLESS" = 0 ] && [ -n "$PNGQUANT" ] && [ "$is_apng" = 0 ]; then
                qout="$tmpdir/quantized.png"
                rm -f "$qout"
                if pngquant --quality="$QUALITY" --skip-if-larger --strip --force \
                        --output "$qout" "$COLORS" -- "$stage" </dev/null; then
                    if [ -f "$qout" ]; then
                        mv -f "$qout" "$stage"
                        echo "  quantized: pngquant ($COLORS colors, quality $QUALITY)"
                    fi
                else
                    # 98 = output not smaller / 99 = below quality floor: keep the input.
                    rm -f "$qout"
                    echo '  quantize skipped: would not improve size/quality'
                fi
            fi

            if [ -n "$PNG_LOSSLESS" ]; then
                if optimize_png "$stage"; then
                    echo "  optimized: $PNG_LOSSLESS_KIND"
                else
                    ok=0
                fi
            fi
            ;;
        jpg)
            if [ "$JPEG_TOOL_KIND" = jpegoptim ]; then
                if jpegoptim --strip-all --all-progressive --max="$JPEG_QUALITY" --quiet "$stage" </dev/null; then
                    echo "  re-encoded: jpegoptim (quality $JPEG_QUALITY)"
                else
                    ok=0
                fi
            else
                if "$MAGICK" "$stage" -strip -interlace Plane -quality "$JPEG_QUALITY" "$stage.im" </dev/null \
                        && mv -f "$stage.im" "$stage"; then
                    echo "  re-encoded: ImageMagick (quality $JPEG_QUALITY)"
                else
                    rm -f "$stage.im"; ok=0
                fi
            fi
            ;;
    esac

    if [ "$ok" = 1 ] && [ -f "$stage" ]; then
        compressed=$(wc -c < "$stage" | tr -d ' ')
        if [ "$compressed" -lt "$original" ]; then
            pct=$(awk "BEGIN { print (1 - $compressed / $original) * 100 }")
            saved=$((saved + original - compressed))
            total_final=$((total_final + compressed))
            if [ "$DRY_RUN" = 1 ]; then
                planned=$((planned + 1))
                printf '  would replace (save %.1f%%)\n' "$pct"
            else
                # Keep the source timestamp; the replacement is atomic on the same filesystem.
                touch -r "$file" "$stage" 2>/dev/null || true
                mv -f "$stage" "$file"
                replaced=$((replaced + 1))
                printf '  replaced (saved %.1f%%)\n' "$pct"
            fi
        else
            skipped=$((skipped + 1)); total_final=$((total_final + original))
            echo '  skipped: output was not smaller'
        fi
    else
        failed=$((failed + 1)); total_final=$((total_final + original))
        echo '  FAILED: could not compress this file' >&2
    fi
    [ "$DRY_RUN" = 1 ] || rm -f "$stage"
done < "$filelist"

if [ "$DRY_RUN" = 1 ]; then
    printf '\nDry run: %s files | would replace: %s | skipped: %s | ignored: %s | failed: %s\n' \
        "$processed" "$planned" "$skipped" "$ignored" "$failed"
    printf 'Projected saving: %s bytes (%s MB). Re-run without --dry-run to apply.\n' \
        "$saved" "$(awk "BEGIN { printf \"%.2f\", $saved / 1048576 }")"
else
    printf '\nProcessed: %s | replaced: %s | skipped: %s | ignored: %s | failed: %s\n' \
        "$processed" "$replaced" "$skipped" "$ignored" "$failed"
    printf 'Space saved: %s bytes (%s MB)\n' \
        "$saved" "$(awk "BEGIN { printf \"%.2f\", $saved / 1048576 }")"
fi
printf 'Total: %s MB -> %s MB\n' \
    "$(awk "BEGIN { printf \"%.2f\", $total_original / 1048576 }")" \
    "$(awk "BEGIN { printf \"%.2f\", $total_final / 1048576 }")"
