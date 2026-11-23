---
title: Script hooks
sidebar_position: 20
description: Every callback the engine fires into Lua, Python and HScript, with arguments and return semantics.
---

# Script hooks

Hooks are plain functions you define in a script. The engine calls the ones it finds and
caches the absence of the rest, so unused hooks cost nothing.

Syntax below is Lua; Python is identical with `def name(args):`, and standalone
HScript (`.hx`/`.hscript`) with `function name(args) { ... }` — see
`docs/TemplateScript.hx` for the exact typed signatures.

## Return values

| Return | Effect |
|---|---|
| nothing / `Function_Continue` | the engine proceeds normally |
| `Function_Stop` | cancels the engine's default behaviour for that hook |
| `Function_StopLua` (Python/HScript: also `Function_StopAll`) | stops the hook propagating to further scripts |

Only hooks documented as cancellable react to `Function_Stop`.

## Lifecycle

| Hook | When | Cancellable |
|---|---|---|
| `onCreate()` | script created; many `PlayState` variables do not exist yet | |
| `onCreatePost()` | end of `create()` — **the recommended setup point** | |
| `onDestroy()` | script ending (song fade-out finished) | |
| `onUpdate(elapsed)` | start of the frame, before engine updates | |
| `onUpdatePost(elapsed)` | end of the frame | |

## Song flow

| Hook | When | Cancellable |
|---|---|---|
| `onStartCountdown()` | before the countdown — stop it to run a dialogue, then call `startCountdown()` | ✓ |
| `onCountdownStarted()` | the countdown actually began | |
| `onCountdownTick(counter)` | `0`=Three, `1`=Two, `2`=One, `3`=Go!, `4`=none | |
| `onSongStart()` | inst + vocals start, `songPosition = 0` | |
| `onEndSong()` | song finished / transition starting | ✓ |
| `onStepHit()` | 16× per section | |
| `onBeatHit()` | 4× per section | |
| `onSectionHit()` | once per section | |

### A worked example

```lua
-- mods/MyMod/scripts/countdown.lua
function onCreate()
    debugPrint('script attached to ' .. songName)
end

function onStartCountdown()
    startDialogue('intro')       -- data/<song>/intro.json
    return Function_Stop         -- the dialogue calls startCountdown() when it ends
end

function onCountdownTick(counter)
    if counter == 3 then
        playSound('countdown', 1, 'goSfx')
    end
end

function onSongStart()
    debugPrint('song started at ' .. getSongPosition() .. ' ms')
end

function onEndSong()
    if getProperty('songMisses') == 0 then
        setTextString('resultTxt', 'PERFECT RUN')
        runTimer('leave', 2, 1)
        return Function_Stop      -- block the default results hand-off
    end
end

function onTimerCompleted(tag)
    if tag == 'leave' then endSong() end
end
```

## Notes and input

| Hook | Arguments | Notes |
|---|---|---|
| `onSpawnNote(id, noteData, noteType, isSustainNote, strumTime)` | | fired as a note enters play |
| `goodNoteHit(id, direction, noteType, isSustainNote)` | | player hit a note |
| `opponentNoteHit(id, direction, noteType, isSustainNote)` | | opponent hit a note |
| `goodNoteSkip(id, direction, noteType, isSustainNote)` | | a player note was skipped (when `noSkipFuncs` is false) |
| `opponentNoteSkip(id, direction, noteType, isSustainNote)` | | an opponent note was skipped (when `noSkipFuncs` is false) |
| `noteMiss(id, direction, noteType, isSustainNote)` | | note missed by letting it pass |
| `noteMissPress(direction)` | | ghost miss — pressed with no note |
| `onGhostTap(key)` | | a tap that hit nothing, with ghost tapping on |
| `onKeyPress(key)` / `onKeyRelease(key)` | | raw lane input |

`id` is the note's member index — read more with
`getPropertyFromGroup('notes', id, 'strumTime')`. Direction: `0` left, `1` down,
`2` up, `3` right.

