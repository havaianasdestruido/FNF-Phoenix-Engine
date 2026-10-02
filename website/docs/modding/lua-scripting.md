---
title: Lua scripting
sidebar_position: 10
description: How Lua scripts are loaded, the variables they get, control flow, and practical patterns.
---

# Lua scripting

Lua scripts need a build with `LUA_ALLOWED` (`-DMODDING_LEVEL=1` or `2`; desktop and
mobile default to `2`). The VM is LuaJIT through `hxluajit`.

## Where scripts go

| Location | Loaded |
|---|---|
| `mods/<mod>/scripts/*.lua` | for every song (global scripts) |
| `mods/scripts/*.lua` | same, for loose files not in a mod |
| `assets/preload/scripts/*.lua` | engine-level global scripts |
| `mods/<mod>/data/<song>/<song>.lua` | when that song plays |
| `mods/<mod>/stages/<stage>.lua` | when that stage loads |
| `mods/<mod>/custom_notetypes/<type>.lua` | when the chart uses that notetype |
| `mods/<mod>/custom_events/<event>.lua` | when the chart uses that event |

Global scripts are deduplicated by file name; the first match in priority order
(global mods → current mod → loose `mods/` → preload) wins.

A script can also be loaded on demand from another script with
`addLuaScript(path, ignoreAlreadyRunning)` and removed with `removeLuaScript(path)`.

## A minimal script

```lua
function onCreate()
    -- the earliest hook; many PlayState variables do not exist yet
end

function onCreatePost()
    -- everything is loaded — do your setup here
    makeLuaSprite('myBg', 'myImage', 0, 0)
    setObjectCamera('myBg', 'camGame')
    addLuaSprite('myBg', false)
end

function onUpdate(elapsed)
end

function onBeatHit()
end

function onDestroy()
end
```

`docs/TemplateScript.lua` contains the fully commented template with every hook.

## Variables the engine publishes

Before each call, the engine pushes a set of globals into the VM
(`setOnScripts` keeps them current). The most used:

| Group | Variables |
|---|---|
| Timing | `curBeat`, `curStep`, `curDecBeat`, `curDecStep`, `crochet`, `stepCrochet`, `bpm`, `curBpm`, `songLength`, `playbackRate` |
| Song | `songName`, `songPath`, `difficulty`, `difficultyName`, `difficultyPath`, `week`, `weekRaw`, `isStoryMode`, `seenCutscene`, `startedCountdown` |
| Chart state | `mustHitSection`, `gfSection`, `altAnim`, `scrollSpeed`, `noteOffset`, `curStage` |
| Characters | `boyfriendName`, `dadName`, `gfName`, `defaultBoyfriendX/Y`, `defaultOpponentX/Y`, `defaultGirlfriendX/Y` |
| Strums | `defaultPlayerStrumX/Y`, `defaultOpponentStrumX/Y` |
| Score | `score`, `misses`, `hits`, `rating`, `ratingName`, `ratingFC` |
| Camera | `cameraX`, `cameraY`, `cameraZoomOnBeat` |
| Preferences | `downscroll`, `middlescroll`, `ghostTapping`, `hideHud`, `flashingLights`, `lowQuality`, `scoreZoom`, `healthBarAlpha`, `noteSkin`, `splashSkin`, `timeBarType`, `framerate`, `shadersEnabled` |
| Modifiers | `practice`, `botPlay`, `instakillOnMiss`, `healthGainMult`, `healthLossMult`, `noResetButton`, `npsSpeedMult`, `polyphonyBF`, `polyphonyOppo` |
| Environment | `buildTarget`, `version`, `jsVersion`, `phoenixVersion`, `screenWidth`, `screenHeight`, `scriptName`, `modFolder`, `currentModDirectory`, `user_path`, `inChartEditor`, `inGameOver`, `luaDebugMode`, `luaDeprecatedWarnings` |
| Control flow | `Function_Stop`, `Function_Continue`, `Function_StopLua` |

Anything not in that list is reachable with `getProperty` / `setProperty`:

```lua
local health = getProperty('health')
setProperty('health', health + 0.2)
setPropertyFromGroup('notes', id, 'multAlpha', 0.5)
setPropertyFromClass('backend.ClientPrefs', 'downScroll', true)
```

## Control flow

Hooks that can cancel engine behaviour check your return value:

```lua
function onStartCountdown()
    startDialogue('myDialogue', 'myMusic')
    return Function_Stop   -- suppress the countdown; call startCountdown() later
end
```

| Return | Meaning |
|---|---|
| `Function_Continue` (or nothing) | proceed normally |
| `Function_Stop` | cancel the engine's default behaviour |
| `Function_StopLua` | stop passing this hook to further Lua scripts |

## Talking to other scripts

```lua
setGlobalFromScript('otherScript.lua', 'myVar', 10)
local v = getGlobalFromScript('otherScript.lua', 'myVar')
callScript('otherScript.lua', 'myFunction', {1, 2, 3})
callOnLuas('customHook', {})
getRunningScripts()
```

## Common patterns

**Sprites**

```lua
makeAnimatedLuaSprite('boombox', 'boombox', 100, 200)
addAnimationByPrefix('boombox', 'bop', 'boombox bop', 24, false)
addLuaSprite('boombox', true)      -- true = in front of characters
objectPlayAnimation('boombox', 'bop', true)
```

**Tweens and timers**

```lua
doTweenX('moveIt', 'boombox', 500, 1.5, 'quadOut')
runTimer('later', 2, 1)

function onTweenCompleted(tag) if tag == 'moveIt' then ... end end
function onTimerCompleted(tag, loops, loopsLeft) if tag == 'later' then ... end end
```

**Per-mod save data**

```lua
initSaveData('MyMod')
setDataFromSave('MyMod', 'timesPlayed', getDataFromSave('MyMod', 'timesPlayed') + 1)
flushSaveData('MyMod')
```

**Debugging**

```lua
debugPrint('value is', value)   -- draws on screen via DebugLuaText
```

## Performance notes

The engine optimises the script bridge aggressively — missing hooks are cached, calls with
up to 8 arguments skip array allocation, and variable paths are split on a fast path. Help
it:

- Do work in `onBeatHit` / timers rather than every frame in `onUpdate`.
- Cache values you read repeatedly instead of calling `getProperty` in a loop.
- Create sprites in `onCreatePost`, not during gameplay.
- Prefer `setPropertyFromGroup` over looping across notes from Lua.

## Next

- [Lua API reference](./lua-api-reference.md) — all 233 functions.
- [Script hooks](./script-hooks.md) — every callback and its arguments.
- [HScript](./hscript.md) — run Haxe when Lua is not enough.
