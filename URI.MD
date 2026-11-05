# Phoenix Engine URI scheme

## Version 1: menu navigation

Phoenix uses the custom scheme **`phoenix`** on Android, iOS and Windows. On Windows
the handler is claimed by the player from Options → Misc, never by a startup or an
installer. For example, a website can offer:

```html
<a href="phoenix://menu/misc">Open Phoenix Misc settings</a>
<a href="phoenix://mods">Open Phoenix Mods</a>
```

The app must be installed, and on Windows registered from **Options → Misc →
Toggle Deeplink**. Browsers may ask for permission before opening it. This is a
custom scheme, **not** an HTTPS Android App Link or iOS Universal Link; there is
no website ownership verification or web fallback. Another installed app can
claim the same scheme.

### Menu route table

| Canonical URI | Short alias | Destination |
| --- | --- | --- |
| `phoenix://menu/main` | `phoenix://main`, `phoenix://menu` | Main Menu |
| `phoenix://menu/mods` | `phoenix://mods` | Mods manager |
| `phoenix://menu/options` | `phoenix://options` | Options categories |
| `phoenix://menu/misc` | `phoenix://misc` | Options → Misc, opened immediately |
| `phoenix://menu/story` | `phoenix://story` | Story Mode |
| `phoenix://menu/freeplay` | `phoenix://freeplay` | Freeplay song selection |
| `phoenix://menu/credits` | `phoenix://credits` | Credits |

Misc is the existing settings substate, not a new standalone menu. Back closes
Misc into Options; Back from Options returns to Main Menu. In builds without
`MODS_ALLOWED`, the Mods route falls back to Main Menu.

This table is complete **for version 1**: every row must keep working forever.
Version 2 adds the resource and support routes listed under
“Version 2: resources and support” further down.

### Grammar and validation

```text
URI      = "phoenix://" authority ["/" destination] ["/"]
authority = "menu" | destination
destination = "main" | "mods" | "options" | "misc" | "story" | "freeplay" | "credits"
```

A destination path is allowed **only** after authority `menu`; bare `menu`
means `main`. Scheme, authority and destination are ASCII case-insensitive.
One trailing slash is accepted. Maximum input length: 256 characters.

No query parameters, fragments, credentials, ports, whitespace, percent escapes,
backslashes, additional path segments or empty internal segments are accepted.
Inputs are not trimmed or URL-decoded. Unknown/malformed links are ignored,
without a popup or change to the pending valid destination. Examples rejected:

```text
phoenix:///mods
phoenix://menu/../mods
phoenix://menu/%6disc
phoenix://mods?enable=all
phoenix://mods#settings
phoenix://user@mods
phoenix://song/test
```

Links never install/enable mods, load a filesystem path, run scripts or commands,
change preferences, download content, or start a song. The parser returns only
an allowlisted internal route; it never resolves a class from external text.
(The version 2 routes below add one thing to that list: a `song` link starts a
chart **only** after the normal chart lookup finds it.)

## Version 2: resources and support

Version 2 keeps every version 1 link working and adds structured hosts, parsed
by `PhoenixURI.parseEx`. `PhoenixURI.parse` still returns only the version 1
menu names, so anything written against v1 is unaffected.

```text
URI      = "phoenix://" host ["/" segment]* ["/"] ["?" query]
host     = "menu" | menuName | "screen" | "song" | "mod" | "diagnostics" | "replay"
menuName = "main" | "mods" | "options" | "misc" | "story" | "freeplay" | "credits"
segment  = [A-Za-z0-9_-]+
query    = key "=" value *( "&" key "=" value )
```

| Canonical URI | Short alias | Destination |
| --- | --- | --- |
| `phoenix://menu/<menuName>` | `phoenix://<menuName>` | the version 1 menu routes |
| `phoenix://screen/<menuName>` | — | same destinations as `menu/…`, for readers that expect a path |
| `phoenix://song/<song>?difficulty=<name>` | — | starts that chart in Freeplay, after the normal lookup confirms it exists |
| `phoenix://mod/<modId>` | `phoenix://mod/<modId>/song/<song>` | Mods manager with that folder focused (and the song, when it exists) |
| `phoenix://diagnostics` | `phoenix://screen/diagnostics` | the read-only diagnostics page |
| `phoenix://replay/<id>` | — | reserved: says “not implemented” instead of pretending to play |

