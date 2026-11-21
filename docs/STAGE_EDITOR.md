# Stage Editor

In-game authoring tool for Psych-compatible stage JSON. Open it from the
editors hub (`MasterEditorMenu` → **Stage Editor**).

A stage file is `stages/<id>.json` under `assets/preload/` or
`mods/<mod>/`. Gameplay already read camera/character placements from that
file; the editor adds a Psych 1.0 **object graph** so a custom stage can be
built without a Haxe class or a Lua script.

## What it edits

| Tab | Fields |
|---|---|
| **Stage** | save name, asset directory, camera zoom and follow speed, pixel flag, hide GF, shader warm-up list |
| **Chars** | preview character ids (`_editorMeta`), character positions, per-character camera offsets |
| **Object** | name, image, x/y, scale, scroll (parallax), alpha, angle, color, flip, antialiasing, quality filters, dance-every-N-beats |
| **Anims** | prefix/indices animations for `animatedSprite` props, plus which one is the main/idle |

The left **Sprite List** is front-first (last JSON object draws on top).
**Up** / **Down** change z-order, including the Girlfriend / Opponent /
Boyfriend slots, so a prop can sit in front of GF and behind BF.

**New** adds:

- **No Animation** — still `images/<name>.png`
- **Animated** — Sparrow/Packer atlas
- **Solid Color** — a scaled white rectangle (`type: "square"`)

**Week 1 Template** starts from the vanilla week-1 layout as JSON props
(`stageback`, `stagefront`, lights, curtains) so a custom stage does not have
to copy `stages.StageWeek1`.

## Controls

| Input | Action |
|---|---|
| E / Q | zoom in / out (Shift = faster) |
| I J K L or right-drag | pan |
| R | reset zoom to the stage default |
| Click a sprite | select (front-most wins) |
| Left-drag / arrow keys | move the selection (Shift = 10px, Control = 1px snap) |
| Mouse wheel | zoom (when the cursor is not over a panel) |
| Ctrl+S | export JSON (system save dialog) |
| Ctrl+Shift+S | write `mods/<mod>/stages/<name>.json` |
| Ctrl+Z / Ctrl+Y | undo / redo |
| G | snap to a 10px grid |
| F1 | help overlay |
| F12 | toggle the selection rectangle |
| Esc | back to the editors hub (warns if unsaved) |
| Mouse wheel on the sprite list | scroll when there are more than 14 rows |

Bottom-left buttons focus the camera on the opponent, BF or GF (the same
targets PlayState uses). **Save to Mod** writes into the active mod folder
(or `mods/stages/` when none is loaded); **Copy JSON** puts the same text
on the clipboard. The Low / High Quality and Story / Freeplay checkboxes
preview the Psych `filters` mask so a "high quality only" curtain or a
story-mode-only overlay can be hidden.

## JSON shape

Vanilla files stay compact (no `objects` array). Saving from the editor
writes the Psych 1.0 shape:

```json
{
  "directory": "",
  "defaultZoom": 0.9,
  "isPixelStage": false,
  "stageUI": "normal",
  "boyfriend": [770, 100],
  "girlfriend": [400, 130],
  "opponent": [100, 100],
  "hide_girlfriend": false,
  "camera_boyfriend": [0, 0],
  "camera_opponent": [0, 0],
  "camera_girlfriend": [0, 0],
  "camera_speed": 1,
  "shaders": ["rain"],
  "objects": [
    {
      "type": "sprite",
      "name": "stageback",
      "image": "stageback",
      "x": -600,
      "y": -200,
      "scale": [1, 1],
      "scroll": [0.9, 0.9],
      "alpha": 1,
      "angle": 0,
      "color": "FFFFFF",
      "flipX": false,
      "flipY": false,
      "antialiasing": true,
      "filters": 3
    },
    { "type": "gf" },
    { "type": "dad" },
    { "type": "boyfriend" }
  ],
  "preload": { "images/stageback": 3 },
  "_editorMeta": { "gf": "gf", "dad": "dad", "boyfriend": "bf" }
}
```

`filters` is a bit mask: `1` low quality, `2` high quality, `3` both,
plus `4` story-only and `8` freeplay-only.

Character slot objects (`"type": "gf"` / `"dad"` / `"boyfriend"`) do not
draw extra sprites; they mark where PlayState inserts `gfGroup` /
`dadGroup` / `boyfriendGroup`.

`danceEvery` replays `firstAnimation` on those beats (1 = every beat, 2 =
every other beat, 0 = leave looping anims alone). Psych itself required a
Lua `onBeatHit` for this; Phoenix does it in `play.helpers.PlayStateStageObjects`.

## Runtime

`PlayState` still constructs the hardcoded week classes (`StageWeek1`,
`Philly`, …). After that it calls `PlayStateStageObjects.spawn`:

- empty / missing `objects` → the historical add-gf-then-dad-then-bf order
- a JSON graph → props and character groups interleaved in array order

Named props are registered on `PlayState.variables` and, when Lua/Python
are compiled in, `PlayState.modchartSprites`, so a script can
`getProperty('stageback.x')` or `objectPlayAnimation('crowd', 'idle')`
without `makeLuaSprite`.

Vanilla stage JSON is unchanged, so Week 1 does not draw twice.

## Tests

```
bash tests/haxe/run-stage-editor.sh
```

The spec covers JSON round-trip, Psych file compatibility, z-order edits,
filters (including story/freeplay packing), undo, the Week 1 template, sprite-list
scrolling and `mods/<mod>/stages/` path sanitizing, without Flixel. The runner
also checks that `MasterEditorMenu` lists the editor, that `PlayState` calls
`PlayStateStageObjects.spawn`, and that Save to Mod is wired.
