# Modcharts

Phoenix ships a FunkinModchart-style modchart runtime: a beat-timed event
timeline that drives modifiers which move, rotate, scale and fade the arrow
field. It runs natively in Haxe (`source/modchart/`, renderer-free) and is
exposed to Lua and Python scripts through the same functions, so a chart can be
modded without touching `PlayState`.

Nothing is enabled by default and no modifier exists until a script adds one, so
Psych/JS mods that never call this API keep the exact vanilla arrow behaviour.
The runtime only ever offsets sprites — it never hides or replaces them — so
existing camera, shader and sprite helpers continue to work.

```
source/modchart/            pure logic (no Flixel imports)
source/modchart/modifiers/  the 34 built-in modifiers
source/modchart/lab/        Modchart Lab editor core (catalog + Lua/Python export)
source/play/helpers/PlayStateModchart.hx   adapter that moves the live sprites
source/psychlua/callbacks/ModchartCallbacks.hx  Lua API
source/psychlua/pystdlib/PyModchartLib.hx       Python API
source/editors/ModchartLabState.hx   visual tuner (Editors menu -> Modchart Lab)
```

## Scripting API

All functions are global in Lua and Python scripts, with identical names and
argument order. `player` is `0` for the opponent, `1` for the player and `-1`
(the default) for both. `field` is a playfield index; `-1` (the default) means
every playfield.

| Function | Effect |
| --- | --- |
| `addModifier(name, field = -1)` | Installs a modifier. Returns `false` for an unknown name (a warning is printed) or when there is no active playfield. |
| `setPercent(name, value, player = -1, field = -1)` | Sets a modifier percent immediately. |
| `getPercent(name, player = 0, field = 0)` | Reads back the current percent as a number. |
| `modSet(name, beat, value, player = -1, field = -1)` | Sets a percent when the song reaches `beat`. |
| `modEase(name, beat, length, value, ease, player = -1, field = -1)` | Tween a percent from its value at `beat` to `value` over `length` beats. |
| `modAdd(name, beat, length, addition, ease, player = -1, field = -1)` | Same, but adds `addition` instead of setting an absolute value. |
| `modSetAdd(name, beat, valueToAdd, player = -1, field = -1)` | Instantly adds to the current value at `beat` (no tween). |
| `modCallback(beat, callbackName, field = -1)` | Calls the script function `callbackName()` at `beat`. |
| `modRepeater(beat, length, callbackName, field = -1)` | Calls `callbackName()` every `length` beats, starting at `beat`. |
| `addPlayfield()` | Adds a playfield. Every playfield transforms its assigned sprites. |
| `resetModchart()` | Removes all modifiers and timeline events, and restores the receptors. |
| `isModchartActive()` | `true` while at least one modifier or event is alive. |
| `getModchartModifiers()` | Array of installed modifier names. |
| `setModchartPerspective(enabled, fovDegrees = 90, zScale = 1)` | Turns on the 3D projection used by `z` offsets and rotations. |

Beats are decimal and follow the same clock as `curDecBeat` (so BPM changes and
`setProperty('curDecBeat', ...)` are respected). Eases accept the usual engine
ease names, case-insensitively: `linear`, `sineIn`/`sineOut`/`sineInOut`,
`quad*`, `cube*`, `quart*`, `quint*`, `expo*`, `circ*`, `elastic*`, `back*`,
`bounce*`, `smoothStep*` and `smootherStep*` (for example `'quadOut'`,
`'elasticInOut'`). An unknown name falls back to `linear`.

## Modifiers and percents

Percents are numbers in pixel/degree units unless the modifier says otherwise.
Names are case-insensitive. Lane variants accept the lane digit `0`–`3`
(`x0`, `drunk2`, ...); playfield and player independence is described above.

