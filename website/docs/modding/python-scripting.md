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
| Function count | 273 | 168 |
| Comments | `--` | `#` |

Both languages receive every hook listed in [Script hooks](./script-hooks.md);
missing hooks silently never fire, so parity is load-bearing. Python callbacks
are dispatched through the same `PlayState.callOnScripts` path as Lua (#87).

The Python library covers sprites, text, cameras, characters, properties, sound, score,
timers, tweens, inter-script calls, Discord and window effects. Where a Lua function has no Python twin
yet it is explicitly unsupported — use Lua for that part, or add the twin in
`psychlua/pystdlib/` and send a PR
([how](../subsystems/scripting-runtime.md#adding-a-callback)). Intentionally unsupported
areas remain file I/O / shader / effect helpers, which are documented as Lua-only in
the [Python API reference](./python-api-reference.md).

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

## Debug output

```python
debugPrint('health is', getProperty('health'))
```

Output goes to the on-screen `pythonDebugGroup`, the Python counterpart of the Lua debug
text. Errors are caught per call — a raised exception prints and the song keeps playing.

## Performance

Hython is an interpreter written in Haxe; it is slower than LuaJIT. For per-frame work in
a demanding chart, prefer Lua. For setup, event reactions and beat-synced logic, the
difference is irrelevant.

## Next

- [Python API reference](./python-api-reference.md) — all 168 functions (generated).
- [Transparent window](./transparent-window.md) — make the game window see-through.
- [Script hooks](./script-hooks.md) — the callbacks, shared with Lua.
