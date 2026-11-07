---
title: Why is my Lua script not running?
sidebar_position: 12
description: The ordered list of gates a .lua mod script must pass, and where each one fails silently.
---

# Why is my Lua script not running?

A `.lua` script that never runs produces no in-game error: it simply has no
effect. The silence has a small number of causes, and they happen in a fixed
order. Check them in this order.

The repository keeps a runnable version of this list in
`tests/haxe/run-lua-discovery.sh`; see
[`docs/LUA_SCRIPT_DEBUGGING.md`](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/blob/main/docs/LUA_SCRIPT_DEBUGGING.md)
for the long form with source references.

## 1. Is Lua compiled in?

Every `psychlua/*.hx` file is behind `#if LUA_ALLOWED`. A build made with
`-DMODDING_LEVEL=0` has no Lua support and ignores `.lua` files completely.

## 2. Is the script where the engine looks?

| Scope | Folders |
|---|---|
| Global | `mods/scripts/`, `assets/scripts/` |
| Global, per mod | `mods/<mod>/scripts/` — while that mod is current, and for every song when `pack.json` sets `"runsGlobally": true` |
| Song | `mods/data/<song>/` |
| Stage | `stages/<stage>.lua` |
| Note type / event | `custom_notetypes/<type>.lua`, `custom_events/<event>.lua` |

Only the top level of each folder is scanned — a script in a subfolder is never
found. Enabling a mod in `modsList.txt` does **not** make its `scripts/` folder
global: it is read while that mod is the current mod, plus on every song if the
mod declares `"runsGlobally": true`.

## 3. Does the folder name match the chart?

The song folder is `mods/data/<formatToSongPath(chart.song)>/`, where the chart's
own `song` field is used. Spaces become `-`, and a few characters are replaced or
dropped. `"song": "Transparency Test"` means `mods/data/transparency-test/`.

## 4. Did the security scan reject it?

Before a Lua state is created, the source is scanned. Any finding means the
script is never loaded. The most common false positives are on executable lines
that merely mention a blocked name, for example a `debugPrint('http://…')` (rule
`network.url`) or a call inside a string. See the
[script security sandbox](./script-security.md) page for the rule list and for
`scriptSandboxAllowlist`.

## 5. Does it fail on the first line that runs?

The whole file is executed once, at load time, after the engine globals are
registered. A syntax error or a call to a function that does not exist at that
moment stops the script, and the state is closed.

## 6. Is the hook actually fired?

Declaring `function onBeatHit()` does nothing unless the engine calls that name.
`song-hooks.md`/`script-hooks.md` lists what is dispatched; hooks outside that
list never run.

## Turning on the durable log

Lua errors and `debugPrint` go through `trace()`. The session log file is only
written when **Options → Misc → Enable VLog** is on (it writes `vlog/log.txt`).
With it enabled, look for:

* `[ModSecurity] BLOCKED …` — the scan stopped the script (step 4)
* `failed to initialise Lua sandbox: …` — the sandbox itself failed
* `Error on lua script! …` — load-time failure (step 5)
* `ERROR (<hook>): …` — a hook raised while running

If there is no line mentioning your script at all, it was never discovered — go
back to step 2.
