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

The sandbox is enabled by default for every mod. Engine-owned scripts under `assets/`
are not treated as softmods. A player who trusts a mod can turn the sandbox off for
that one mod with the [switch in the Mods menu](#per-mod-switch-in-the-mods-menu).

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
| `engine.clipboard` | reading or replacing the OS clipboard (`getClipboardText`, `setClipboardText`) |
| `engine.window-list` | listing the titles of other open windows (`getOpenWindowTitles`) |
| `engine.screen-capture` | screenshotting the whole desktop (`captureDesktop`) |
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
[ModSecurity] Only if you trust mod "ExampleMod": Mod Info in the Mods menu can turn ModSecurity off for it, which lets its blocked scripts run.
```

The mod's assets still work; only that script is stopped. Fix or remove the call, then
reload the song/mod. The last line is printed once per mod and points at the
[per-mod switch](#per-mod-switch-in-the-mods-menu). Loose scripts do not get it, and
neither does a file that is not readable text (`security.binary-source`,
`security.unreadable`): that one would not run without the sandbox either.

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
`"scriptSandbox": false` is the documented form. There is no global off switch: the
sandbox is only ever turned off for one mod at a time, by that mod's `pack.json` or by
the player in the Mods menu.
Scripts placed loosely in `mods/scripts/`, `mods/data/`, and the other shared content
folders remain sandboxed and cannot opt out, not even through the Mods menu; put a
script in a named mod folder when it needs an explicit policy.

## Per-mod switch in the Mods menu

A player can decide for each mod, without editing any of its files:

1. Open **Mods** and select the mod.
2. Press the gear button in the button strip. It opens **Mod Info**.
3. Choose **Turn off** and answer **Yes**, or choose **Turn on**.

Mod Info shows the mod's folder, whether it is enabled, whether ModSecurity is **ON**
or **OFF** for it, and the `scriptSandboxAllowlist` exceptions its `pack.json` asks
for. The Mods menu shows the same state under the description as `ModSecurity: ON` or
`ModSecurity: OFF`.

- ModSecurity is **on by default** for every mod. Nothing changes until the switch is
  used.
- **Off** stops both the source scan and the runtime guards for that one mod. Its Lua,
  Python and HScript files then run with full engine privileges. Every other mod, and
  every loose script, stays sandboxed.
- The player's choice wins over `pack.json`. **Turn on** therefore also sandboxes a mod
  whose `pack.json` opts out; the `scriptSandboxAllowlist` exceptions of that mod still
  apply.
- The choice is used the next time that mod's scripts are loaded, for example by the
  next song. The game does not need a restart.
- Importing a `.zip` into a folder, also to replace the mod that was there, drops a
  **Turn off** you chose for that folder. The files are new, so they start under their
  own `pack.json` again (sandboxed, unless that opts out) and the decision is yours to
  make again.

The first time a script from a mod you switched off is loaded, the log says so:

```text
[ModSecurity] WARNING: ModSecurity is turned off for mod "MyMod" in the Mods menu (Mod Info). Its Lua/Python/HScript scripts run with full engine privileges.
```

The choices are kept in `modSecurity.txt`, next to `modsList.txt`. It has one line for
each mod whose state differs from that mod's own default:

```text
MyTrustedMod|0
ModThatOptsOut|1
```

`0` turns ModSecurity off for that mod folder and `1` forces it on. The folder name has
to be written exactly as the folder is called. A choice belongs to the folder name: it
stays in effect when you change or swap the files in that folder by hand, so remove
the line when you put a different mod there. Delete a line, or the whole file, to
return to the default; the Mods menu reads the file again every time it opens. A line
the engine cannot read, or one that names no installed folder, changes nothing: that
mod stays at its default.
