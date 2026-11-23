---
title: Mod folder structure
sidebar_position: 2
description: Every folder the engine recognises inside a mod, plus pack.json, modsList.txt and load order.
---

# Mod folder structure

A mod is a folder inside `mods/`. Nothing is registered or compiled — the engine
discovers folders at startup and resolves assets through them.

```text
mods/
├── modsList.txt is in the game root, not here
└── MyMod/
    ├── pack.json              # metadata (optional but recommended)
    ├── data/                  # charts, song JSON, per-song scripts, scripted states
    │   ├── states/            # <StateName>.hx overlay or ModState replacement
    │   │   └── FreeplayState.hx
    │   └── mySong/
    │       ├── mySong.json
    │       ├── mySong-hard.json
    │       ├── events.json
    │       └── mySong.lua
    ├── songs/                 # audio
    │   └── mySong/
    │       ├── Inst.ogg
    │       └── Voices.ogg
    ├── weeks/                 # week definitions
    │   └── myWeek.json
    ├── characters/            # character JSON
    │   └── my-char.json
    ├── stages/                # stage JSON + stage scripts
    │   ├── myStage.json
    │   └── myStage.lua
    ├── images/                # PNG + XML/TXT/JSON atlas data
    ├── sounds/                # SFX
    ├── music/                 # music tracks (menu overrides included)
    ├── videos/                # cutscenes
    ├── fonts/                 # TTF/OTF
    ├── shaders/               # .frag / .vert for runtime shaders
    ├── scripts/               # global scripts (always loaded in gameplay)
    ├── custom_events/         # <eventName>.lua / .py / .hx / .hscript
    ├── custom_notetypes/      # <noteType>.lua / .py / .hx / .hscript
    └── achievements/          # custom achievements
```

Those folder names are exactly the list in `Mods.ignoreModFolders` — they are *content*
folders, so the mods manager never treats them as nested mods.

## The smallest working mod

Four files are enough for a song with a script. Everything else in the tree above is
optional:

```text
mods/HelloMod/
├── pack.json
├── data/hello/hello.json          # the chart
├── songs/hello/Inst.ogg           # the instrumental
└── scripts/hello.lua              # runs on every song
```

`mods/HelloMod/pack.json`:

```json
{
  "name": "Hello Mod",
  "description": "One song with one script.",
  "color": [255, 128, 0],
  "runsGlobally": false
}
```

`mods/HelloMod/weeks/hello-week.json` — only needed to list the song in Story Mode:

```json
{
  "songs": [["hello", "bf", [146, 113, 253]]],
  "weekCharacters": ["", "bf", ""],
  "weekBackground": "stage",
  "storyName": "Hello",
  "weekName": "Hello",
  "hideStoryMode": false,
  "hideFreeplay": false,
  "startUnlocked": true
}
```

The chart itself is a single `song` object; the parts a softmod actually edits are the
metadata block and `notes`:

```json
{
  "song": {
    "song": "Hello",
    "bpm": 150,
    "speed": 2.0,
    "player1": "bf",
    "player2": "dad",
    "gfVersion": "gf",
    "stage": "stage",
    "needsVoices": false,
    "validScore": true,
    "notes": [
      {
        "sectionNotes": [
          [1200.0, 0, 0],
          [1350.0, 1, 0],
          [1500.0, 2, 200]
        ],
        "lengthInSteps": 16,
        "mustHitSection": true,
        "typeOfSection": 0
      }
    ],
    "events": []
  }
}
```

`sectionNotes` entries are `[strumTime, lane, sustainLength]`; an optional fourth element
is the note type (see [Custom events & notetypes](./custom-events-and-notetypes.md)).

Two details bite hand-written charts:

* `lengthInSteps` is the *Psych 1.0* field. Current charts size a section with
  `sectionBeats` (4 = one bar in 4/4); the loader deletes `lengthInSteps` when it
  converts an old chart.
* A chart file either has a top-level `"song"` wrapper — the shape above — or, when it
  carries a `"format"` field, is the bare song object itself. The loader treats the
  presence of `format` as "already unwrapped".

Difficulty variants are separate files — `hello-easy.json`, `hello-hard.json` — and fall
back to `hello.json` when a difficulty is missing.

## `pack.json`

Read by `Mods.getPack(folder)`, parsed with the tolerant `tjson`:

```json
{
  "name": "My Mod",
  "description": "What it does.",
  "restart": false,
  "color": [255, 128, 0],
  "runsGlobally": false,
  "platforms": ["desktop"],
  "scriptSandbox": true,
  "scriptSandboxAllowlist": []
}
```

| Field | Effect |
|---|---|
| `name`, `description` | shown in the mods menu |
| `color` | accent colour in the list |
| `restart` | ask for a restart when toggled |
| `runsGlobally` | **important** — see below |
| `platforms` | optional build targets this mod works on (see below); **omitted, `[]` or `["all"]` = everywhere** |
| `scriptSandbox` | defaults to `true`; setting `false` gives this mod's scripts full engine privileges and prints a warning |
| `scriptSandboxAllowlist` | exact [script-security rule IDs](./script-security.md) this trusted mod is allowed to use |

Keep the sandbox enabled unless the mod is trusted and cannot use a narrower allowlist.
See [Script security sandbox](./script-security.md) for the denylist, runtime guards and
log format.

### Platform-specific mods

