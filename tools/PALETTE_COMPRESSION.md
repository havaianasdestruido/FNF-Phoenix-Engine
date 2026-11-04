# Palette reduction / extra image compression

Tool: `tools/reduce_image_palettes.py` (maintenance only — **not** needed to
build or play the game). Report: `tools/reports/palette-reduction-report.json`.
Tests: `tests/test_reduce_image_palettes.py`.

## What it does

It scans **every raster image tracked by Git**, requantizes PNGs to the
smallest colour palette that still passes a measured quality gate, and writes
an indexed PNG at the lowest possible bit depth:

| palette entries | PNG bit depth |
|---|---|
| 1–2   | 1 bpp |
| 3–4   | 2 bpp |
| 5–16  | 4 bpp |
| 17–256 | 8 bpp |

Alpha is kept as a `tRNS` palette chunk (multiple alpha levels, not a 1-bit
mask), so semi-transparent smoke, glows and anti-aliased sprite edges survive.
Many source PNGs already had tiny palettes but were stored as 8 bpp; dropping
them to 4/2/1 bpp halves (or better) the raw scanline data.

Pipeline per file:

1. Decode to RGBA and count unique colours.
2. Try palettes of 256, 128, 64, 32, 16, 8, 4 and 2 colours with
   `libimagequant` (dithering off for flat art, on for photographic/gradient
   art with more than 256 colours).
3. Compact the palette (drop unused entries), keep full alpha, and measure the
   error on visible pixels: premultiplied-RGBA PSNR, mean/max alpha error,
   fraction of opaque pixels with a large colour shift, fraction of visible
   pixels with any shift above 8 (the anti-banding guard for smooth gradients),
   lost visible pixels and transparent-pixel halos.
4. Encode as an indexed PNG and losslessly re-optimize the deflate stream with
   `oxipng` (`-D`, libdeflater). Without oxipng the Pillow PNG is kept.
5. **Replace the file only if the result is strictly smaller**, and only after
   a byte-exact decode check of the quantized pixels.

Pixel dimensions, filenames, XML/JSON atlas coordinates and code references
are never changed — frames stay exactly where the engine expects them.

## Quality gates

All thresholds are enforced over the whole image, restricted to visible
pixels. `lost` (visible pixels turned transparent) must always be zero, which
is what protects sprite outlines from being eaten by an over-small palette.

| profile | min PSNR | max alpha MAE | max alpha delta | max opaque pixels changed >24 | max visible pixels changed >8 | max halo ratio |
|---|---|---|---|---|---|---|
| `safe`       | 36 dB | 1.0 | 96  | 1%  | 10% | 0.01% |
| `balanced`   | 31 dB | 2.0 | 160 | 5%  | 15% | 0.05% |
| `aggressive` | 30 dB | 3.0 | 192 | 10% | 20% | 0.05% |

`changed_gt8` is the anti-banding guard: the fraction of visible pixels whose
premultiplied colour or alpha moved by more than 8 levels. Smooth gradients
fail it even when PSNR looks fine and the `>24` count stays near zero, so it
prevents an over-small palette from posterizing skies, blurs and hair shading.

This pass used `--profile aggressive`. Visual spot checks (character sheets,
cutscene sheets, smoke, backgrounds, achievement icons) were done before
applying it; candidates that banded gradients or erased outlines were
rejected by the `changed_gt8`, alpha, `lost` and `opaque_bad` gates.

## Formats

| content | action |
|---|---|
| PNG | palette reduction as above; animated PNGs (none in this tree) are skipped |
| JPEG (including a JPEG stored with a `.png` name) | re-encode at quality 78, progressive, 4:2:0, only if smaller |
| GIF (`.github/res/deeplink.gif`) | skipped: lossless frame optimization made it larger |
| WebP payload under `assets/embed/images/moron.png` | skipped: already compact, no palette |
| ICO / SVG | skipped: icon container / vector, no raster palette |

## Results

Measured with `--profile aggressive` (including the `changed_gt8`
anti-banding guard) and recorded per file in
`tools/reports/palette-reduction-report.json`:

| metric | before | after |
|---|---|---|
| raster assets scanned | 689 | 689 |
| files replaced | — | 435 (434 PNG + 1 JPEG) |
| total raster bytes | 42,260,094 (40.30 MiB) | 36,173,498 (34.50 MiB) |
| saving | — | **6,086,596 bytes (5.80 MiB, 14.40%)** |
| average palette entries (changed PNGs) | 45.0 | 16.5 |
| changed PNGs stored at 8 bpp | 363 | 72 |
| changed PNGs stored at 4 bpp | 58 | 314 |
| changed PNGs stored at 2 bpp | 12 | 41 |
| changed PNGs stored at 1 bpp | 1 | 7 |

Typical gains: `gfChristmas.png` 3.65 → 2.36 MB (32 colours, −35.5%),
`christmas/bgWalls.png` 137 → 37 KB (16 colours, −73.8%), `christmas/evilBG.png`
249 → 63 KB (16 colours, −74.5%), `phillyStreets/phillySkybox.png` 171 → 134 KB
(8 colours, −21.3%, kept at 8 instead of 4 colours to avoid banding),
achievement icon `lol.png` 43 → 12 KB (256 colours instead of RGBA, −71.8%),
`caseys.jpg` 755 → 683 KB (quality 78, −9.5%).

254 files were left untouched: 249 PNGs were already so tightly compressed
that every passing candidate was larger, plus the animated GIF, the WebP
payload, the ICO/SVG assets and a 5 KB JPEG that grew when re-encoded.
No file got larger, no dimension changed and no XML/JSON atlas was edited.

## Important caveat: RAM

Indexed PNGs shrink the **download** and the on-disk asset pack, which is the
goal of this change. OpenFL/Lime decodes PNGs into RGBA `BitmapData` at load
time, so the decoded texture still costs `width × height × 4` bytes: palette
reduction alone does **not** reduce runtime RAM/VRAM. Runtime memory is
dominated by the (often very large) sprite-sheet dimensions. Reducing *that*
requires geometric downscaling plus atlas-coordinate changes — see
`tools/IMAGE_DOWNSCALE.md`, which documents the separate 2× downscale work and
why it cannot be applied blindly to atlases with odd frame coordinates.

## Reproducing / verifying

```sh
pip install -r tools/requirements-image-palette.txt
# optional but recommended; also accepts --oxipng /path/to/oxipng or $OXIPNG
# install oxipng via your package manager / cargo / the npm package above

python3 tools/reduce_image_palettes.py --dry-run          # measure, change nothing
python3 tools/reduce_image_palettes.py --profile aggressive
python3 tools/reduce_image_palettes.py --check            # validate report vs files
python3 -m unittest tests/test_reduce_image_palettes.py -v
```

`--dry-run` reports the projected saving without touching files or the report.
`--check` re-hashes every recorded asset, re-decodes every changed PNG and
asserts it is still an indexed PNG with unchanged dimensions.

`tools/compress-images.sh` remains the general-purpose, dependency-light
(pngquant + oxipng/optipng) one-shot compressor; this tool is the deeper,
quality-gated pass for repositories whose art is already indexed but still
wastes bits per pixel.
