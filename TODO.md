# Phoenix Engine — TODO / Roadmap (large feature & cleanup backlog)

Generated from full repo audit. Priority: `[P0]` critical/blocker, `[P1]` high, `[P2]` medium, `[P3]` nice-to-have. Sections grouped by system. Bold = biggest payoff. Section 12 is a filtered Codename Engine (CNE) comparison: only CNE differences that Phoenix has **not** implemented (or has only partially implemented) are listed there.

Sections 13–20 are a second backlog pass written against the current tree. Every entry there was checked against §0–12: anything already listed is **cross-referenced, not repeated**, and each item names the file/behaviour that proves it is still missing. They target Phoenix's stated identity — low-end devices, easy Lua/Python/HScript modding, Android-first platform work and Psych/JS compatibility — rather than generic engine cloning.

_quick reminder that everything i say here that is a "port" of [x] feature of the [y] engine, i will port WITH THE APROPRIATED CREDITS!!!_

_every feature ported MUST be enabled by default (unless specified beforehand) and MUST have a toggle to enable/disable or to change its options_

Examples of options:

- Colorful [thing].
- - Must make the color be customizable, or atleast have some presets

_keep in mind i will only port stuff if their license is compatible with mine (Apache 2.0 AFAIK)_

_i accept suggestions too_

---

## 0. PRIORITY-ish / UNCATEGORIZED

- FIX `BF-CLICKER`!!! _(i wont release v0.0.1 UNTIL i fix this)_

- FIX UPDATE SCREEN TO USE THIS REPO INSTEAD OF JSE!!! _(i also wont release v0.0.1 UNTIL i fix this)_

- FIX IN-GAME ENGINE WATERMARK VERSIONING (its 0.3.2 instead or the real one) _(i ALSO wont release v0.0.1 UNTIL i fix this)_

- Windows 7 support by patching some libs _(prob impossible but whatever)_

- COMPRESS ALL IMAGES **AND FIX ITS XML SPRITESHEET COORDINATES!!!!!!!!!!** to 2 times lower res _(for low end devices, but will prob be low-res by default since its the main Phoenix engine focus)_

- Rewrite all code from [x] to [y]:
  - C -> Rust
  - Java -> Kotlin
  - Objective-C -> Swift (maybe???)
  - JavaScript -> TypeScript (only for complex code bits)

- Be able to change you character to any from the game + from loaded mods

- Be able to change your noteskin to any from the engine + from loaded mods

- FIX HTML5/WEB!!!

### Overly complex stuff that would take weeks of work (but that would be 100% worth the time)

- Making the user be able to change ALL game text to a custom font.

