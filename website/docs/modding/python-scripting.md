---
title: Python scripting
sidebar_position: 40
description: Hython-based Python scripting — setup, differences from Lua, and examples.
---

# Python scripting

Python scripting is a Phoenix Engine addition. It mirrors the Lua system: the same file
locations, the same callback names, and a subset of the same functions, so a script can be
ported between the two languages mostly by changing syntax.

## Requirements

- A build with `PYTHON_ALLOWED` — `-DMODDING_LEVEL=2`, which is the **default** on desktop
  and mobile.
- Nothing else. The interpreter is [Hython](https://github.com/Paopun20/Hython)
  (haxelib `hython`), a pure-Haxe Python implementation, so no CPython runtime is
  installed or bundled.

```bash
lime test windows -DMODDING_LEVEL=2   # Lua + Python (default)
lime test windows -DMODDING_LEVEL=1   # Lua only — .py files are ignored
```

## Where scripts go

Exactly where Lua scripts go, with a `.py` extension:

| Location | Loaded |
|---|---|
| `mods/<mod>/scripts/*.py` | every song |
| `mods/<mod>/data/<song>/<song>.py` | that song |
| `mods/<mod>/stages/<stage>.py` | that stage |
| `mods/<mod>/custom_notetypes/<type>.py` | that notetype |
| `mods/<mod>/custom_events/<event>.py` | that event |

Lua and Python scripts coexist; both are loaded and both receive every hook.

:::caution[Softmod sandbox]

Python files under `mods/` are source-scanned before Hython is created. Dangerous
OS/process/network/file imports and APIs are blocked by default, and host Haxe class
resolution is disabled. A finding stops that script and logs its mod, file and line. See
[Script security sandbox](./script-security.md) for the rules and per-mod allowlist.

:::

## A minimal script

```python
def onCreate():
    # some variables don't exist yet
    pass

def onCreatePost():
    makeLuaSprite('myBg', 'myImage', 0, 0)
    setObjectCamera('myBg', 'camGame')
    addLuaSprite('myBg', False)

def onUpdate(elapsed):
    pass

def onBeatHit():
    if curBeat % 4 == 0:
        cameraShake('camGame', 0.005, 0.1)

def onDestroy():
    pass
```

`docs/TemplateScript.py` (and `example_mods/scripts/TemplateScript.py`) is the commented
template with every hook — Lua and Python share the same hook list; the shipped
`mods/bf-clicker/` mod is a complete working example.

## Differences from Lua

| | Lua | Python |
|---|---|---|
| Hook definition | `function onCreate()` | `def onCreate():` |
| Booleans | `true` / `false` | `True` / `False` |
| Nil | `nil` | `None` |
| Tables as arguments | `{1, 2, 3}` | `[1, 2, 3]` |
| Comments | `--` | `#` |

Both languages receive every hook listed in [Script hooks](./script-hooks.md);
missing hooks silently never fire, so parity is load-bearing. Python callbacks
are dispatched through the same `PlayState.callOnScripts` path as Lua (#87).

The Python library covers sprites, text, cameras, characters, properties, sound, score,
timers, tweens, inter-script calls, Discord and window effects. Anything the Python
library does not declare for itself still reaches Python through the inherited Lua
registry (see the note below), so the practical difference is smaller than it looks — but
Lua-only areas remain: file reading (`getTextFromFile`), runtime GLSL
(`initLuaShader`, `setSpriteShader`, `setShaderFloat`), the built-in screen effects
(`addCRTEffect`, `clearEffects`, …) and a few gameplay helpers with no Python case. Use a
Lua script for those, or add the twin in `psychlua/pystdlib/` and send a PR
([how](../subsystems/scripting-runtime.md#adding-a-callback)).

Function names are intentionally **identical** to Lua, including the `luaX` prefixes
(`makeLuaSprite`, `addLuaText`, …), so that porting is mechanical.

## Control flow

The same sentinels exist, as globals:

```python
def onStartCountdown():
    return Function_Stop     # suppress the countdown

def onEndSong():
    return Function_Continue
```

`PythonScript` names the third sentinel `Function_StopAll` internally; from a script both
that name and the Lua-compatible `Function_StopLua` global are available (they are the
same sentinel value, #51).

## Android haptics

```python
vibrate()       # 50 ms pulse
vibrate(120)    # 120 ms pulse (maximum 5000)
```

`vibrate(durationMs)` mirrors the Lua callback: Android-only, returns `True` when
the pulse is sent to the Android bridge, and is independent of the automatic
**Haptic Feedback** option (Off / Misses / Hits and Misses) in Mobile Options.

## Debug output

```python
debugPrint('health is', getProperty('health'))
```

Output goes to the on-screen `pythonDebugGroup`, the Python counterpart of the Lua debug
text. Errors are caught per call — a raised exception prints and the song keeps playing.

## Cookbook

The same recipes as the [Lua cookbook](./lua-scripting.md#cookbook), in Python. Every
snippet is self-contained: drop it in `mods/MyMod/scripts/` (or a song's
`data/<song>/` folder) and it runs on any chart. Image keys are `images/` paths, so
`'menu/boombox'` loads `mods/MyMod/images/menu/boombox.png`.

:::note[Python sees the Lua registry too]

After the generated `Py*Lib` functions are bound, `PythonScript` copies every entry of
`FunkinLua.registeredFunctions` into the Python namespace. So a function that is missing
from the [Python API reference](./python-api-reference.md) (for example `startTween`,
`setSoundVolume`, `createCamera`, `addCRTEffect`, `runHaxeCode`) is still **callable**
from Python, with the Lua signature. The reference only lists what the Python library
declares itself.

:::

### Sprites and draw order

```python
def onCreatePost():
    # Behind the characters (False = back layer).
    makeLuaSprite('spotlight', 'stages/spotlight', -200, -100)
    setScrollFactor('spotlight', 0.6, 0.6)
    setBlendMode('spotlight', 'add')
    setProperty('spotlight.alpha', 0.65)
    addLuaSprite('spotlight', False)

    # Flat colour block, no image file needed.
    makeLuaSprite('vignetteBar', '', 0, 0)
    makeGraphic('vignetteBar', 8, 8, '000000')
    setGraphicSize('vignetteBar', screenWidth, 80)
    updateHitbox('vignetteBar')
    setScrollFactor('vignetteBar', 0, 0)
    setObjectCamera('vignetteBar', 'camHUD')
    addLuaSprite('vignetteBar', True)

    loadGraphic('spotlight', 'stages/spotlight2')   # swap the image in place
    debugPrint('draw order of spotlight: ' + str(getObjectOrder('spotlight')))
```

`addLuaSprite(tag, True)` puts the sprite in front of the characters; `False` inserts it
behind them. `screenCenter(tag, 'xy')` and `setObjectOrder(tag, index)` reposition and
re-sort it afterwards, and `luaSpriteExists(tag)` tests whether a tag is live.

### Animated sprites

```python
def onCreatePost():
    makeAnimatedLuaSprite('speaker', 'props/speaker', 900, 500)
    addAnimationByPrefix('speaker', 'bump', 'speaker bump', 24, True)
    addAnimationByIndices('speaker', 'glitch', 'speaker idle', '0,2,4,1', 12)
    addAnimationByIndicesLoop('speaker', 'idleLoop', 'speaker idle', '0,1,2,3', 12)
    addAnimation('speaker', 'quick', [0, 1, 2, 3], 24, True)   # by frame number
    setGraphicSize('speaker', 320, 320)
    updateHitbox('speaker')
    addLuaSprite('speaker', True)
    playAnim('speaker', 'idleLoop', True)


def onBeatHit():
    if curBeat % 4 == 0:
        playAnim('speaker', 'bump', True)
```

The third animation helper takes raw frame indices instead of a prefix; the prefix
variants match every frame whose name starts with the string, so `'speaker bump'` picks
up `speaker bump0000`, `speaker bump0001`, … .

### Text and HUD readouts

```python
def onCreatePost():
    makeLuaText('comboTxt', '', 400, 0, 40)
    setTextSize('comboTxt', 28)
    setTextFont('comboTxt', 'vcr.ttf')
    setTextColor('comboTxt', 'ffee88')
    setTextBorder('comboTxt', 2, '000000')
    setTextAlignment('comboTxt', 'center')
    setTextWidth('comboTxt', 400)
    screenCenter('comboTxt', 'x')
    addLuaText('comboTxt')


def onUpdatePost(elapsed):
    setTextString('comboTxt', 'COMBO ' + str(int(getProperty('combo'))))


def onDestroy():
    removeLuaText('comboTxt')
```

`getTextString`, `getTextSize`, `getTextWidth` and `getTextFont` read a text object back;
`luaTextExists(tag)` tells you whether it is still around.

### Tweens

```python
def onCreatePost():
    doTweenX('slideIn', 'spotlight', 0, 0.8, 'quadOut')
    doTweenAlpha('fadeIn', 'spotlight', 1, 1.2, 'sineOut')
    doTweenAngle('spin', 'spotlight', 360, 4, 'linear')
    doTweenScale('pulse', 'spotlight', 1.15, 0.5, 'elasticOut')
    doTweenColor('tint', 'spotlight', 'ff5599', 0.6, 'quadInOut')

    # Several properties at once: chain short tweens with the same tag scheme.
    doTweenY('riseUp', 'spotlight', 120, 1.0, 'backOut')
    doTweenAlpha('riseFade', 'spotlight', 0.4, 1.0, 'sineOut')


def onBeatHit():
    if curBeat == 16:
        cancelTween('spin')
```

The optional `startTween(tag, vars, values, duration, options)` from the Lua registry is
callable from Python, but its `values`/`options` arguments are Lua tables that Hython hands
over as Haxe objects — awkward to build in Python. The `doTween*` helpers cover the same
ground and need no tables, which is why the examples use them.

`doTweenZoom` is camera-only (`'camGame'` / `'camHud'`); on a sprite it logs an error and
does nothing. `doTweenColor` takes a hex string without `0x`, and every tween divides its
duration by `playbackRate`.

### Timers

```python
def onSongStart():
    runTimer('everyTwoSeconds', 2, 0)   # 0 loops = forever
    runTimer('oneShot', 5, 1)


def onTimerCompleted(tag, loops, loopsLeft):
    if tag == 'everyTwoSeconds':
        cameraShake('camGame', 0.004, 0.08)
    elif tag == 'oneShot':
        cancelTimer('everyTwoSeconds')
```

Re-using a tag cancels the previous timer first, so this doubles as "restart the
countdown".

### Sound effects and music

```python
def onCreatePost():
    precacheSound('countdown')


def onSongStart():
    playSound('countdown', 0.8, 'countSfx')   # third argument tags the sound
    soundFadeIn('countSfx', 1.0, 0, 0.8)


def onBeatHit():
    if curBeat == 8:
        stopSound('countSfx')
    elif curBeat == 12:
        playSound('countdown', 0.5, 'countSfx')
        soundFadeOut('countSfx', 2.0)


def onSoundFinished(tag):
    debugPrint('sound finished: ' + str(tag))
```

Only tagged sounds can be stopped, paused, faded or queried; an untagged `playSound`
cannot even be cancelled, and it never fires `onSoundFinished`. An empty tag is the
special case that targets the song's own track: `setSoundVolume('', 0.4)` ducks it and
`soundFadeIn('', 1.0, 0, 1)` brings it back, while `playMusic(sound, volume, loop)`
replaces it outright.

### Cameras

```python
def onCreatePost():
    cameraSetTarget('dad')
    cameraFlash('camGame', 'ffffff', 0.3, True)   # colour, seconds, forced
    cameraFade('camHUD', '000000', 1.0, False)    # fade in from black


def onBeatHit():
    if curBeat % 8 == 0:
        cameraShake('camGame', 0.01, 0.15)
```

The `forced` argument is required: `False` respects the player's **Flashing Lights**
option, `True` ignores it.

Custom cameras use the Lua three-step pattern: create, add, then clear the background so
the extra camera does not paint over the game. The `config` table is a Lua anonymous
structure, so from Python create the camera first and size it with `setProperty` — the
same three values the table would have set:

```python
def onCreatePost():
    # createCamera() with no config builds a 0x0, zoom-0 camera, so size it below.
    createCamera('camOverlay')            # a FlxCamera, stored under this name
    addCamera('camOverlay', None, False)  # append after camHUD, so it draws last
    setProperty('camOverlay.width', screenWidth)
    setProperty('camOverlay.height', screenHeight)
    setProperty('camOverlay.zoom', 1)
    setProperty('camOverlay.bgColor', 0x00000000)   # do not paint over the game

    makeLuaSprite('overlayDim', '', 0, 0)
    makeGraphic('overlayDim', 8, 8, '000000')
    setGraphicSize('overlayDim', screenWidth, screenHeight)
    updateHitbox('overlayDim')
    setProperty('overlayDim.alpha', 0.4)
    setScrollFactor('overlayDim', 0, 0)
    setObjectCamera('overlayDim', 'camOverlay')
    addLuaSprite('overlayDim', True)


def onDestroy():
    removeCamera('camOverlay')
```

### Filters and screen effects

```python
def onCreatePost():
    addColorFilter('global', 'handheld', 'gameboy')   # whole window
    addBlurFilter('hud', 'soft', 3, 3)
    addSpriteOutlineEffect('dad', 'white', 2, 'fast')
    addRainbowEffect('dad', 1, 1, 6)
    addCRTEffect('game')


def onUpdate(elapsed):
    blur = 12 if getProperty('health') > 1.5 else 3
    setFilterProperty('hud', 'soft', 'blurX', blur)
    setFilterProperty('hud', 'soft', 'blurY', blur)


def onBeatHit():
    if curBeat == 16:
        addMosaicEffect('game', 12.0)
    elif curBeat == 20:
        clearEffects('game')
        clearFilters('global')
```

Filters (`add*Filter`, `setFilterProperty`, `clearFilters`) need no GLSL and ignore the
Shaders toggle. Screen effects (`addCRTEffect`, `addMosaicEffect`, `clearEffects`, …) are
GLSL passes: they are only registered in builds with shader support and do nothing while
the player has **Shaders** turned off, so guard the block on the published
`shadersEnabled` global instead of assuming they work.

### Save data

```python
SAVE = 'MyModSave'


def savedNumber(field):
    # A field that was never written comes back as None.
    value = getDataFromSave(SAVE, field)
    return int(value) if value is not None else 0


def onCreatePost():
    initSaveData(SAVE)
    setDataFromSave(SAVE, 'plays', savedNumber('plays') + 1)
    flushSaveData(SAVE)


def onEndSong():
    setDataFromSave(SAVE, 'clears', savedNumber('clears') + 1)
    flushSaveData(SAVE)
```

`initSaveData` / `getDataFromSave` / `setDataFromSave` come from the shared Lua registry
(they are not in the generated Python table), so they take the Lua argument order. Values
only reach the disk on `flushSaveData`. The engine-wide save is reachable through the
property bridge, as `mods/bf-clicker` does:

```python
best = getPropertyFromClass('flixel.FlxG', 'save.data.myModBest')
best = int(best) if best is not None else 0
setPropertyFromClass('flixel.FlxG', 'save.data.myModBest', best + 1)
flushGlobalSave()
```

### Input

```python
def onUpdate(elapsed):
    if keyJustPressed('space'):
        cameraFlash('camHUD', 'ffffff', 0.1, False)

    if mouseClicked('left'):
        debugPrint('mouse at ' + str(getMouseX('hud')) + ', ' + str(getMouseY('hud')))
```

Python's `keyJustPressed` supports the four directions plus `'reset'` and `'space'` —
there is no `'accept'` / `'back'` / `'pause'` case, so use a Lua script (or a standalone
`.hx`) if you need those. `keyboardJustPressed(name)` from the shared registry covers raw
`FlxG.keys` names.

### Modchart

```python
def onCreatePost():
    addModifier('reverse')
    addModifier('drunk')
    addModifier('bounce')

    modSet('reverse', 8, 1)
    modEase('drunk', 8, 4, 0.25, 'quadOut')
    modAdd('drunk', 8, 2, 0.2, 'linear')
    modSetAdd('bounce', 16, 0.4)
    modCallback(24, 'onDrop')
    modRepeater(28, 4, 'onPulse')


def onDrop(beat):
    setModchartPerspective(True, 90, 1)


def onPulse(beat):
    modEase('bounce', beat, 2, 0.5, 'quadOut')
    modEase('bounce', beat + 2, 2, 0, 'quadIn')


def onDestroy():
    resetModchart()
```

Timeline callbacks receive the beat they fired on, so follow-up eases are scheduled from
it. `addModifier(name, field)` targets a playfield created with `addPlayfield()`;
`getPercent(name)`, `isModchartActive()` and `getModchartModifiers()` report state.

### Talking to other scripts

```python
def onCreatePost():
    if not isRunning('scripts/extra.py'):
        addPythonScript('scripts/extra.py')

    setGlobalFromScript('otherScript.py', 'sharedValue', 10)
    value = getGlobalFromScript('otherScript.py', 'sharedValue')
    callScript('scripts/helper.py', 'doThing', [1, 2, 3])
    callOnScripts('myHook', ['payload'])
```

`callOnScripts` (alias `callOnLuas`) dispatches to every loaded script of every language;
`callScript` targets one file. `addScript(path)` picks the loader from the extension and
falls back to trying `.lua`, `.py` and `.hx` in turn.

### Score, health and gameplay helpers

```python
def onUpdatePost(elapsed):
    if curStep % 16 == 0 and curBeat > 60:
        addScore(50)
        addCombo(1)


def goodNoteHit(id, direction, noteType, isSustainNote):
    if not isSustainNote:
        addHealth(0.02)


def onBeatHit():
    if curBeat == 32:
        changeMaxHealth(4)     # SETS max health (default 2)
        setHealthBarColors('ff5599', '33ccff')
        setTimeBarColors('ff5599', '33ccff')
```

`getHealth()`, `getScore()`, `getHits()`, `getMisses()` and `getMaxHealth()` read the
totals; `setHealth`, `setScore`, `setHits` and `setMisses` overwrite them.
`setPlaybackSpeed(value)` and `addPlaybackSpeed(delta)` change the rate the song plays at
(everything script-scheduled scales with it), `setRatingPercent` / `setRatingName` /
`setRatingFC` override the results screen, and `getColorFromHex('ff5599')` turns a hex
string into the number `setProperty` expects for a colour field.

### Preloading

```python
def onCreate():
    precacheImage('props/speaker')
    precacheSound('countdown')
    precacheMusic('menu/freakyMenu')
    addCharacterToList('pico-nightmare', 'dad')
```

Preloading happens during the loading screen; doing it there is what keeps the first
`playSound` or character swap from hitching mid-song.

### Debugging a stubborn script

```python
def onCreatePost():
    debugPrint('difficulty=' + str(difficultyName) + ' speed=' + str(playbackRate))
    debugPrint('scripts: ' + str(getRunningScripts()))
    if not isRunning('scripts/extra.py'):
        debugPrint('extra.py was not loaded — check the filename and folder')
```

`debugPrint` concatenates up to five arguments and never raises. Errors inside a hook are
caught per call: the trace appears in the on-screen Python debug text and the song keeps
playing, so a silent hook usually means a typo in the function name rather than a crash.

## Performance

Hython is an interpreter written in Haxe; it is slower than LuaJIT. For per-frame work in
a demanding chart, prefer Lua. For setup, event reactions and beat-synced logic, the
difference is irrelevant.

## Next

- [Python API reference](./python-api-reference.md) — the generated Python function list.
- [Transparent window](./transparent-window.md) — make the game window see-through.
- [Script hooks](./script-hooks.md) — the callbacks, shared with Lua.