`platforms` uses the same tags as `backend.PlatformSupport`: target names (`windows`,
`mac`, `linux`, `android`, `ios`, `web`, `flash`, `air`), families (`desktop` = native
Windows/macOS/Linux, `mobile`, `native`, `apple`, `sys`) and capabilities
(`window-color-key`, `window-alpha`, `file-picker`, `video-render`, ...). Positive entries
are alternatives; `!tag` entries are exclusions. `all` (aliases `any`, `*`, `everywhere`)
matches every build, and is equivalent to omitting the field:

```json
{ "platforms": ["all"] }
{ "platforms": ["desktop", "!air"] }
{ "platforms": ["mobile"] }
{ "platforms": ["windows"] }
```

**No migration needed:** existing mods have no `platforms` key, and a missing key,
an empty array and `["all"]` all mean "load on every target". Only a mod that names
specific targets is filtered anywhere.

`Mods.isSupportedOnThisPlatform()` is consulted by `Mods.parseList()`, so an unsupported
mod never appears in the Mods menu, is never the active mod and never contributes global
scripts or assets. The bundled engine mods are also dropped from build artefacts on
targets they do not support, which is why the *Window Transparency Test* demo
does not ship to mobile, web, Flash or AIR.

### Global mods

A mod with `"runsGlobally": true` is collected by `Mods.pushGlobalMods()` at startup and
its assets and `scripts/` apply **even when another mod is the active one**. Use it for
things like a global HUD replacement or a universal script; use a normal mod for a song
pack.

## Enabling mods

`modsList.txt` in the game root, one entry per line:

```text
bf-clicker|1
MyMod|0
```

`1` = enabled, `0` = disabled. `Mods.parseList()` reads it and
`Mods.updateModList()` keeps it in sync with the folders actually present. The in-game
Mods menu (`states.ModsMenuState`) writes the same file, and ordering in the list is the
priority order.

## Why did my mod break?

The Mods menu answers that without a log. Each row carries a badge when something is
recorded for that mod - `!` for a break, `?` for missing assets - and the line under the
description summarises it (`No problems detected`, or
`PROBLEMS: script error, 2 blocked scripts, 1 missing asset`).

Select the mod and press the gear button (**Mod Info**) for the details: the last script
load error with its message, a `pack.json` that could not be read and why, the rule IDs
that blocked a script (see [script security](script-security.md)) and which assets are
missing, with up to two of their paths.

`backend.ModHealth` records this while the game runs, per mod folder:

| Problem | Recorded by | Meaning |
|---|---|---|
| Last load error | the Lua/Python/HScript runtimes | the file threw while loading, so none of its hooks ran |
| Invalid `pack.json` | `Mods.getPack()` | the manifest does not parse or is not a JSON object |
| Blocked script | `ModSecurity.report()` | the §6 sandbox refused the file before it ran |
| Blocked runtime call | the script runtimes | the script loaded, but a guarded engine callback was refused |
| Missing assets | `backend.Paths` | images, sounds or atlases of this mod that did not load |

Only facts are counted, and only for this session: the report does not survive a restart,
and re-importing a `.zip` into a folder drops what was recorded about the files it
replaced. The badge and the summary never repeat text written by the mod - the mod's own
paths and messages only appear inside Mod Info, flattened to one line and wrapped to the
panel - so a broken script cannot draw outside the panel.

## Resolution order

For any asset key, `Paths.modFolders(key)` checks:

1. `mods/<currentMod>/<key>` — the active mod,
2. `mods/<globalMod>/<key>` for each global mod, in list order,
3. `mods/<key>` — loose files directly in `mods/`,

and only then falls back to the engine's own `assets/` libraries. So a mod overrides a
base-game asset simply by using the same path:

```text
mods/MyMod/images/characters/BOYFRIEND.png   # replaces the default BF atlas
mods/MyMod/music/freakyMenu.ogg              # replaces the menu theme
```

`Mods.mergeAllTextsNamed(path, defaultDirectory, allowDuplicates)` merges list files
(like credits or achievement lists) across every enabled mod instead of letting one win,
and `Mods.directoriesWithFile(path, fileToFind)` finds every mod providing a given file.

## Scripts the engine loads automatically

| Path | When |
|---|---|
| `scripts/*.lua`, `*.py`, `*.hx`, `*.hscript` | every song (global scripts) |
| `data/states/<StateName>.hx` | overlay on that state/substate, or a `ModState` replacement — see [Scripted states](./scripted-states.md) |
| `data/<song>/*.lua` / `.py` / `.hx` / `.hscript` | that song |
| `stages/<stage>.lua` / `.py` / `.hx` / `.hscript` | when that stage loads |
| `characters/<name>.lua` / `.py` / `.hx` / `.hscript` | when that character is added |
| `custom_notetypes/<type>.lua` / `.py` / `.hx` / `.hscript` | when a note of that type exists in the chart |
| `custom_events/<event>.lua` / `.py` / `.hx` / `.hscript` | when that event exists in the chart |

For HScript, `<name>.hx` and `<name>.hscript` are the same logical script: in the
folder-scanned scopes the `.hx` spelling wins inside a folder, and the first folder in
priority order wins across folders.

Global scripts are deduplicated by **file name** across folders, and the first match in
priority order wins. Global mods are checked *before* the active mod, so a global mod
shadows an active-mod script of the same name — the opposite of asset lookup, where
`mods/<currentMod>/` is searched first.

## Distributing

Zip the mod folder itself (so the zip contains `MyMod/`, not its contents), and tell users
to extract into `mods/`. `example_mods/modTemplate.zip` is a ready-made skeleton.

:::warning[Custom songs must live in a mod]

Songs added to `assets/` require recompiling the game. Put custom songs — chart **and**
audio **and** week JSON — inside a mod folder, or they will not be found.

:::