- Adding a built-in mod download support (gamebanana browser & gamejolt) (just like GMod)
- - (edit: just found out this [https://github.com/miksel1/FNF-ScrewedEngine/blob/main/source/gamejolt/GJClient.hx](https://github.com/miksel1/FNF-ScrewedEngine/blob/main/source/gamejolt/GJClient.hx) snippet from Screwed Engine (JSE grandparent))

- Port some of the [Mic'd Up! engine](https://github.com/Verwex/Funkin-Mic-d-Up-SC) features:
- - Their new charts (Noob & Expert & INSANE)
  - spinning vinil disk freeplay thing
  - game filter thing (dautonic stuff and other filster like the "gameboy" one and the "invert" one)
  - their cool icons
  - the difficult icons redrawed
  - ~~moving checkerboard bg thing~~ **DONE** — `objects.MovingCheckerboard`, enabled by default with a live toggle in Options -> Visuals and UI;
    used across the menu flow with frame-rate-independent movement and in-game Mic'd Up!/Verwex credit. See
    [`docs/MENU_CHECKERBOARD.md`](docs/MENU_CHECKERBOARD.md).
  - cool modes
  - - Marathon
    - Endless
  - brightness & gamma option
  - Engine logo watermark
  - ~~early & late ratings~~ **DONE** — `play.helpers.HitTiming` + `objects.TimingPopup`, opt-in `earlyLateRatings` / `earlyLateDeadzone` in Options -> Optimization, `hitTiming`/`noteDiff` published to Lua/Python/HScript, see [`docs/EARLY_LATE.md`](docs/EARLY_LATE.md) and `bash tests/haxe/run-hit-timing.sh`.
  - CHAOS mode, Dual Arrow mode, Dual CHAOS mode
  - micd up ranking thing (S, A, etc..)
 
- Port these cool stuff from Troll Engine:
- - [source/funkin/api/src/memory.cpp
](https://github.com/troll-slaiyers/FNF-Troll-Engine/blob/main/source/funkin/api/src/memory.cpp) (phoenix engine implmentation is not as complete as this one)
- - [refreshrate.cpp](https://github.com/troll-slaiyers/FNF-Troll-Engine/blob/main/source/funkin/api/src/refreshrate.cpp) (util for Linux users)
- - [darkmode.cpp](https://github.com/troll-slaiyers/FNF-Troll-Engine/blob/main/source/funkin/api/src/darkmode.cpp)
  - [source/funkin/api/Github.hx](https://github.com/troll-slaiyers/FNF-Troll-Engine/blob/main/source/funkin/api/Github.hx) - Utils for in-game update screen and other social stuff
  - https://github.com/troll-slaiyers/FNF-Troll-Engine/tree/main/flixel/flixel-ui/img - port their dark flixel-ui system too.

- Port these cool stuff from Doido Engine:
- - ~~[DistantNoteShader.hx](https://github.com/DoidoTeam/FNF-Doido-Engine/blob/main/source/backend/shaders/DistantNoteShader.hx) - cool note shader thing~~ **DONE** (#245) — `shaders.DistantNoteShader` + `shaders.DistantNoteEffect`, player toggle in Options -> Visuals and UI (`ClientPrefs.distantNotes`), see [`docs/DISTANT_NOTES.md`](docs/DISTANT_NOTES.md) and [`docs/SHADERS.md`](docs/SHADERS.md).
  - cool looking loading screen
  - ~~clear ui (just FPT on top and ram below it)~~ **DONE** (#245) — compact FPS overlay; `legacyFPSUI` in Options -> Visuals and UI restores the old one.
  - settings fully centered instead of being on the left
  - "-[NUMBER]" when you miss note, accumulative and stays red
  - List of available flags
    - ~~-debug can build the game in debug mode. This enables many debug features, such as the FlxDebugger and debugging through VSCode.~~ **DONE** — already handled by Lime (`build/debug/`, `MAIN_DEBUG`, FlxDebugger); now documented in BUILDING.md ("Launch and debug flags").
    - ~~-DFREEPLAY and -DMENU launch the game directly in the Freeplay and MainMenu states, respectively. These can't be used together.~~ **DONE** — `backend.LaunchState` + `states.InitState`, `project.hxp` aborts the build when both are set, tested by `bash tests/haxe/run-launch-state.sh`.
   
- Port the C++ GDI payloads from Slushi Engine:
- - https://github.com/Slushi-Github/Slushi-Engine/tree/260410345801c84ac188e0b3c73e6b97e94de59c/funkinscsource/slushi/windows
 
- add mario madness modifiers: https://github.com/Dewott2501/Mario-Madness/tree/main/source/modchart/modifiers
#### Rebuilding how the MODDING API works and adjusting it to be able to also support other languages (Common Modding API)

Should include exposing almost ALL game screens thought the Modding API. (By screen I mean like the Freeplay page, Mods page, etc.)

- Should contain all in-game screens. (only exclude critical ones like the update screen and the mods picker screen)

- Mods should be able to change assets placement, size, change its assets, or even just toggle it off

- Should not bloat the whole engine

- Making 99,9% of all engine aspects modifiable by softmods. (Python & Lua)

- Adding all upstream-upstream Psych Engine 1.0 new features/commits, keeping in mind that our codebase was refactored.

- Resizing ALL backgrounds to half it's size and just zoom them 2x (gama baja optimization)

- Adjusting for lower Android SDK target (I want to play on my Android 5.0 phone), but only on a new experimental branch.

## 1. BUILD / TOOLCHAIN (all targets green)

- **[P0] HashLink target blocked.** `lime.hdll` missing locally, HL wasn't verifiable, HL agent dead-ended. Install a compatible HashLink (`lime.hdll` + `lime-hdiowrap`), fix any compile errors, re-enable the `hl` CI job in `.github/workflows/main.yml`. ([#63](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/63))
- **[P0] CI Android build.** ([#64](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/64)) Local Android can't be validated: NDK **28.1.13356709** fails on `aarch64-linux-android-strip` (NDK 28 ships only `llvm-strip.exe`; wrapper copy was made but build still fails) and NDK 28 libc++ has a `__posix_l_fallback.h` redefinition bug. Android CI now explicitly pins NDK **27.0.12077973 (r27)** in both workflows; the next CI result must confirm the Android build and merged manifest. Options:
  - Install NDK 27.0.12077973 locally (matches CI) to reproduce `#if mobile` errors faithfully.
  - Or fix the NDK 28 header conflict (locale redefinition) instead of pinning old NDK.
  - Re-run android build to green, then commit + push.
- **[P1] macOS/Linux `sendFakeMsgBox` are TODO** (`source/backend/PlatformUtil.hx:10-11`, `source/utils/PlatformUtilNative.hx:86`). Add native `osascript`/`zenity`/`kdialog`-based implementations so crash dialogs work on all desktops; remove the `trace('not available')` stubs. ([#66](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/66))
- **[P3] Remove dead Flash/Air code paths** — `officialBuild` feature flag never applied (`project.hxp`), unused `renderAll`/`ULTRA_OPTIMIZED` experiments, `WindowColorMode` flash stubs (trace-only). ([#78](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/78))

## 2. GAMEPLAY / PSYCH SYNC (P3 imports)

- **[P3] Missing funkin.vis cross-target** — `SpectralAnalyzer` patched; check hacking shaders (`Glitch`, `Chromatic`, `Malmo`?) compile on flash/air (`#if desktop` guard audit, §9). ([#79](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/79))

### 2.1. 4th WALL BREAKING

**IMPLEMENTED** behind the opt-in `-DMETA_HORROR` define: `backend.MetaHorror`
plus the Lua / Python / HScript bridges. Upstream system effects (wallpaper,
taskbar, other windows, window styles, system volume, mouse/keyboard, file
spoofing) come from the #94 port; the second pass added the "it knows you"
effects (desktop username, machine uptime, local clock, launch counter),
persistent mod counters in their own save slot, clipboard access, window title
rewriting, always-on-top, taskbar flashing, open-window titles and a
whole-desktop screenshot. See [`docs/META_HORROR.md`](docs/META_HORROR.md).

Remaining:

- **[P3] Node-level audio effects.** Per-application (session) volume instead of
  only the master endpoint, so the game can duck the player's music player
  rather than muting everything.
- **[P3] Fake "your system is updating" overlays.** A full-screen borderless
  window drawn over the desktop with click-through off; needs the transparent
  window work in `docs/TRANSPARENT_WINDOW.md` to be reliable in fullscreen.
- **[P3] Reading the desktop wallpaper into the game.** `setWallpaper` and
  `restoreWallpaper` exist, but there is no "show the player's own wallpaper as
  the stage background" helper.
- **[P3] Launch warning UI.** The define is documented as opt-in and mods are
  told to warn players, but the engine does not force a one-time in-game
  warning when a mod calls a desktop effect. A settings toggle ("allow 4th-wall
  effects") would make the trust boundary explicit.

## 3. PLATFORM

- **[P2] Fix fullscreen issues on Android (and other OSes maybe)** - Phones with some cutouts currently don't launch the game with 100% fullscreen, create a toggle that can switch between "Respect cut-out" or "Real Fullscreen". Im pretty much sure this will envolve Native Kotlin/Java in order to work. ([#75](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/75))
- **[P3] iOS** — likely needs `#if ios` nuances (video/hxvlc below). ([#80](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/80))

### WINDOWS / LOW-LEVEL WINDOW MANAGEMENT — IMPLEMENTED

The native window-manipulation inventory below is implemented behind the shared,
process-checked `Windows` / `backend.WindowNative` bridge. See
[`docs/WINDOWS.md`](docs/WINDOWS.md) for the public API, platform limits, and
validation commands. The original inventory is retained as an API reference:

| # | Feature / source code | APIs / mechanisms | What it does |
|---|---|---|---|
| 1 | Window transparency — `Windows.__setWindowTransparencyAlpha()`, `Windows.__setWindowTransparencyColor()`, and `PlatformUtil.setWindowOpacity()` | `SetWindowLong`, `WS_EX_LAYERED`, `SetLayeredWindowAttributes` | Changes native window styles and applies alpha transparency or color-key transparency. Related: transparent-window support is also tracked in §2.1. |
| 2 | Dark title bar/frame — `Windows.setDarkMode()` and `system.Window.setDarkMode()` | `DwmSetWindowAttribute`, `DWMWA_USE_IMMERSIVE_DARK_MODE` | Requests a dark frame from DWM; this does not change the game's rendered graphics. |
| 3 | Window border and title-bar colors — `Windows.setWindowBorderColor()` and `setWindowTitleColor()` | `DwmSetWindowAttribute`, attributes 34, 35, and 36 | Customizes the border, title-bar, and title-bar text colors, subject to Windows-version support. |
| 4 | Close-button control — `Windows.setCloseButtonEnabled()` | `GetSystemMenu`, `EnableMenuItem`, `SC_CLOSE` | Enables or disables the native Close command in the system menu. |
| 5 | Window blur — `Windows.test()` | `DwmEnableBlurBehindWindow`, `DWM_BLURBEHIND` | Requests a DWM-provided blur effect. This is an older API and its effect can vary on modern Windows versions. |
| 6 | Windows 11 window corners — `Main.setupGame()` | `DwmSetWindowAttribute`, `DWMWA_WINDOW_CORNER_PREFERENCE` | When `NO_W11_CORNERS` is defined, requests square (non-rounded) window corners. |
| 7 | Native window lookup/access — `Windows.setDarkMode()`, `setWindowBorderColor()`, `setWindowTitleColor()`, and related methods | `HWND`, `GetActiveWindow`, `GetForegroundWindow`, `FindWindowA`, `FindWindowExA` | Finds window handles for native operations. Selecting the wrong `HWND` can affect another window or cause the operation to have no effect. |
| 8 | Lime border toggling — `system.Window.darkMode()` | `Application.current.window.borderless` | Switches the window between bordered and borderless states to try to force a visual refresh, using Lime's higher-level API rather than the Win32 calls above. |
| 9 | Native dialog boxes — `Dialog.showYesNoWindows()`, `Windows.alert()`, and `CoolUtil.sendMsgBox()` | `MessageBoxW`, `MessageBoxA`, `MultiByteToWideChar` | Opens native Windows dialogs; `Dialog` converts UTF-8 text to UTF-16 before calling the Unicode API. |
| 10 | Native Windows notifications — `Windows.sendWindowsNotification()` and `PlatformUtil.sendNotification()` | `NOTIFYICONDATA`, `Shell_NotifyIcon` | Interacts with the Windows notification-area icon and notification infrastructure. |

## 4. VIDEO / AUDIO

- **[P3] Flash MP3 24/48kHz embed warnings** — 3 warnings, harmless, but notes in `BUILDING.md` claim "zero warnings" post-fix; reconcile. ([#82](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/82))
- **[P3] Offsync long-session** — `MusicBeatState`/`Conductor` saved to same-tick; watch for drift on `sustain` notes w/ `playbackRate != 1`. ([#83](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/83))

## 5. DEBUG / LOGGING

- **[P1] `trace()` spam in production hot paths** (Flash/AIR): `source/backend/Paths.hx:61` (`trace(defaultSkin)`), `:563/:866` `trace('oh no its returning null NOOOO')` inside asset fallback — this is on EVERY lookup. Wrap in `#if MAIN_DEBUG` or a `quiet` flag; these belong in debug builds only. ([#68](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/68))
- **[P3] Leftover stray traces** — `MusicPlayer.hx:100` `trace('Time: ...')` on K key; `WeekEditorState`/`DialogueEditor` `trace("file saved")`. ([#84](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/84))
- **[P3] `DiscordClient.hx:55-56` cast-dep on success** — `request[0].username` may be null on AIR (no hxdiscord_rpc); guard. ([#85](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/85))

## 6. SECURITY

- **[P0] Path traversal** — `WeekData`, `Mods`, `SSPlugin` read user JSON; `Paths.modsJson` splices `songName` into paths. `CoolUtil` mod asset walker uses `FileSystem` unguarded non-sys target? Audit brings up `#if (!target)` correctness. Ensure mod names are sanitized (`..`/absolute) before `FileSystem.exists`. ([#65](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/65))
- **[P1] CrashHandler ref** — `did` handler writes logs into `logs/` w/ `Date.now()` filename; on Android no `sys` — verify guard. ([#70](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/70))
- **[P3] No signature/webhook secrets** — `ChartingSaveLoad`/`WeekData` parse `JSON` without try/catch around `File.getContent` (some are). ([#86](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/86))

## 7. MODDING / SCRIPTS

- **[P1] hscript/Lua mod API parity** — `PsychLua` (`FunkinLua`, `HScript`) methods work, but `#if HSCRIPT_ALLOWED`/`LUA_ALLOWED` only set on `desktop !web !flash !air` (project.hxp:418). No scripting on AIR/Flash — document as intended or shim. ([#71](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/71))
- **[P3] Python (`hython`) not wired everywhere** — check callbacks exposed. ([#87](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/87))

## 8. PERFORMANCE / MEMORY

- **[P3] `FlxG.watch` in FPSCounter** — verify only debug. ([#89](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/89))
- **[P3] `cast` / `Reflect.field` in per-frame paths** — `ChartChartingUI`/`Conductor` use `Reflect.field(ClientPrefs, ...)` in window accessors; cache static before loop. ([#90](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/90))

## 9. GUARD AUDIT — RESOLVED

The remaining desktop/AIR candidates from the guard audit are now either narrowed or documented; the desktop-only resolution and waveform paths use `#if (desktop && !air)`. ([#91](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/91))

| Site | Decision |
|---|---|
| `source/backend/CoolUtil.hx` (`resW`/`resH`/`resetResScale`) | Narrowed to `desktop && !air`; these helpers exist only for native resizable windows. |
| `source/play/PlayState.hx` (render-mode resolution) | Narrowed to `desktop && !air`; AIR cannot use the native window-resize path. |
| `source/options/GraphicsSettingsSubState.hx` (resolution option/callback) | Narrowed to `desktop && !air`; AIR keeps the cross-target framerate setting, but does not offer window resolution changes. `OptionsState` retains its `desktop` keyboard guard because the debug key sequence also works on AIR. |
| `source/backend/FunkinGame.hx` | Keep the desktop constructor to forward `startFullscreen` to `FlxGame`; restrict the custom keyboard/window shortcut and its imports to `desktop && !air`. |

## 10. CI / REPO HYGIENE

- **[P1] .github CI android emulator `CopyState`** — same 2 fixes; confirm CI picks them via `1a8a48d4`+. ([#72](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/72))
- **[P3] BUILDING.md "0 warnings" vs 3 MP3 warnings** — fix text. ([#92](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/92))

## 11. ANDROID NATIVE / PLATFORM INTEGRATION

### MEDIA / AUDIO

- **[P3] Media3 progress vs. engine clock.** `PlayStateAndroidMedia` refreshes the session once per second (`updateTimer`) and reports `PlayState.playbackRate`, so lock-screen/Android Auto progress interpolates in 1 s steps and drifts during long rate changes. Push a rate-aware position (or let the native session interpolate from `PlaybackState`) and assert it in `PhoenixMediaBridgeStateTest`.

### LIFECYCLE / BACKGROUND

- **[P2] Make the process-death recovery blob an actual resume.** `PlayStateAndroidMedia.hx:88` persists `{type, song, difficulty, difficulties, mod}` and `TitleState.checkRecoveryState()` only knows how to restart that chart from the start. Store `songPosition`, `playbackRate`, practice/health state and an engine version, so "Resume" continues where the OS killed the process and a blob written by another build is rejected instead of half-applied.

### INPUT / CONTROLLERS


### DISPLAY / RENDERING


### PERFORMANCE / DEVICE STATE

- **[P2] ~~Android thermal status API~~ REMOVED** — Intentionally not implemented: thermal monitoring offers little benefit for a game of FNF's scope, and `PowerManager.ThermalStatusListener` did not compile under the project's Android toolchain.

### FILES / MODS

### INTENTS / EXTERNAL INTEGRATION

- **[P3] Phoenix URI / deep-link system** — PARTIAL: Android registers the `phoenix://` scheme and forwards intents (`PhoenixCore.handleNewIntent` → `AndroidIntents.onDeepLink`); per-screen routing UI still to do — Add a platform-independent URI routing system for directly opening songs, charts, mods, replays, menus, and other engine resources (e.g. `phoenix://song/bopeebo?difficulty=hard`, `phoenix://mod/whitty/song/lo-fight`, `phoenix://screen/freeplay`). Android should register the `phoenix://` scheme and forward incoming intents to Haxe; expose parsed URI data to Haxe/Lua/HScript and keep the system extensible for other platforms. ([#93](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/93))

### NOTIFICATIONS

- **[P3] Finish or remove `AndroidNotification`.** Done: wired to opt-in events instead of being deleted. `notifyEvent(id, title, text)` posts only when the new `androidNotifications` pref (Options → Mobile Options → "Event Notifications", default off) is enabled; toggling it on requests POST_NOTIFICATIONS on Android 13+ (never unattended at startup). Events wired: "chart backup saved" (`ChartingSaveLoad.saveLevel` autosave, fixed `ID_CHART_BACKUP`) and "crash log saved" (`CrashHandler`, fixed `ID_CRASH_LOG`); both reuse a fixed id with `setOnlyAlertOnce` so repeats update instead of stacking. "Update available" stays unwired because the §12.6 auto-updater is still a non-goal.

### DISCORD / EXTERNAL SERVICES

- **[P3] Discord RPC reconnect.** `DiscordClient.check()` runs once from `ClientPrefs.loadPrefs()`, so if Discord starts after the game or restarts, presence stays off until Phoenix is relaunched. Add bounded reconnect/backoff on `onDisconnected` (`DiscordClient.hx:95`) with a visible toggle, and keep the `request[0].username` AIR guard from §5 #85.

### NATIVE BRIDGE / ARCHITECTURE

- **[P2] Bridge contract check.** There are 64 `JNI.createStaticMethod` sites in `source/android/platform/`, each binding a Java method by string name *and* signature. A Java rename or signature edit still compiles and fails only at runtime as a silent no-op. Add a test (next to `tests/java/.../PhoenixMediaBridgeStateTest`) or a generated table that parses both sides and fails CI on a mismatch, then list every method in `docs/ANDROID_PLATFORM.md`.

## 12. CODENAME ENGINE (CNE) PARITY — DIFFERENCES NOT YET IMPLEMENTED

Added from the supplied CNE-vs-vanilla/Psych comparison, filtered against the current tree. CNE-like features Phoenix already has (runtime Lua/Python, note skins, hxvlc video, Discord RPC, `funkin.vis`, Aseprite/multi-atlas support, custom volume tray, Windows titlebar colors, opponent/both-sides gameplay, P1/P2 vocal split, etc.) are intentionally omitted. Priorities reflect payoff for Phoenix, not blind CNE cloning; anything marked **breaking** needs an importer/compatibility flag before it lands.

### 12.1 SCRIPTING & FULL-ENGINE SOFTCODING

- **[P1] Scripted states/substates.** Done: `psychlua.StateScripts` loads `data/states/<Name>.hx` (also `.hscript`/`.hxs`) onto every `MusicBeatState`/`MusicBeatSubstate`. `states.ModState` / `states.substates.ModSubState` are full replacements (`switchCustomState` / `openModSubState`). `CustomSubstate` still fires PlayState `onCustomSubstate*` hooks and now also hosts a named state script. See `website/docs/modding/scripted-states.md`.
- **[P1] Cancellable event-object API.** Current script hooks pass raw arguments and use `Function_Stop` returns. Add CNE-style event objects (`event.note`, `event.score`, `event.cancel()`), `onGamePause` with exclusion list, `onBopZoom`, `onSplashShown`, `onHealthIconAnimChange`, input-system events, and stage/character data events.
- **[P1] Missing script scopes.** Add scripted transitions (`MusicBeatTransition` equivalent), shader scripts, custom options/controls scripts, dialogue/cutscene scripts, and scripted asset libraries. Existing global/song/character/stage/notetype/event scripts do not cover these.
- **[P2] HScript module system.** PARTIAL (standalone HScript landed native `import`, public/static variables, `addHaxeLibrary()` and `PlayState.variables` sharing): still missing mod-root modules/redirects and ScriptPack-like sharing.
- **[P2] Managed `Script.fromString`-style runtime scripts.** PARTIAL: `HScript.fromFile(name, ?code)` creates an owned instance (tracked in `PlayState.hscriptArray`, `call`/`set`/`stop` lifecycle) from a file or a raw string; a general cross-language runtime-script manager (Lua/Python too, outside PlayState) is still missing.
- **[P2] Script hot reload.** Mods menu reload currently restarts/reloads states through `ModsMenuHelpers.reload`; CNE-style test builds can hot-swap scripts without restarting the relevant context.
- **[P2] Python parity for character scripts.** `source/play/helpers/PlayStateCharacters.hx:46` only loads `characters/<name>.lua`; songs/stages/events/notetypes already support Python.
- **[P3] NDLL / compiled native scripting.** No `.ndll` loader, bridge, or API exists.
- **[P3] Continue PlayState decomposition.** Phoenix already split helpers, but CNE's rewritten gameplay core is much smaller; see §8 for the existing perf/allocation backlog.

### 12.2 DATA, ASSET & FILE STRUCTURE

- **[P2] XML definitions for characters, stages, weeks, and dialogue.** Phoenix still uses Psych-style JSON (`assets/preload/characters/*.json`, `assets/preload/stages/*.json`, `assets/preload/weeks/*.json`). The only XML assets are Sparrow atlases/UI sheets.
- **[P2] CNE song folder layout.** Need `songs/<name>/meta.json`, `songs/<name>/charts/<difficulty>.json`, `songs/<name>/song/`, and `songs/<name>/scripts/`. Phoenix uses `data/<song>/<song>-<difficulty>.json` plus `assets/songs/<song>/Inst.*` / `Voices.*`.
- **[P2] `meta.json` metadata.** Add a real metadata file that syncs freeplay/difficulties/charts and carries custom fields.
- **[P2] Global charts folder.** CNE supports global `data/charts/`; Phoenix only resolves per-song JSON paths.
- **[P2] Custom chart/character properties.** Expose CNE-style `SONG.meta.customValues` and `char.extras`; current `SwagSong`/`CharacterFile` use fixed fields.
- **[P2] True song variations.** `specialAudioName` only swaps an audio suffix; add variation metadata, chart selection, and freeplay preview behavior.
- **[P2] Extra audio formats (flac/opus/wav).** Done: Ogg is the engine's container on every target except Flash/AIR, and `Paths.SOUND_EXTENSIONS` resolves `.ogg` → `.mp3` per file at runtime (`Paths.modsSounds`, `Paths.resolveSoundAsset`, `Paths.returnSound`), so no track ships twice. Remaining: flac/opus/wav support, which is now just another entry in that list plus a decoder check per target.
- **[P2] Multi-extension images/paths.** `Paths.image()` hardcodes `.png`; CNE supports multiple image extensions through path resolution.
- **[P2] Unlimited vocals per strumline.** Phoenix supports separate P1/P2 vocal files, but not CNE's arbitrary per-strumline vocals.
- **[P2] Declarative stage node graph.** Stage JSON only stores camera/character positions. Add XML/script nodes for sprites, solids, characters, ratings/combo, zoom/scroll factors, beat intervals, colors/skew/scale, and stage extensions.
- **[P2] Universal asset replacement.** Mod folders currently override a limited set of categories (`Mods.ignoreModFolders` + `Paths.modFolders`). CNE can replace essentially every asset; Phoenix cannot override arbitrary engine/Flixel assets at runtime.
- **[P3] Per-character extras.** CNE character data can define `gameOverChar` and custom extras; Phoenix currently keeps game-over character at song level and has no generic extras map.
- **[P3] Music BPM INIs.** No CNE-style `.ini` metadata for music files.
- **[P3] `.pack` bundles.** No packer/loader for softcoded events/notetypes/cutscenes/assets.

### 12.3 EDITORS & LIVE TOOLS

- **[P1] Multi-strumline Charter.** `PlayState` and `ChartingState` are built around fixed player/opponent strumlines. Add unlimited strumlines, GF/additional strumlines, multiple characters per strumline, and multi-icon support.
- **[P2] Simultaneous multi-waveform display.** `ChartingUIWaveform.hx:51-52` selects only one waveform source (inst, player vocals, or opponent vocals) at a time.
- **[P2] Strumline data editor.** Add editable strumline type (Player/Opponent/Additional), HUD ratio/position, scale, and stage positioning.
- **[P2] Event packing/importing (`.pack`).** Not implemented.
- **[P2] CNE built-in event parity.** Existing events include camera zoom/scroll/animation/property basics, but not CNE's Camera Movement/Modulo/Flash, richer BPM-change handling, HScript Call, and related event set.
- **[P2] Custom property editing in Charter.** No UI for custom chart/meta properties.
- **[P2] In-engine song/difficulty creation.** Difficulty is just a text field; add proper song/difficulty scaffolding and asset creation.
- **[P2] Folder/subfolder selectors.** Character/editor dropdowns read flat folders; add recursive subfolder support.
- **[P2] Stage Editor.** `MasterEditorMenu` has no stage editor.
- **[P2] NoteSkin Editor.** Not implemented.
- **[P2] Alphabet Editor.** Not implemented.
- **[P2] Character Editor parity.** Add undo/redo, unsaved-change warnings, folder support, and stronger flip/offset tooling.
- **[P2] Boxes/solids in editors.** Not implemented.
- **[P2] ImGui Console + Inspector.** No F2 console or F4 live object inspector. Note that F2 is currently screenshot/crash-capture (`source/backend/SSPlugin.hx:34`), so keybinds must be configurable.
- **[P3] Field auto-complete** in editors.
- **[P3] In-game TAB mod switcher.** `InitState.hx:25` currently prevents TAB; CNE exposes a TAB mod menu with scriptable sorting.

### 12.4 GAMEPLAY, CHARTS, HUD & QOL

- **[P1] Unlimited strumlines / multiple characters per strumline.** Current gameplay uses fixed `playerStrums` / `opponentStrums`.
- **[P1] BREAKING — section → `curCameraTarget` migration.** Phoenix still uses `Section.mustHitSection`. CNE replaced sections with explicit camera targets; only do this behind an importer/compat layer.
- **[P2] CNE/modern chart parser.** Psych v1 conversion exists, but CNE's extensible chart format and modern FNF parser are absent.
- **[P2] Camera zoom multipliers / bop events.** No `camGameZoomMult`, `camHUDZoomMult`, configurable lerp speeds, sprite/text angle/zoom factors, or `onBopZoom`.
- **[P2] Unlimited health-icon states.** `HealthIcon` can load strips, but `PlayState.hx:2197-2222` only special-cases two/three frames. Add CNE's 150×N icon strips and threshold selection.
- **[P2] True local co-op.** Phoenix has `bothSides`, but one player still hits both sides; `PlayerSettings.player2` is not wired into gameplay input. Add real P2 controls and rebinds.
- **[P3] Gitaroo easter-egg toggle.** Not present.
- **[P3] Desktop audio-device hotplug.** Android audio focus/interruptions are done; desktop headphone/device-change recovery is missing.
- **[P3] Advanced FPS counter.** Add 1% lows, selectable/copyable diagnostics, and a true uncapped mode. Current option is merely capped at 1000 FPS.
- **[P3] Low Memory Mode.** Done: `backend.MemoryProfiles` defines `Off` / `Low` / `Extreme` profiles (CNE's `Options > Appearance` idea), each a bundle of appearance/performance preferences plus a cleanup policy, selected in Options -> Optimization -> "Memory Profile" with a "Free Memory Now" action next to it. `backend.LowMemory` snapshots the player's own values before forcing anything and restores them when the profile is turned off or the settings file is saved (`ClientPrefs.saveSettings` writes user values, never forced ones); the codec lives in `MemoryProfiles.encodeBaseline`/`decodeBaseline` and is excluded from the settings backup. Cleanup hooks: after songs, when PlayState is destroyed, on `FlxG.signals.focusLost`, on an idle timer in menus, and Android's existing trim-memory handler now records pressure against the active profile. `ClientPrefs.lowMemoryMode` is kept as a derived mirror for scripts, and `memoryProfile`/`lowMemoryMode` are published to Lua/Python/HScript. See [`docs/LOW_MEMORY_MODE.md`](docs/LOW_MEMORY_MODE.md), `bash tests/haxe/run-memory-profiles.sh` and the diagnostics page's new "Memory profile" row.
- **[P3] Localization / translations.** No language key system or locale files.
- **[P3] Lagless GitHub contributors + mod credits.** Credits are static; add cached GitHub contributor fetching and per-mod credit integration.
- **[P3] Complete mouse support in base menus.** Freeplay/Story/Mods have partial wheel/click support; main menu/credits/etc. still need full mouse navigation.
- **[P3] Free gamemode keybind.** Not implemented.

### 12.5 RENDERING, SHADERS, MODCHARTS & 3D

- **[P2] ~~FunkinModchart-style advanced modcharts~~ DONE** — native runtime in `source/modchart/` (renderer-free manager → playfields → 34 modifiers + a beat-timed event list), applied to the live receptors/notes by `play.helpers.PlayStateModchart`; Lua API (`psychlua.callbacks.ModchartCallbacks`) and Python mirror (`psychlua.pystdlib.PyModchartLib`) expose `addModifier`, `setPercent`/`getPercent`, `modSet`/`modEase`/`modAdd`/`modSetAdd`, `modCallback`/`modRepeater`, `addPlayfield`, `resetModchart`, `isModchartActive`, `getModchartModifiers` and `setModchartPerspective`. Opt-in per script (`addModifier`), so Psych/JS mods and vanilla charts are untouched; see [`docs/MODCHART.md`](docs/MODCHART.md), `example_mods/scripts/ModchartExample.lua`, `bash tests/haxe/run-modchart.sh` and `bash tests/haxe/run-modchart-typecheck.sh`. Ported from [FunkinModchart](https://github.com/dotaxel/FunkinModchart) (Apache-2.0). Remaining: `ArrowShape`/`PathModifier` ports and a skew-capable renderer (Flixel sprites cannot shear).
- **[P2] Advanced shader scripting.** Add shader scripts, shader imports, `FunkinShader.fromFile`-style loading, and tweenable shader uniforms/arrays. Current Lua API only sets basic bool/int/float/array/sampler values.
- **[P3] Real 3D support (FoxLite/Away3D equivalent).** `ThreeDEffect`/`ThreeDShader` are shader effects, not a 3D scene/renderer.

### 12.6 MOD PACKAGING, VERSIONING & RUNTIME CONFIG

- **[P1] Addon system with load priority.** Phoenix has normal mods and `pack.runsGlobally`, but no CNE-style addons that layer over core/other mods with explicit before/after priority.
- **[P2] `modpack.ini` / API versioning.** `pack.json` lacks API/engine version metadata and outdated-mod warnings.
- **[P2] Runtime flags file.** Add a `flags.ini`-style runtime config for editors, transitions, beta warnings, default scripts, GLSL version, URLs, window title/icon, and other toggles. Current toggles are mostly compile-time `project.hxp` flags.
- **[P3] In-app auto-updater.** `OutdatedState` only opens GitHub Releases; CNE downloads assets/executable. This was previously removed from Phoenix because it was broken/Windows-only, so only reintroduce if secure and cross-platform.
- **[P3] Mod-supplied window title/icon.** Window title comes from preload `windowTitleBase.txt`; icons are compile-time assets. Allow active mod metadata to override both.
- **[P3] Full replacement of engine/Flixel assets.** See §12.2 universal asset replacement.

### 12.7 BUILD / DEV ERGONOMICS

- **[P3] Nix shell or CNE-like CLI wrapper.** Phoenix has `setup/*.sh|bat`, but no Nix environment or unified build command with advanced flags (`--reinstall`, `--fast`, etc.).
- **[P3] Porting guide.** Document Psych/Phoenix → Phoenix-CNE-parity conversion for charts, characters, stages, and scripts.

### 12.8 EXPLICIT NON-GOALS / COMPATIBILITY CAUTIONS

- **Do not remove Lua/Python to match CNE.** Phoenix's identity is Lua + Python + HScript; CNE's "no Lua" stance is not a target.
- **Do not drop Psych/JS JSON compatibility.** Any CNE chart/XML/meta format must ship with importers and keep existing mods working.
- **Do not remove `Boyfriend`, sections, or `LoadingState` without shims.** These are CNE architectural differences, not automatic wins.
- **Do not remove video support.** CNE's softcoded Week 7 cutscenes are a goal for scriptability, not a reason to delete hxvlc/MP4 support.
- **Do not adopt an auto-updater blindly.** The old updater was intentionally removed; revisit only with a safe cross-platform design.

---

## 13. SAVE DATA, PROFILES & MIGRATION

There is exactly one persistent store: `FlxG.save` bound as `funkin` in `InitState.hx:34`. `ClientPrefs.save()` copies every static field into it by reflection, and `Highscore` (`songScores`, `songRating`, `weekScores`), `Achievements` and the playtime counter all live in the same blob; only keyboard binds got a separate `controls_v2` file. There is no schema version, no backup, no atomic write and no export.

- **[P1] Save schema version + migrations.** `ClientPrefs.loadPrefs()` reflects every class field and assigns whatever the save contains; a renamed, retyped or removed field silently keeps a stale value or falls back to the default, and the reverse direction (opening a newer save in an older build) writes unknown keys back unchanged. Add a `saveVersion` key, an ordered rename→convert→drop migration chain, and a spec that loads a fixture from each older layout.
- **[P2] Split the monolithic save.** Prefs, highscores, achievements and playtime share one `funkin` file, so one truncated flush loses everything. `controls_v2` already proves the pattern; give scores/achievements/prefs their own FlxSaves (or namespaced keys) and make "reset only my scores" possible without wiping settings.
- **[P2] Atomic, verified writes.** `FlxSave.flush()` rewrites in place. On Android a kill mid-flush can leave a truncated file and the next boot quietly starts from defaults. Write to a temp file, verify it parses, then rename, and keep one `.bak` so a failed boot can offer the previous save.
- **[P2] Profile slots.** Everything is global per install. Content creators and co-op/competitive testing need named profiles under `CoolUtil.getSavePath()` (e.g. `profiles/<name>/`), with create/duplicate/rename/delete and a "current profile" indicator. Must migrate the existing save into `profiles/default/` so nobody loses progress (§13 P1).
- **[P2] Export/import a save bundle.** A JSON (or zip) with prefs, scores, achievements, binds, engine version and mod list, so players can move Android ↔ desktop or to a new phone without root. Export is manual; import shows exactly what will be overwritten and never happens automatically.
  Done (prefs only): every settings list ends with "Export/Import Settings (.json)" (`backend.SettingsBackup` + `backend.SettingsBackupCodec`). The file carries prefs, gameplay modifiers, keybinds and audio volume, is versioned (`formatVersion`) and is applied through a confirm prompt. Scores, achievements and the mod list still need the full bundle.
- **[P3] Prune orphan score entries.** `Highscore.formatSong()` keys are `songPath + difficultySuffix` only (`Highscore.hx:95`), so two mods with the same song name/difficulty share — and overwrite — one record, while deleting a mod leaves unreachable keys forever. Namespace new keys by mod id (compat-read the old ones) and add a cleanup view.
- **[P3] Downgrade warning.** Detect `saveVersion > ENGINE_VERSION` before writing and offer "back up and continue" / "reset" instead of silently re-saving a file the older build does not fully understand.

## 14. REPLAYS, DETERMINISM & SCORE TRUST

There is no replay, ghost or determinism layer anywhere in the tree (the only "replay" hits are a `CharacterEditorState` key label, the Android cold-start deep-link buffer comment and a Flixel comment). Input is consumed directly from `FlxG.keys` in `PlayStateInput` and scores are written from whatever the run reports, guarded only by the `antiCheatEnable` preference flag.

- **[P1] Deterministic replay recording.** One JSON per attempt: chart hash, difficulty, rate, note offsets, mod list + order, engine version and an event log. Record *resolved* gameplay events (hit/miss, hold release, pause, death, health change) from `PlayStateInput` rather than raw keys, so rebinds don't invalidate old replays. This is the missing piece for reproducible bug reports ("this pattern always drops"), score verification and no-botplay demos.
- **[P2] Replay playback + ghost notes.** Let `PlayState` run from a replay as its input source (score writes disabled), and optionally draw the live player's notes beside it as ghost arrows — the growth path for practice and tournament use.
- **[P2] Verify scores from the replay.** `Highscore.saveScore()` trusts the value it is handed; `ClientPrefs.antiCheatEnable` only flips a flag. Add a "verified" mark when a replay is attached and re-simulated (no accounts, no backend), and let mod packs/tourneys require it.
- **[P3] Compatibility gates on import.** Refuse — or require an explicit "force" — when chart hash, engine chart version, rate or the mod set differ; label files with "recorded on Phoenix x.y.z".
- **[P3] Seed the RNG.** Miss sounds, splash variance and any future RNG-driven mode all use `FlxG.random`. Store a per-attempt seed and seed `FlxG.random` when the chart starts so a replay reproduces the same run visually and logically.

## 15. INPUT & CONTROLLERS

`Controls` already models gamepads (`Device.Gamepad(id)`, `addGamepad`, `addDefaultGamepad`, per-action button maps), but `ControlsSubState` only captures `FlxKey` values and `controls_v2` persists `Map<String, Array<FlxKey>>`. So gamepad support today is a fixed default map: unconfigurable and unpersisted.

- **[P1] Gamepad rebinding + persistence.** Add a device column to `ControlsSubState` (keyboard / gamepad slot / Android hardware keys), capture buttons and axes, serialize gamepad binds next to `customControls`, and offer "reset this device" instead of resetting all binds.
- **[P2] Hotplug and slot assignment.** Verify a pad unplugged mid-song (or a controller that sleeps) keeps its bindings on reconnect, show "Controller 2 connected/disconnected", and let the player choose which physical pad is P1 instead of relying on `FlxG.gamepads` enumeration order.
- **[P2] Stick deadzone + trigger threshold calibration.** A live axis readout plus per-control deadzone, remembered per controller id/vendor. Analog drift is currently unfixable without different hardware, and trigger axes vary wildly between controllers.
- **[P2] Audio-visual latency calibration.** `NoteOffsetState` is a manual slider with no feedback loop. Add an interactive test (metronome + pulse, tap N times, median offset written to prefs) and separate offsets for wired vs Bluetooth output — Android BT adds 100–300 ms that one global offset cannot cover.
- **[P3] Poll-rate and key-rollover audit.** `PlayStateInput` reads `FlxG.keys`/`firstJustPressed` once per frame; on high-polling keyboards and multiple keys per frame, presses can merge or drop. Test with a 1000 Hz device, document the behaviour, and avoid per-frame allocations in the hot path (§8).
- **[P3] Android TV / remote navigation.** D-pad-only navigation and Back handling across Main Menu, Freeplay, Mods and Pause, a leanback launcher entry, and a UI that is usable without a touchscreen. TV boxes are a real low-end target for this engine.

## 16. ACCESSIBILITY & COMFORT

The only accessibility affordance today is `ClientPrefs.flashing`, honoured one call site at a time (`Philly.hx:84-225`, `PlayStateEvents.hx:542`), plus the once-per-install warning in `TitleState.hx:171` → `FlashingState`. Options has no accessibility category (`OptionsState.hx:35`).

- **[P1] Central `reducedMotion` preference.** Gate camera bops/shakes/scroll, character screen shake (`PlayStateNotes.hx:402-405`, `:584-587`, `:631-635`), event shakes (`PlayStateEvents.hx:414`), menu tweens and stage flashes in one helper, then let stages/scripts query it. `camZooms` only covers zoom; everything else is per-site today.
- **[P2] Add an Accessibility options category.** Split from "Visuals and UI" so flashing/reduced motion/high contrast/UI scale/hold-to-confirm are discoverable instead of buried among style options.
- **[P2] High-contrast / colorblind note palettes.** `noteColorStyle` offers Normal/Quant-Based/Char-Based with editable `arrowRGB`/`quantRGB`, but palettes still rely on hue. Ship named presets (deuteranopia/protanopia/tritanopia), a "force luminance contrast" mode, and optionally lane glyphs/numbers so lanes never depend on colour alone.
- **[P2] UI scale / text size.** Menus are authored at fixed pixel sizes. Add 100/115/130 % scale applied through `ScreenLayout`/`ViewportVisuals` (reused by the chart editor UI) with live preview, for 1440p desktops and small phones alike.
- **[P2] ~~Hold-to-confirm and larger touch targets~~ DONE** — `backend.HoldToConfirmLogic` +
  `objects.TouchTarget` / `objects.HoldToConfirm`: invisible ≥88×88 hit areas centred on untouched
  art, runtime progress bar, mouse + multi-touch + keyboard/gamepad input, cancel on release,
  drag-out, stray press or timeout. `ClientPrefs.holdToConfirm` / `holdToConfirmTime` (0.3–2 s)
  are exposed in Options → Visuals and UI; off switches to a two-press confirmation, never back
  to a single tap. Wired into destructive `objects.Prompt`s, guarded chart-editor delete/clear/
  load-events buttons, `ResetScoreSubState`, the pause `Exit to ...` submenu, a guarded
  **Reset All Settings** row in every options list, and SHIFT+RESET in Gameplay Changers.
  `requireHold` also overrides "Ignore Progress Warnings". CANCEL/Back/No stay single taps.
  Docs: `website/docs/subsystems/options-menu.md`, `website/docs/subsystems/mobile.md`.
  Specs: `bash tests/haxe/run-hold-to-confirm.sh`, `bash tests/haxe/run-hold-to-confirm-typecheck.sh`.
- **[P3] Re-openable photosensitivity warning.** `FlashingState` only shows while `FlxG.save.data.flashing == null`, so it is once-per-install and unreachable afterwards. Add "Show warning again" in Options and a quick "Reduce flashing" toggle in the pause menu.
- **[P3] Dialogue comfort settings.** `DialogueBoxPsych` reads a per-line `speed` (default `0.05`) and nothing else. Add a global speed multiplier, instant-advance, and dim-background / hide-box options — dialogue is where most reading happens and it currently has no user-side control.
- **[P3] Visual beat indicator.** An optional screen-edge pulse that respects `reducedMotion`, so players who mute the game (or play on silent mobile) keep timing feedback without relying on flashes.

## 17. MODDER TOOLING & SCRIPT SAFETY

Modding is a core promise (Lua + Python + HScript, `ModSecurity`, `ScriptSecurityScanner`, `CustomSubstate`, custom events/notetypes), but the authoring loop is still "run the game, read a log". `Mods.getPack()` parses `pack.json` with `tjson`, and `pack.json` only understands `name`, `description`, `restart`, `color`, `runsGlobally`, `scriptSandbox` and `scriptSandboxAllowlist`.

- **[P1] Script execution budget / watchdog.** Lua (`FunkinLua`), Python (`PythonScript`) and HScript (`HScript`) callbacks run inline on the main thread. A `while true do end` freezes the frame with no log, and on mobile there is no console. Add a per-callback instruction/time budget, abort with `file:line`, disable only the offending script for the session (assets stay), and surface the event in the mods menu.
- **[P2] Mod linter CLI (`tools/`).** Validate `pack.json` schema, unknown/duplicate folders (reusing `Mods.ignoreModFolders`), assets referenced by character/stage/week JSON, duplicate achievement IDs, difficulty names, and Lua/Python/HScript syntax before shipping. This is also what makes the §20 compatibility corpus possible.
- **[P2] Dependency and conflict metadata.** Add `id`, `version`, `requires` and `conflicts` to `pack.json`, with a resolve/report step before enabling. Without stable ids, `modsList.txt` is ordered by folder name and "requires ModX ≥ 1.2" is impossible. (Distinct from the CNE addon load-priority work in §12.6.)
- **[P2] Script error overlay with actions.** Show `file:line`, traceback and the offending snippet, with "reload script", "disable for this session" and "open folder". Today a failing script traces to a log or takes the state down; pairs with the §19 diagnostics work.
- **[P2] Path resolution debugger.** `Paths.modFolders()` silently returns the first hit across active mod → global mods → loose `mods/` → `assets/`. Add an overlay/console command that prints every candidate for a key, whether it exists, and which mod won, plus a grouped "missing assets" list. This is the natural complement to the trace cleanup in §5 #68.
- **[P3] Asset hot reload (desktop).** Watch the active mod's `images/`, `sounds/`, `music/` and `data/` and reload images/audio/charts without restarting the state. Complementary to the script hot reload in §12.1 — one covers code, this covers assets.
- **[P3] Mod scaffold generator (`tools/new-mod.py`).** Produce `pack.json`, the standard content folders and starter `scripts/`, `custom_events/`, `custom_notetypes/` from `docs/TemplateScript.lua`/`.py`, so a new mod starts valid instead of with a typo'd folder name.
- **[P3] Per-script profiling.** Measure time per hook (`onUpdate`, `onStepHit`, `goodNoteHit`, …) and list the worst offenders in the profiler output. Three mods with 200 `onUpdate` hooks each is otherwise invisible.

## 18. LOW-END PERFORMANCE & FRAME PACING

Phoenix's identity is "runs on weak devices", yet configuration is manual: `ClientPrefs` defaults are desktop-oriented and Options exposes dozens of toggles. Existing infrastructure to build on: `SystemInfo` (logical CPU count, physical RAM, page size), `FrameProfiler` (F3 overlay, F6 CSV/log export, `setStateName`), `PoolStats`, `Paths.clearUnusedMemory()`/`clearStoredMemory()` and the `dumpExclusions` list.

- **[P1] First-run performance profile.** Use `SystemInfo` plus the GPU/driver detection from open issue #96 to pick an initial preset (framerate, `lowQuality`, `shaders`, `cacheOnGPU`, `dynamicSpawnTime`, GC flags, splash limit), tell the player it was applied, and keep every value editable. Today a low-end phone starts with desktop defaults and the player has to find Optimization by hand.
- **[P2] Texture/atlas memory accounting.** There is freeing logic but no visibility: add a diagnostics view listing loaded `FlxGraphic`s (size, source, owning mod/stage), total estimated VRAM/RAM and the biggest atlases, with a warning when a stage exceeds a budget. Complements the §0 downscale work — you cannot tell whether a stage is over budget today.
- **[P2] Frame pacing and high-refresh support.** `ClientPrefs.framerate` writes both `FlxG.updateFramerate` and `drawFramerate` (`GraphicsSettingsSubState.hx:131-140`). Add display-refresh detection, recommended values (60/90/120/144) and a separate update rate, so a 120 Hz panel doesn't run gameplay logic at 120 Hz with a different feel — and so the offsync risk in §4 #83 stays measurable.
- **[P2] Preload/streaming policy.** Preload only the active stage and its characters; add "preload next song" for week runs, and verify `Paths` tracking actually releases the previous stage (graphics *and* cached sounds) when switching mods/songs. Debug builds can assert on tracked-vs-loaded counts.
- **[P3] Device benchmark mode.** A fixed, mod-free stage/chart that runs ~60 s and reports average, 1% low and worst frame plus device info — reachable without F3/F6, which do not exist on Android. Reuses `FrameProfiler.exportLog()`; this is a *test run*, not the live counter in §12.4.

## 19. DIAGNOSTICS, SUPPORT & SAFE MODE

`CrashHandler` catches errors, writes text logs and shows a summarized-reason screen, but recovery is still manual: the next launch re-enters the same mod/save, Android users can't easily reach `logs/`, and support requests have to ask for versions by hand.

- **[P1] Safe Mode after repeated crashes.** Count unclean starts, then offer "start with all mods disabled", "start with fresh prefs", "start with default resolution/framerate" *before* `InitState` loads mods. A single bad `pack.json`/script currently turns into a crash loop the player must fix by editing files.
- **[P2] "Copy diagnostics" action.** One button producing a redacted, pasteable block: engine version (`VERSION` in `project.hxp`), commit (`HaxeCommit`), target, `SystemInfo` CPU/RAM, GPU/driver (#96), save path, mod list + order, non-default prefs, last N log lines. Offline only — the recent update flow is deliberately repo-based (§0), so no auto-upload. `backend.DiagnosticsReport` (built for `phoenix://diagnostics`) already assembles that text, so what is left is the button, plus running the result through `backend.LogUtils.redact` so a copied block is no more identifying than a saved log — the deep-linked page only *warns* about usernames in paths.
- **[P2] Crash bundle export.** Done: alongside the log, every crash now writes `crash/FNF-Phoenix-Engine_crash-bundle_<date>.zip` (crash text, `modsList.txt`, each mod's `pack.json`, prefs in the settings-backup format, a screenshot of the crashed frame, the vlog tail when enabled, and a `bundle.json` manifest). `backend/CrashBundleWriter` (Flixel-free) builds the zip with `ModPathPolicy` entry-name checks, per-entry/total/count caps, atomic writes and a 3-bundle retention; `backend/CrashBundle` collects the pieces best-effort. The bundle lands in `crash/` — the SAF "Crash Logs" root on Android — and the crash screen adds an **Export crash bundle** action (`[E]` / touch button) that saves it anywhere through `MobileFilePicker` (SAF "save as" → Downloads/share), plus a touch **Restart** button on mobile. Same `#if sys` target guard as the §6 #70 crash log. See `docs/CRASH_BUNDLE.md`.
- **[P2] Log rotation and redaction.** `logs/` accumulates a file per crash and per profiler export with no cap. Rotate by size/age and strip usernames/absolute paths before a log leaves the machine.
- **[P3] Per-mod "why did it break?" report.** In the mods menu, show last load error, invalid `pack.json`, blocked script rule (§6 sandbox) and missing-asset count per mod, instead of requiring a log read.

### OPT-OUT BY DEFAULT ANALYTICS

Currently, its hard to tell if anyone is having issues on Phoenix Engine, i'm developing this engine for months now and i've never got ANY issue on this github repo other than the ones Arena.AI generated for me. So, by making this optional analytics system, anyone can help me discovering bugs as fast as possible.

It would collect **ONLY**

- Device info (GPU/CPU specs, needed to know if someone is playing on a laggy phone or high-budget ultra gamer pc)
- Amount of mods loaded (so its easier to tell if its a problem with the mods itself)
- - _AND if they use the ultra mega hyper experimental WIP instable Python softmodding support_
- Crash logs
- Errors inside MODS scripts (so its easier to know if Phoenix engine is incompatible if some Psych engine mod)
- - _AND if they use the ultra mega hyper experimental WIP instable Python softmodding support_

Please keep in mind that im not evil and i will not steal your data, i'm just trying to improve my game.

## 20. TESTING & RELEASE VERIFICATION

There is real infrastructure to extend: `tests/haxe/*Spec.hx` (layout, chart timing, mod security, pooling), host-JVM Java tests for the Media3 bridge, SAF policy and cutout layout (`tests/java/run.sh`), and standalone native C/C++ smoke tests (`tests/native/run.sh`). There is no compatibility corpus, no save/chart round-trip guarantee and no performance gate.

- **[P2] Mod compatibility corpus.** A tiny fixture set (standard-layout `pack.json` variants, a Psych chart, a shader mod, a noteskin, Lua/Python/HScript scripts, a broken mod) loaded by a headless harness in CI. Every §12.2 format change needs this to prove old mods still load.
- **[P2] Save-migration fixtures.** Once §13 lands, ship fixture saves (old version, missing fields, truncated, newer-than-engine) and assert load/migrate/backup behaviour in the existing Haxe suite.
- **[P2] Chart round-trip golden tests.** Save → load → save must be structurally identical for notes, events, BPM changes and `mustHitSection` (including the compressed path in `ChartingSaveLoad.saveLevel`). Silent field drops currently only show up in-game, and §12.4 may replace sections entirely.
- **[P3] Broaden the Haxe specs.** Add `Paths` resolution order, `Mods.parseList`/`updateModList`, `Highscore.formatSong` namespacing and replay determinism to the modules already covered by `run-layout.sh` / `run-charting-timing.sh` / `run-pool-stats.sh`.
- **[P3] First-run smoke test.** Boot with an empty save path, assert Title is reached, the save is created, no mod loads, and `flashing == null` triggers `FlashingState`. Run it on the Android emulator job from §10 as well as desktop CI.
- **[P3] Performance baseline gate.** Keep a `FrameProfiler` export for a fixed chart/build and fail when average or 1% low regress past a threshold, making the low-end promise testable instead of anecdotal.

## OTHER

### Port other Psych Engine fork features

Read `docs/research/psych-fork-engine-changes.md`.
---

## TOP 5 (do these first)
1. Commit + push the two uncommitted Android fixes (`CopyState.hx` ThreadPool, `PlatformUtilNative.hx` utsname) — they ARE the Android CI fix.
2. Resolve local NDK mismatch (install 27.0.12077973/r27 or fix the NDK 28 libc++ redefinition) so Android builds locally → green. ([#64](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/64))
3. HashLink target: install working `lime.hdll`, build, re-enable CI `hl` job. ([#63](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/63))
4. Kill `Paths.hx`/`BuildingEffect.hx` production trace spam.
5. Path-traversal + keystore-secret hardening (security). ([#65](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/65))

## 21. PLAYER-FACING SCREENS, SUBSTATES & OPTIONS (idea review)

Ideas checked against the current tree: none of the screens, substates or options below exist yet (`PlayerStats`, `ResultsState`, `StatsState`, `ModchartLabState`, `ExtrasState`, `QuickOptionsSubState`, `PracticeLoopSubState`, `ModReportSubState`, `FreeplayFilterSubState`, `PhotoModeSubState`, `laneUnderlayAlpha`, `resumeCountdown`, `hapticFeedback`, `menuFramerate`, `adaptivePerformance` have no matches in `source/`). Overlaps with existing entries are cross-referenced, not repeated.

### 21.1. New states

- **[P1] Results screen (`states/ResultsState`).** `PlayStatePlayback.endSong()` currently goes straight back to `FreeplayState` / `StoryMenuState`. After a song or week, show score, accuracy, judgement breakdown, max combo, peak NPS, FC tier and a histogram of hit offsets. The totals already exist on `PlayState`; only per-hit offsets need recording (via `play.helpers.HitTiming`). Roadmap link: the Mic'd Up S/A rank (§0) would live on this screen.
- **[P2] Player stats (`states/StatsState`, `backend/PlayerStats`).** Lifetime totals: playtime, songs finished, notes per judgement, deaths, full combos, most-played songs and mods. A small `PlayerStats` backend is needed because playtime is only stored as progress toward the 50-hour badge and stops counting once that unlocks. Link it from Awards (`MainMenuState`'s `awards` entry); a new main-menu button would need its own sprite atlas.
- **[P3] Modchart lab (`editors/ModchartLabState`).** Pick any of the 34 built-in modifiers in `source/modchart/modifiers/`, drag their percents over a looping section, watch the arrows react, then copy the matching `modEase(...)` calls as Lua or Python. There is no visual way to tune a modchart today. Related to the modchart work in §12.
- **[P2] Extras hub (`states/ExtrasState`).** A menu listing custom screens that enabled mods declare in a new `menus` list in `pack.json`. `ModState` screens can only be opened by a script calling `switchCustomState` (`states/ModState.hx`), so each mod currently has to build its own entry point, for example by overlaying `MainMenuState`. Needs `backend.Mods` parsing of `menus` and a platform-support check for each entry.
- **[P3] Input tester (`states/InputTestState`, `phoenix://input`).** Live view of keys, gamepad buttons and touch points, with a simultaneous-press counter and press timing, so a player can see that a keyboard drops a third key or a phone tracks only two fingers. Give it a `phoenix://` route like `phoenix://diagnostics` (`DiagnosticsReport`). Player-facing tool for the poll-rate and key-rollover audit in §15 (`PlayStateInput`).

### 21.2. New substates

- **[P1] Quick options (`QuickOptionsSubState`, from pause).** Change settings that can apply live (offsets, hitsound, track volumes, flashing, camera zooms) without leaving the song. Today choosing Options from `PauseSubState` switches to `OptionsState` and reloads `PlayState` from the start on return, which loses the run and is slow on weak devices.
- **[P2] Practice loop (`PracticeLoopSubState`, from pause).** Mark a start and end point, pick a playback rate and loop that part with score saving off. The seek code already exists behind `Skip Time` in `PauseSubState`, which is only added inside the `PlayState.chartingMode` branch (and not while the song is still starting).
- **[P2] Mod report (`ModReportSubState`, from Mods menu and after a `.zip` import).** One page per mod: whether it opted out of the script sandbox, which rules it allowlists, blocked scripts by file and line, and Lua functions it calls that Phoenix does not implement. Today security findings only reach the debug console and the log when a script loads. Player-facing counterpart to the mod linter CLI in §17 and the per-mod report in §19.
- **[P2] Freeplay filter (`FreeplayFilterSubState`).** Sort by name, mod, best accuracy or unplayed; show a single mod; star favourites; pick a random song. Freeplay currently has only text search.
- **[P3] Photo mode (`PhotoModeSubState`, from pause).** Hide the HUD, pan and zoom the game camera freely, and save a shot through the existing `backend/Screenshot` / `backend/SSPlugin` path. Fits the creator tooling the engine already ships.

### 21.3. New options

- **[P3] Lane underlay (`laneUnderlayAlpha`, percent, default 0, Visuals and UI).** A dark strip behind the player's strums so notes stay readable over busy stages. It is one stretched sprite, so it is cheap on low-end devices.
- **[P2] Resume countdown (`resumeCountdown`, bool, default on, Gameplay).** Count 3-2-1 after unpausing instead of resuming instantly. Matters most on phones, where thumbs leave the hitbox to press Resume. Should be exposed to Lua/Python/HScript like the other pause events.
- **[P2] Haptic feedback (`hapticFeedback`, string: Off / Misses / Hits and Misses, default Off, Mobile Options with `onlyOn([PlatformSupport.ANDROID])`).** `AndroidHaptics` and the `VIBRATE` permission already ship, and `modchart/modifiers/Vibrate.hx` exists, but nothing triggers haptics from gameplay. Add matching Lua and Python `vibrate()` callbacks.
- **[P2] Menu FPS cap (`menuFramerate`, int, default 60, Graphics).** Menus currently render at the gameplay framerate, which can be set up to 1000, so they drain battery for nothing. A companion row can expose the focus-lost rate, which is hard-coded to `60` in `states/InitState.hx` (`FlxG.game.focusLostFramerate`). Roadmap link: next to the frame-pacing work in §18.
- **[P3] Adaptive performance (`adaptivePerformance`, bool, default off, Optimization).** When the frame rate stays below target for a few seconds, switch off cosmetics in order (note splashes, rating popups, camera zooms) for the rest of the song and tell the player. Roadmap link: the first-run profile in §18 picks settings once; this one reacts during play.

### 21.4. Quick win before any new option

- **[P1] Expose eight preferences that are read but have no menu row.** `reducedMotion`, `dialogueSpeedMult`, `dimDialogueBackground`, `instantDialogueAdvance`, `hideDialogueBox`, `safeMode`, `showPhotosensitivityWarning` and `disableAprilFools` are defined in `backend/ClientPrefs.hx` and used by the game, but no file under `source/options/` creates an `Option` for them. Each needs roughly one `new Option(...)` line plus a description. Note `showPhotosensitivityWarning` pairs with the re-openable warning in §16.

## 22. NEW OPTION IDEAS (three lists, merged)

Thirty option ideas from three separate lists. Five options appeared in two lists, so they are merged into 25 entries (both names stay in the title): 22 new options in §22.1–22.5, none of which repeats §21.3, and three additions to existing entries in §22.6. Checked against the tree at `b0a5429`, which is also where the line numbers come from: none of the proposed keys exists in `backend/ClientPrefs.hx` (`startFullscreen` and `metronome` only appear in `source/` as the `Main.game` launch field and a chart-editor checkbox). Where a list's premise did not match the code, the entry says what is there instead, after "Checked:". Effort is quoted where a list estimated it: S = a preference, one `Option` row and a few call sites; M = also a small helper/object or a layout pass. The third list gave no keys, types or estimates, so its entries leave them open. The priority tags are a reading of the lists' own recommendations, which are kept in §22.8.

### 22.1. Audio

- **[P2] Master volume (`masterVolume`, percent, default 100%, a new Audio category or Misc).** No options menu has a volume row. `FlxG.sound.volume` only changes through the volume keys (`volume_up` / `volume_down` / `volume_mute`, with the `objects/CustomSoundTray` popup) and through a settings import (`backend/SettingsBackup.hx:146`), so a player on a gamepad or a touchscreen cannot set it in-game. Every `FlxSound` multiplies by it, so one row covers music, vocals, hitsounds and the pause track. Checked: the value is already saved and restored, which one list missed. `ClientPrefs.saveSettings()` and `loadPrefs()` round-trip it through the `flixelSound` list (`ClientPrefs.hx:367`, `:405`, `:464`), the tray stores it too (`CustomSoundTray.hx:121`) and `SettingsBackup` exports it (`:205`). So do not store it twice: `Option` binds to a `ClientPrefs` field by name, so give it one that mirrors `FlxG.sound.volume` and is kept out of the save and the backup (`saveBlackList` / `loadBlackList` in `ClientPrefs.hx:366-368`, `SettingsBackup.NOT_PREFERENCES`). The row has to use the tray's curve (`CustomSoundFrontEnd.changeVolume()` stores a log-scaled value, so half the tray is a `FlxG.sound.volume` of about 0.03) and has to follow the volume keys, or it goes stale. Two lists rank this first; with persistence already in place it is a convenience row, hence P2. Effort: S.
- **[P3] Menu music volume.** Control menu music separately from gameplay audio, with an optional fade when entering a song. `Paths.playMenuMusic(force, volume)` (`backend/Paths.hx:853`) already takes a volume, but 18 call sites in 12 files (the editors, `GameOverSubstate`, `NoteOffsetState`, `VisualsUISubState`, `RenderingDoneSubState`, one Lua callback) still start the menu track with `FlxG.sound.playMusic(Paths.music('freakyMenu…'))` directly, so route those through the helper first.
- **[P3] Metronome (`metronome`, string: Off / Count-in / Always, default Off, Gameplay or the Audio category).** `assets/shared/sounds/Metronome_Tick.ogg` ships, but only the chart editor plays it (`editors/ChartingState.hx:1964`). Add a `beatHit` path in `PlayState` with three modes: off, during the count-in only, or through the whole song. Scale the tick with `playbackRate` and skip it during `startOnTime` seeks. The list pitches it for practising muted, on a silent phone or with latency; the tick shares the game's audio output, so on a muted device that job belongs to the visual beat indicator in §16, whose pref exists but is not wired (§22.7). The interactive latency test in §15 needs the same tick. Effort: S–M.

### 22.2. Window, stage and effects

- **[P2] Window mode / fullscreen on start (`windowMode`, string: Windowed / Borderless / Fullscreen, Graphics, `onlyOn([PlatformSupport.DESKTOP])`).** F11 is the only fullscreen toggle in `source/` (`backend/FunkinGame.hx:24`, native desktop only), the game always starts windowed (`startFullscreen: false`, `Main.hx:51`) and nothing remembers the choice. The small version is a `startFullscreen` bool, default off. The full version is the three-way row, which gives players borderless without exclusive-fullscreen artifacts. Apply it through `lime.ui.Window` / `FlxG.fullscreen` after prefs load, and persist the mode, including when F11 changes it. Watch two interactions: `backend/TransparentWindow.hx` leaves fullscreen when it is enabled and suspends itself while fullscreen, and `CoolUtil.checkForOBS()` drops out of fullscreen to read `tasklist` and then goes back. Effort: S for the bool, M for the three-way row.
- **[P2] Stage dim / stage brightness (`stageDim`, percent, default 0%, Visuals and UI).** One black overlay with `scrollFactor` 0, above the stage and characters and below the strums and HUD, with its alpha driven by the pref. It dims a distracting background without touching the notes, works on pixel stages and costs one sprite. Unlike the lane underlay in §21.3 it covers the whole gameplay background, and unlike the Mic'd Up brightness/gamma idea in §0 it leaves notes and HUD bright. `Opponent Note Alpha` (`oppNoteAlpha`) already shows the demand for readability controls. The default of 0 changes nothing for existing players. Layering: the stage and characters draw on `camGame`, and notes draw on `camNotes` when Distant Notes is on and on `camHUD` otherwise (`PlayState.hx:1601`), so the overlay has to render above everything on `camGame` and below the note camera. Effort: S–M.
- **[P2] Camera effects intensity (`cameraFxIntensity`, percent, default 100%, Visuals and UI until the Accessibility category in §16 exists).** `reducedMotion` already gates beat bops (`PlayState.hx:3183`, `:3256`), event zooms and shakes (`PlayStateEvents.hx:323`, `:415`) and character shakes (`PlayStateNotes.hx:416`, `:623`, `:673`), but only as on or off. `camZooms` is a bool, and `camBopIntensity` is a `PlayState` field that only the bop event sets (`PlayStateEvents.hx:222`). One 0–100% multiplier lets players keep a little motion instead of none. Apply it at those sites and in a `shake()` override on `backend/PsychCamera`, which does not have one today. Keep `reducedMotion` as the master off switch; the slider refines it. Related: the zoom multipliers in §12.4. Effort: M.
- **[P1] Flash intensity (`flashIntensity`, percent, default 100%, Visuals and UI until the Accessibility category in §16 exists).** `flashing` is only on or off. A 0–100% dial that scales flash alpha and duration lets photosensitive players keep the cue without the punch, which is more useful than another toggle. Precedence: `flashing = false` forces 0, otherwise the percentage applies. There are few camera flash sites: `stages/Philly.hx:181` and `:227`, `states/TitleState.hx:520` and `:672`, `play/helpers/PlayStateCamera.hx:322`, and the script callbacks (`psychlua/callbacks/GameCallbacks.hx:240`, `psychlua/pystdlib/PyCameraLib.hx:33`). Checked: two of them ignore `flashing` completely today, the 4 s white flash that ends the title intro (`TitleState.hx:672`) and the 1 s white flash in `tankmanStep()` (`PlayStateCamera.hx:322`), and script flashes are passed through as they are. Route every site through one helper; that gap is why this is P1. Pairs with `reducedMotion`. Effort: S–M.

### 22.3. Notes and playfield

- **[P2] Note and strum scale / independent note size (`noteScale`, int %, 50–150, default 100, Visuals and UI).** One multiplier for notes and receptors that keeps the field proportional and leaves the rest of the HUD alone. It helps on small phones and 1440p desktops and supports the low-end downscale goal in §0. Checked: the scale is hard-coded as `0.7` at five sites, not three (`objects/Note.hx:215`, `:356`, `:416`, `:671` and `objects/StrumNote.hx:121`), and pixel notes are sized by `PlayState.daPixelZoom` instead (`Note.hx:334`, `StrumNote.hx:86`). `Note.swagWidth` is a `static final` `160 * 0.7` (`Note.hx:124`) that also sets lane spacing (`StrumNote.hx:153`), sustain centring (`Note.hx:447`, `:463`) and splash placement (`NoteSplash.hx:48`), so it has to become a computed value. The existing UI Scale (`uiScalePercent`) only resizes the options menus. Include a preview so lanes cannot overlap. Effort: S–M.
- **[P3] Lane spacing.** Increase or decrease the distance between the player's lanes independently of note size, for different screen sizes and preferences. Spacing is not a separate value today: `StrumNote.postAddedToGroup()` steps each lane by `Note.swagWidth` (`StrumNote.hx:153`), which is the note width. It needs the same `swagWidth` split as the note scale above, so build it with or after that entry.
- **[P3] Hold note transparency.** Set the opacity of sustain bodies separately from note heads, so dense hold patterns are easier to read. No pref covers it. Sustain pieces are created with `multAlpha: 1` (`play/helpers/PlayStateChartLoader.hx:286`) and drawn at `strum.alpha * multAlpha` (`objects/Note.hx:433`), so `multAlpha` on those pieces is the hook.
- **[P2] Hit error bar / hit timing meter (`hitErrorBar`, bool, default off, Gameplay).** A small HUD object that keeps the last 15 or so hit offsets and draws them as a strip of dots under the strums, early on one side of a centre mark and late on the other, with the offset in milliseconds. The signed value already exists: `noteTimingDiff` (`PlayState.hx:2916`, set in `PlayStateRating.hx:109`) and `HitTiming.classify()`. The only feedback today is one popup per hit (`showMS` and `earlyLateRatings`, Options -> Optimization). A strip shows a consistent bias ("always 12 ms late"), which gives `NoteOffsetState` and `ratingOffset` something to be tuned against. Hide it with `hideHud` and flip its position for downscroll. The Results screen in §21.1 wants the same per-hit offsets for its histogram, so record them once. Effort: M.

### 22.4. Timing and song flow

- **[P2] Accuracy presets (`accuracyPreset`, string: Vanilla / Psych / Kade / ITG / Custom, Gameplay).** The hit windows are five separate rows: `perfectWindow` 15, `sickWindow` 45, `goodWindow` 90, `badWindow` 135 and `safeFrames` 10 (`ClientPrefs.hx:318-322`, rows in `options/GameplaySettingsSubState.hx:197-252`). A preset row writes all five at once and switches itself to Custom when any of them is moved, which is what players want when they go from Psych charts to Kade charts. Each row computes its min and max from its neighbours once, when the menu is built (`:204-238`), and `badWindow` is capped at 135 ms, so the preset row has to refresh those bounds and its values have to fit the cap or raise it. Call `Conductor.recalculateTimings()` after writing `safeFrames`, as that row's `onChange` does. Effort: S.
- **[P2] Countdown style (`countdownStyle`, string: Normal / Short / Off, default Normal, Gameplay).** `PlayState.skipCountdown` (`play/PlayState.hx:433`) already skips the intro (`PlayStateCountdown.hx:93`), but nothing in `source/` sets it: only a script can, and `startOnTime` takes its own path. So every attempt, retries included, waits five beats of "3, 2, 1, Go" (3 s at 100 BPM). This is the persisted, player-facing version, and the sibling of the resume countdown in §21.3. Effort: S.
- **[P2] Restart on death (`deathRestart`, string: Hold ACCEPT / Tap / Off, default Hold, Gameplay).** `GameOverSubstate.update()` only retries on `controls.ACCEPT` (`states/substates/GameOverSubstate.hx:297`; `controls.BACK` leaves), and `endGameOver()` then waits 0.7 s plus a 2 s fade before `FlxG.resetState()` (`:387-391`). When a player grinds a hard section this is the most repeated input in the game. Add a "hold to skip, tap to restart" mapping and a `deathDelay` override that shorten it. The list does not define the three values further; whichever is the default has to keep today's single press working. Effort: S.
- **[P3] Auto-retry (`autoRetry`, bool, default off, Gameplay).** `doDeathCheck()` (`play/PlayState.hx:2723`) always opens `GameOverSubstate`, directly or after the `GameOverSubstate.deathDelay` timer. With the option on, skip or shorten that and call `restartSong()` after a delay, while still running the `onGameOver` script callback and `stage.onGameOver()`. For practice, speedruns and chart testing. A companion `autoRetryDelay` is optional. The entry above shortens the death screen; this one removes it. Effort: M.
- **[P2] Pause on controller disconnect (`pauseOnControllerDisconnect`, bool, default on, Gameplay).** A pad that sleeps or unplugs mid-song stops feeding `holdArray`, and the player is dead a few seconds later. On disconnect, open the pause menu (`PlayState.openPauseMenu()`) with a short "Controller disconnected" line, stay paused and resume only on input. The signals exist and have no listener: `AndroidGamepad.onDisconnected` (`android/platform/AndroidGamepad.hx:43`) on Android and Flixel's `FlxG.gamepads.deviceDisconnected` elsewhere. This is the gameplay half of the hotplug entry in §15, so it takes that entry's P2 even though it is cheap. Effort: S–M.

### 22.5. Menus, capture, touch and data

- **[P3] Freeplay auto-preview (`freeplayPreview`, bool plus a length, default off).** Checked: Freeplay can already play the highlighted song, but only by hand. Space or virtual pad X (`states/FreeplayState.hx:501`, `:588`) runs `FreeplayStateHelpers.playSong()` (`states/helpers/FreeplayStateHelpers.hx:351`), which parses the chart and loads the instrumental and both vocal tracks. What is missing is a preview that starts by itself: about 10 s of the instrumental once the cursor settles, from one cached `FlxSound`, cancelled on scroll or confirm, and never competing with the manual player (`player.playingMusic`). It makes a 300-song mod list browsable, most of all on a phone with no file manager to peek at. Related: the variation preview in §12.2. Effort: M.
- **[P3] Auto-screenshot on results (`autoScreenshot`, string: Off / Personal best / Every song, default Off).** `backend/SSPlugin` already saves to `screenshots/`, but only from its key check (`screenshotKey = F2`, `SSPlugin.hx:34`, `:129`), so a player without a keyboard cannot take one. A capture at song end gives every player a results image to share and needs no new rendering code. It needs three things: a public entry point (`SSPlugin.screenshot()` is private; `backend/Screenshot.save(directory, name)` is the alternative), a hook (the Results screen in §21.1, or `PlayStatePlayback.endSong()` until that exists), and for Personal best a `Highscore.saveScore()` that reports whether the record was beaten, because it returns `Void` today. Effort: S–M.
- **[P2] Achievement popups (`achievementPopups`, string: Full / Compact / Off, default Full).** `Achievements.startPopup()` (`backend/Achievements.hx:175`) always spawns a full `AchievementPopup`, a 420×130 box added with `FlxG.game.addChild` in the top-left corner above every camera, and pushes earlier ones down by 150 px. No pref guards it, so it appears over the playfield mid-song. Compact and Off help recordings and small screens. Effort: S.
- **[P2] Touch control scale (`mobileControlScale`, percent, default 100%, Mobile Options).** Checked: this is about the virtual pad. `FlxVirtualPad` draws each button at the art's native size, at a fixed pixel offset from a screen edge (for example `createButton(105, FlxG.height - 356, …)`), and already re-anchors horizontally on resize (`mobile/flixel/FlxVirtualPad.hx:271`). `FlxHitbox` fills the viewport and lays itself out. `MobileControlsSelectSubState` lets players move pad buttons (`Pad-Custom`, saved in `FlxG.save.data.buttons`), but nothing changes their size, which is the bigger problem on small phones and for large hands. Scale the buttons and their edge offsets together, keep saved custom positions valid, and keep the hitbox's extra-button strip consistent. Effort: M.
- **[P3] Portable settings folder (`portableData`, bool, default off, Misc, desktop only).** Keep save data next to the executable, so the game runs from a USB stick or on a shared school PC. It composes with the export/import in `backend/SettingsBackup`. Checked: only the `FlxSave` files live in the per-user path (`funkin` and `controls_v2`, bound through `CoolUtil.getSavePath()`). `mods/` (`Paths.mods()`) and `screenshots/` are already relative to the working directory, so the work is the save path, not `Mods.getModDirectories()`. The switch cannot be stored in the save it relocates, so read it from a marker file next to the executable. Restrict it with `PlatformSupport.DESKTOP`, because the `FILESYSTEM` tag also matches Android and iOS. Effort: M.
- **[P3] Per-mod settings profiles.** Remember separate visual, performance and gameplay preferences for each mod and apply them automatically, with a "Use Global Settings" fallback. Nothing like it exists: prefs are one global set. The nearest code, Psych's `ModSettingsSubState`, is commented out in `states/ModsMenuState.hx` (`:18`, `:282-291`) and is a different feature (options that a mod defines, not the player's engine prefs per mod). Build this on the profile slots and the save split in §13.

### 22.6. Additions to entries that already exist

- **Lane background opacity: see lane underlay, §21.3.** The same option, a dark 0–100% background behind the player's lanes. One list puts it among the first three to build, above its current P3.
- **Practice loop: see §21.2.** The same feature, described as a practice-only mode where the player picks a section to repeat. New detail: a configurable lead-in countdown before each repeat. Score saving stays off while it is active, as §21.2 already says.
- **Adaptive background quality: see adaptive performance, §21.3.** A further step for the same option: when the frame rate stays below target, also reduce optional stage particles and decorative animations (the stages already branch on `lowQuality`). It must never alter note timing or hide gameplay-relevant objects.

### 22.7. Found while checking (no new option needed)

- **`comboOffset` needs no new rows.** One list proposed four int options because the rating and combo position "is only editable from the editor or a script". Checked: Options -> Adjust Delay and Combo (`options/NoteOffsetState.hx:230-319`) already edits all four values with the arrow keys, WASD or by dragging, and gameplay reads them (`objects/Popup.hx:60`, `play/objects/JudgeText.hx:66`, `play/helpers/PlayStateRating.hx:278`).
- **`gamepadDeadzone` is declared and never read** (`ClientPrefs.hx:14`, no other match in `source/`). Do not ship a deadzone row until the stick calibration in §15 wires it into `FlxG.gamepads`; until then the row would do nothing.
- **Five accessibility prefs are declared and never read:** `noteColorblindPreset`, `laneGlyphs` and `forceLuminanceContrast` (`ClientPrefs.hx:69-71`), `highContrast` (`:94`) and `visualBeatIndicator` (`:100`). A row for any of them would be misleading until the §16 work behind it exists.
- **§21.4 re-checked: still open.** One list called it partly stale, but all eight prefs it names are still read by the game and still have no `Option` row.
- **[P3] Mute is not restored on launch.** The second `flixelSound` entry is `"sound"` (`ClientPrefs.hx:367`), which is not a `SoundFrontEnd` field, so `saveSettings()` and `loadPrefs()` only round-trip `volume`. The tray writes `data.mute` into the `funkin` save (`objects/CustomSoundTray.hx:122`), but its only reader is Flixel's `SoundFrontEnd` constructor, which runs in `Main` (`Main.hx:193`) before `InitState` binds that save (`states/InitState.hx:36`). So volume survives a restart and mute does not. This comes from reading the code, not from a run, so confirm it while fixing. Fix it with the master volume row in §22.1.
- **[P3] `perfectWindow` has two defaults.** `ClientPrefs.perfectWindow` starts at `15.0` (`ClientPrefs.hx:318`), but its row resets to `22.0` (`options/GameplaySettingsSubState.hx:201`). Settle it when defining the default accuracy preset in §22.4.

### 22.8. Suggested order

The lists' own recommendations, unchanged. The eight rows in §21.4 are free and come before any of these.

1. Cheapest and most visible: Master volume, Pause on controller disconnect, Flash intensity.
2. Smallest changes (about one call site, a `ClientPrefs` field and a row): Accuracy presets, Countdown style, Master volume, Achievement popups.
3. Most noticeable to players: Window mode, Hit error bar, Touch control scale.
4. Best fit for the engine's low-end and accessibility identity, with no per-frame cost: Camera effects intensity, Stage dim.
5. The third list's first three, chosen for clear benefit without a new system: Lane underlay (§21.3), Hit error bar, Stage dim.

Ship the larger ones as separate PRs.
