---
title: Menu easter eggs
sidebar_position: 12
description: The hidden scenes on the main menu, including the FlxClothSprite cloth demo and its key code.
---

# Menu easter eggs

Easter eggs in Phoenix are gated by the `FUNNY_ALLOWED` feature flag
(`project.hxp`), which is on for desktop C++ builds and off for Flash, AIR and
the web. They never change gameplay, never write to the save file unless they
have to, and never block a normal play session:

| Easter egg | Trigger | Where |
|---|---|---|
| `FlxClothSprite` cloth scene | type `C L O T H` on the main menu | `states.substates.ClothEasterEggSubstate` |
| Cat picture at 3 AM | open the main menu at 03:00 | `states.MainMenuState` (`funnycatperson`) |

## The cloth scene

Typing the five letters of *cloth* within
`backend.ClothEasterEggLogic.SEQUENCE_TIMEOUT` seconds opens a substate that
hangs four [`FlxClothSprite`](https://api.haxeflixel.com/flixel/addons/effects/FlxClothSprite.html)
meshes over the menu, the same component used by the
[official HaxeFlixel demo](https://haxeflixel.com/demos/FlxClothSprite/).
Moving the pointer drags the left banner; holding the pointer button blows wind
through every piece; `ESC` (or the gamepad/virtual pad back button) returns to
the menu, which was never unloaded and therefore keeps its music, tips and
selected item.

The four pieces are **cut out of the menu's own backdrop**
(`images/menuBG.png`), so the cloth is made of the art the menu is drawn with:
a mod that replaces that image changes both at once. Each piece gets its own
window of the texture — the banners take different thirds of it, the ropes the
left and right columns — cut at the piece's on-screen size and never outside the
texture. A build without a backdrop, or `backend.ClothEasterEggLogic.TEXTURE`
set to `BACKDROP_CLOTH_ART`, falls back to the bundled `clothFlag`/`clothRope`
art.

Two details are worth knowing when touching this code:

- **The menu is the parent state.** The scene is a substate, not a state switch,
  so nothing has to be rebuilt afterwards. `MainMenuState.update()` skips its own
  navigation while `clothSceneOpen` is true, so the scene's pointer and close key
  cannot also scroll the list behind it.
- **Layout lives outside Flixel.** Positions, gravity, wind, the texture choice,
  the crop rectangles and the hidden key code are in
  `backend.ClothEasterEggLogic`, which imports no Flixel/OpenFL/Lime code and is
  checked by `tests/haxe/ClothEasterEggSpec.hx`. The spec verifies the code
  (timeout, restart letter, lower-case input), the wind clamping, the
  reduced-motion gravity, that all four pieces fit inside the centered
  1280-pixel content column at 4:3, 16:9, ultrawide and portrait viewports, and
  that every crop is a valid rectangle inside its texture.

`ClientPrefs.reducedMotion` lowers the mesh gravity instead of disabling the
effect, and `ClientPrefs.globalAntialiasing` is passed through to the pieces.

Full details, the file list and the provenance of the textures are in the
[cloth easter egg design note](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/blob/main/docs/CLOTH_EASTER_EGG.md).

## Adding another one

1. Gate the trigger with `#if FUNNY_ALLOWED` and put the rules in a
   renderer-free `backend.*Logic` module, mirroring `ClothEasterEggLogic`.
2. Trigger it from an existing state instead of adding a new entry to the menu:
   the menu list is mod-visible, and an easter egg that shows up there is not an
   easter egg.
3. Add a spec under `tests/haxe/` plus a `run-*.sh` wrapper and a step in
   `.github/workflows/checks.yml`; the renderer-free modules run under
   `haxe --interp` in CI without the game's haxelibs.
