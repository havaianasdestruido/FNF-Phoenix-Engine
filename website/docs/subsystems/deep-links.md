---
title: Deep links (phoenix://)
sidebar_position: 10
description: The custom URI scheme — routes, grammar, dispatch rules, the read-only diagnostics link and per-platform registration.
---

# Deep links — `phoenix://`

Phoenix uses the custom scheme **`phoenix`** on Android, iOS and Windows, so a web
page or another app can open a specific menu:

```html
<a href="phoenix://menu/misc">Open Phoenix Misc settings</a>
<a href="phoenix://mods">Open Phoenix Mods</a>
<a href="phoenix://diagnostics">Show the read-only diagnostics page</a>
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
| `phoenix://replay/<id>` | reserved — reports "not implemented" rather than pretending |

Segment counts are exact, so `phoenix://song` or `phoenix://diagnostics/all` are
invalid links, ignored without a popup.

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
`C`/`A` copies the text, `ESC`/`B` returns to the Main Menu, and absolute paths
can carry the player's username, so the footer says to redact before posting.
Nothing is ever uploaded.

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
```

## Implementation

Four modules in `backend/deeplink/`:

- **`PhoenixURI`** — `parse(uri)` validates the v1 grammar and returns an
  allowlisted route string; `parseEx(uri)` returns a structured `ParsedURI` for
  the version 2 hosts. Neither resolves a class from external text.
- **`URIKind` / `ParsedURI`** — the route enum (`Menu`, `Screen`, `Song`, `Mod`,
  `Diagnostics`, `Replay`) and its query map.
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
parameters, resolves nothing and writes nothing.

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

* `python3 tests/uri/run.py` — runs `tests/uri/TestPhoenixURI.hx` in the Haxe
  interpreter with the parser isolated from `source/import.hx`: every route and
  alias, the case and slash rules, injection-shaped input, the size limits, and the
  `phoenix://diagnostics` contract (both spellings accepted, parameters rejected).
* `bash tests/haxe/run-diagnostics-report.sh` — compiles and runs `backend.DiagnosticsReport`
  and `states.DiagnosticsState` against `tests/haxe/stubs/diagnostics`: the seven
  sections in order, the padded value column, `not reported here` where a target
  cannot know, the ten-line log tail, a throwing data source costing one row, and on
  the page side the scroll bounds, the clipboard contents, the `R` refresh, the
  single-shot exit and the camera being released on `destroy`.
* `python3 -m unittest tests.test_deeplink_diagnostics` — source guards for what the
  compiler cannot see: only the idle menu states dispatch, the diagnostics path
  writes nothing, and `URI.MD` and this page keep telling the same story.

Full specification: [`URI.MD`](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/blob/main/URI.MD).
