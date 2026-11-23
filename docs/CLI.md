# Command line launch options

The desktop and mobile builds read the arguments they were started with, so a
shortcut, a script, a terminal or `adb` can change how this one session runs:

```
FNF-Phoenix-Engine.exe --fullscreen --fps=144
FNF-Phoenix-Engine.exe --freeplay
./FNF-Phoenix-Engine --song=bopeebo --profile
./FNF-Phoenix-Engine "phoenix://menu/mods"
FNF-Phoenix-Engine --help
```

The vector is parsed once, before a window exists, by
[docopt-ng](https://lib.haxe.org/p/docopt-ng/) (a Haxe port of
[docopt-ng](https://github.com/jazzband/docopt-ng)) against the docstring in
`backend.CommandLine.USAGE`. That string is the single source of truth: it is
the grammar the parser enforces *and* the text `--help` prints, so the two can
never drift apart. The parsed result is a plain record,
`backend.LaunchOptions`, that the boot sequence reads.

These are **runtime** options. The compile-time launch flags (`-DFREEPLAY`,
`-DMENU`, `-debug`) belong to the build command and are documented in
`BUILDING.md` → *Launch and debug flags*.

## Options

| Option | Effect | Read by |
|---|---|---|
| `-h`, `--help` | Print the usage text and exit `0` without opening a window. | `Main.answerInformationRequest` |
| `--version` | Print `FNF-Phoenix-Engine <version>` and exit `0`. | `Main.answerInformationRequest` |
| `-w`, `--windowed` | Start windowed for this session. | `Main`, `ClientPrefs.applyWindowModePreference` |
| `-f`, `--fullscreen` | Start in exclusive fullscreen for this session. | `Main`, `ClientPrefs.applyWindowModePreference` |
| `-b`, `--borderless` | Start in borderless fullscreen for this session. | `ClientPrefs.applyWindowModePreference` |
| `--fps=<n>` | Gameplay framerate for this session, `1`–`10000` (clamped, then clamped again by the Uncapped FPS policy). Menus keep **Menu Framerate**. | `Main`, `ClientPrefs.loadPrefs` |
| `--freeplay` | Boot straight into `FreeplayState`, like `-DFREEPLAY` but without a rebuild. | `states.InitState` → `backend.LaunchState.resolve` |
| `--menu` | Boot straight into `MainMenuState`, like `-DMENU` but without a rebuild. | `states.InitState` → `backend.LaunchState.resolve` |
| `--song=<name>` | Open `phoenix://song/<name>` once the game is idle in a menu. | `backend.deeplink.DeepLinks` |
| `--mod=<id>` | Open `phoenix://mod/<id>` (with `--song`, `phoenix://mod/<id>/song/<name>`). | `backend.deeplink.DeepLinks` |
| `--profile` | Turn the frame profiler on and export its `.log` to `debug/log/` on exit. | `debug.FrameProfiler.init` |
| `--vlog` | Write the verbose log (`vlog/log.txt`) for this session, even when **Enable VLog** is off. | `Main` → `backend.VLog.init` |
| `--safe-mode` | Boot into the recovery screen, exactly like a crash loop does. | `Main.safeModeBoot` |
| `--troll` | Super danger mode: `CoolUtil.selfDestruct()` really deletes the build folder. | `Main.superDangerMode` |
| `--no-deeplinks` | Ignore every `phoenix://` link on the command line. | `backend.deeplink.DeepLinks` |

Positional arguments are `phoenix://` links, the same ones Windows hands to the
executable when it launches the registered protocol handler (`URI.MD`):

```
FNF-Phoenix-Engine.exe "phoenix://song/bopeebo?difficulty=hard"
```

Anything else positional is reported as ignored and dropped, so a stray path in
a shortcut cannot be mistaken for a link.

## Session only, never saved

A launch option changes **this run** and nothing else:

- The window mode override is applied with `WindowMode.apply()`, which never
  writes. Options → Graphics → **Window Mode** keeps showing the saved mode.
- `--fps` overrides `ClientPrefs.framerate` in memory, and
  `ClientPrefs.saveSettings()` writes the player's own number back
  (`savedValueOf`) instead of the session value — the same protection
  `backend.LowMemory.beginSave()` gives the preferences a memory profile
  forces. Pick a rate in Options during such a session and your choice is what
  gets saved, because the live value is then no longer the override.
- `--freeplay` / `--menu` decide the first screen of this run; they do not
  touch `ClientPrefs.disableSplash`.
- `--vlog`, `--profile` and `--safe-mode` are switches for this process; the
  saved **Enable VLog** and **Frame Profiler** preferences stay as they were.

## Conflicts and precedence

Fixed order, never argument order — the same rule `backend.LaunchState`
documents for `-DFREEPLAY` against `-DMENU`:

| Given | Result |
|---|---|
| `--fullscreen` and `--windowed` | Fullscreen |
| `--borderless` and `--windowed` | Borderless |
| `--fullscreen` and `--borderless` | Fullscreen |
| `--freeplay` and `--menu` | Freeplay (`LaunchState.resolve`) |
| `--song=<name>` and a positional link | `--song`, queued last, is the link `DeepLinks` keeps |
| `--safe-mode` and a crash loop | The recovery screen (both ask for it) |
| `--safe-mode` and `--vlog` | The recovery screen, with the verbose log off until that screen offers it |

Short options cluster the way docopt always clusters them, so `-wfb` is
`-w -f -b` and resolves to fullscreen by the table above.

## Spellings that predate docopt

Older builds scanned `Sys.args()` by hand. Those spellings still work and are
rewritten by `CommandLine.normalizeLegacy()` before parsing:

| Old | Now |
|---|---|
| `-troll` | `--troll` |
| `-profile` | `--profile` |
| `--frame-profiler` | `--profile` |

One dash in front of a whole word is a *cluster* to docopt, which is never what
a player means, so `-fullscreen` is expanded to `--fullscreen` as well — for
any option documented in the usage text.

## Arguments the parser cannot use

**The game boots anyway.** An unknown flag (`--nope`), a duplicated option, or a
value that cannot be parsed (`--fps=fast`, `--song=bad name!`) leaves every
option at its default and is recorded in `LaunchOptions.error`; `phoenix://`
links in the same vector are still delivered, because a protocol launch is
indistinguishable from "the game ignored my argument" otherwise.

What was requested and what had to be ignored lands in the verbose log as one
line (`--vlog`, or **Enable VLog** in Options → Misc):

```
[CLI] --fullscreen --fps=144 phoenix://song/fresh
[CLI] ignored: --fps="fast" is not a whole number
```

The raw vector is unchanged in `backend.DiagnosticsReport` (**Launch args**)
and in the vlog's boot block, which is what a support request should attach.

`--help` and `--version` print on stdout, so they are only visible when the
executable was started from a terminal; a shortcut launch never asks for them.

## Targets without a command line

`CLI_OPTIONS_ALLOWED` (default: desktop and mobile) decides whether docopt-ng is
on the classpath at all. Web, Flash and AIR builds have no arguments to read,
so they skip the library and `backend.CommandLine` reports "nothing requested"
— while still handing any `phoenix://` argument to `DeepLinks`. Turn the parser
off in a desktop build with `-DNO_CLI_OPTIONS_ALLOWED` for the same behaviour.

Mobile notes: the Android/iOS launch path delivers links through intents and
`onDropFile` (`URI.MD`), not through arguments; `adb shell am start ... -d
'phoenix://menu/misc'` keeps using that path. Options that need a window or a
save file behave as they do on desktop when the platform supports them
(`backend.PlatformSupport`).

## Adding an option

1. Add it to the `Options:` block of `CommandLine.USAGE` — two spaces minimum
   between the option and its description, one line each; that is docopt's
   contract, and it is what `--help` prints.
2. Add the field to `backend.LaunchOptions` (with its doc comment) and to
   `CommandLine.defaults()`, then read it in `fromParsed()` — `--safe-mode`
   arrives as `parsed.safe_mode`, `[URI...]` as `parsed.URI`.
3. Wire it where it belongs (a preference override goes through
   `ClientPrefs`, a boot-time decision through `Main`, a screen through
   `LaunchState.resolve`) and keep it session-only.
4. Cover it in `tests/haxe/CommandLineSpec.hx`, pin the wiring in
   `tests/haxe/CommandLineWiringSpec.hx` and document it above — the wiring
   spec fails when an option in the usage text is missing from this file.

Spec: `bash tests/haxe/run-command-line.sh` (runs in `checks.yml`). It skips the
docopt half with a message when the library is not installed
(`haxelib path docopt-ng`, or `DOCOPT_NG_PATH`); the flag-off and wiring halves
always run.
