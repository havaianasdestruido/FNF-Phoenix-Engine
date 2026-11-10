# Early & Late ratings (Mic'd Up! port)

Phoenix tells you *which way* a hit missed: `Early` when the key came before the
note's time, `Late` when it came after. It is the Mic'd Up! judgement label,
ported without its scoring or combo changes — accuracy, score and FC strings are
exactly what they were before.

The feature is **off by default**. Two options in **Options -> Optimization**
control it:

| Option | `ClientPrefs` field | Default |
|---|---|---|
| Early/Late Ratings | `earlyLateRatings` | `false` |
| Early/Late Dead Zone | `earlyLateDeadzone` | `0.1` |

## What it looks like

* `Early` / `Late` art pops just under the rating sprite and drifts up with it,
  fading on the same timeline. Combo numbers, stacked popups and
  **Combo Stacking** behave exactly like they do for the rating itself.
* With **Simple Popups** on (the text-only HUD) the word is appended to the
  rating line instead, e.g. `Sick!! (Early)`.
* Missing a note never shows a label, and neither does botplay.

The art is optional per ratings style. Every bundled folder ships
`early` / `late` next to `sick` / `good` (`assets/shared/images/ratings/<style>/`,
plus the `-pixel` variants under `assets/shared/images/pixelUI/ratings/<style>/`),
each drawn in that style's own lettering and colours.
A mod that overrides a ratings style without those files simply gets the rating
alone: the lookup happens once per song in `PlayStateRating.cachePopUpScore()`
and a missing file costs nothing at judgement time.

To regenerate the bundled art (or add a style), edit the table in
`tools/generate-timing-labels.sh` and run it — ImageMagick and the fonts in
`assets/fonts` are all it needs:

```bash
bash tools/generate-timing-labels.sh          # all eight styles
bash tools/generate-timing-labels.sh default  # one style
```

## How the hit is classified

The judged difference is

```
noteDiff = strumTime - songPosition + ratingOffset   (ms, divided by playbackRate)
```

`noteDiff > 0` means the note's time is still ahead, so the player was **early**;
`noteDiff < 0` means it was already behind, so they were **late**.

The sign is taken *before* the engine's usual `Math.abs()`, and hits inside the
dead zone show nothing at all:

```
dead zone = ±(deadzone × Conductor.safeZoneOffset)
```

With the defaults (180 ms safe zone, `0.1`) that is ±18 ms: outside it you get
`Early`/`Late`, inside it the rating is plain. Raise the dead zone to be more
forgiving about what counts as "on time", lower it to label almost everything.
`play/helpers/HitTiming.hx` holds these rules and has no Flixel dependency, so
`bash tests/haxe/run-hit-timing.sh` asserts them directly.

`noteDiff` on `PlayState` keeps its old absolute meaning, so nothing that already
read it changes; the signed value lives in `PlayState.noteTimingDiff`.

## Scripting

The last judged hit publishes two globals before every `goodNoteHit` /
`opponentNoteHit` callback, and each note remembers its own value:

| Global | Values |
|---|---|
| `hitTiming` | `"early"`, `"late"` or `""` (on time, or no judgement yet) |
| `noteDiff` | signed milliseconds, `+` early / `-` late |

They are mirrored across Lua, Python (Hython) and HScript, like every other
published variable — see [`website/docs/modding/lua-scripting.md`](../website/docs/modding/lua-scripting.md).

```lua
function goodNoteHit(id, noteData, noteType, isSustainNote)
    if isSustainNote then return end
    if getPropertyFromGroup('notes', id, 'hitTiming') == 'late' then
        -- your own late-hit feedback
    end
end
```

## Files

| Path | Role |
|---|---|
| `source/play/helpers/HitTiming.hx` | renderer-free classification, dead zone, labels |
| `source/objects/TimingPopup.hx` | pooled `Early`/`Late` sprite |
| `source/play/helpers/PlayStateRating.hx` | classifies the hit, resolves art, draws the label, feeds Simple Popups |
| `source/play/objects/JudgeText.hx` | `(Early)` / `(Late)` suffix for Simple Popups |
| `tests/haxe/run-hit-timing.sh` | interpreter spec for the rules (runs in CI) |
| `tests/haxe/run-early-late-typecheck.sh` | compiles the popups + rating helper against real Flixel/OpenFL/Lime (needs the haxelibs; skips otherwise) |
| `tools/generate-timing-labels.sh` | regenerates the 32 label PNGs for every ratings style |
