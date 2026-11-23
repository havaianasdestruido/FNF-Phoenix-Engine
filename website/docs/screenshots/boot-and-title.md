---
title: Boot and title screens
sidebar_position: 1
description: StartupState, TitleState, FlashingState, OutdatedState and ErrorState — the screens before and around the main menu.
---

# Boot and title screens

## `StartupState` — engine splash

`source/states/StartupState.hx`. The first `MusicBeatState` after `InitState` decides
whether to show the splash at all: `InitState` skips straight to `LoadingState` when
`disableSplash` is set, and `-DFREEPLAY` / `-DMENU` builds skip the whole boot chain
(`backend.LaunchState`).

The splash is the boot preloader's logo (`assets/preload/images/phoenix_logo.png`)
over a solid background with a pink `0xFFFF16D2` progress bar, then an optional startup
video from `assets/splash/videos/` if the build has `VIDEOS_ALLOWED`. Content-stripped
builds ship no splash videos, so the logo is the whole screen there.

## `TitleState` — title screen

`source/states/TitleState.hx`; layout numbers live in
`assets/preload/images/gfDanceTitle.json`.

| JSON field | Meaning |
|---|---|
| `titlex`, `titley` | `logoBumpin` position (`-150`, `1500` — the logo artwork bleeds way off screen) |
| `gfx`, `gfy` | the optional dancing GF sprite (`gfDanceTitle`) |
| `startx`, `starty` | the `titleEnter` prompt |
| `backgroundSprite` | optional full-screen background; empty means black |
| `bpm` | menu music tempo the title bops to |

`titleEnter` has three animations: `ENTER IDLE`, `ENTER PRESSED` and `ENTER FREEZE`
(used instead of `PRESSED` when `ClientPrefs.flashing` is off), so the prompt matches the
rest of the game's flashing policy.

The title is also where a lot of one-off work happens: an update check through
`CHECK_FOR_UPDATES`, the interrupted-song resume `Prompt` (built from the session log),
`TITLE_SCREEN_EASTER_EGG`, deeplink dispatch and the first `Paths.playMenuMusic(true)`.

## `FlashingState` — photosensitivity warning

`source/states/FlashingState.hx` is one centered `FlxText` in `VCR OSD Mono` 32px, white
on black, with `ENTER` to continue. It only appears on a first run or after the warning
was reset in Options; the title screen links to it, not the boot chain.

## `OutdatedState` — update notice

`source/states/OutdatedState.hx` is only reached from `TitleState` when
`CHECK_FOR_UPDATES` is compiled in and the release feed reports a newer tag. It shows the
warning, the changelog body from the release notes, and the Yes/No choice that opens the
release page. Builds with `-Dno-version-check`-style local setups never see it.

## `ErrorState` — recoverable error screen

`source/states/ErrorState.hx` is the friendly error screen the menus use instead of
crashing: a message plus two callbacks, e.g. Freeplay with no weeks offers "open the Week
Editor" or "back to the Main Menu". It is distinct from the crash handler
(`backend.CrashHandler`), which kills the process and writes a crash bundle.

:::note[Where to see the real thing]

These five screens have no interactive state to inspect, which makes them the easiest to
capture for real: launch the game, press `F2` on each (or take the screenshot with the OS
tool) at 1280×720. `F2` writes to `./screenshots/` via `backend.SSPlugin`.
:::
