---
title: Custom events & notetypes
sidebar_position: 60
description: Chart-driven scripting — defining your own event notes and note types.
---

# Custom events & notetypes

Both features work the same way: the chart names something, and the engine automatically
loads a matching script file from the mod.

## Custom events

### 1. Add the event in the chart editor

Place an event note and type a name the engine does not already handle (the built-in list
is on the [Charts & songs](../subsystems/charts-and-songs.md#events) page), plus up to two
string values.

### 2. Create the script

```text
mods/MyMod/custom_events/My Cool Event.lua
```

The file name must match the event name exactly. It is loaded automatically when the chart
contains that event.

```lua
-- mods/MyMod/custom_events/My Cool Event.lua
function onEvent(name, value1, value2)
    if name == 'My Cool Event' then
        cameraFlash('camGame', value2, tonumber(value1))
    end
end

function eventEarlyTrigger(name)
    if name == 'My Cool Event' then
        return 150   -- fire 150 ms early
    end
end
```

Python works identically with `custom_events/My Cool Event.py`.

:::note

`onEvent` fires for **every** event in the song, not only yours — always check `name`.
Events triggered from a script with `triggerEvent()` do **not** call `onEvent`.

:::

### More event examples

**Read both values as numbers.** Values always arrive as strings, so convert defensively:

```lua
-- mods/MyMod/custom_events/Strobe Burst.lua
local function num(value, fallback)
    local parsed = tonumber(value)
    if parsed == nil then return fallback end
    return parsed
end

function onEvent(name, value1, value2)
    if name ~= 'Strobe Burst' then return end

    local times = math.floor(num(value1, 4))     -- how many flashes
    local duration = num(value2, 0.08)           -- seconds per flash

    for i = 1, times do
        runTimer('strobe' .. i, duration * (i * 2 - 1), 1)
    end
end

function onTimerCompleted(tag, loops, loopsLeft)
    if tag:sub(1, 6) == 'strobe' then
        cameraFlash('camGame', 'ffffff', 0.05, true)
    end
end
```

**Toggle something that already exists** — create the sprite once, flip it per event:

```lua
-- mods/MyMod/custom_events/Spotlight Toggle.lua
function onCreatePost()
    makeLuaSprite('eventSpot', 'stages/spotlight', 0, -100)
    setBlendMode('eventSpot', 'add')
    setProperty('eventSpot.alpha', 0)
    setObjectCamera('eventSpot', 'camGame')
    addLuaSprite('eventSpot', false)
end

function onEvent(name, value1, value2)
    if name == 'Spotlight Toggle' then
        doTweenAlpha('spotFade', 'eventSpot', tonumber(value1) or 1, 0.4, 'quadOut')
    elseif name == 'Spotlight Colour' then
        setProperty('eventSpot.color', getColorFromHex(value1))
    end
end
```

**Fire an engine event from a script.** `triggerEvent` runs the engine's own handler for
the named event — it does **not** broadcast `onEvent`:

```lua
function onBeatHit()
    if curBeat == 64 then
        triggerEvent('Hey!', 'bf', '0.6', getSongPosition())
        triggerEvent('Change Character', 'dad', 'pico-nightmare', getSongPosition())
    end
end
```

### The event JSON, if you are authoring it by hand

Charts and `events.json` share one shape: a list of `[strumTime, [ [name, value1, value2] ]]`
entries, where several events may share a timestamp.

```json
{
  "song": {
    "events": [
      [ 20210.5, [ ["Spotlight Toggle", "1", ""] ] ],
      [ 25184.2, [ ["Spotlight Colour", "ff5599", ""], ["Hey!", "bf", "0.6"] ] ]
    ]
  }
}
```

## Custom notetypes

### 1. Set the notetype in the chart

Select a note in the chart editor and set its type to a name of your choosing, for example
`Hurt Note Plus`. The value is stored as index 3 of the note entry in `sectionNotes`.

### 2. Create the script

```text
mods/MyMod/custom_notetypes/Hurt Note Plus.lua
```

Loaded automatically when the chart contains at least one note of that type. `onSpawnNote`'s
`id` indexes the `notes` group (`sustainNotes` for hold notes), so target that group —
not `unspawnNotes`:

```lua
function onSpawnNote(id, noteData, noteType, isSustainNote, strumTime)
    local group = isSustainNote and 'sustainNotes' or 'notes'
    if noteType == 'Hurt Note Plus' then
        setPropertyFromGroup(group, id, 'texture', 'HURTNOTE_assets')
        setPropertyFromGroup(group, id, 'hitHealth', 0)
        setPropertyFromGroup(group, id, 'missHealth', 0.5)
        setPropertyFromGroup(group, id, 'hitCausesMiss', true)
    end
end

function goodNoteHit(id, direction, noteType, isSustainNote)
    if noteType == 'Hurt Note Plus' then
        setProperty('health', getProperty('health') - 0.3)
    end
end
```

### Notetype recipes

**A note that only plays a sound.** No property changes at all, so the note looks and
scores like a normal one:

```lua
-- mods/MyMod/custom_notetypes/Clap Note.lua
local NOTE_TYPE = 'Clap Note'   -- must match this file's name

function goodNoteHit(id, direction, noteType, isSustainNote)
    if noteType ~= NOTE_TYPE or isSustainNote then return end
    playSound('clap', 0.8)
end
```

**A hold note that drains health while you keep it.** Sustain notes fire `goodNoteHit` on
every hold tick, so gate on `isSustainNote`:

```lua
local NOTE_TYPE = 'Drain Note'
local DRAIN_PER_TICK = 0.004

function onSpawnNote(id, noteData, noteType, isSustainNote, strumTime)
    if noteType ~= NOTE_TYPE then return end
    local group = isSustainNote and 'sustainNotes' or 'notes'
    setPropertyFromGroup(group, id, 'texture', 'DRAINNOTE_assets')
end

function goodNoteHit(id, direction, noteType, isSustainNote)
    if noteType ~= NOTE_TYPE or not isSustainNote then return end
    setProperty('health', getProperty('health') - DRAIN_PER_TICK)
end
```

**A free hit that does not touch the score.** `ignoreNote` keeps it out of accuracy and
`noAnimation` stops the character from singing:

```lua
local NOTE_TYPE = 'Air Note'

function onSpawnNote(id, noteData, noteType, isSustainNote, strumTime)
    if noteType ~= NOTE_TYPE then return end
    local group = isSustainNote and 'sustainNotes' or 'notes'
    setPropertyFromGroup(group, id, 'ignoreNote', true)
    setPropertyFromGroup(group, id, 'noAnimation', true)
    setPropertyFromGroup(group, id, 'multAlpha', 0.6)
end
```

**A note that changes which character sings.** `gfNote` routes the lane to the girlfriend,
and `animSuffix` appends to the sing animation name:

```lua
local NOTE_TYPE = 'GF Ballad'

function onSpawnNote(id, noteData, noteType, isSustainNote, strumTime)
    if noteType ~= NOTE_TYPE then return end
    local group = isSustainNote and 'sustainNotes' or 'notes'
    setPropertyFromGroup(group, id, 'gfNote', true)
    setPropertyFromGroup(group, id, 'animSuffix', '-alt')
end
```

**Reacting to a miss instead of a hit.** `noteMiss` receives the same arguments, so the
same four-line handler works:

```lua
local NOTE_TYPE = 'Bomb Note'

function noteMiss(id, direction, noteType, isSustainNote)
    if noteType ~= NOTE_TYPE then return end
    cameraShake('camGame', 0.03, 0.4)
    setProperty('health', 0.2)     -- survive the punishment
end
```

### Chart JSON for a notetype

Hand-authoring a chart means writing the type as the **fourth** element of a note:

```json
{
  "sectionNotes": [
    [ 1200.0, 0, 0, "Clap Note" ],
    [ 1500.0, 2, 350, "Drain Note" ]
  ],
  "sectionBeats": 4,
  "mustHitSection": true
}
```

`[strumTime, lane, sustainLength, type]`: `lane` is `0–3` for the player's side or `4–7` for
the opponent's, and a numeric type index from older charts is resolved through
`ChartingState.noteTypeList` when the chart loads.

### Note fields worth knowing

| Field | Meaning |
|---|---|
| `texture` | note graphic override |
| `noteskin` | per-note skin |
| `hitHealth` / `missHealth` | health change on hit / miss |
| `hitCausesMiss` | hitting it counts as a miss (hurt notes) |
| `noAnimation` / `noMissAnimation` | suppress the sing / miss animation |
| `gfNote` | girlfriend sings this note |
| `ignoreNote` | not counted for score or accuracy |
| `blockHit` | cannot be hit at all |
| `lowPriority` | deprioritised when several notes overlap |
| `multSpeed` / `multAlpha` | per-note speed and transparency multipliers |
| `animSuffix` | suffix appended to the sing animation |

The complete list is on the [`objects.Note`](../reference/objects/Note.md) reference page.

Engine-side configuration for shipped notetypes lives in `backend.NoteTypesConfig`.

If a script swaps in a note atlas the mod does not ship, Phoenix keeps the note's
current skin instead of blanking it (the missing atlas is logged once). Missing
sound files are a silent no-op. `onSpawnNote` fires for every spawned note,
including objects recycled out of the note pool, after the chart's per-note flags
have been re-applied.

### Ready-made notetypes

`example_mods/custom_notetypes/` ships ready-to-use ports of the Mario Madness custom note
types as Lua scripts — poison, bad poison, bomb, coin, ring, water, boo, bullet, bullet bill,
jumpscare and invisible notes — with credits in each header and a readme that explains the
skins you need to supply. The scripts call no file-read callbacks, so they run under the
default mod sandbox. Copy what you need into your mod's `custom_notetypes/` folder and chart
with the matching name.

## Patterns

**Shared helper for several events** — put the logic in `scripts/` (global) and keep the
`custom_events/` file as a thin trigger, or call across scripts with
`callScript('scripts/helper.lua', 'doThing', {value1})`.

**Visual-only events** — create your sprites in `onCreatePost` and only toggle them in
`onEvent`, so the event handler stays cheap.

**Early triggering** — anything with an audible attack (a sound effect, a zoom that must
land on a beat) should use `eventEarlyTrigger` rather than being placed early in the
chart; the chart stays readable and the offset stays explicit.

## Testing

1. Enable the mod in `modsList.txt` or the Mods menu.
2. Open the song in the chart editor and place the event / notetype.
3. Play it. Script errors appear on-screen through the debug text.
4. `debugPrint(...)` is your friend — it prints into the same overlay.