Segment counts are exact, and a query parameter is only read where it means
something (`difficulty` on `song`), so `phoenix://song`,
`phoenix://menu/misc/extra` and `phoenix://diagnostics/all` are all invalid. A
missing chart or song is reported and lands on Main Menu; nothing is installed,
downloaded or enabled, and no path outside `mods/` and the bundled assets is
ever resolved from link text.

### `phoenix://diagnostics` — one link, one screenshot

This route exists so a support thread can ask for a single tap instead of a
walk-through. It is read-only **by construction**, so nobody has to trust the
person tapping it:

```html
<a href="phoenix://diagnostics">Show my Phoenix diagnostics</a>
```

- **Nothing is written.** No file, no preference, no save data, no registry, no
  download. The page even skips the `Paths.clearUnusedMemory()` a menu normally
  runs on entry, because freeing cached assets would rewrite the memory numbers
  the screenshot is supposed to show.
- **Nothing is executed.** It resolves no path from link text, runs no script
  and starts no song. The route takes **no parameters at all**: a
  `phoenix://diagnostics?copy=1` style link is rejected as malformed rather
  than accepted and ignored, so a mistyped link cannot half-work.
- **It never interrupts a session.** Like every other route it is queued, and
  only an idle Title or Main Menu opens it (see “Startup and lifecycle
  behavior”); gameplay, pause, editors, Options, Mods, Story, Freeplay and
  Credits keep it pending until you return to the Main Menu.

The page (`states.DiagnosticsState`, text from `backend.DiagnosticsReport`)
takes one snapshot when it opens and re-reads it on `R`. `C` — or `A` on a
controller — puts the same text on the clipboard for a bug report; `ESC`/`B`
returns to the Main Menu. The sections:

| Section | Rows |
| --- | --- |
| `BUILD` | Phoenix version, JSE/Psych markers, git commit, target, architecture, feature flags, launch arguments |
| `HARDWARE` | OS, CPU model/vendor/cores, total RAM, GPU model/vendor/driver, graphics and audio API |
| `RUNTIME` | game size, scale mode, framerate targets, uptime, heap, process and peak RSS, current state |
| `FILES` | working directory, save-data id, session log path and whether it is live, crash folder, mods folder, Windows handler registration |
| `MODS` | enabled mods in load order (first 10, then a count), disabled ones, folders the engine rejected, active mod directory |
| `SETTINGS` | the preferences that change feel or performance: resolution/widescreen, framerate, quality and shaders, optimization, scroll and ghost tap, note skins, debug aids, update checks/Discord/deeplink opt-in, anti-cheat |
| `RECENT LOG` | the last 10 lines of `vlog/log.txt` plus anything still buffered, in the redacted form the log keeps, or how to turn VLog on |

Every section is guarded, so a value the target cannot report (no render
context, no native memory query, unwritable storage) prints as `unavailable` or
`not reported here` instead of taking the page down. Log lines arrive as
`backend.LogUtils` left them (home directories, usernames and absolute paths
already replaced), because that is how VLog stores them; the paths this report
prints itself are **not** rewritten, so they can contain the player's username and
the footer says to redact before posting. The page uploads nothing anywhere. On Windows the link only arrives when this copy owns
the handler (Options → Misc → Toggle Deeplink); Android and iOS accept it cold
or warm like any other route.

## Startup and lifecycle behavior

- Native events queue a destination; they never switch Flixel states directly.
- Startup never registers anything. On Windows the scheme is only claimed when the
  player checks **Toggle Deeplink** in Options → Misc, and that choice is not
  re-applied, re-verified or unregistered on any later launch.
- A cold launch still performs storage permission/copy setup, preferences,
  saves, mods, splash, title initialization, and the first-run flashing warning.
  After the title intro objects/music have initialized, the link is dispatched
  automatically without requiring Enter. It does not bypass those prerequisites.