| Modifier | Percents |
| --- | --- |
| `beat` | `beat`, `beatX`/`Y`/`Z` and their `...Speed`, `...Offset`, `...Mult` |
| `bounce` | `bounce`, `bounceX`/`Y`/`Z`, `bounceSpeed`, `bounceOffset` |
| `boost` | `boost` (accelerate), `brake` (decelerate), `wave`, `waveMult` |
| `bumpy` | `bumpy`, `bumpyX`/`Y`/`Z` (+ `...Offset`/`Period`/`Mult`), `bumpyAngle`, `bumpyAngleX`/`Y`/`Z` (+ the same suffixes) |
| `centerrotate` | `centerRotateX`/`Y`/`Z` |
| `confusion` | `confusion` (Z), `confusionX`/`Y`/`Z`, `confusionOffset`/`X`/`Y`/`Z`, `roll`/`twirl`/`dizzy` (+ `...Speed`) |
| `counterclockwise` | `counterClockWise` |
| `drugged` | `drugged` |
| `drunk` | `drunk` (lane variant), `drunkX`/`Y`/`Z`, `drunkSpeed`, `drunkPeriod`, `drunkOffset` |
| `fieldrotate` | `fieldRotateX`/`Y`/`Z` |
| `infinite` | `infinite` |
| `invert` | `invert` (mirror lanes), `flip` (mirror the field) |
| `localrotate` | `localRotateX`/`Y`/`Z` |
| `opponentswap` | `opponentSwap` |
| `radionic` | `radionic` |
| `receptorscroll` | `receptorScroll` |
| `reverse` | `reverse`, `xmod`, `scrollAngleX`/`Y`/`Z`, `curvedScrollX`/`Y`/`Z`,
`curvedScrollPeriod`, `split`, `alternate`, `cross`, `centered`, `unboundedReverse` |
| `rotate` | `rotateX`/`Y`/`Z` |
| `sawtooth` | `sawtooth`, `sawtoothPeriod` |
| `scale` | `scale`/`scaleX`/`scaleY` (multipliers, default 1), `tiny`/`tinyX`/`tinyY` (`1` = half size) |
| `schmovindrunk` | `schmovinDrunk` |
| `schmovintipsy` | `schmovinTipsy` |
| `schmovintornado` | `schmovinTornado` |
| `skew` | `skewX`, `skewY` (stored only, see limitations) |
| `spiral` | `spiral`, `spiralDist` |
| `square` | `square`, `squareOffset`, `squarePeriod` |
| `stealth` | `stealth` (tap arrows) / `dark` (sustains), `alpha` (default 1),
`sudden`/`hidden` with `...Start`/`...End` (distance thresholds, percent × 100 px) and `...Glow` |
| `tipsy` | `tipsy`, `tipsyX`/`Y`/`Z`, `tipsySpeed`, `tipsyOffset` |
| `tornado` | `tornado` |
| `transform` | `x`/`y`/`z`, `xoffset`/`yoffset`/`zoffset`, plus lane variants (`x0`, `y3`, ...) |
| `vibrate` | `vibrate` |
| `wiggle` | `wiggle` |
| `zigzag` | `zigZag` |
| `zoom` | `zoom`, `mini`, `localZoom`, `localMini` |

`reverse` is implemented as an offset mirror around the current receptor
position rather than a hard-coded direction flip, so it composes with
downscroll and middlescroll; `xmod` scales the resulting scroll offset.

## Example

`example_mods/scripts/ModchartExample.lua` is a fuller, runnable version of this
(trimmed here):

```lua
function onCreatePost()
	addModifier('reverse')
	addModifier('drunk')
	addModifier('bounce')
	addPlayfield()

	modSet('reverse', 8, 1)                     -- flip the scroll on beat 8
	modEase('drunk', 8, 4, 0.2, 'quadOut')      -- ease wobble in
	modSet('xmod', 16, 0.6)                     -- slow the scroll offset
	modEase('reverse', 24, 2, 0, 'quadInOut')   -- unflip at beat 24

	modCallback(32, 'onModchartDrop')
	modRepeater(36, 4, 'onModchartPulse')
end

function onModchartDrop()
	setModchartPerspective(true, 90, 1)
end

function onModchartPulse(beat)
	-- Callbacks receive the beat they fired on: schedule from it.
	local b = beat
	modEase('bounce', b, 2, 0.5, 'quadOut')
	modEase('bounce', b + 2, 2, 0, 'quadIn')
end
```

