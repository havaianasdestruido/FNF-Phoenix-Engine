# Cloth easter egg (`FlxClothSprite`)

A hidden scene on the main menu where four pieces of cloth hang over the menu and
react to the pointer, using HaxeFlixel's
[`flixel.addons.effects.FlxClothSprite`](https://api.haxeflixel.com/flixel/addons/effects/FlxClothSprite.html)
— the same class as the [official demo](https://haxeflixel.com/demos/FlxClothSprite/).

## How to open it

On the **main menu**, type `C`, `L`, `O`, `T`, `H` (the letters of *cloth*) within
`ClothEasterEggLogic.SEQUENCE_TIMEOUT` seconds of each other. A confirm sound
plays and the scene appears over the menu.

| Input | What it does |
|---|---|
| Move the pointer | Drags the left-hand banner around |
| Hold the pointer button | Blows wind through all four pieces |
| `ESC` / gamepad back / virtual pad | Returns to the menu |

Nothing else on the menu reacts while it is open: `MainMenuState.update()` skips
its own navigation (and the 3 AM cat gag) behind an `inputBlocked` flag, so a
click that blows wind cannot also launch a menu item.

The menu is **not** restarted: it is the parent state, so music, the tip line and
the selected item stay exactly as they were.

The code only listens for those five letters, so it never eats menu navigation.
It is also armed only in builds with the `FUNNY_ALLOWED` feature flag (desktop,
the same flag that gates the other menu easter eggs) and only while the main menu
owns the screen: while a substate is open (a mod's prompt, the cloth scene
itself, a locked-in menu choice) the tracker is skipped.

## What is on screen

The four pieces mirror the demo's three configurations:

1. **Follow banner** — `clothFlag`, pinned on its **left** edge, a 10 × 10 mesh,
   moved to the pointer every frame. Its movement is handed to the sprite as
   `velocity`, which the cloth mesh reads as wind.
2. **Wide banner** — `clothFlag`, pinned at **both top corners** by explicit
   indices (`setMesh(15, 10, 0, 0, [0, 14])` with `pinnedSide = NONE`), a 1.5×
   horizontal `meshScale` and `iterations = 8` so the constraint solve keeps it
   stiff.
3. **Two ropes** — `clothRope`, pinned on the top edge with
   `crossingConstraints = true` and a 2 × 10 mesh, so it bends like a rope
   instead of sheeting.

All four are drawn on a camera added on top of the menu's stack, over a 55%
black backdrop, and the menu keeps drawing on its own cameras underneath. The
pointer is sampled with `FlxG.mouse.getScreenPosition(clothCam)` rather than
`FlxG.mouse.x`: the menu camera pans and zooms on every beat, and `mouse.x` is
relative to that camera.

Gravity is `meshVelocity.y`, applied every frame; `ClientPrefs.reducedMotion`
swaps the full `40` for a gentler `10` px/s instead of turning the effect off.
Wind is `random × the piece's maxVelocity.x` while the button is held and `0`
otherwise, exactly like the demo.

Sizes, positions and speeds live in `backend.ClothEasterEggLogic` and are
covered by `tests/haxe/ClothEasterEggSpec.hx`; `tests/haxe/ClothAssetsSpec.hx`
reads the PNG headers and fails if a texture is re-exported at another size or
dropped from the allowlist.

## Files

| File | Purpose |
|---|---|
| `source/backend/ClothEasterEggLogic.hx` | Hidden key code, scene layout, gravity/wind numbers. No Flixel imports, so it runs under `haxe --interp`. |
| `source/states/substates/ClothEasterEggSubstate.hx` | The Flixel scene: builds the meshes, follows the pointer, closes on `BACK`. |
| `source/states/MainMenuState.hx` | `trackClothCode()` / `openClothScene()`, plus the `inputBlocked` guard that keeps the menu from reacting behind the scene. |
| `assets/preload/images/clothFlag.png` | 300 × 200 banner: stripe gradient, Phoenix emblem, caption. |
| `assets/preload/images/clothRope.png` | 20 × 360 chain of rounded links. |
| `tools/generate-cloth-easter-egg-art.sh` | Regenerates both textures with ImageMagick from `phoenix_logo.png` + `vcr.ttf`. |

The two textures sit at the root of `assets/preload/images/` on purpose: that
folder is already registered by `project.hxp` for every build mode, including the
compact `-DNO_BUILTIN_CONTENT` CI build, while the character/dialogue subfolders
are filtered there. They are listed in `tests/assets/builtin-assets.txt`, which
`tests/haxe/run-content-policy.sh` checks.

## Credits and provenance

- `FlxClothSprite` is part of [flixel-addons](https://github.com/HaxeFlixel/flixel-addons),
  already a dependency of this engine (`hmm.json`, `project.hxp`); author
  **adrianulima**. The demo scene is by
  [HaxeFlixel](https://github.com/HaxeFlixel/flixel-demos).
- The behaviour in `ClothEasterEggSubstate` follows the demo's three setups; the
  code is Phoenix's own (documented, resize-aware, reduced-motion aware).
- **No asset or source file is copied from the demo.** Both textures are
  generated from Phoenix's own art by the script above, so the textures are
  covered by this repository's license.

## Testing

```bash
bash tests/haxe/run-cloth-easter-egg.sh
bash tests/haxe/run-content-policy.sh     # the two textures are shipped
```

The first spec is renderer-free: it checks the key code (including the timeout,
the restart letter and lower-case input), the wind clamping, the reduced-motion
gravity and that every piece stays inside the centered 1280-pixel content column
at 4:3, 16:9, ultrawide and portrait viewports. The second one parses the two
PNGs, so the layout numbers cannot drift away from the art, and checks both are
on the compact-build allowlist.