```lua
local comboMilestone = 50

function goodNoteHit(id, direction, noteType, isSustainNote)
    -- Only count real notes, not the hold segments.
    if isSustainNote then return end

    if combo > 0 and combo % comboMilestone == 0 then
        cameraFlash('camHUD', 'ffff00', 0.15, false)
        playSound('milestone', 0.7)
    end
end

function noteMiss(id, direction, noteType, isSustainNote)
    setProperty('health', getProperty('health') - 0.02)
end

function noteMissPress(direction)
    debugPrint('ghost tap on lane ' .. direction)
end

function onGhostTap(key)
    -- `key` is the lane index (0–3), the same number noteMissPress gets.
    debugPrint('ghost tapped lane ' .. tostring(key))
end

function onKeyPress(key)
    -- Also a lane index — not a key name. For other buttons use
    -- keyJustPressed('pause') / keyboardJustPressed('ESCAPE') in onUpdate.
    if key == 0 then
        debugPrint('left lane pressed')
    end
end
```

`goodNoteHit`, `opponentNoteHit` and the `*Skip` hooks all receive the same four
arguments, so one helper can serve them:

```lua
local function logHit(owner, id, direction, noteType, isSustainNote)
    debugPrint(owner .. ' hit note ' .. id .. ' lane ' .. direction ..
        ' type ' .. tostring(noteType))
end

function goodNoteHit(id, direction, noteType, isSustainNote)
    logHit('player', id, direction, noteType, isSustainNote)
end

function opponentNoteHit(id, direction, noteType, isSustainNote)
    logHit('opponent', id, direction, noteType, isSustainNote)
end
```

## Events

| Hook | Arguments | Notes |
|---|---|---|
| `onEvent(name, value1, value2, strumTime)` | | an event note fired (**not** fired by `triggerEvent()`) |
| `eventEarlyTrigger(name, value1, value2, strumTime)` | | return a millisecond offset to fire the event earlier; overrides the engine's hardcoded values |

```lua
function eventEarlyTrigger(name, value1, value2, strumTime)
    if name == 'Kill Henchmen' then
        return 280   -- fire 280ms early so the sound lands on the beat
    end
end
```

## Pause, game over, dialogue

| Hook | Arguments | Cancellable |
|---|---|---|
| `onPause()` | | ✓ (block pausing) |
| `onResume()` | fires when the song actually resumes. With the **Resume countdown** option on (`resumeCountdown`), this fires at the GO tick, after the 3-2-1-GO, not when the pause menu closes | |
| `onResumeCountdownStart()` | unpausing and the resume countdown is about to start (**Resume countdown** option) | ✓ (skip the countdown; resume instantly) |
| `onResumeCountdownTick(count)` | `count` is `3`, `2`, `1` or `0` (GO); fired on each tick | |
| `onGameOver()` | called every frame health ≤ 0 | ✓ (block the game over) |
| `onGameOverStart()` | the game over screen opened | |
| `onGameOverConfirm(retry)` | `retry` is `false` when the player pressed Esc | |
| `onNextDialogue(line)` | dialogue line index, starting at 1 | |
| `onSkipDialogue(line)` | a line was skipped while typing | |

## Camera, rating, score

| Hook | Arguments | Cancellable |
|---|---|---|
| `onMoveCamera(focus)` | `'boyfriend'`, `'dad'` (or `'gf'`) | |
| `onRecalculateRating()` | fired **before** the calculation; stop it and use `setRatingPercent()` / `setRatingName()` / `setRatingFC()` for your own | ✓ |
| `onUpdateScore(miss)` | just after the score text is rewritten | |

### Custom score text

`onUpdateScore(miss)` fires at the end of every score refresh, *after* the engine has
written `scoreTxt.text`, so whatever you set there is what the player sees:

```lua
function onCreatePost()
    scoreTxt.color = 0xffee88          -- field access through the state
end

function onUpdateScore(miss)
    setProperty('scoreTxt.text',
        'SCORE ' .. getScore() ..
        ' | MISS ' .. getMisses() ..
        ' | ACC ' .. math.floor(getProperty('ratingPercent') * 100) .. '%')

    if miss then
        cameraFlash('camHUD', 'ff0000', 0.12, false)
    end
end
```

Two caveats:

* The hook only runs while `scoreTxt` is visible — the engine returns early when the
  player turned the score text off, so do not put gameplay logic here.
