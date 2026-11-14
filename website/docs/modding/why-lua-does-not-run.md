---
title: Why is my Lua script not running?
sidebar_position: 12
description: The ordered list of gates a .lua mod script must pass, what the engine prints at each one, and how to turn on the step-by-step log.
---

# Why is my Lua script not running?

A `.lua` script that never runs has no effect in game. The causes are few, and
they happen in a fixed order. The engine reports the ones it can see in lines
that start with `[LuaDiag]`, so ask it first, then check the list in order.

The repository keeps runnable versions of this list in
`tests/haxe/run-lua-diagnostics.sh` and `tests/haxe/run-lua-discovery.sh`; see
[`docs/LUA_SCRIPT_DEBUGGING.md`](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/blob/main/docs/LUA_SCRIPT_DEBUGGING.md)
for the long form with source references and sample output.

## Ask the engine first

Start the game from a terminal and play the song. On Windows, run the `.exe`
from `cmd` or PowerShell: the game has no console window of its own, but it
writes to the one it was started from. On Android, use `adb logcat -s trace`.

Problems are reported without any setting. Each line names the file and the
reason:

| Line starts with | Meaning | Step |
|---|---|---|
| `[LuaDiag] This build does NOT include the Lua VM` | The game was built without Lua. No script can run. | 1 |
| `[LuaDiag] ERROR: N Lua scripts found, but this build cannot run Lua` | The same, per song, with the list of scripts. Also shown on screen. | 1 |
| `[LuaDiag] WARNING: … looks like a Lua script but is not loaded` | The file name does not end in exactly `.lua` | 2 |
| `[LuaDiag] WARNING: … is not the folder this song reads` | The song folder has another spelling | 3 |
| `[LuaDiag] ERROR: … was blocked by ModSecurity before it ran` | The security scan refused the file; the line gives the `pack.json` entry | 4 |
| `[LuaDiag] ERROR: … did not load: … (syntax error)` or `(runtime error)` | The file failed while loading; the source line follows | 5 |
| `[LuaDiag] ERROR: hook … failed` | A hook raised an error; each distinct error is printed once | 6 |

If none of them names your script, turn on **verbose mode**. It prints every
folder that is searched, what happens to every file in it, each stage of
loading a script, the hooks the script defines and the first time each hook
runs. Any one of these switches it on:

* **Options → Misc → Verbose Lua Logging**
* `verboseLua = true` under `[scripts]` in `flags.ini`, next to the executable
* the environment variable `PHOENIX_LUA_VERBOSE=1`
* a build made with `-DLUA_VERBOSE`

In verbose mode the warnings and errors are also shown on screen.

## 1. Is Lua compiled in?

Every `psychlua/*.hx` file is behind `#if LUA_ALLOWED`. A build without that
define contains no Lua VM.

:::caution[A plain desktop build has no Lua]

`lime test windows`, `lime test linux` and `lime test mac` build **without** Lua
and Python today: the default only applies when Lime's `cpp` target flag is set.
Add `-DMODDING_LEVEL=1` (Lua) or `-DMODDING_LEVEL=2` (Lua and Python) to include
them — that is exactly what CI does, so the Windows and release artifacts do run
Lua scripts. Mobile builds cannot include Lua yet, so CI builds Android at level
`0`. The artifact name tells them apart (`…_LUA_PYTHON_HSCRIPT` versus
`…_HSCRIPT`), and so does the run title.

:::

The build output says which one was made:

```text
[INFO] Script support: Lua OFF, Python OFF, HScript ON (Lua: default for this target)
[WARN] Lua scripts (.lua) will NOT run in this build: LUA_ALLOWED is off.
```

So does the game. A build without Lua prints
`[LuaDiag] This build does NOT include the Lua VM (LUA_ALLOWED is off): .lua scripts cannot run.`
when it starts, and shows a notice on screen in the first song that has `.lua`
files. HScript (`.hx`) scripts run in every build.

## 2. Is the script where the engine looks?

