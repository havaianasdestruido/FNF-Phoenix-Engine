---
title: Characters & stages
sidebar_position: 3
description: The character JSON format, animation handling, stage JSON and hardcoded stages.
---

# Characters & stages

## Characters

`objects.Character` is an `FlxSprite` driven by a JSON file at
`characters/<id>.json` (`assets/preload/characters/` or `mods/<mod>/characters/`).

### `CharacterFile`

| Field | Type | Meaning |
|---|---|---|
| `image` | `String` | atlas path, e.g. `characters/BOYFRIEND` |
| `animations` | `Array<AnimArray>` | the animation table (below) |
| `scale` | `Float` | sprite scale |
| `sing_duration` | `Float` | beats a sing animation is held |
| `healthicon` | `String` | icon id in `images/icons/` |
| `position` | `Array<Float>` | `[x, y]` offset on the stage |
| `camera_position` | `Array<Float>` | camera offset when this character sings |
| `flip_x` | `Bool` | horizontal flip |
| `no_antialiasing` | `Bool` | for pixel characters |
| `healthbar_colors` | `Array<Int>` | `[r, g, b]` |
| `noteskin` *(optional)* | `String` | force a note skin while this character plays |
| `vocals_file` *(optional)* | `String` | per-character vocal track |
| `flixel_trail`, `trail_length`, `trail_delay`, `trail_alpha`, `trail_diff` *(optional)* | | `FlxTrail` configuration |
| `health_drain`, `drain_amount`, `drain_floor` *(optional)* | | continuous health drain |
| `shake_screen`, `shake_intensity`, `shake_duration` *(optional)* | | screen shake on sing |
| `_editor_isPlayer` *(optional)* | `Bool` | editor-only hint |

### `AnimArray`

```json
{ "anim": "singLEFT", "name": "BF NOTE LEFT0", "fps": 24, "loop": false,
  "indices": [], "offsets": [5, -6] }
```

`anim` is the engine-facing name, `name` the atlas prefix, `indices` an optional frame
subset, `offsets` the per-animation position correction.

### Animation names the engine expects

`idle` (or `danceLeft`/`danceRight` for dancers), `singLEFT`, `singDOWN`, `singUP`,
`singRIGHT`, optional `...miss` variants, plus `hey`, `scared`, `dodge`, `attack` and
`-alt` suffixed variants depending on the chart. Missing animations degrade gracefully
rather than crashing.

### At runtime

`Character` keeps `animOffsets`, a `debugMode` used by the character editor, dance
alternation driven by the beat callbacks, and `playAnim(name, force, reversed, frame)`.
`play.helpers.PlayStateCharacters` owns the gameplay-side behaviour (who sings, idle
timers, alt animations, character swaps from the `Change Character` event).

Related objects: `objects.HealthIcon` (bopping icons with winning/losing frames),
`objects.MenuCharacter` (story menu), and `shaders.CrossFade` for the character crossfade
effect configured by `ClientPrefs.crossFadeMode` and the per-character limits.

## Stages

A stage is either **JSON-only** or **JSON + a hardcoded class**.

### `StageFile` (`data.StageData`)

| Field | Meaning |
|---|---|
| `directory` | asset library/folder for the stage's assets |
| `defaultZoom` | base camera zoom |
| `isPixelStage` *(optional)* | pixel-perfect rendering and UI skin |
| `stageUI` | which UI skin to use |
| `boyfriend`, `girlfriend`, `opponent` | `[x, y]` character placements |
| `hide_girlfriend` | skip spawning gf |
| `camera_boyfriend`, `camera_opponent`, `camera_girlfriend` | per-character camera offsets |
| `camera_speed` | follow lerp speed |
| `shaders` *(optional)* | shader names to pre-compile on the loading screen (`shaders.ShaderWarmup`) |

