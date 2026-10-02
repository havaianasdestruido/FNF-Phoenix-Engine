---
title: Overview
sidebar_position: 1
description: The two kinds of modding, what each can do, and where to start.
---

# Modding overview

Phoenix Engine is built around two ways of modding, and tries to make both pleasant:

| | **Softmodding** | **Hardmodding** |
|---|---|---|
| What | a folder in `mods/` | a fork of the engine |
| Language | Lua / Luau, Python, HScript, JSON | Haxe |
| Needs a compiler | no | yes |
| Can replace assets | yes | yes |
| Can change engine behaviour | through the scripting API | anything |
| Distribution | zip the folder | ship a build |

Most mods only need softmodding. The scripting API exposes **233 Lua functions** and
**128 Python functions**, plus reflective `getProperty`/`setProperty` access to almost any
field in the engine.

## Compatibility

Phoenix keeps the Psych Engine / JS Engine mod contract, so existing mods generally load
unchanged: the same folder layout, the same callback names, the same chart format
(including Psych 1.0 charts). Phoenix additions are strictly additive —
Python scripting, extra callbacks, extra events.

## What a build supports

Scripting is compile-time gated. A binary built with `-DMODDING_LEVEL=0` has no script VM
at all, and one built with `=1` has Lua but no Python:

| Build | `MODS_ALLOWED` | Lua | Python | HScript |
|---|---|---|---|---|
| Desktop (default) | ✓ | ✓ | ✓ | ✓ |
| Mobile (default) | ✓ | ✓ | ✓ | ✓ |
| `-DMODDING_LEVEL=1` | ✓ | ✓ | ✗ | ✓ |
| `-DMODDING_LEVEL=0` | ✓ | ✗ | ✗ | ✓ |
| HTML5 / Flash / AIR | ✗ | ✗ | ✗ | web only |

## Getting started

1. **Create the folder** — `mods/MyMod/` with the subfolders you need.
   See [Mod folder structure](./mod-folder-structure.md).
2. **Enable it** — add `MyMod|1` to `modsList.txt`, or toggle it in the in-game Mods menu.
3. **Add content** — charts in `data/`, audio in `songs/`, art in `images/`,
   characters in `characters/`, weeks in `weeks/`.
4. **Add behaviour** — a `.lua` or `.py` script in `scripts/` (global) or
   `data/<song>/` (per song). Start from `docs/TemplateScript.lua` /
   `docs/TemplateScript.py`.
5. **Test** — run the game, watch the on-screen debug text for script errors.

```lua
-- mods/MyMod/scripts/hello.lua
function onCreatePost()
    debugPrint('Hello from MyMod!')
end

function onBeatHit()
    if curBeat % 4 == 0 then
        cameraShake('camGame', 0.005, 0.1)
    end
end
```

```python
# mods/MyMod/scripts/hello.py
def onCreatePost():
    debugPrint('Hello from MyMod!')

def onBeatHit():
    if curBeat % 4 == 0:
        cameraShake('camGame', 0.005, 0.1)
```

## The bundled example

`mods/bf-clicker/` is a shipped example mod written in **Python**:

```text
mods/bf-clicker/
├── data/bf-clicker/bf-clicker.json         # chart (normal)
├── data/bf-clicker/bf-clicker-easy.json
├── data/bf-clicker/bf-clicker-hard.json
├── data/bf-clicker/bf-clicker.py           # the song script
├── songs/bf-clicker/Inst.ogg
└── weeks/bf-clicker-week.json
```

`example_mods/` also contains `modTemplate.zip` and a script template.

## Where to go next

| Page | Contents |
|---|---|
| [Mod folder structure](./mod-folder-structure.md) | every folder the engine looks for, `pack.json`, load order |
| [Lua scripting](./lua-scripting.md) | how scripts are loaded, globals, patterns |
| [Lua API reference](./lua-api-reference.md) | all 233 functions, generated from the engine |
| [Python scripting](./python-scripting.md) | the Hython runtime and its differences |
| [Python API reference](./python-api-reference.md) | all 128 functions |
| [HScript](./hscript.md) | running Haxe from a Lua script |
| [Script hooks](./script-hooks.md) | every callback the engine fires |
| [Custom events & notetypes](./custom-events-and-notetypes.md) | chart-driven scripting |
