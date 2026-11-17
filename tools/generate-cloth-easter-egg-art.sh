#!/usr/bin/env bash
# Generate the art used by the FlxClothSprite easter egg
# (states/substates/ClothEasterEggSubstate.hx).
#
#     bash tools/generate-cloth-easter-egg-art.sh
#
# Output (2 files, listed in tests/assets/builtin-assets.txt):
#   assets/preload/images/clothFlag.png
#   assets/preload/images/clothRope.png
#
# Both images are built from Phoenix's own art (the shipped phoenix_logo.png and
# assets/fonts/vcr.ttf) plus drawn shapes, so nothing is copied from the
# HaxeFlixel demo. They sit at the root of `assets/preload/images/` on purpose:
# that folder is already registered by project.hxp for every build mode
# (including the compact -DNO_BUILTIN_CONTENT CI build), while the character and
# dialogue subfolders are filtered there.
set -euo pipefail
cd "$(dirname "$0")/.."

convert -version >/dev/null 2>&1 || {
  echo "SKIP: ImageMagick (convert) not found"
  exit 0
}

logo=assets/preload/images/phoenix_logo.png
font=assets/fonts/vcr.ttf
[ -f "$logo" ] || { echo "FAIL: missing $logo" >&2; exit 1; }
[ -f "$font" ] || { echo "FAIL: missing $font" >&2; exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

#
# Banner: a horizontally striped cloth with the Phoenix emblem and a caption.
# The stripes give the mesh something to visibly bend, and the caption sits
# low so it stays readable while the flag streams to the right.
#
# A portrait gradient rotated into a 300x200 landscape banner.
convert -size 200x300 gradient:'#2A1030-#7B1857' -rotate 90 \
  "$work/base.png"

convert -size 300x200 xc:none \
  -fill 'rgba(255,255,255,0.055)' \
  -draw "polygon 0,0 150,0 40,200 0,200" \
  -draw "polygon 210,0 300,0 300,120 100,200 40,200 210,0" \
  "$work/sheen.png"

convert "$logo" -resize 132x132 "$work/emblem.png"

convert "$work/base.png" \
  "$work/sheen.png" -composite \
  "$work/emblem.png" -gravity north -geometry +0+12 -composite \
  -fill '#FFB3E6' -font "$font" -pointsize 20 \
  -gravity south -annotate +0+10 'PHOENIX ENGINE' \
  -fill none -stroke 'rgba(255,22,210,0.85)' -strokewidth 3 \
  -draw "rectangle 1,1 298,198" \
  -depth 8 -strip \
  assets/preload/images/clothFlag.png

#
# Rope: a hanging chain of alternating links. Rendered tall and thin so the
# cloth mesh (2 columns, 10 rows) bends it like a rope instead of a sheet.
#
: >"$work/links.mvg"
y=0
link=0
while [ "$y" -lt 360 ]; do
  if [ $((link % 2)) -eq 0 ]; then fill='#D9B36C'; edge='#8A6B1C'; else fill='#A8823A'; edge='#5E4713'; fi
  printf 'fill %s stroke %s stroke-width 1.5 roundrectangle 4,%s 16,%s 6,6\n' \
    "$fill" "$edge" "$y" "$((y + 30))" >>"$work/links.mvg"
  y=$((y + 22))
  link=$((link + 1))
done

convert -size 20x360 xc:none -draw @"$work/links.mvg" \
  -depth 8 -strip \
  assets/preload/images/clothRope.png

echo 'cloth easter egg art written'
