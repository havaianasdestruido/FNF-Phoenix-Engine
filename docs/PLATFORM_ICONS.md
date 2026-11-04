# Platform badge on the engine version watermark

A small platform icon sits on top of the engine-version watermark: a Windows
flag on a Windows build, the droid on Android, the apple on macOS/iOS, Tux on
Linux, a globe on web, Adobe's wedge on AIR, a bolt on Flash, and a plain
monitor when the engine cannot name the target. Every badge is white with a
dark outline, drawn on the same grid with the same outline weight, and it
resizes itself with the screen it ends up on.

It shows up in two places:

| Where | Anchor |
| --- | --- |
| Gameplay HUD (`play/PlayState.hx`) | On top of `EngineWatermark`, left-aligned with the text — or right-aligned for the `Forever Engine` style, which hugs the right edge. Hidden with the watermark, faded by the same HUD tweens, drawn on `camHUD`. |
| Main menu (`states/MainMenuState.hx`) | On top of the `Phoenix Engine vX.Y.Z` label in the version stack. |

**Options → Visuals → Platform Badge** turns it off (`ClientPrefs.platformWatermark`,
on by default). Setting **Watermark Style** to `Hide` hides the badge too, since
it follows the watermark's visibility.

## Why the icons are vectors

There is no single sensible pixel size for the badge: the same build runs in a
1280×720 window, fullscreen on a 4K monitor and on a 440-dpi phone. Instead of
shipping a PNG per platform per density, each glyph is vector data on a 100×100
grid in `backend/PlatformIcons.hx` and is rasterised on demand at the size the
current display needs. One grid, one outline weight and one optical box is also
what keeps the badges looking like a set.

## How "dynamic with the screen DPI" works

Two separate numbers, both from `backend/ScreenDensity.hx`:

* **Size** follows the *physical* density (`dpi()`): Android's density bucket
  through JNI, otherwise Lime's `System.getDisplay(0).dpi`, with
  `Capabilities.screenDPI` on Flash. The badge is
  `BASE_SIZE × clamp(sqrt(dpi / baseline), 1, 1.5)` game pixels, where the
  baseline is 96 dpi on desktop/web and 160 dpi (`mdpi`) on mobile. The square
  root keeps the growth gentle and the clamp keeps an 18-pixel badge from
  turning into a 48-pixel one next to 16-pixel text; it never shrinks below its
  authored size, so a standard monitor looks exactly as before.
* **Sharpness** follows `pixelsPerGamePixel()`: the scale mode factor
  (`FlxG.scaleMode.scale.x`) times the window's HiDPI backing scale
  (`FlxG.stage.window.scale`). The bitmap is rasterised at
  `logical size × that ratio`, capped at 4×, so a fullscreen 4K window draws
  the badge from a 4× bigger bitmap instead of smearing a 720p one.

Both are recomputed on every resize (`PlayStateLayout.resize`,
`MainMenuState.onResize`), which is also when the cached DPI is invalidated —
dragging the window to another monitor counts. Re-rasterising is skipped when
the result would be identical, and finished bitmaps are cached per
platform-and-size, with the same "is the graphic still alive" guard
`HealthIcon` uses, because `Paths.clearStoredMemory()` evicts bitmaps between
states.

## How a glyph is painted

`objects/PlatformIcon.hx` draws each glyph into a `Shape` and into a
`BitmapData` in three passes:

1. every `BODY` part is **filled and stroked** in the outline colour, so parts
   that overlap (an arm over a torso, Tux's head over his belly) weld into one
   silhouette with a single halo instead of showing inner seams;
2. every `BODY` part is **filled white** with no stroke, leaving half the
   stroke width showing as the outline;
3. `DETAIL` parts are filled dark (eyes, the counter inside the AIR wedge) and
   `MARK` parts are stroked dark (the globe's equator and meridian).

Each part gets its own `beginFill`/`endFill`: overlapping sub-paths inside a
single fill cancel out (even-odd) instead of merging.

## Editing or adding artwork

Glyphs live in `backend/PlatformIcons.hx` as `body(...)`, `detail(...)` and
`mark(...)` entries built from `Rect`, `RoundRect`, `Circle`, `Ellipse`,
`Polygon`, `Contour` (closed, quadratic curves) and `Stroke` (open). Keep every
coordinate inside the 0..100 grid: the renderer reserves exactly one outline
width of padding around it.

Preview a change without a full `lime test` — the tool reads the same Haxe file,
so there is no second copy of the artwork to keep in sync:

```sh
python3 tools/platform_icon_preview.py                      # needs Pillow
python3 tools/platform_icon_preview.py --sizes 16 24 48 128 --out /tmp/badges.png
```

## Regression checks

```sh
bash tests/haxe/run-platform-icons.sh      # needs the Haxe compiler
```

The Haxe spec runs the real detection/density/raster math under `--interp`, once
per target define (`windows`, `mac`, `linux`, `android`, `ios`, `html5`, `air`,
plus a run with no define at all), and walks the artwork to prove nothing leaves
the grid. Flash is the exception: `flash` is a *reserved* compiler flag that
cannot be set with `-D`, so the Flash and AIR branches are type-checked by
compiling the spec for the real SWF target (`--swf … --no-output`, with `-D air`
for the AIR case, which is exactly the build where both branches match). The
rule that AIR wins over Flash is asserted by the `-D air --interp` run, where
`detect()` must return `AIR` even though `flash` is also defined. It runs in the
**Checks** workflow.

The spec cannot prove pixel-perfect rendering: for release validation, look at the
watermark corner at 1280×720 and fullscreen on a HiDPI display, and on a phone
build, with each `Watermark Style` value.
