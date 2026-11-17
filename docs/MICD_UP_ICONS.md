# Mic'd Up icons

The health-icon sets and the redrawn difficulty labels are from
[Friday Night Funkin': Mic'd Up](https://github.com/Verwex/Funkin-Mic-d-Up-SC),
stable revision `5895d3de9766da281f5bf9e1f1b60b316d2c350b`.
The upstream license says: “if u make mods, open source them, lol!”

## Health-icon styles

Mic'd Up! ships whole icon sets in per-style folders and switches between
them from its settings (`iconStyle`). Phoenix does the same: the flat
`assets/preload/images/icons/` folder is the `Default` set, and every extra
style is a subfolder named after its display name, slugified the same way the
rating styles are (`"Mic'd Up"` → `mic'd-up`).

| Style | Folder | Source |
|---|---|---|
| Default | `assets/preload/images/icons/` | Phoenix's existing flat icons |
| Mic'd Up | `assets/preload/images/icons/mic'd-up/` | Mic'd Up's `assets/shared/images/icons/mic'd up/` |
| Vanilla | `assets/preload/images/icons/vanilla/` | Mic'd Up's `assets/shared/images/icons/vanilla/` |

Each bundled style covers the same 24 characters (`bf`, `dad`, `gf`, `mom`,
`pico`, `senpai`, `spirit`, `spooky`, `tankman`, …) as three 150×150 frames
(normal, losing, winning), matching the layout `HealthIcon` already expects.
The style list lives in `assets/preload/images/icons/list.txt` (one display
name per line), merged with mods exactly like the rating styles.

The feature is **off by default**. One option in **Options → Visuals and UI**
controls it:

| Option | `ClientPrefs` field | Default |
|---|---|---|
| Health Icon Style | `iconStyle` | `Default` |

`HealthIcon` walks the candidates from `backend.IconStyle` in order: the
active style's `icon-<char>` first, then the flat icons, then `face`.
Characters a style does not cover — `darnell`, `senpai-pixel`,
`spirit-pixel`, … — silently fall back to the flat set, exactly like a
missing rating-style file does. The `BF Icon Style` option is a separate,
BF-only override and still composes on top.

To add a style (or override one from a mod), drop a folder of
`icon-<char>.png` files under `images/icons/` and add its display name to
`images/icons/list.txt`. The slugify rule is
`toLowerCase().replace(' ', '-')`, so `"My Style"` reads from `my-style/`.

## Difficulty labels

The six `assets/preload/images/menudifficulties/` labels (`easy`, `normal`,
`hard`, `expert`, `insane`, `noob`) are crops of Mic'd Up's redrawn
`assets/preload/images/difficulties.png` atlas, cut on the `SubTexture`
rectangles from its `difficulties.xml`:

| File | Atlas rect (x, y, w, h) |
|---|---|
| `easy.png` | 2, 2, 190, 63 |
| `expert.png` | 195, 2, 197, 60 |
| `hard.png` | 2, 68, 175, 59 |
| `insane.png` | 180, 68, 206, 59 |
| `noob.png` | 2, 130, 187, 53 |
| `normal.png` | 192, 130, 191, 59 |

`jshard.png` is Phoenix-only (JS Engine) and has no Mic'd Up counterpart, so
it is unchanged. Story Mode shows these labels next to the difficulty
arrows; Freeplay still shows the difficulty as text.

## Files

| Path | Role |
|---|---|
| `source/backend/IconStyle.hx` | renderer-free style slug + candidate order |
| `source/objects/HealthIcon.hx` | walks the candidates, first existing file wins |
| `source/backend/ClientPrefs.hx` | `iconStyle` preference |
| `source/options/VisualsUISubState.hx` | Health Icon Style option (from `list.txt`) |
| `tests/haxe/IconStyleSpec.hx` | interpreter spec for the resolution rules |
| `tests/haxe/run-icon-style.sh` | runs the spec (runs in CI) |
