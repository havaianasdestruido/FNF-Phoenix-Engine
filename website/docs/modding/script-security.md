---
title: Script security sandbox
sidebar_position: 9
description: Default Lua/Python/HScript softmod sandbox, blocked capabilities, logs, and per-mod exceptions.
---

# Script security sandbox

Lua, Python and standalone HScript (`.hx`/`.hscript`) files under `mods/` are treated
as untrusted softmod scripts. Phoenix
checks them **before the interpreter is created or any top-level statement runs**. A
script with a blocked finding is not loaded, so none of its hooks run and none of its
code can affect the game.

The sandbox is enabled by default. Engine-owned scripts under `assets/` are not treated
as softmods.

:::warning[Defence in depth, not process isolation]

This is basic in-process hardening. It combines a source denylist with runtime guards,
but it is not an operating-system sandbox. Only install mods from authors you trust,
and treat any mod that asks you to disable the sandbox as native code.

:::

## What is blocked

The scanner reports the exact mod, script, one-based line number, rule ID and source
snippet. It ignores comment-only lines, but suspicious text on an executable line is a
finding.

| Rule ID | Examples |
|---|---|
| `lua.os` | `os.execute`, `os.remove`, or other `os.*` access |
| `lua.io` | `io.open`, `io.popen`, or other `io.*` access |
| `lua.package` | `require`, `module`, `package.*` |
| `lua.dynamic-code` | `load`, `loadstring`, `loadfile`, `dofile` |
| `lua.native` | `ffi`, `debug`, and `jit` APIs |
| `python.dangerous-import` | imports of `os`, `sys`, `io`, `pathlib`, `subprocess`, network modules, and similar libraries |
| `python.dangerous-module` | direct use of those dangerous modules |
| `python.dynamic-code` | `open`, `exec`, `eval`, `compile`, `__import__`, `input` |
| `engine.file-read` | `getTextFromFile`, `checkFileExists`, `directoryFileList` |
| `engine.file-write` | `saveFile`, `deleteFile` |
| `engine.script-loader` | `addLuaScript`, `addPythonScript`, `addScript` |
| `engine.native-class` | reflection into `Sys`, `sys.*`, `cpp.*`, `ModSecurity`, native platform classes, etc. |
| `haxe.process` | `Sys.command`, `Sys.exit`, `sys.io.Process` in HScript (standalone or embedded) |
| `haxe.filesystem` | `sys.io.File`, `sys.FileSystem` in HScript (standalone or embedded) |
| `haxe.native` | native library or application access in HScript (standalone or embedded) |
| `haxe.reflection` | dynamic class resolution/instantiation or reflected method calls in HScript |
| `haxe.network` | Haxe/OpenFL/Lime HTTP and network APIs in HScript |
| `process.shell` | `python -c`, `cmd /c`, PowerShell, shell execution, `curl`, `wget` |
| `network.url` | `http://`, `https://`, `ftp://`, `file://` |
| `network.api` | socket/request client APIs |

The source scan is backed by runtime restrictions:

- sandboxed Lua states replace the OS, IO, package, dynamic-code, debug, JIT and FFI
  entry points with blocking proxies;
- privileged engine callbacks are checked again immediately before invocation;
- Hython host-class resolution is disabled for sandboxed Python scripts;
- Lua-to-HScript code is scanned when it is executed, and privileged classes cannot be
  added to the HScript interpreter. Standalone HScript is scanned before its
  interpreter is created, and while sandboxed its `import` resolution is disabled and
  `Type`/`Reflect` are not seeded. `addHScript` is blocked by `engine.script-loader`
  exactly like `addLuaScript`/`addPythonScript`.

Gameplay APIs such as hooks, state/property access, score functions, sprites, timers,
tweens and sound are unchanged.

## Block report

A blocked script writes messages both to the on-screen mod debug console and the process
log. For example:

```text
[ModSecurity] BLOCKED lua script "scripts/unsafe.lua" from mod "ExampleMod" before execution (1 security finding).
[ModSecurity] mod="ExampleMod" script="scripts/unsafe.lua" line=12 rule=lua.os: Lua os library access | os.execute('python -c payload.py')
```

The mod's assets still work; only that script is stopped. Fix or remove the call, then
reload the song/mod.

## Narrow allowlist

If a trusted mod intentionally needs one category, add the exact rule ID to its
`pack.json`:

```json
{
  "name": "My trusted mod",
  "scriptSandboxAllowlist": [
    "engine.file-read"
  ]
}
```

An allowlist entry applies to both the source check and the matching runtime guard. Keep
this list as narrow as possible. Unknown IDs do nothing. The grouped form below is also
accepted:

```json
{
  "scriptSecurity": {
    "enabled": true,
    "allowlist": ["lua.io"]
  }
}
```

## Full opt-out

A mod can explicitly disable its sandbox:

```json
{
  "name": "My native-style mod",
  "scriptSandbox": false
}
```

Phoenix prints a prominent warning the first time a script from that mod is loaded:

```text
[ModSecurity] WARNING: mod "MyMod" opted out of script sandboxing in pack.json. Its Lua/Python/HScript scripts run with full engine privileges.
```

`"allowUnsafeScripts": true` is accepted as a compatibility alias, but
`"scriptSandbox": false` is the documented form. There is no global off switch.
Scripts placed loosely in `mods/scripts/`, `mods/data/`, and the other shared content
folders remain sandboxed and cannot opt out; put a script in a named mod folder when it
needs an explicit policy.
