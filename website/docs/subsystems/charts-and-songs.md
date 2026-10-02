---
title: Charts & songs
sidebar_position: 2
description: The SwagSong/SwagSection chart format, loading, migration, events and weeks.
---

# Charts & songs

## Where a song lives

```text
assets/preload/data/<song>/<song>-<difficulty>.json   # chart
assets/preload/data/<song>/events.json                # standalone events (optional)
assets/songs/<song>/Inst.ogg                          # instrumental
assets/songs/<song>/Voices.ogg                        # vocals (if needsVoices)
assets/preload/weeks/<week>.json                      # week definition
```

Mods mirror this under `mods/<mod>/data/<song>/`, `mods/<mod>/songs/<song>/` and
`mods/<mod>/weeks/`. Lookup order is handled by [`Paths`](../architecture/assets-and-paths.md).

## The chart format

`data.Song.SwagSong` is the root object:

| Field | Type | Meaning |
|---|---|---|
| `song` | `String` | display name |
| `notes` | `Array<SwagSection>` | the sections |
| `events` | `Array<Dynamic>` | chart events |
| `bpm` | `Float` | starting BPM |
| `speed` | `Float` | scroll speed |
| `needsVoices` | `Bool` | whether `Voices.ogg` is loaded |
| `player1` / `player2` / `gfVersion` | `String` | boyfriend / opponent / girlfriend character ids |
| `stage` | `String` | stage id |
| `arrowSkin` / `splashSkin` | `String` | note and splash skins |
| `gameOverChar`, `gameOverSound`, `gameOverLoop`, `gameOverEnd` | `String` *(optional)* | game-over overrides |
| `disableNoteRGB` | `Bool` *(optional)* | turn off the note colour shader |
| `songCredit`, `songCreditBarPath`, `songCreditIcon` | `String` | the built-in song credits feature |
| `windowName` | `String` | window title override while the song plays |
| `specialAudioName`, `specialEventsName` | `String` | alternate audio/event file names |
| `event7`, `event7Value` | `String` | legacy JS Engine event slot |

### Sections

`data.Section.SwagSection`:

| Field | Type | Meaning |
|---|---|---|
| `sectionNotes` | `Array<Dynamic>` | `[strumTime, noteData, sustainLength, noteType]` tuples |
| `sectionBeats` | `Float` | length in beats (default 4) |
| `mustHitSection` | `Bool` | camera and lane ownership |
| `gfSection` | `Bool` | girlfriend sings this section |
| `altAnim` | `Bool` | use `-alt` animations |
| `changeBPM` + `bpm` | `Bool`, `Float` | BPM change at this section |
| `crossFade` | `Bool` | trigger the crossfade effect |
| `typeOfSection` | `Int` | legacy field |

A note entry is an array, not an object — index 0 is the strum time in ms, 1 is the lane
(0–3 player, 4–7 opponent in the raw chart), 2 the sustain length in ms, and 3 the
notetype name when present.

## Loading and migration

`data.Song.loadFromJson(...)` reads the chart through `Paths` (BOM-stripped) and runs
`onLoadJson()`, which upgrades older formats in place:

- generates an empty `events` array and extracts inline event notes from `sectionNotes`
  when a chart predates the events system,
- normalises missing fields to defaults,
- handles **Psych 1.0 charts** (`Song.psychV1Chart`), including the different note and
  event layout.

Stage resolution falls back through `StageData.vanillaSongStage(songName)`, a central
mapping of base-game songs to their stage, so charts with no `stage` field still work.

`Conductor.mapBPMChanges(song)` is called once after load to build the BPM map used by
every later time conversion.

## Events

Events live either in the chart's `events` array or in a separate `events.json`
(`Paths.songEvents(song, difficulty)`). Each entry is
`[strumTime, [[name, value1, value2], ...]]`.

Built-in events handled by `play.helpers.PlayStateEvents`:

| Event | What it does |
|---|---|
| `Hey!` | bf/gf cheer animation |
| `Set GF Speed` | girlfriend dance rate |
| `Add Camera Zoom`, `Camera Bopping`, `Enable/Disable Camera Bop` | camera bop control |
| `Tween Camera Zoom`, `Camera Twist`, `Camera Follow Pos` | camera movement |
| `Change Character` | swap bf/dad/gf mid-song |
| `Play Animation`, `Alt Idle Animation` | force or alter animations |
| `Change Scroll Speed`, `Change Note Multiplier` | note speed |
| `Change Song Name`, `Fake Song Length` | HUD text and time bar |
| `Screen Shake` | camera shake |
| `Kill Henchmen` | week 7 tankmen |
| `Enable/Disable Bot Energy`, `Set Bot Energy Speeds` | the A-Bot speaker |
| `Credits Popup`, `Popup` | on-screen popups |
| `Rainbow Eyesore` | shader effect |
| `Set Property` | set any field reflectively |
| `Windows Notification` | desktop notification |
| `VS Nonsense V2`, `Leather Engine` | compatibility shims |

Anything else is forwarded to scripts as `onEvent(name, value1, value2)`, and a matching
`mods/<mod>/custom_events/<name>.lua` / `.py` is auto-loaded — see
[Custom events & notetypes](../modding/custom-events-and-notetypes.md).

Scripts also receive `eventEarlyTrigger(name)` so they can ask for an event to fire early
(useful for effects that need lead-in time).

## Weeks

`backend.WeekData` loads `weeks/<week>.json`: song list, difficulties, week characters,
week name/image, hidden/locked flags and the asset folder. `StoryMenuState` renders them;
`FreeplayState` flattens every week's songs into one list. Mods add weeks by dropping JSON
into `mods/<mod>/weeks/`.

## Difficulties

Difficulty names come from the week data (default `Easy`, `Normal`, `Hard`) and map to the
chart suffix: `<song>-hard.json`, with the default difficulty using no suffix. Highscores
are stored per song **and** difficulty.

## Editing charts

`editors.ChartingState` is the in-game chart editor (split into `editors/charting/*` for
grid, sections, waveform, selection, save/load and events). It writes the same JSON format
and keeps multiple backups — see [Editors](./editors.md).
