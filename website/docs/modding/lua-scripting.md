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
| `mods/<mod>/scripts/*.lua` | while that mod is the current mod, **and** for every song when its `pack.json` sets `"runsGlobally": true` |
| `mods/scripts/*.lua` | same, for loose files not in a mod |
| `assets/scripts/*.lua` | engine-level global scripts (the path is `Paths.getPreloadPath('scripts/')`) |
| `mods/<mod>/data/<song>/<song>.lua` | when that song plays |
| `mods/<mod>/stages/<stage>.lua` | when that stage loads |
| `mods/<mod>/custom_notetypes/<type>.lua` | when the chart uses that notetype |
| `mods/<mod>/custom_events/<event>.lua` | when the chart uses that event |

Global scripts are deduplicated by file name; the first match in priority order
(global mods → current mod → loose `mods/` → preload) wins. Note the direction: an
enabled global mod shadows a same-named script in the active mod, not the other way
round. (Asset lookup uses the opposite order — the active mod wins there.)

Only the top level of each folder is read, so a script in a subfolder
(`mods/data/song/scripts/x.lua`) is never discovered.

A script can also be loaded on demand from another script with
`addLuaScript(path, ignoreAlreadyRunning)` and removed with `removeLuaScript(path)`.

If a script seems to be ignored entirely, see
[Why is my Lua script not running?](./why-lua-does-not-run.md) for the ordered
list of gates it has to pass.

:::caution[Softmod sandbox]

Lua files under `mods/` are source-scanned before they run, and dangerous standard
libraries/callbacks (OS, IO, package loading, native/process/network/file access) are
blocked at runtime by default. A finding stops that script and logs its mod, file and
line. See [Script security sandbox](./script-security.md), including narrowly scoped
`pack.json` allowlists for trusted mods.

:::

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
| Timing | `hitTiming` (`"early"` / `"late"` / `""`), `noteDiff` (signed ms, `+` early) |
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