* It fires on score *events*, not every frame, and the `score` / `misses` /
  `rating` globals are refreshed by the rating calculation that follows it — read
  `getScore()`, `getMisses()` and `getProperty('ratingPercent')` inside the hook to
  get current values. For a readout that must change every frame (combo, health, NPS)
  rewrite the text from `onUpdatePost` instead.

`onRecalculateRating` is the other half: it runs **before** the rating is calculated, so
returning `Function_Stop` keeps whatever you set with `setRatingPercent` /
`setRatingName` / `setRatingFC`, which is how mods show a custom rank on the results
screen.

```lua
function onRecalculateRating()
    setRatingPercent(1.0)   -- a 0..1 fraction, shown as 100%
    setRatingName('SSS')
    setRatingFC('Marvelous!!')
    return Function_Stop
end
```

`Function_Stop` here stops the hook for the remaining scripts and suppresses the engine's
own calculation; omit it and the engine overwrites your values a moment later.

## Tweens, timers, sound

| Hook | Arguments |
|---|---|
| `onTweenCompleted(tag)` | a tween you started finished |
| `onTimerCompleted(tag, loops, loopsLeft)` | a timer loop finished |
| `onSoundFinished(tag)` | a sound you started finished |

## Modcharts

`modCallback(beat, name)` and `modRepeater(beat, length, name)` call any function
defined in your script by name, so no fixed hook is required:

```lua
function onCreatePost()
    addModifier('drunk')
    modEase('drunk', 8, 4, 0.5, 'quadOut')
    modRepeater(16, 4, 'onPulse')
end

function onPulse(beat)
    -- Callbacks receive the beat they fired on: schedule from it.
    modEase('bounce', beat, 2, 0.5, 'quadOut')
end
```

Modifiers only run once a script adds them, so charts and mods that ignore the
API keep vanilla arrows. The full function and percent list lives in
[MODCHART.md](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/blob/main/docs/MODCHART.md).

You do not have to write these calls by hand: **Editors → Modchart Lab** (the
`debug_1` key from the main menu) lets you drag percents over a looping section
while the arrows react, then copies the matching `modSet`/`modEase` calls as Lua
or Python. See
[MODCHART.md § Modchart lab](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/blob/main/docs/MODCHART.md#modchart-lab).

## Custom substates

Scripts can open their own substate with `openCustomSubstate(name, pauseGame)`.
That helper now also loads `data/states/<name>.hx` if present, and works outside
`PlayState`. Full-screen replacements use `switchCustomState(name, data)` /
`openModSubState(name, data)` — see [Scripted states](./scripted-states.md).

| Hook |
|---|
| `onCustomSubstateCreate(name)` / `onCustomSubstateCreatePost(name)` |
| `onCustomSubstateUpdate(name, elapsed)` / `onCustomSubstateUpdatePost(name, elapsed)` |
| `onCustomSubstateDestroy(name)` |

## Full engine list

These are the hook names `PlayState` and its helpers broadcast:

```text
onCreate            onCreatePost        onDestroy           onUpdate            onUpdatePost
onStartCountdown    onCountdownStarted  onCountdownTick     onSongStart
onStepHit           onBeatHit           onSectionHit        onEndSong
onSpawnNote         goodNoteHit         opponentNoteHit     goodNoteSkip        opponentNoteSkip
noteMiss            noteMissPress       onGhostTap          onKeyPress          onKeyRelease
onEvent             eventEarlyTrigger   onPause             onResume
onResumeCountdownStart  onResumeCountdownTick
onGameOver          onGameOverStart     onGameOverConfirm   onNextDialogue      onSkipDialogue
onMoveCamera        onRecalculateRating onUpdateScore       onSoundFinished
onTweenCompleted    onTimerCompleted    onCustomSubstateCreate      onCustomSubstateCreatePost
onCustomSubstateUpdate  onCustomSubstateUpdatePost  onCustomSubstateDestroy
```

:::tip[Keep it cheap]

`onUpdate` and `onUpdatePost` run every frame for *every* loaded script. Move work into
beat hooks, timers or event handlers whenever the timing allows.

:::
