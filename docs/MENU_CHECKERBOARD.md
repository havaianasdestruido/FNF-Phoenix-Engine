# Moving menu checkerboard

Phoenix menus can draw a softly tinted checkerboard over their normal background.
The layer moves diagonally and wraps forever, matching the visual idea used by the
[Mic'd Up! Engine](https://github.com/Verwex/Funkin-Mic-d-Up-SC) menus.

## Player option

**Options → Visuals and UI → Moving Menu Checkerboard** controls the effect.
It is enabled by default and applies immediately, including to the options screen
currently open. Turning it off hides and pauses every live checkerboard, so there
is no per-frame update cost while disabled. `ClientPrefs.reducedMotion` keeps the
pattern visible but stops its movement.

The effect appears behind the main, freeplay, mods, credits, achievements and
options interfaces. The update and render-complete screens use the same
component and therefore honor the same preference.

The story menu is deliberately left out: its week title cards and character row
are drawn over the flat yellow band and the solid black bars, so a tinted tiled
layer there reads as a transparency checkerboard instead of a background.

## Tile variants (debug menu)

**Options → Secret Debug Menu → Menu Checker Texture** picks which tile every
checkerboard repeats. The engine ships five 120 × 120 tiles in
`assets/preload/images/` — `checker.png` (the default), `checker_fatty.png`,
`checker_folk.png`, `checker_logo.png` and `checker_lol.png` — so the row
offers exactly those, plus any other `checker*` image found in that folder.
The value is stored as `ClientPrefs.menuCheckerTexture` (the file name without
its extension) and applies immediately to every open menu.

Adding a variant is dropping a same-sized PNG into `assets/preload/images/`;
`backend.MenuCheckerTextures` reads the key from the file name and
`objects.MovingCheckerboard.availableTextures()` lists it. A variant that is
not installed on the running build (hand-edited save, content-stripped build,
disabled mod) silently falls back to the default tile instead of leaving the
menus blank, and `ClientPrefs.loadPrefs()` normalizes anything that is not
`checker`/`checker_*`. A mod can still replace the pixels of any of these keys:
`Paths.image()` resolves mod folders before the engine's own assets.

## Implementation

`objects.MovingCheckerboard` is a `FlxBackdrop` that:

- reuses the shared 120 × 120 `images/checker.png` tile, or the variant
  `ClientPrefs.menuCheckerTexture` selects;
- accepts a tint, opacity, tile scale and pixels-per-second velocity so each menu
  keeps its own color and direction;
- keeps Mic'd Up!'s subtle vertical camera parallax (`scrollFactor.y = 0.07`);
- uses Flixel velocity, making its speed independent of the configured frame rate;
- tracks live instances only to apply the options without reopening a menu; and
- unregisters itself on destruction.

This costs one tiny shared texture and one tiled draw layer per visible menu. No
separate color textures are shipped.

The key/value rules live in `backend.MenuCheckerTextures`, a renderer-free
module so both specs can run on the Haxe interpreter without the game's
haxelibs: `bash tests/haxe/run-menu-checker-textures.sh` (keys, listings,
fallbacks) and `bash tests/haxe/run-moving-checkerboard.sh` (the live instances,
including the tile swap).

## Credit and provenance

The moving-checkerboard menu treatment is credited in-game to **Verwex / Mic'd
Up! Engine**. Phoenix's class was newly written for this engine and uses Phoenix's
pre-existing neutral checker tile; no Mic'd Up! source image or source file is
included. The behavioral reference was the `stable` branch of
`Verwex/Funkin-Mic-d-Up-SC` (`MainMenuState.hx`, `SettingsState.hx`,
`MenuFreeplay.hx` and `MenuWeek.hx`).
