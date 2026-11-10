#!/usr/bin/env bash
# Generate the Early/Late label art for every bundled ratings style.
#
# The labels have to look like they belong to the style they sit under, so each
# one borrows that style's lettering: a font and a fill/outline pair picked to
# match its rating art, sized to about a third of the rating's width so it reads
# as a little sibling rather than a second, competing judgement.
#
#     bash tools/generate-timing-labels.sh          # rewrite all 8 styles
#     bash tools/generate-timing-labels.sh default  # just one
#
# Output (32 files, listed in tests/assets/builtin-assets.txt):
#   assets/shared/images/ratings/<style>/{early,late}.png
#   assets/shared/images/pixelUI/ratings/<style>/{early,late}-pixel.png
#
# ImageMagick only, fonts from assets/fonts. Two ImageMagick traps this script
# exists to avoid: `-alpha shape` blurs and leaves grey halos (use `-alpha extract`
# + `-threshold` + `-morphology` instead), and stacking `-fill`/`-stroke` labels in
# one `convert` call floods the fill over the outline (draw the two layers
# separately and composite them).
set -euo pipefail
cd "$(dirname "$0")/.."

convert -version >/dev/null 2>&1 || {
  echo "SKIP: ImageMagick (convert) not found"
  exit 0
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# style | font | pointsize | fill | outline | stroke width | pixel fill | pixel outline
styles=(
  "default|riffic.ttf|46|#FFFFFF|#161616|9|#FFF5FC|#34343C"
  "doki-doki+|riffic.ttf|44|#F7F3F8|#E34846|8|#F7F3F8|#8C3A52"
  "fire-in-the-hole|tf2build.ttf|34|#FFFFFF|#1B1B1B|7|#FFFFFF|#1B1B1B"
  "kade|riffic.ttf|46|#FFFFFF|#3367C2|8|#FFFFFF|#2A4E8C"
  "nmcw|comic.ttf|40|#FFF4D6|#3A1B0E|7|#FFF4D6|#3A1B0E"
  "tgt-v4|riffic.ttf|54|#FFFFFF|#000000|10|#FFFFFF|#101010"
  "vs-impostor|tf2build.ttf|48|#FFFFFF|#3A3A3A|8|#FFFFFF|#3A3A3A"
  "yeahs|vcr.ttf|44|#4A4A4A|#F2F2F1|8|#4A4A4A|#F2F2F1"
)

# $1 text, $2 font, $3 pointsize, $4 stroke width, $5 fill, $6 outline, $7 out
# Draws the outline layer and the fill layer separately (same font and size, so
# the glyphs line up exactly) and composites the fill over the outline.
draw_label() {
  local text="$1" font="$2" size="$3" stroke="$4" fill="$5" outline="$6" out="$7"
  convert -background none -fill "$outline" -stroke "$outline" -strokewidth "$stroke" \
    -font "assets/fonts/$font" -pointsize "$size" label:"$text" "$work/outline.png"
  convert -background none -fill "$fill" -stroke none \
    -font "assets/fonts/$font" -pointsize "$size" label:"$text" "$work/fill.png"
  convert "$work/outline.png" "$work/fill.png" -gravity center -compose over -composite \
    -trim +repage -rotate -4 -trim +repage PNG32:"$out"
}

# Same, on the low-res grid: render aliased and small (so every edge lands on a
# pixel boundary), take the glyph as the fill layer and a one-pixel dilation of
# it as the outline layer, then composite. Aliased rendering is what makes it
# read like the chunky `*-pixel` sheets instead of a blurred thumbnails of the
# hi-res label.
draw_pixel_label() {
  local text="$1" fill="$2" outline="$3" out="$4"
  convert -background none -fill white -font assets/fonts/riffic.ttf -pointsize 15 \
    +antialias label:"$text" -trim +repage "$work/pixel-src.png"
  convert "$work/pixel-src.png" -alpha extract -threshold 50% "$work/pixel-core.png"
  convert "$work/pixel-core.png" -morphology Dilate Square:1 "$work/pixel-mask.png"
  convert "$work/pixel-mask.png" -fill "$outline" -opaque white -transparent black \
    -alpha on PNG32:"$work/pixel-outline.png"
  convert "$work/pixel-core.png" -fill "$fill" -opaque white -transparent black \
    -alpha on PNG32:"$work/pixel-fill.png"
  convert "$work/pixel-outline.png" "$work/pixel-fill.png" -compose over -composite \
    -trim +repage PNG32:"$out"
}

selected=("$@")
[ ${#selected[@]} -eq 0 ] && selected=(default "doki-doki+" fire-in-the-hole kade nmcw tgt-v4 vs-impostor yeahs)

for row in "${styles[@]}"; do
  IFS='|' read -r style font size fill outline stroke pfill poutline <<<"$row"

  found=0
  for want in "${selected[@]}"; do [ "$want" = "$style" ] && found=1; done
  [ "$found" = 1 ] || continue

  hi="assets/shared/images/ratings/$style"
  px="assets/shared/images/pixelUI/ratings/$style"
  mkdir -p "$hi" "$px"

  for word in Early Late; do
    lower=$(echo "$word" | tr '[:upper:]' '[:lower:]')
    draw_label "$word" "$font" "$size" "$stroke" "$fill" "$outline" "$hi/$lower.png"
    draw_pixel_label "$word" "$pfill" "$poutline" "$px/$lower-pixel.png"
  done
  echo "wrote $hi/{early,late}.png and $px/{early,late}-pixel.png"
done
