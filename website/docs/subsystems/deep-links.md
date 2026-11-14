---
title: Deep links (phoenix://)
sidebar_position: 10
description: The custom URI scheme — routes, grammar, dispatch rules, the read-only diagnostics link, the input tester link and per-platform registration.
---

# Deep links — `phoenix://`

Phoenix uses the custom scheme **`phoenix`** on Android, iOS and Windows, so a web
page or another app can open a specific menu:

```html
<a href="phoenix://menu/misc">Open Phoenix Misc settings</a>
<a href="phoenix://mods">Open Phoenix Mods</a>
<a href="phoenix://diagnostics">Show the read-only diagnostics page</a>
<a href="phoenix://input">Test the keyboard, controller and touch screen</a>
```

The app must be installed. On Windows the handler is also **opt-in**: the player
claims it from **Options → Misc → Toggle Deeplink**, and no launch ever writes the
registry on its own. This is a *custom scheme*, not an Android App Link or iOS
Universal Link: there is no domain verification and no web fallback, and another
installed app could claim the same scheme.

## Routes

| Canonical URI | Short alias | Destination |
|---|---|---|
| `phoenix://menu/main` | `phoenix://main`, `phoenix://menu` | Main Menu |
| `phoenix://menu/mods` | `phoenix://mods` | Mods manager |
| `phoenix://menu/options` | `phoenix://options` | Options categories |
| `phoenix://menu/misc` | `phoenix://misc` | Options → Misc, opened immediately |
| `phoenix://menu/story` | `phoenix://story` | Story Mode |
| `phoenix://menu/freeplay` | `phoenix://freeplay` | Freeplay |
| `phoenix://menu/credits` | `phoenix://credits` | Credits |

Misc is the existing settings substate, not a new menu: Back closes Misc into Options,
Back from Options returns to the Main Menu. Without `MODS_ALLOWED`, the Mods route falls
back to the Main Menu.

### Resource routes (version 2)

Version 1's table stays the compatibility contract; `PhoenixURI.parseEx` adds
structured hosts on top of it:

| Canonical URI | Destination |
|---|---|
| `phoenix://screen/<menuName>` | same destinations as `phoenix://menu/<menuName>` |
| `phoenix://song/<song>?difficulty=<name>` | starts that chart in Freeplay, only if the normal lookup finds it |
| `phoenix://mod/<modId>` (optionally `/song/<song>`) | Mods manager with that folder focused, or the song when it exists |
| `phoenix://diagnostics` | the read-only diagnostics page (alias `phoenix://screen/diagnostics`) |
| `phoenix://input` | the input tester (alias `phoenix://screen/input`) |
| `phoenix://replay/<id>` | reserved — reports "not implemented" rather than pretending |

Segment counts are exact, so `phoenix://song`, `phoenix://diagnostics/all` or
`phoenix://input/keyboard` are invalid links, ignored without a popup.

## Diagnostics: `phoenix://diagnostics`

The route a support thread asks for. Tap it, screenshot what opens, paste the
report — one link instead of a walk-through of the menus. `states.DiagnosticsState`
renders a single snapshot built by `backend.DiagnosticsReport`: build identity
(version, commit, target, feature flags, launch arguments), hardware (OS, CPU,
RAM, GPU and driver, graphics and audio API), runtime (viewport, scale mode,
framerate targets, uptime, heap, RSS), file locations (working directory,
save-data id, session log, crash folder, mods folder), the enabled mods in load
order, the settings that change feel or performance, and the last ten `vlog`
lines.

It is read-only by construction: it writes no file, changes no preference,
touches no save data, resolves no path from the link text, and skips the
`Paths.clearUnusedMemory()` a menu usually runs on entry — freeing cached assets
would rewrite the memory numbers the screenshot exists to show. The route also
takes **no parameters**: `phoenix://diagnostics?copy=1` is rejected as malformed
rather than half-accepted. Each section is guarded, so a value the target cannot
report becomes `unavailable` instead of an error page. `R` re-reads the snapshot,
`C`/`A` copies the text, `ESC`/`B` returns to the Main Menu. Log lines are shown
in the redacted form `backend.LogUtils` gives VLog, but the paths the report prints
itself are not rewritten, so they can carry the player's username and the footer
says to redact before posting. Nothing is ever uploaded.

## Input tester: `phoenix://input` {#input-tester}

The route for "my keyboard eats notes" and "my phone ignores the third finger".
`states.InputTestState` shows what the game itself receives, so a hardware limit
stops looking like an engine bug. The same page opens from
**Options → Gameplay → Input Tester**.

- **Per device** (`KEYBOARD`, `GAMEPAD`, `TOUCH`): `held now`, `most at once`,
  `presses`, and the names of what is held. Three keys held and a `2` on screen
  means the keyboard does not report the third; four fingers and a `2` means the
  screen tracks two.
- **Press timing**: the gap between the last two presses, how long the last
  released input was held, the size of the last chord and how long it took to
  build, the most presses inside one frame, and the taps that went down and came
  back up inside one frame, which a once-per-frame read never sees held.
- **History**: the last 12 presses and releases, newest first.
- **Crosshairs**: a numbered one per finger for the first ten; more are still
  counted.

Keys come from the stage key events that gameplay judges notes from
(`PlayState` listens to the same ones) and are timed as they reach the game.
Gamepads and touches are read from `FlxG.gamepads` and `FlxG.touches` once per
update, so their gaps are whole frames. The numbers are arrival times inside the
game, not a device's polling rate.

Every input is a test subject, so a tap never navigates. Leaving is a one second
hold with nothing else held on that device — Escape or a key bound to Back, `B`
or Back on a pad, or the on-screen `EXIT` button with one finger or the mouse —
and Android's system Back leaves at once. The volume shortcuts are switched off
while the page is open and restored when it closes. The page binds, saves and
writes nothing; the engine-wide desktop hotkeys are handled outside any state and
still work (`F2` screenshot, `F3`/`F6` frame profiler, `F11` fullscreen). Like the
diagnostics route it takes **no parameters** and has no sub-pages, and it returns
to the Main Menu (or to Options when it was opened from there).

`backend.InputTestLogic` is the renderer-free half: counters, peaks, chord and
frame statistics, the history ring and the hold-to-leave gesture, with no Flixel
import. `InputTestState` only feeds it and draws it, and rebuilds its text when an
input changes rather than every frame.

## Grammar

Version 1, and what `PhoenixURI.parse` still accepts:

```text
URI         = "phoenix://" authority ["/" destination] ["/"]
authority   = "menu" | destination
destination = "main" | "mods" | "options" | "misc" | "story" | "freeplay" | "credits"
```

A destination path is allowed **only** after the authority `menu`; bare `menu` means
`main`. Scheme, authority and destination are ASCII case-insensitive, one trailing slash
is accepted, and the maximum input length is 256 characters.

Rejected outright (no popup, pending destination unchanged): query parameters, fragments,
credentials, ports, whitespace, percent escapes, backslashes, extra path segments and
empty internal segments. Input is neither trimmed nor URL-decoded. The same strictness
applies to the version 2 hosts, where each host fixes its own exact segment count.

```text
phoenix:///mods
phoenix://menu/../mods
phoenix://menu/%6disc
phoenix://mods?enable=all
phoenix://mods#settings
phoenix://user@mods
phoenix://diagnostics?copy=1
phoenix://input?device=touch
```

## Implementation

Four modules in `backend/deeplink/`:

- **`PhoenixURI`** — `parse(uri)` validates the v1 grammar and returns an
  allowlisted route string; `parseEx(uri)` returns a structured `ParsedURI` for
  the version 2 hosts. Neither resolves a class from external text.
- **`URIKind` / `ParsedURI`** — the route enum (`Menu`, `Screen`, `Song`, `Mod`,
  `Diagnostics`, `InputTest`, `Replay`) and its query map.
- **`DeepLinks`** — platform subscription, queueing and dispatch into the states.

```haxe
DeepLinks.init();             // from Main, before the game exists: queues only
DeepLinks.receive(uri);       // native callback: validates and queues
DeepLinks.dispatch();         // called from an idle Title/Main Menu
DeepLinks.applyRegistration(); // the Misc "Toggle Deeplink" checkbox
```

### Dispatch rules

- Native events only **queue** a destination; they never switch Flixel states directly.
- Startup registers nothing at all. On Windows the handler is claimed only when the player
  checks Options → Misc → Toggle Deeplink, and that preference is never re-applied,
  re-checked or undone by a later launch.
- A cold launch still performs the full startup (permissions/copy, preferences, saves,
  mods, splash, title, first-run flashing warning). Once the title has initialised, the
  link is dispatched automatically — no Enter required.
- A warm link dispatches from an **idle Title or Main Menu**, after any substate or
  transition closes. Every other state defers: gameplay, pause, editors, Options, Mods,
  Story, Freeplay, Credits. Return to the Main Menu to consume it. This is deliberate —
  it prevents an incoming link from destroying an editing or settings session.
- One pending destination is kept in memory; the latest valid link wins, it is consumed
  once, invalid links do not clear it, and nothing is persisted across process death.

### Security boundary

Links never install or enable mods, load a filesystem path, run scripts or commands,
change preferences, download content, or start a song. Version 2's `song` route is the
one addition to that list, and it only starts a chart the normal lookup already found;
`phoenix://diagnostics` sits on the strict side of it — a read-only page that takes no
parameters, resolves nothing and writes nothing. `phoenix://input` sits there too: no
parameters, and a page that only shows what the input devices report.

## Per-platform registration

### Android

The manifest template advertises a browsable `ACTION_VIEW` filter for `phoenix`. Lime's
activity is exported and `singleTask` — keep both when customising the build.
`MainActivity` forwards cold intents in `onCreate` and warm intents in `onNewIntent`;
`PhoenixCore` buffers cold URLs and `DeepLinks` subscribes through
`AndroidIntents.subscribeDeepLink`.

```bash
adb shell am force-stop quack.fnf.phoenix
adb shell am start -W -a android.intent.action.VIEW -d 'phoenix://menu/misc' quack.fnf.phoenix
```

### iOS

`project.hxp` enables the repo's iOS templates; the Info.plist override adds
`CFBundleURLTypes` / `CFBundleURLSchemes` for `phoenix`. The Lime fork's SDL UIKit
delegate forwards `openURL` as `SDL_DROPFILE`, which Lime exposes as
`Application.current.window.onDropFile` — `DeepLinks` installs that listener in `Main`
and ignores ordinary file drops.

```bash
xcrun simctl terminate booted quack.fnf.phoenix
xcrun simctl openurl booted 'phoenix://menu/misc'
```

### Windows

Registration is **explicit, per-user and player-driven**. `DeepLinks.init()` only scans
the launch arguments; it never touches the registry. **Options → Misc → Toggle Deeplink**
(the `deeplinkEnabled` preference) does the writing: checking runs
`uri/Register-PhoenixURI.ps1` against the running executable and rolls the checkbox back
when another copy owns the scheme, unchecking deletes `HKCU\Software\Classes\phoenix`.
The choice is remembered, but a later launch neither re-applies, re-verifies nor removes
anything. Both scripts (source in `setup/uri/`) ship next to the executable, and because
protocol launches do not inherit a sane working directory, the engine resets the CWD to
the executable's folder when a link is pending. The whole path is behind
`#if (windows && sys)`, so browser and mobile builds compile without any of it.

## Tests

* `bash tests/uri/run.sh` — runs `tests/uri/TestPhoenixURI.hx` in the Haxe
  interpreter with the parser isolated from `source/import.hx`: every route and
  alias, the case and slash rules, injection-shaped input, the size limits, and the
  `phoenix://diagnostics` and `phoenix://input` contracts (both spellings accepted,
  parameters and sub-paths rejected).
* `bash tests/haxe/run-diagnostics-report.sh` — compiles and runs `backend.DiagnosticsReport`
  and `states.DiagnosticsState` against `tests/haxe/stubs/diagnostics`: the seven
  sections in order, the padded value column, `not reported here` where a target
  cannot know, the ten-line log tail, a throwing data source costing one row, and on
  the page side the scroll bounds, the clipboard contents, the `R` refresh, the
  single-shot exit and the camera being released on `destroy`.
* `bash tests/haxe/run-input-test.sh` — `backend.InputTestLogic` on its own (rollover
  counters, chord and frame statistics, short taps, the history ring, slot reuse for
  fingers, the hold-to-leave rules), then `states.InputTestState` against
  `tests/haxe/stubs/input-test`, driven by key events, pads, fingers, a mouse and a
  scripted clock: what each panel shows, that no tap or chord closes the page, every
  way out, focus loss, resizing, and that the listeners, the volume keys and the
  pointer are handed back on `destroy`.
* `bash tests/haxe/run-input-test-typecheck.sh` — compiles the same page against the
  real Flixel, flixel-addons, OpenFL and Lime sources for html5, desktop and Android
  when they are installed, and prints `SKIP` otherwise. It is not part of CI.
* `python3 -m unittest tests.test_deeplink_diagnostics` — source guards for what the
  compiler cannot see: only the idle menu states dispatch, the diagnostics path
  writes nothing, and `URI.MD` and this page keep telling the same story.

Full specification: [`URI.MD`](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/blob/main/URI.MD).
