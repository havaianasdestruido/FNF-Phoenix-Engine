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
source/play/helpers/PlayStateModchart.hx   adapter that moves the live sprites
source/psychlua/callbacks/ModchartCallbacks.hx  Lua API
source/psychlua/pystdlib/PyModchartLib.hx       Python API
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
| `vibrate` | `vibrate` (visual jitter; device haptics use `ClientPrefs.hapticFeedback` / script `vibrate()`) |
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
bash tests/haxe/run-modchart.sh           # core math, timeline, all 34 modifiers
bash tests/haxe/run-modchart-typecheck.sh # adapter + Lua/Python registration
```

Windows runners (`run-modchart.bat`, `run-modchart.ps1`,
`run-modchart-typecheck.bat`, `run-modchart-typecheck.ps1`) run the same specs.