- A warm mobile link dispatches from an idle Title or Main Menu, after any
  substate/transition closes. **All other states defer navigation**: gameplay,
  pause, editors, Options, Mods, Story, Freeplay and Credits. Return to Main Menu
  to consume the request. This prevents destructive interruption or abandoned
  editing/settings sessions.
- One pending destination is kept in memory; the latest valid link wins. It is
  consumed once. Invalid links do not clear it. Pending links are not persisted
  across process death. A repeated link after consumption is a new request.
- Ordinary launches without a valid URI keep their existing startup flow.

## Platform implementation

### Android

The existing manifest template advertises a browsable `ACTION_VIEW` filter for
`phoenix`. Lime's activity defaults are exported and `singleTask`; retain these
when customizing the build. `MainActivity` forwards the cold intent in
`onCreate` and warm intents in `onNewIntent` (also updating `getIntent()`).
`PhoenixCore` buffers cold URLs; `DeepLinks` subscribes via
`AndroidIntents.subscribeDeepLink`, which uses the existing JNI delivery tracker
and startup drain. No additional Android library is required.

```sh
adb shell am force-stop quack.fnf.phoenix
adb shell am start -W -a android.intent.action.VIEW -d 'phoenix://menu/misc' quack.fnf.phoenix
adb shell am start -W -a android.intent.action.VIEW -d 'phoenix://mods' quack.fnf.phoenix
```

### iOS

`project.hxp` enables the repo's iOS templates. The Info.plist override adds
`CFBundleURLTypes` / `CFBundleURLSchemes` for `phoenix`, preserving the current
Lime template's other metadata. No associated-domains entitlement is needed.

The Lime fork's SDL UIKit application delegate forwards `openURL` to
`SDL_DROPFILE`; Lime exposes this as `Application.current.window.onDropFile`.
The listener is installed in `Main` before game initialization, and queues only
validated Phoenix links. Ordinary file drops are ignored. This uses the current
SDL app-delegate lifecycle, not a UIScene delegate. When upgrading Lime or adding
scene support, revalidate cold/warm URL delivery and merge upstream plist changes.

With an installed simulator build (a device IPA cannot run in the simulator):

```sh
xcrun simctl terminate booted quack.fnf.phoenix
xcrun simctl openurl booted 'phoenix://menu/misc'
xcrun simctl openurl booted 'phoenix://mods'
```

On a signed device build, open the example links from Safari/Notes and repeat
with the game foregrounded, backgrounded and terminated.

### Windows

Registration is per-user and **opt-in**: launching the game never writes the
registry. **Options → Misc → Toggle Deeplink** does the work, and its state is
the `deeplinkEnabled` preference in `ClientPrefs`.

- Checking it runs `uri/Register-PhoenixURI.ps1` (shipped next to the
  executable) against the running `.exe`. The script checks the registry first
  and refuses to overwrite another copy's handler; the engine reads the value
  back and, when the scheme could not be claimed, snaps the checkbox back off
  and says why. Toggling it on when this copy is already registered writes
  nothing.
- Unchecking deletes `HKCU\Software\Classes\phoenix` outright, even when the
  entry points at another or a deleted copy, so a stale handler never keeps
  offering links to a game that opted out. `uri\Unregister-PhoenixURI.ps1` is
  still there if you would rather have that ownership check.
- The choice is remembered but never re-applied on a later launch: nothing is
  registered, unregistered or verified at startup, so moving or deleting the
  folder leaves the entry alone until you use the option again.
- Manual registration always works and is required when PowerShell/registry
  access is restricted. From the game directory:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\uri\Register-PhoenixURI.ps1
