---
title: Screens and their captures
sidebar_position: 0
description: What the screen gallery is, how each page's image is produced, and how to replace a reconstruction with a real screenshot.
---

# Screens and their captures

This section has one page per screen the engine can display: boot, title, the menus,
gameplay, its overlays, and the support screens. Each page explains what the screen is
for, which code owns it, what its widgets actually are, and shows an image of the
layout.

## These images are reconstructions, not screenshots

:::warning[Read this before quoting an image]

The images in this section are **reconstructions**. They are composed from the engine's
own shipped art — `alphabet.png`, the `menu_*` atlases, the character and stage
sprites, `healthBar.png`, `timeBar.png`, `NOTE_assets.png`, `logoBumpin.xml`,
`titleEnter.xml` — at the coordinates the state source files actually use. Small labels
use the shipped `assets/fonts/vcr.ttf`.

They were generated in an environment with no GPU, no display server and no Haxe
toolchain, so the engine itself could not be built or launched to take real captures.
A reconstruction gets the layout, the art and the strings right; it does **not** prove
framerate, blending, shader output or animation frames.
:::

## How the coordinates were derived

Every page names the file its numbers come from. The repeated ones:

| Geometry | Source |
|---|---|
| Stage 1 piece offsets (`stageback`, `stagefront`, `stage_curtains`, lights) | `source/stages/StageWeek1.hx` |
| Character positions, `defaultZoom: 0.9` | `assets/preload/stages/stage.json` |
| Strum lines (`y = 50` up-scroll, `STRUM_X = 48`, `Note.swagWidth = 160 * 0.7`) | `source/play/helpers/PlayStateNoteHelpers.hx`, `source/play/PlayState.hx` |
| Health bar (`y = 0.89 * height`), time bar and score text | `source/play/PlayState.hx` |
| Freeplay song rows (`contentLeft + 90`, `y = 320`, one per 120px) | `source/states/FreeplayState.hx` |
| Main menu items (140px apart, centered on X) | `source/states/MainMenuState.hx` |
| Title layout (`titlex`, `titley`, `gfx`, `gfy`, `startx`, `starty`) | `assets/preload/images/gfDanceTitle.json`, `source/states/TitleState.hx` |
| Loading screen colours and bar | `docs/LOADING_SCREEN.md` |

Glyphs follow `objects.Alphabet`: `bold` text uses the `"<char> bold"` frames, plain
text uses `"<char> uppercase"` / `"<char> lowercase"` for letters and
`"<char> normal"` for everything else, which is the suffix rules in
`AlphaCharacter.setupImageGlyph`. Text drawn at a smaller size in the reconstructions
(credits rows, options categories) is the same atlas art scaled down, because
`Alphabet` has a single sprite size per style.

## Regenerating the set

The generator lives in `tools/wiki-screens/` (see its
[README](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/blob/main/tools/wiki-screens/README.md)).
It reads only tracked art from `assets/`, so the whole set is reproducible:

```bash
python3 -m venv .venv && .venv/bin/pip install pillow
.venv/bin/python tools/wiki-screens/render.py
```

`website/tests/screens.test.mjs` checks that every image a page references exists, is a
1280×720 PNG and stays under 900 KiB, so a broken or oversized replacement fails CI.

## Replacing a reconstruction with a real screenshot

Drop a PNG in `website/static/img/screens/` and change that page's `img/...` reference.
Nothing else in the page depends on the image, so a real capture only replaces the
file. The suggested capture settings, so every screen matches:

- 1280×720 windowed (the `project.hxp` default), 100 % scale, no mobile virtual pad.
- `F2` saves to `./screenshots/` through `backend.SSPlugin`; Photo Mode (`Pause → Photo
  Mode`) gives the HUD-off variant.
- Base game, no mods enabled, default `ClientPrefs` (up-scroll, classic notes, VCR font).
- One frame per screen, taken after the intro transition finished.

## Related pages

- [State flow](../architecture/state-flow.md) — how the screens connect.
- [PlayState](../subsystems/playstate.md) — the gameplay screen in depth.
- [Options menu](../subsystems/options-menu.md) — every category and setting.