`modCallback` fires once, on the first update at or after its beat.
`modRepeater` fires on its beat and then every `length` beats for the rest of
the song (or until `resetModchart()`); because these callbacks run on song
frames, both callbacks receive the beat they fired on as their only argument;
schedule follow-up tweens from it instead of hard-coded beats (the `curBeat`
global only refreshes on beat hits). A timeline with no modifier still counts as active, so callback-only
modcharts work; finished `set`/`ease`/`add`/`callback` events are dropped from
the list automatically, while repeaters stay until reset.

Beats in the past resolve immediately: `modEase` with a beat the song has
already passed applies its target value instead of tweening.

## Modchart lab

Tuning a modchart by editing beats and re-running the song is slow, so the
engine ships a lab for it: **Main menu -> `7` (the `debug_1` bind) -> Modchart
Lab** (desktop only, like the other editors). Pick any of the 34 modifiers,
drag its percents while a beat clock loops over a section, watch the preview
arrows react, then copy the matching `modEase(...)` calls as Lua or Python.

The lab runs the real `ModchartManager`/`PlayField.transform` chain on
synthetic `ModchartParams` — no `PlayState`, no song files, no audio — and
`ModchartLabCatalog` is checked against `ModifierRegistry.names()` by the
tests, so a modifier cannot appear in the picker without its percent list.

### Controls

| Input | Action |
| --- | --- |
| Click a name in the list, or `Up`/`Down` | Pick a modifier (`Left`/`Right` jump a column) |
| Drag a percent slider | Set that percent; while the clock runs the value is recorded |
| `Shift` + `Up`/`Down` | Select the next percent |
| `Shift` + `Left`/`Right` | Nudge the selected percent by its step (`Ctrl` = 5x) |
| `Enter` | Restore the percent to the value its modifier ships with |
| `Space` | Play/pause the looping section |
| Drag on the timeline strip | Scrub the section (pauses the clock) |
| `1` / `2` / `3` | Record for both sides / the opponent / the player |
| `E` / `R` | Next/previous ease |
| `L` | Toggle the looping export |
| `Tab` | Switch the export between Lua and Python |
| `C` | Copy the generated script to the clipboard |
| `X` / `Shift` + `X` | Clear the selected percent / every recorded percent |
| `Esc` | Back to the editors menu |

Modifiers you have recorded are marked with `*` in the list, each slider shows
how many keyframes it holds (`drunk (5)`), and the timeline strip under the
preview draws the selected percent's keyframes plus the playhead.

### What gets recorded

Every drag writes keyframes for the current `(modifier, percent, side)` pair:

- Beats snap to the **16th-note grid** (`0.25` beats) and are stored
  **relative to the section start**, so changing `Start` shifts the generated
  beats without touching the shape.
- A keyframe inside the same grid bucket is rewritten instead of appended, so
  holding a value or passing the playhead again does not pile up keys.
- Recorded tracks are replayed on every pass: the arrows show the automation,
  not just your mouse, which is what lets you shape a section over several
  loops.
- Values start from what the modifier ships with (`scale` = `1`, `stealth`
  `alpha` = `1`, `beat` speeds = `1`, ...), not from zero.

`Set` (bumpers/speed/period/toggles) knobs behave the same way: they are
ordinary percents, and the exported script is still `modSet`/`modEase`.

### The generated script

`C` copies a complete fragment for the selected language. Every track becomes
one `modSet` anchoring the section at its first recorded value, then one
`modEase` per segment:

```lua
-- Modchart Lab - Phoenix Engine
-- Section: beats 4 -> 12 (8 beats), ease quadOut
-- Paste into a Lua script; merge the bodies if you already have these callbacks.

function onCreatePost()
	addModifier('drunk')

	modSet('drunk', 4, 0)
	modEase('drunk', 4, 2, 0.5, 'quadOut')
	modEase('drunk', 6, 2, 0.25, 'quadOut')
end
```

The `length` of each `modEase` is the distance to the *next* keyframe and its
target is that keyframe's value, so the script passes through the recorded
points exactly like the preview. Side-specific tracks get the `player`
argument appended (`..., 'quadOut', 1`); both-sided tracks leave it out.