| Scope | Folders |
|---|---|
| Global | `mods/scripts/`, `assets/scripts/` |
| Global, per mod | `mods/<mod>/scripts/` — while that mod is current, and for every song when `pack.json` sets `"runsGlobally": true` |
| Song | `mods/data/<song>/`, `mods/<mod>/data/<song>/` |
| Stage | `stages/<stage>.lua` |
| Character | `characters/<name>.lua` |
| Note type / event | `custom_notetypes/<type>.lua`, `custom_events/<event>.lua` |

Only the top level of each folder is scanned — a script in a subfolder is never
found. Enabling a mod in `modsList.txt` does **not** make its `scripts/` folder
global: it is read while that mod is the current mod, plus on every song if the
mod declares `"runsGlobally": true`.

After two unclean exits in a row (a crash or a forced close) the game starts on
the **Safe Mode** screen, with "Start with all mods disabled" ticked. A session
started that way reads nothing from `mods/`, so no mod script runs until you
restart the game.

The file name must end in exactly `.lua`, in lower case. `Script.LUA` and
`script.lua.txt` (which Windows shows as `script.lua` while file extensions are
hidden) are skipped, and the engine prints a warning for them.

When two folders hold a script with the same file name, only the first one
found is loaded. Verbose mode lists the folders in the order they are searched.

## 3. Does the folder name match the chart?

The song folder is `mods/data/<formatToSongPath(chart.song)>/`, where the chart's
own `song` field is used. Spaces become `-`, and a few characters are replaced or
dropped. `"song": "Transparency Test"` means `mods/data/transparency-test/`.

The engine warns when it finds `.lua` files in a folder that is the same name
under another spelling, such as `Transparency Test` or `transparency_test`.

## 4. Did the security scan reject it?

Before a Lua state is created, the source is scanned. Any finding means the
script is never loaded. The most common false positives are on executable lines
that merely mention a blocked name, for example a `debugPrint('http://…')` (rule
`network.url`) or a call inside a string. The `[LuaDiag] ERROR` line names the
rule, the line number and the `scriptSandboxAllowlist` entry that allows it. See
the [script security sandbox](./script-security.md) page for the rule list.

If you trust the mod and only want to play it, you do not have to edit it: the
[switch in the Mods menu](./script-security.md#per-mod-switch-in-the-mods-menu)
turns the scan off for that one mod.

A script saved as UTF-16 is also rejected here (rule `security.binary-source`).
Save it as UTF-8.

## 5. Does it fail on the first line that runs?

The whole file is executed once, at load time, after the engine globals are
registered. A syntax error or a call to a function that does not exist at that
moment stops the script, and the state is closed. The `[LuaDiag] ERROR` line
says which of the two happened and prints the source line it points at.

## 6. Is the hook actually fired?

Declaring `function onBeatHit()` does nothing unless the engine calls that name.
`song-hooks.md`/`script-hooks.md` lists what is dispatched; hooks outside that
list never run.

Hook names are case-sensitive: `function oncreate()` is never called. Verbose
mode lists the hooks each script defines and points out a function name that is
one letter or one capital away from a real hook.

Not every hook starts with `on`. The note hooks are `goodNoteHit`,
`opponentNoteHit`, `noteMiss` and `noteMissPress`, so `function onGoodNoteHit()`
is never called either.

A hook that raises an error is skipped for that call and the song continues. In
game the error is only shown when the script sets `luaDebugMode = true`. The
console gets the first occurrence of each distinct error, and the total when
the song ends.

## Turning on the durable log

`[LuaDiag]` lines, load errors and `debugPrint` all reach the console. The session
log file is only written when **Options → Misc → Enable VLog** is on (it writes
`vlog/log.txt`). With it enabled, look for:

* `[LuaDiag] …` — the lines described above (tag `LUA`)
* `[ModSecurity] BLOCKED …` — the scan stopped the script (step 4)
* `failed to initialise Lua sandbox: …` — the sandbox itself failed
* `Error on lua script! …` — load-time failure (step 5)
* `ERROR (<hook>): …` — a hook raised while running

If there is no line mentioning your script at all, it was never discovered — go
back to step 2, with verbose mode on.
