# Copy diagnostics

`Options → Misc → "Copy Diagnostics"` is the one-button version of "please tell
me your specs". It builds a redacted, paste-ready block, puts it on the system
clipboard, saves a copy under `crash/` and opens a read-only viewer.

It is **offline by design**: the recent-update flow is deliberately
repository-based (`TODO.md` §0), so a diagnostics report is never uploaded,
never posted and never scheduled. The player decides where the text goes.

## What is in the block

```
<!-- phoenix-diagnostics:v1 -->
Phoenix Engine diagnostics
generated 2026-11-04 21:30:00 (local time)

[build]
  engine: v0.0.1              # PhoenixVersion.display(ENGINE_VERSION) - VERSION in project.hxp
  jse: 1.51.0                 # upstream compatibility markers
  psych: 0.6.3
  commit: c7bb4a0             # backend.HaxeCommit
  target: windows (hxcpp) release build
  haxe: Haxe 4.307
  framework: 9.4.1            # openfl version the build resolved
  runtime_lib: 8.1.2          # lime
  game_framework: 5.9.0       # flixel

[hardware]
  os: Windows 10.0.19045
  cpu: Intel(R) Core(TM) i7-9700K CPU @ 3.60GHz
  cpu_vendor: Intel
  cpu_cores: 8 logical         # debug.system.SystemInfo.logicalCPUCount
  ram_total: 16GB              # debug.system.SystemInfo.totalPhysicalMemory()
  ram_used: 210MB resident     # debug.mem.GetTotalMemory current RSS
  gpu: NVIDIA GeForce RTX 3060 # backend.Native (#96)
  gpu_vendor: NVIDIA
  gpu_driver: 535.104.05
  gfx_api: OpenGL 4.6
  renderer: NVIDIA Corporation | 4.6.0 NVIDIA 535.104.05
  audio: OpenAL Soft | 1.23.1
  heap_used: 90.6MB            # VLog.heapUsedBytes()
  process_rss: 210MB           # same figure as ram_used

[runtime]
  display: 2560x1440 fullscreen
  framerate: 144 fps
  mods: 2 enabled / 3 installed
  state: play.PlayState
  vlog: recording (vlog/log.txt)

[paths]
  install: C:\Users\<user>\Games\Phoenix
  save: C:\Users\<user>\AppData\Roaming\company\funkin (funkin.sol, controls_v2.sol)

[mods]
  #1: mymod (enabled)          # load order, exactly like modsList.txt
  #2: other (enabled)
  #3: old (disabled)

[prefs]
  downScroll=true              # only values that differ from the engine default
  framerate=144

[log] last 60 lines of vlog/log.txt   # "last N of 60" on a short session
  [2026-11-04 21:29:59.500] [f0000060] [FRAME] fps=60 frame=16.7ms
  …
```

`Unknown` means the target cannot answer (no native CPU query, no live GL
context, no writable filesystem) — never a crash and never an empty line.

## Redaction

`backend.DiagnosticsReport` scrubs every line, including the log tail:

| Pattern | Becomes |
| --- | --- |
| `C:\Users\bob\…`, `C:/Users/bob/…`, `C:\Documents and Settings\bob\…` | `…\<user>\…` |
| `/home/bob/…`, `/Users/bob/…` | `…/<user>/…` |
| `/root/…` | `/root/<user>` |
| `%USERPROFILE%`, `$HOME`, the exact `HOME`/`USERPROFILE` of the running user | `<home>` |
| `name@example.com` | `<email>` |
| `phoenix://menu/misc?mod=x` | `phoenix://<redacted>` |
| `GITHUB_TOKEN=…`, `api_key: …` | `<redacted>` |

Nothing else is collected: no save contents, no keybinds, no note colours
(the table is summarised as `[[3 items], …]` when it changes), no script
source and no history. Long lines are clipped with a `… (+N chars)` marker so
one runaway stack trace cannot blow up the paste.

## Log tail without enabling the vlog

`backend.VLog` is opt-in and stays opt-in. To make the log section useful on a
default install it keeps the last 64 KiB of the session log (`TAIL_MAX_CHARS`)
in a bounded in-memory buffer, recorded from the same formatted lines
`vlog/log.txt` would receive (a boot header, traces, state changes, asset
caches, memory events and crashes).

Nothing is created on disk while the log is off — `VLog.init()` seeds the one
boot header and returns before the session starts, and `log()` only touches the
tail. `VLog.recentText()` is what a report reads: with a session open it reads
the last `TAIL_MAX_CHARS` of `vlog/log.txt` (never the whole file, which can be
10 MiB) plus the unflushed buffer; with it off it returns the tail. Trimming
snaps to a line boundary, and `DiagnosticsReport.tail()` slices the last N lines
and drops a cut continuation line, so a pasted report never starts mid-stack-frame.

## The viewer

The report opens in `states.substates.DiagnosticsSubstate` right after it is
built. That screen exists for two reasons: a phone may not hand the clipboard to
the game, and the player should be able to read *what* is about to be pasted
before it leaves the machine.

It is a scroller (`UP`/`DOWN` or the wheel), reports whether the clipboard copy
worked (from `Diagnostics.lastClipboardOk`, not by parsing the message), and
`ACCEPT`/`BACK` copies the same string once more before closing — a retry for a
target whose clipboard became ready late. A failed build is never shown: the
viewer is opened with no text and the error is in the message instead of the
previous report.

## Where the copy goes

| Target | Clipboard | File |
| --- | --- | --- |
| Windows / Linux / macOS | `lime.system.Clipboard` | `crash/diagnostics-<date>.txt` |
| Android | `PsychJNI.clipboardSetText` (Lime does not bridge it here) | same, in the app's external-files folder |
| HTML5 / Flash | not available | not available — the viewer shows the text |

`crash/` is already one of the roots `PhoenixDocumentsProvider` exposes on
Android (`Crash Logs`, next to `Mods` and `VLogs`), so the file is reachable
from the system Files app exactly like a crash report.

## Defaults, and the "non-default" list

`[prefs]` lists a field only when it differs from its initialiser in
`ClientPrefs`. Because `ClientPrefs.loadPrefs()` overwrites those fields at
startup, the defaults live in a table (`Diagnostics.DEFAULTS` /
`GAMEPLAY_DEFAULTS`) generated from the initialisers;
`tests/test_diagnostics.py` fails if the two ever disagree, so a new
preference cannot silently be reported as "changed by the player".

## Tests

* `tests/haxe/run-diagnostics-report.sh` — runs `DiagnosticsReportSpec.hx` in
  the Haxe interpreter: the section/field contract, the redaction rules (home
  folders, secrets, e-mails, deep links), log-tail slicing, clipping, value
  formatting and the fail-safe edges (null facts, empty lists, missing log).
* `tests/test_diagnostics.py` — source guards: the Misc entry and its wiring,
  every roadmap field present, no HTTP/socket imports anywhere in the feature,
  the defaults table matching `ClientPrefs`, and the spec being wired into CI.

## See also

* [`SETTINGS_BACKUP.md`](SETTINGS_BACKUP.md) — the other half of "support on a
  locked-down device": moving the settings themselves between installs.
* `backend.VLog` — the opt-in verbose log the `[log]` section is taken from.