`StageData.getStageFile(stage)` reads `stages/<stage>.json`, checking mods first, and
`StageData.dummy()` supplies a safe fallback. `StageData.loadDirectory(SONG)` sets the
asset directory before anything loads, and `StageData.vanillaSongStage(songName)` is the
central map from base-game songs to stage ids (previously duplicated in several places).

### Hardcoded stages

Classes in `stages/` extend `play.BaseStage` and get the full lifecycle:

```haxe
class MyStage extends BaseStage {
  override function create():Void { ... }      // build props
  override function createPost():Void { ... }  // after characters exist
  override function update(elapsed:Float):Void { ... }
  override function stepHit():Void { ... }
  override function beatHit():Void { ... }
  override function sectionHit():Void { ... }
  override function countdownTick(count:Countdown, num:Int):Void { ... }
  override function eventCalled(name:String, v1:String, v2:String, flag:Int, time:Float):Void { ... }
  override function declareShaders():Array<Shader> { ... }  // see "Shader warm-up"
}
```

Shipped stages: `StageWeek1`, `Spooky`, `Philly`, `PhillyBlazin`, `PhillyStreets`,
`PhillyStreetsBF`, `Limo`, `Mall`, `MallEvil`, `School`, `SchoolEvil`, `Tank`, and
`Template` (the starting point for a new one).

Stage props live in `stages/objects/`: `PhillyTrain`, `PhillyGlowGradient`,
`PhillyGlowParticle`, `BackgroundDancer`, `BackgroundGirls`, `BackgroundTank`,
`TankmenBG`, `MallCrowd`, `DadBattleFog`, `ABotSpeaker` (the spectrum-analyzer speaker),
`SpraycanAtlasSprite`, `PicoBlazinHandler`, `DarnellBlazinHandler`.

### Shader warm-up

The driver compiles GLSL the first time a shader is actually drawn, which used to land
on the first bop of a song (the stage's camera filter, the `Pulse` event's
`RuntimeShaders.pulseEffect`, a mod's runtime shader…). `PlayState` now compiles what a
stage declares while the loading screen is still up (`play.helpers.PlayStateShaders` →
`shaders.ShaderWarmup`), so the program is already in OpenFL's per-context program cache
when gameplay starts.

Two ways to declare a shader:

```jsonc
// stages/<stage>.json — built-in names and/or <mod>/shaders/<name>.frag
"shaders": ["rain", "glitch", "myModShader.frag"]
```

```haxe
// a hardcoded stage: hand over the instances it renders with
override function declareShaders():Array<Shader>
  return rainShader != null ? [rainShader] : [];
```

Built-in names (`shaders.ShaderWarmupRegistry`): `rain`, `glitch`, `blockedglitch`,
`bloom`, `building`, `chromatic`, `distant`/`distantnote`/`distantnoteshader`, `distortbg`,
`grain`, `grayscale`/`greyscale`, `invert`, `pulse`, `rgbpalette`, `scanline`, `threed`/`3d`,
`tiltshift`, `vcr`, `vfd`.
Names are matched case-insensitively and ignore a `.frag`/`.vert` extension, so `Rain`
and `shaders/rain.frag` both work. Runtime shaders a Lua/Python/HScript script creates
while the state loads are queued automatically. Backends without a GL render context
(Flash/AIR, HTML5 canvas) simply skip warm-up; unknown names only log a warning.

### Stage scripts

Independently of the class, `PlayState` loads `stages/<stage>.lua` and `stages/<stage>.py`
from the mod folders, so a soft mod can build a complete stage with no Haxe at all.

## Adding content

**A character (mod):** drop `characters/<id>.json` + the atlas in `images/characters/`
and an icon in `images/icons/`. Reference the id from the chart's `player1`/`player2`/
`gfVersion`.

**A stage (mod):** add `stages/<id>.json`, the images, and optionally
`scripts`-style logic in `stages/<id>.lua`.

**A stage (engine):** add a class in `stages/` extending `BaseStage`, register it where
`PlayState` resolves `curStage`, and add the JSON under `assets/preload/stages/`.
