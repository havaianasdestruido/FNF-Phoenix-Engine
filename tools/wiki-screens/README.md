# wiki-screens — screen reconstructions for the docs and wiki

Renders one PNG per Phoenix Engine screen into `website/static/img/screens/`, which the
[Screens section](../../website/docs/screenshots/intro.md) renders and the wiki mirror
copies into the GitHub wiki.

```bash
python3 -m venv .venv && .venv/bin/pip install pillow
.venv/bin/python tools/wiki-screens/render.py            # into website/static/img/screens
.venv/bin/python tools/wiki-screens/render.py /tmp/out    # anywhere else
```

## What these images are — and are not

They are **reconstructions**, not screenshots. `render.py` composes the engine's own
shipped art at the coordinates the state source files use:

- `assets/preload/images/alphabet.png`, read through the same glyph suffix rules as
  `objects.Alphabet` (`atlas.py`).
- The `menu_*`, `logoBumpin`, `titleEnter`, `gfDanceTitle`, `campaign_menu_UI_assets`
  and `Freeplay_Discs` atlases; the character, stage, health-bar, time-bar and note-skin
  sprites.
- `assets/fonts/vcr.ttf` for the small print the game itself sets in VCR.
- Geometry from `source/states/*.hx`, `source/play/PlayState.hx`,
  `source/play/helpers/PlayStateNoteHelpers.hx`, `source/stages/StageWeek1.hx` and
  `assets/preload/stages/stage.json`.

A reconstruction gets the layout, art and strings right. It does **not** prove
framerate, blend modes, shader output or animation frames, and it cannot show anything
the sandbox has no art for. When a real capture exists, drop it in place of the PNG —
the doc pages only reference the file name.

Do not use this script to *fake* a feature screenshot. If a change is visible and you
can run the game, capture the real thing (`F2`, or Photo Mode with the HUD off); the
repo's AGENTS.md rule 13 requires a real screenshot in the PR description.
