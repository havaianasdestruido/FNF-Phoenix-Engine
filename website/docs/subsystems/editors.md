---
title: Editors
sidebar_position: 6
description: The in-game authoring tools — chart, character, stage, dialogue, week, menu character and note splash editors.
---

# Editors

Phoenix ships the Psych-style authoring tools, reachable from
`editors.MasterEditorMenu` (main menu) and, for the chart editor, from the pause menu.

| Editor | Module | Edits |
|---|---|---|
| Chart editor | `editors.ChartingState` | `data/<song>/<song>-<diff>.json` |
| Character editor | `editors.CharacterEditorState` | `characters/<id>.json` |
| Stage editor | `editors.StageEditorState` | `stages/<id>.json` |
| Dialogue editor | `editors.DialogueEditorState` | dialogue JSON |
| Dialogue character editor | `editors.DialogueCharacterEditorState` | dialogue portraits |
| Week editor | `editors.WeekEditorState` | `weeks/<week>.json` |
| Menu character editor | `editors.MenuCharacterEditorState` | story-menu characters |
| Note splash debugger | `editors.NoteSplashDebugState` | splash skins and configs |
| Music editor | `editors.EditingMusic` | menu music tooling |
| Editor playtest | `editors.EditorPlayState` | plays a chart section without leaving the editor |

Helpers live in `editors/helpers/` (`CharacterEditorHelpers`, `StageEditorHelpers`,
`DialogueEditorHelpers`, `EditorPlayStateHelpers`, `WeekEditorHelpers`). The stage
editor's Flixel-free rules live in `data.StageEditorCore` and
`data.StageUndoStack`; gameplay spawns the saved `objects` graph through
`play.helpers.PlayStateStageObjects`. Walkthrough: `docs/STAGE_EDITOR.md`.

## Chart editor

`ChartingState` was cut from 4821 to 2367 lines by extracting `editors/charting/`:

| Module | Responsibility |
|---|---|
| `ChartingUIGrid` | the note grid, snapping, zoom and layer caching |
| `ChartingUISections` | section properties (must-hit, gf, alt, BPM change, crossfade) |
| `ChartingUIWaveform` | the audio waveform display and its buffer cache |
| `ChartingEvents` | the event list and event editing |
| `ChartingSaveLoad` | load, save, autosave and the backup chain |
| `SelectionNote` | the selection box and multi-note operations |
| `AttachedFlxText` | labels attached to grid objects |

Features that matter when working on it:

- **Multiple chart backups** — saves rotate through backup files rather than overwriting,
  and `Paths.getBackupFilePath(songPath, diff)` resolves them.
- **Song credits** — the chart's `songCredit`, `songCreditIcon` and `songCreditBarPath`
  fields are editable here.
- **Cached grid layers and waveform buffers**, and a deduplicated undo stack — these were
  explicit performance fixes; re-creating the grid every frame will regress them.
- **Editor playtest** (`EditorPlayState`) runs a real `PlayState`-like session from the
  cursor position, including playback rate.

## Character editor

Loads a `CharacterFile`, lets you add animations (prefix or indices), set per-animation
offsets, position, camera offset, scale, flip, antialiasing, health icon and bar colours,
then writes the JSON back. `Character.debugMode` disables gameplay behaviour so the
editor can drive animations directly.

## Stage editor

Loads a `StageFile`, lets you place BF/GF/Dad, set camera zoom/offsets, and build
a Psych 1.0 object graph (`sprite`, `animatedSprite`, `square`, plus character
slot markers for z-order). Props support parallax, scale, color, quality and
story/freeplay filters, and beat-synced `danceEvery`. **Save** exports a JSON
file; **Save to Mod** writes `mods/<mod>/stages/<id>.json`; **Copy JSON** puts
the same text on the clipboard. Snap-to-grid (G) and a scrolling sprite list
help with large stages. Ctrl+Z/Y undo, unsaved-exit warning, Week 1 template.
Named props are registered for Lua/Python/HScript.

## Week editor

Builds `weeks/<week>.json`: the song list, difficulties, week name and image, the three
story-menu characters, lock/hide flags and the asset directory.

## File handling

- Desktop and Android use native dialogs through `hxnativefiledialog`; mobile goes through
  `mobile.files.MobileFilePicker`.
- Drag-and-drop import is behind `FEATURE_FILE_DROP` (disabled on macOS, Flash and AIR).
- Everything is written as JSON through the same models gameplay uses, so a file saved by
  an editor always loads back.

## Working on an editor

- The editors use `flixel-ui`, with engine overrides in `source/source-haxelib-patches/flixel/addons/ui/` and
  `objects.FlxUIDropDownMenuCustom`.
- Keep heavy logic in `editors/helpers/` or `editors/charting/`; the state classes are
  already as large as they should get.
- Editors must tolerate missing or malformed assets — they are the tools people use to
  *fix* broken content.
