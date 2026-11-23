# Per-mod "why did it break?" report

`backend.ModHealth` answers, inside the Mods menu, the question a broken mod
usually sends its author to the log for: *what actually failed, and in which
mod?* It is the §19 item of `TODO.md`.

## What is recorded

Four facts, per mod folder, recorded by the code that already knows about the
failure:

| Problem | Source | How it is recorded |
|---|---|---|
| Last script load error | `psychlua.FunkinLua`, `psychlua.PythonScript`, `psychlua.HScript`, `psychlua.HaxeScript` | `ModHealth.recordLoadError(modFolder, scriptName, message)` on every load failure (syntax error, runtime error, unreadable file) |
| Invalid `pack.json` | `backend.Mods.getPack()` | `ModHealth.recordInvalidPack(folder, reason)` when the manifest does not parse, is empty, or is not a JSON object |
| Blocked script rule | `backend.ModSecurity.report()` | `ModHealth.recordSecurity(folder, script, language, findings)` with the scanner's rule ids (`lua.os`, `engine.file-write`, …) |
| Blocked runtime call | the runtimes' `reportSecurityRuntime()` | `ModHealth.recordRuntimeBlock(folder, script, capability)`; covers a script that loaded but lost a guarded callback |
| Missing assets | `backend.Paths` | `ModHealth.recordMissingAsset(path)` from the image, sound and atlas failure paths |

Only the **last** load error per mod is kept, which is what the menu means by
"last load error". Blocked scripts are deduplicated by language and path and
capped at `MAX_BLOCKED_SCRIPTS`; missing assets are counted by distinct key, so
retrying a load does not inflate the number. Everything is bounded, so a mod
that fails in a loop cannot grow the record.

## Where it shows up

- **Mods menu row** (`states.ModsMenuState`, `Class.ModItem`): a `!` badge
  (break) or `?` (missing assets only) on the icon, plus one line under the
  description: `No problems detected`, or
  `PROBLEMS: script error, invalid pack.json, 2 blocked scripts, 1 missing asset`.
- **Mod Info** (`states.substates.ModInfoSubState`): a **WHAT BROKE** block with
  the last load error and its message, why `pack.json` could not be used, the
  rules and script that were blocked, and the missing-asset count with up to two
  paths. `ModInfoFlow.problemsBlock()` wraps it to the panel width and caps the
  displayed lines.

The badge and the summary line are built from counts only, so nothing a mod
wrote reaches them. The mod's own text (a path, an interpreter message) appears
only inside Mod Info, where `ModHealth` flattens it to one bounded line and
`ModInfoFlow` wraps it; a mod cannot open a new line or draw outside the panel.

## Lifetime

The report is per session and per folder:

- it starts empty every launch (nothing is written to disk);
- `ModHealth.keepOnly(modsList.all)` runs when the Mods menu is built, so a
  report cannot outlive the folder it belongs to;
- `Mods.forgetHealth(folder)` runs after a `.zip` import replaces a folder, and
  `ModHealth.forget(folder)` drops a single mod.

## Attribution

Recording needs a mod folder. The runtimes pass theirs; when they have lost it,
`ModHealth.folderForPath()` reads the `mods/<folder>/…` segment out of the path,
the same rule `backend.MemoryLedger` uses for RAM. Loose content directly under
`mods/` (the reserved folder names in `ModPathPolicy.RESERVED_MOD_FOLDERS`) and
engine assets under `assets/` are never blamed on a mod.

## Tests

```bash
bash tests/haxe/run-mod-health.sh
```

- `tests/haxe/ModHealthSpec.hx` — recording, severity, summary, report lines,
  caps, ownership, text flattening and the Mod Info wrapping.
- `tests/haxe/ModPackHealthSpec.hx` — the `Mods.getPack()` half against small
  stubs (`tests/haxe/stubs/mod-pack`, including a minimal `tjson`), run inside a
  throwaway `mods/` tree.
- `tests/haxe/AssetCacheSpec.hx` — a missing mod asset is counted for that mod,
  through the real `backend.Paths`.