With `Loop` enabled the same calls are wrapped in a callback that
`modRepeater` re-schedules every section and the beats become relative to the
`beat` argument:

```lua
function onCreatePost()
	addModifier('drunk')

	modRepeater(4, 8, 'onModchartLabSection')
end

function onModchartLabSection(beat)
	modSet('drunk', beat, 0)
	modEase('drunk', beat, 2, 0.5, 'quadOut')
	modEase('drunk', beat + 2, 2, 0.25, 'quadOut')
end
```

That is the shape a real modchart loop takes: the `modSet` re-anchors the
section on every repeat and the tweens are scheduled from the callback's beat,
which is why the lab's export can be pasted as-is.

### Limitations

- The preview runs the section **from its own start beat**, so modifiers that
  read absolute song time (`drunk`, `tipsy`, `receptorScroll`,
  `counterClockWise`) have a phase that will not match a given spot of a real
  song. Beat-driven ones (`beat`, `bounce`, `confusion`, `wiggle`, ...) do.
- One playfield, one side pair, 4 lanes: the lab is for tuning numbers, not for
  composing multi-field layering.
- `skew` is stored but not drawn (Flixel sprites have no skew matrix), and
  `vibrate` is random, so both look inconsistent by design.
- Editing the exported text is expected: the lab writes the tween skeleton, not
  your callbacks, perspective changes or per-lane variants (`drunk0`, ...).

## Haxe API

Scripts use the callbacks above; engine code can use the manager directly:

```haxe
PlayState.instance.modchart.addModifier('drunk');
PlayState.instance.modchart.setPercent('drunk', 1, -1);
PlayState.instance.modchart.ease('drunk', 8, 4, 0, modchart.ModchartEase.quadOut);
PlayState.instance.modchart.update(PlayState.instance.curDecBeat);
```

`PlayStateModchart` is the only place that touches Flixel objects: it captures
each receptor's resting position/angle/scale/alpha, applies every playfield in
order, then moves the receptor. Before each frame it removes the visuals it
wrote last frame, so the engine's own intro alpha tween and script
`setProperty` changes to receptors keep working; notes only receive a field's
offset while `copyX`/`copyY`/`copyAngle`/`copyAlpha`/`copyScale*` are enabled. Notes are transformed after `Note.followStrum`,
so they inherit the shifted receptor and then take their own offset — pooled and
recycled notes therefore need no per-note state.

## Limitations

- **Lane count.** The playfield follows the live receptor groups, so 5K+ charts
  keep their layout; modifiers that use a fixed lane count (for example
  `tornado`) read it from the current chart.
- **`skew` is stored, not drawn.** Flixel sprites have no skew matrix, so
  `skewX`/`skewY` are tracked for completeness but have no visual effect.
- **Sustain tails keep their length.** `scaleY` of a sustain encodes the hold
  length, so the vertical scale modifier is skipped for sustain notes.
- **No `ArrowShape` or `PathModifier`.** Only offset-based modifiers are ported;
  scripts that expect path/shape mods need charts authored for those features.
- **HScript** reuses `FunkinLua.registeredFunctions`, so the modchart API is
  available to Haxe scripts only when a Lua/Python script instance already exists
  (pre-existing engine behaviour).
- The runtime does not own cameras or shaders. Combine it with the existing
  camera helpers for zoom/shake, and with `setModchartPerspective` for 3D.

## Tests

```bash
bash tests/haxe/run-modchart.sh                  # core math, timeline, all 34 modifiers
bash tests/haxe/run-modchart-typecheck.sh        # adapter + Lua/Python registration
bash tests/haxe/run-modchart-lab.sh              # lab catalog, automation and export
bash tests/haxe/run-modchart-lab-typecheck.sh    # drives the lab state through Flixel stubs
```

Every script has `.bat`/`.ps1` twins (`run-modchart.bat`,
`run-modchart-lab-typecheck.ps1`, ...) and the four run in CI (`checks.yml`).
The lab specs also prove that each catalog percent actually moves its
modifier, so a typo in a percent name fails the build instead of producing a
slider that does nothing.