Start-Process 'phoenix://menu/misc'
Start-Process 'phoenix://mods'
```

From a source checkout, pass the built executable explicitly:

```powershell
.\setup\uri\Register-PhoenixURI.ps1 -Executable 'C:\Games\Phoenix\FNF-Phoenix-Engine.exe'
```

The script writes `HKCU\Software\Classes\phoenix`, the empty `URL Protocol`
value, icon and `shell\open\command`. The command is exactly:

```text
"C:\Games\Phoenix\FNF-Phoenix-Engine.exe" "%1"
```

Both arguments are quoted; no command shell is involved. The engine parses
`Sys.args()` and, on a valid protocol launch, sets its working directory to the
executable directory before loading relative assets. All arguments use the same
strict validator; when several valid URIs are supplied, the last wins.

**Each Windows activation starts a new process.** There is no single-instance
IPC or forwarding to an already-running game. Avoid concurrent sessions that
write the same save. This differs from mobile warm delivery.

Re-register after moving the folder: turn the option off and on again, or run the
script by hand. Registering another copy replaces the per-user handler; only one
copy can own this scheme. To uninstall, uncheck the option (or run the unregister
script) before deleting the game; the unregister script is the one that refuses to
remove a registration pointing at a different copy. No elevation is required;
enterprise policy may restrict protocol handlers or PowerShell, in which case the
checkbox stays off and the manual commands above are the fallback.

## Validation and release checklist

Dependency-free parser tests (Haxe required; no engine haxelibs):

```sh
bash tests/uri/run.sh
bash tests/haxe/run-diagnostics-report.sh
python3 -m unittest tests.test_deeplink_diagnostics
```

The first runner isolates the parser from `source/import.hx`; its tests cover every
route and alias, case, slashes, malformed input, injection-shaped input and size
limits. The second compiles `backend.DiagnosticsReport` and
`states.DiagnosticsState` against the stubs in `tests/haxe/stubs/diagnostics`, so
the section layout, the bounded log tail, the scroll bounds and the "nothing was
written" promise are executed rather than eyeballed. The third needs no Haxe at
all: it pins the source-level rules the compiler cannot see (which states may
dispatch, that the page writes no files, that both documents still agree).

Build with the normal SDK/toolchains:

```sh
haxelib run lime build android -Dofficial
haxelib run lime build ios -nosign -Dofficial
haxelib run lime build windows -Dofficial
```

Before release, test on **each platform**:

1. Both example links from a stopped app; Misc must actually be open, not just
   highlighted. Back must return to Options, then Main Menu.
2. First-run storage setup and flashing warning; destination survives both.
3. Warm mobile links in Main Menu, then gameplay/editor/Options: unsafe states
   stay intact and the latest valid link opens after returning to Main Menu.
4. Invalid links, duplicate delivery, multiple rapid valid links, and normal
   icon launch. Check no unexpected state changes or repeated startup navigation.
5. Mods route with and without `MODS_ALLOWED`.
6. Inspect the packaged Android manifest and generated iOS Info.plist. Exercise
   foreground, background and terminated mobile launches on actual devices.
7. Windows executable path containing spaces; launch from an unrelated working
   directory; move/re-register/unregister; confirm another copy's registration
   cannot be inadvertently overwritten. Then exercise the option itself: check
   **Toggle Deeplink**, restart and confirm the registry is untouched (no write,
   no verification, no popup) while links still route; uncheck it and confirm the
   handler is gone and the checkbox survives a restart as off.

Implementation environment: the parser tests, the diagnostics specs and the whole
Python guard suite were compiled and run in the editing sandbox against a Haxe
compiler installed from npm. What was **not** done there: native builds (no Android,
iOS or Windows SDKs) and any run against the real flixel/openfl/lime tree —
`DiagnosticsReport.hx` and `DiagnosticsState.hx` are typechecked against the stubs,
so a flixel signature that changed under us would only surface in a real build.
The runtime checks above remain required.

## Evolution plan

Version 1 is deliberately menu-only and has no version query parameter. Keep
these routes compatible. New safe destinations must be added to the parser,
router, tests, `URI.MD` and `website/docs/subsystems/deeplinks.md` together —
`phoenix://diagnostics` is the worked example of that rule, and its read-only
contract is why it was allowed at all. Mod installation, remote content and
editor/file targets remain **not implemented**; a route that writes, installs or
resolves a path needs explicit user confirmation, resource validation and a
separate security review first. Windows single-instance handoff is a future
enhancement, not part of the current delivery contract.