Sprites, animated sprites, text, tweens, timers, sound, cameras, shaders, filters, save
data, input, modcharts and score helpers all have worked examples in the
[Cookbook](#cookbook) below. Two one-liners stay here:

**Android haptics**

```lua
vibrate()       -- 50 ms pulse
vibrate(120)    -- 120 ms pulse (maximum 5000)
```

`vibrate(durationMs)` is Android-only and returns `true` when the pulse is sent to
the Android bridge, `false` on other targets or for an invalid/non-positive duration.
It is an explicit script effect, independent of the automatic **Haptic Feedback**
option (Off / Misses / Hits and Misses) in Mobile Options.

**Debugging**

```lua
debugPrint('value is', value)          -- draws on screen via DebugLuaText
debugPrint('health ', getHealth())     -- any number of arguments, up to five
```

## Cookbook

Each snippet below is self-contained: paste it into `mods/MyMod/scripts/` (or a song's
`data/<song>/` folder) and it works on any chart. Paths in `makeLuaSprite` are
`images/` keys, so `'menu/boombox'` loads `mods/MyMod/images/menu/boombox.png`.

### Sprites and draw order

```lua
function onCreatePost()
    -- Behind the characters ('false' = back layer).
    makeLuaSprite('spotlight', 'stages/spotlight', -200, -100)
    setScrollFactor('spotlight', 0.6, 0.6)   -- slight parallax
    setBlendMode('spotlight', 'add')         -- add, screen, multiply, overlay...
    setProperty('spotlight.alpha', 0.65)
    addLuaSprite('spotlight', false)

    -- Flat colour block, no image file needed (8x8 stretched to size).
    makeLuaSprite('vignetteBar', '', 0, 0)
    makeGraphic('vignetteBar', 8, 8, '000000')
    setGraphicSize('vignetteBar', screenWidth, 80)
    updateHitbox('vignetteBar')
    setScrollFactor('vignetteBar', 0, 0)     -- pinned to the screen
    setObjectCamera('vignetteBar', 'camHUD') -- drawn by the HUD camera
    addLuaSprite('vignetteBar', true)

    -- Swap the image later without recreating the tag.
    loadGraphic('spotlight', 'stages/spotlight2')

    debugPrint('draw order of spotlight: ' .. getObjectOrder('spotlight'))
end
```

`addLuaSprite(tag, true)` puts the sprite in front of the characters; `false` inserts it
behind them. `setObjectOrder(tag, index)` re-sorts an existing sprite relative to the
whole state, and `screenCenter(tag, 'x' | 'y' | 'xy')` positions it.

### Animated sprites

```lua
function onCreatePost()
    makeAnimatedLuaSprite('speaker', 'props/speaker', 900, 500)
    addAnimationByPrefix('speaker', 'bump', 'speaker bump', 24, true)
    addAnimationByIndices('speaker', 'glitch', 'speaker idle', '0,2,4,1', 12)
    addAnimationByIndicesLoop('speaker', 'idleLoop', 'speaker idle', '0,1,2,3', 12)
    setGraphicSize('speaker', 320, 320)
    updateHitbox('speaker')
    addLuaSprite('speaker', true)
    playAnim('speaker', 'idleLoop', true)   -- forced = restart if already playing
end

function onBeatHit()
    if curBeat % 4 == 0 then
        playAnim('speaker', 'bump', true)
    end
end
```

`makeAnimatedLuaSprite` supports `'sparrow'` (default), `'packer'` and `'aseprite'`/
`'jsoni8'` as the fifth argument. Animations added with `addAnimationByPrefix` start
automatically if the sprite has no animation yet, so a `playAnim` call is optional.

### Text and HUD readouts

```lua
function onCreatePost()
    makeLuaText('comboTxt', '', 400, 0, 40)
    setTextSize('comboTxt', 28)
    setTextFont('comboTxt', 'vcr.ttf')       -- any font in fonts/ (or the base assets)
    setTextColor('comboTxt', 'ffee88')       -- 'RRGGBB' or '0xAARRGGBB'
    setTextBorder('comboTxt', 2, '000000')
    setTextAlignment('comboTxt', 'center')
    setTextWidth('comboTxt', 400)
    screenCenter('comboTxt', 'x')
    addLuaText('comboTxt')
end

function onUpdatePost(elapsed)
    -- `combo` is one of the globals the engine republishes on every judgement,
    -- so no getProperty call is needed.
    setTextString('comboTxt', 'COMBO ' .. math.floor(combo))
end

function onDestroy()
    removeLuaText('comboTxt')                -- also destroys the object
end
```

Text objects are created on `camHUD` and are not added to the state until `addLuaText`
runs. `getTextString`, `getTextSize`, `getTextWidth` and `getTextFont` read them back;
`luaTextExists(tag)` tells you whether the tag is live.

### Tweens

```lua
function onCreatePost()
    -- Short form: one property per call, same tag scheme as modchart tweens.
    doTweenX('slideIn', 'spotlight', 0, 0.8, 'quadOut')
    doTweenAlpha('fadeIn', 'spotlight', 1, 1.2, 'sineOut')
    doTweenAngle('spin', 'spotlight', 360, 4, 'linear')
    doTweenScale('pulse', 'spotlight', 1.15, 0.5, 'elasticOut')
    doTweenColor('tint', 'spotlight', 'ff5599', 0.6, 'quadInOut')

    -- Multi-property tween with options and a callback by name.
    startTween('riseUp', 'spotlight', {y = 120, alpha = 0.4}, 1.0, {
        ease = 'backOut',
        type = 'oneshot',        -- 'oneshot', 'persist', 'looping', 'pingpong', 'backward'
        startDelay = 0.25,
        onComplete = 'onRiseDone'
    })
end

function onRiseDone(tag, vars)
    debugPrint('tween finished:', tag, ' on ', vars)
end

function onBeatHit()
    if curBeat == 16 then
        cancelTween('spin')      -- stop it early; no onTweenCompleted fires
    end
end
```

`doTweenZoom` only accepts `camGame` / `camHud` (or `Game` / `Hud`); on a sprite it logs
an error and does nothing. Every tween here divides its duration by `playbackRate`, so
rate changes stay in sync.

### Timers

```lua
function onSongStart()
    runTimer('everyTwoSeconds', 2, 0)   -- loops = 0 means forever
    runTimer('oneShot', 5, 1)
end

function onTimerCompleted(tag, loops, loopsLeft)
    if tag == 'everyTwoSeconds' then
        cameraShake('camGame', 0.004, 0.08)
    elseif tag == 'oneShot' then
        cancelTimer('everyTwoSeconds')
    end
end
```

Calling `runTimer` again with the same tag cancels the previous timer, which makes it a
cheap way to restart a countdown.

### Sound effects and music

```lua
function onCreatePost()
    precacheSound('countdown')      -- load during the loading screen, not mid-song
end

function onSongStart()
    playSound('countdown', 0.8, 'countSfx')   -- third argument tags the sound
    soundFadeIn('countSfx', 1.0, 0, 0.8)
end

function onBeatHit()
    if curBeat == 8 then
        stopSound('countSfx')
    elseif curBeat == 12 then
        playSound('countdown', 0.5, 'countSfx')
        setSoundVolume('countSfx', 0.35)
        soundFadeOut('countSfx', 2.0)
    end
end

function onSoundFinished(tag)
    debugPrint('sound finished:', tag)
end

-- A custom event of your own (mods/MyMod/custom_events/Duck The Song.lua) can
-- duck the instrumental mid-song.
function onEvent(name, value1, value2)
    if name == 'Duck The Song' then
        -- Empty tag = the song's instrumental: fade to 30% volume over 0.5 s.
        soundFadeOut('', 0.5, 0.3)
    end
end
```

`playSound(sound, volume, tag)` without a tag is fire-and-forget: it cannot be paused,
stopped, faded or queried afterwards, and `onSoundFinished` will not fire for it.
`getSoundTime(tag)` / `setSoundTime(tag, seconds)` seek a tagged sound.

`playMusic(sound, volume, loop)` replaces the song's instrumental outright — useful in a
menu or a custom state (it is how mods swap the menu theme), but starting it mid-song
desynchronises the chart, so use `playSound` for anything inside a song.

### Cameras

```lua
function onCreatePost()
    cameraSetTarget('dad')                        -- point camGame at the opponent
    cameraFlash('camGame', 'ffffff', 0.3, true)   -- colour, seconds, forced
    cameraFade('camHUD', '000000', 1.0, false)    -- fade in from black
end

function onBeatHit()
    if curBeat % 8 == 0 then
        cameraShake('camGame', 0.01, 0.15)
        cameraFlash('camHUD', 'ff0000', 0.15, false)
    end
end
```

Both `cameraFlash` and `cameraFade` take `forced` as a required boolean: pass `false` to
respect the player's **Flashing Lights** option, `true` to ignore it.

Custom cameras are three calls — create, add, then paint the background transparent:

```lua
function onCreatePost()
    createCamera('camOverlay', {
        x = 0, y = 0,
        width = screenWidth, height = screenHeight,
        zoom = 1,
        defaultDrawTarget = false
    })
    addCamera('camOverlay', nil, false)   -- nil = append after camHUD, so it draws last
    setProperty('camOverlay.bgColor', 0x00000000) -- do not paint over the game

    makeLuaSprite('overlayDim', '', 0, 0)
    makeGraphic('overlayDim', 8, 8, '000000')
    setGraphicSize('overlayDim', screenWidth, screenHeight)
    updateHitbox('overlayDim')
    setProperty('overlayDim.alpha', 0.4)
    setScrollFactor('overlayDim', 0, 0)
    setObjectCamera('overlayDim', 'camOverlay')   -- any name from createCamera works
    addLuaSprite('overlayDim', true)
end

function onDestroy()
    removeCamera('camOverlay')
end
```

### Shaders

Ship `mods/MyMod/shaders/colorShift.frag` (see `docs/SHADERS.md` for the GLSL
conventions), then:

```lua
function onCreatePost()
    if not shadersEnabled then return end        -- the player's Shaders option

    initLuaShader('colorShift')
    setSpriteShader('boyfriend', 'colorShift')
    setShaderFloat('boyfriend', 'uAmount', 0.0)
    setShaderInt('boyfriend', 'uSteps', 8)
    setShaderBool('boyfriend', 'uDesaturate', false)
    setShaderFloatArray('boyfriend', 'uTint', {1.0, 0.2, 0.1})

    -- Animate a uniform; onTweenCompleted fires with the tag like any other tween.
    tweenShaderFloat('shift', 'boyfriend', 'uAmount', 1.0, 1.5, 'quadInOut')
    tweenShaderFloatArray('tintSweep', 'boyfriend', 'uTint', {0.2, 0.7, 1.0}, 0.8, 'linear')
end

function onTweenCompleted(tag)
    if tag == 'shift' then
        debugPrint('shader finished ramping')
    end
end

function onBeatHit()
    if curBeat == 32 then
        -- Camera-wide shader. The third argument is the *name* the filter is
        -- stored under, which is what removeCameraShader() takes back.
        initLuaShader('scanlines')
        setCameraShader('camGame', 'scanlines', 'scanlinesFilter')
        setShaderFloat('camGame', 'uStrength', 0.35)
    elseif curBeat == 40 then
        removeCameraShader('camGame', 'scanlinesFilter')
        removeSpriteShader('boyfriend')
    end
end
```

`initLuaShader` returns `false` when the game was built without shader support or the
player turned shaders off — check it before using the shader. Files are looked up as
`shaders/<mod>/<name>.frag` and an optional `.vert`. `setShaderFloat` and friends act on
the shader attached to the object you name, so `setShaderFloat('camGame', ...)` targets
whatever shader is first on `camGame`.

### Filters and chainable sprite effects

These need no GLSL and never depend on the Shaders toggle:

```lua
function onCreatePost()
    addColorFilter('global', 'handheld', 'gameboy')  -- whole window
    addBlurFilter('hud', 'soft', 3, 3)
    addGlowFilter('game', 'warm', 'ff8800', 0.8, 8, 8, 2)

    -- Chainable per-sprite effects, applied in call order.
    addSpriteOutlineEffect('dad', 'white', 2, 'fast')
    addRainbowEffect('dad', 1, 1, 6)
    addSpriteGlitchEffect('dad', 6, 2, 0.08, 'horizontal')
end

function onUpdate(elapsed)
    if getProperty('health') > 1.5 then
        setFilterProperty('hud', 'soft', 'blurX', 12)
        setFilterProperty('hud', 'soft', 'blurY', 12)
    else
        setFilterProperty('hud', 'soft', 'blurX', 3)
        setFilterProperty('hud', 'soft', 'blurY', 3)
    end
end

function onBeatHit()
    if curBeat == 24 then
        removeFilter('hud', 'soft')
        clearFilters('global')      -- only what scripts added; engine filters stay
    end
end
```

`getFilters(target)` lists the filters currently on a camera and
`getFilterPresets()` lists the colour-matrix presets (`'invert'`, `'greyscale'`,
`'sepia'`, `'sepiacold'`, `'gameboy'`, `'nightvision'`, `'protanopia'`,
`'deuteranopia'`, `'tritanopia'`, `'identity'`).

### Screen effects

```lua
function onCreatePost()
    addCRTEffect('game')                    -- one camera, eleven texture fetches
    addBloomEffect('hud', 0.35, 1.0)        -- intensity, blur size
end

function onBeatHit()
    if curBeat == 16 then
        addMosaicEffect('game', 12.0)
    elseif curBeat == 20 then
        clearEffects('game')                -- drops every effect this script added
        addGrayscaleEffect('game')
    elseif curBeat == 24 then
        clearEffects('game')
    end
end
```

Every `add*Effect` here takes a camera name, not a sprite tag. They stack, and each one
is a full-screen pass, so one or two at a time is the practical limit on mobile.

### Save data

```lua
local SAVE = 'MyModSave'

function onCreatePost()
    initSaveData(SAVE)      -- call once, before any get/set
    local plays = getDataFromSave(SAVE, 'plays') or 0
    setDataFromSave(SAVE, 'plays', plays + 1)
    flushSaveData(SAVE)     -- writes to disk; without this the value is lost on quit
end

function onEndSong()
    -- A different field, written when the song actually finishes.
    local clears = getDataFromSave(SAVE, 'clears') or 0
    setDataFromSave(SAVE, 'clears', clears + 1)
    flushSaveData(SAVE)
end
```

Data is per-mod-name, not per-song, and survives restarts. A field that was never
written reads back as `nil`, so always `or` a default. To read or write the engine's own
save instead, use the property bridge:

```lua
local best = getPropertyFromClass('flixel.FlxG', 'save.data.myModBest') or 0
setPropertyFromClass('flixel.FlxG', 'save.data.myModBest', best + 1)
```

### Input

```lua
function onUpdate(elapsed)
    -- Lane controls: respects the player's key bindings.
    if keyJustPressed('accept') then
        debugPrint('accepted')
    end

    -- Raw keyboard, by Flixel key name.
    if keyboardJustPressed('SPACE') then
        cameraFlash('camHUD', 'ffffff', 0.1, false)
    end

    if mouseClicked('left') then
        debugPrint('mouse at', getMouseX('hud'), getMouseY('hud'))
    end
end
```

`keyJustPressed` accepts `'left'`, `'down'`, `'up'`, `'right'`, `'accept'`, `'back'`,
`'pause'`, `'reset'` and `'space'`; the non-`Just` pair, `keyPressed` / `keyReleased`,
only knows the four lanes plus `'space'`. Anything else — arrows, F-keys, letters — goes
through `keyboardJustPressed` / `keyboardPressed` / `keyboardReleased`, which accept any
`FlxG.keys` name. Gamepad variants exist (`gamepadJustPressed(id, name)`,
`anyGamepadJustPressed(name)`, `gamepadAnalogX(id)`), and mouse helpers take `'left'`
(default), `'right'` or `'middle'`.

### Modchart

```lua
function onCreatePost()
    addModifier('reverse')
    addModifier('drunk')
    addModifier('bounce')

    modSet('reverse', 8, 1)                        -- beat, value
    modEase('drunk', 8, 4, 0.25, 'quadOut')        -- beat, length, value, ease
    modSetAdd('bounce', 16, 0.4)                   -- add to the current value
    modAdd('drunk', 8, 2, 0.2, 'linear')           -- ease a delta instead of a value
    setPercent('drunk', 0.1)                       -- jump straight to a value now
    modCallback(24, 'onDrop')
    modRepeater(28, 4, 'onPulse')
end

function onDrop(beat)
    setModchartPerspective(true, 90, 1)
end

function onPulse(beat)
    modEase('bounce', beat, 2, 0.5, 'quadOut')
    modEase('bounce', beat + 2, 2, 0, 'quadIn')
end

function onDestroy()
    resetModchart()
end
```

`addModifier('name', field)` installs a modifier for the default playfield; pass `1`, `2`,
… to target a field created with `addPlayfield()`. `isModchartActive()` reports whether
anything is installed, `getPercent(name)` reads a percent back, and
`getModchartModifiers()` lists the active ones. The modifier and percent tables live in
[MODCHART.md](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/blob/main/docs/MODCHART.md).

### Events and other scripts

```lua
-- Fire an engine event from code. Note it does NOT call any onEvent handler.
triggerEvent('Camera Zoom', 1.2, '', getSongPosition())

-- Talk to another script by file name and global.
setGlobalFromScript('otherScript.lua', 'sharedValue', 10)
local value = getGlobalFromScript('otherScript.lua', 'sharedValue')

-- Call a function inside another script; the table becomes its arguments.
callScript('scripts/helper.lua', 'doThing', {1, 2, 3})

-- Broadcast a custom hook to every running script (your own included).
callOnLuas('myHook', {'payload'})

-- Load and unload scripts at runtime.
if not isRunning('scripts/extra.lua') then
    addLuaScript('scripts/extra.lua')
end
```

### Score, health and gameplay helpers

```lua
function onUpdatePost(elapsed)
    -- award a bonus every 4 beats in the last section
    if curStep % 16 == 0 and curBeat > 60 then
        addScore(50)
        addCombo(1)
    end
end

function goodNoteHit(id, direction, noteType, isSustainNote)
    if not isSustainNote then
        addHealth(0.02)          -- clamped to maxHealth
    end
end

function onBeatHit()
    if curBeat == 32 then
        changeMaxHealth(4)       -- SETS max health (default 2); health is not rescaled
        setHealthBarColors('ff5599', '33ccff')
        setTimeBarColors('ff5599', '33ccff')
    end
end
```

`getHealth()`, `getScore()`, `getHits()` and `getMisses()` read the totals back;
`setHealth`, `setScore`, `setHits` and `setMisses` overwrite them outright, and
`setRatingPercent` / `setRatingName` / `setRatingFC` override the values shown on the
results screen (usually from `onRecalculateRating`).

### Preloading

```lua
function onCreate()
    precacheImage('props/speaker')
    precacheImage('stages/spotlight2')
    precacheSound('countdown')
    precacheMusic('menu/freakyMenu')
    addCharacterToList('pico-nightmare', 'dad')   -- 'dad', 'gf' or 'boyfriend'
end
```

Everything here is loaded during the loading screen, which is what keeps the first
`playSound` or character swap from hitching mid-song.

## Performance notes

The engine optimises the script bridge aggressively — missing hooks are cached, calls with
up to 8 arguments skip array allocation, and variable paths are split on a fast path. Help
it:

- Do work in `onBeatHit` / timers rather than every frame in `onUpdate`.
- Cache values you read repeatedly instead of calling `getProperty` in a loop.
- Create sprites in `onCreatePost`, not during gameplay.
- Prefer `setPropertyFromGroup` over looping across notes from Lua.

## Next

- [Lua API reference](./lua-api-reference.md) — the generated list of every Lua function.
- [Script hooks](./script-hooks.md) — every callback and its arguments.
- [HScript](./hscript.md) — run Haxe when Lua is not enough.
- [Transparent window](./transparent-window.md) — make the game window see-through.
