# Phoenix Engine — TODO / Roadmap (large feature & cleanup backlog)

Generated from full repo audit. Priority: `[P0]` critical/blocker, `[P1]` high, `[P2]` medium, `[P3]` nice-to-have. Sections grouped by system. Bold = biggest payoff. Section 12 is a filtered Codename Engine (CNE) comparison: only CNE differences that Phoenix has **not** implemented (or has only partially implemented) are listed there.

Sections 13–20 are a second backlog pass written against the current tree. Every entry there was checked against §0–12: anything already listed is **cross-referenced, not repeated**, and each item names the file/behaviour that proves it is still missing. They target Phoenix's stated identity — low-end devices, easy Lua/Python/HScript modding, Android-first platform work and Psych/JS compatibility — rather than generic engine cloning.

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

### Overly complex stuff that would take weeks of work

- Making the user be able to change ALL game text to a custom font.

- Adding a built-in mid download support (gamebanana browser) (just like GMod)

- Rebuilding how the MODDING API works and adjusting it to be able to also support other languages (Common Modding API)

- Making 99,9% of all engine aspects modifiable by softmods. (Python & Lua)

## 1. BUILD / TOOLCHAIN (all targets green)

- **[P0] HashLink target blocked.** `lime.hdll` missing locally, HL wasn't verifiable, HL agent dead-ended. Install a compatible HashLink (`lime.hdll` + `lime-hdiowrap`), fix any compile errors, re-enable the `hl` CI job in `.github/workflows/main.yml`. ([#63](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/63))
- **[P0] CI Android build.** ([#64](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/64)) Local Android can't be validated: NDK **28.1.13356709** fails on `aarch64-linux-android-strip` (NDK 28 ships only `llvm-strip.exe`; wrapper copy was made but build still fails) and NDK 28 libc++ has a `__posix_l_fallback.h` redefinition bug. Android CI now explicitly pins NDK **27.0.12077973 (r27)** in both workflows; the next CI result must confirm the Android build and merged manifest. Options:
  - Install NDK 27.0.12077973 locally (matches CI) to reproduce `#if mobile` errors faithfully.
  - Or fix the NDK 28 header conflict (locale redefinition) instead of pinning old NDK.
  - Re-run android build to green, then commit + push.
- **[P1] macOS/Linux `sendFakeMsgBox` are TODO** (`source/backend/PlatformUtil.hx:10-11`, `source/utils/PlatformUtilNative.hx:86`). Add native `osascript`/`zenity`/`kdialog`-based implementations so crash dialogs work on all desktops; remove the `trace('not available')` stubs. ([#66](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/66))
- **[P2] Refactor relic `REFACTOR:` comments** — dozens across `source/editors/`, `source/headers/`, `options/`. They document relocations but say nothing actionable. Fold into proper file headers or delete. ([#73](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/73))
- **[P3] Remove dead Flash/Air code paths** — `officialBuild` feature flag never applied (`project.hxp`), unused `renderAll`/`ULTRA_OPTIMIZED` experiments, `WindowColorMode` flash stubs (trace-only). ([#78](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/78))

## 2. GAMEPLAY / PSYCH SYNC (P3 imports)

- **[P3] Missing funkin.vis cross-target** — `SpectralAnalyzer` patched; check hacking shaders (`Glitch`, `Chromatic`, `Malmo`?) compile on flash/air (`#if desktop` guard audit, §9). ([#79](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/79))

### 2.1. 4th WALL BREAKING


## 3. PLATFORM

- **[P2] Fix fullscreen issues on Android (and other OSes maybe)** - Phones with some cutouts currently don't launch the game with 100% fullscreen, create a toggle that can switch between "Respect cut-out" or "Real Fullscreen". Im pretty much sure this will envolve Native Kotlin/Java in order to work. ([#75](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/75))
- **[P3] iOS** — likely needs `#if ios` nuances (video/hxvlc below). ([#80](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/80))

### WINDOWS / LOW-LEVEL WINDOW MANAGEMENT

Top 10 inventory of the engine's native window-manipulation paths and the Windows APIs they use:

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

- **[P2] Install a mod from a `.zip`.** `AndroidStorage` knows the `zip` MIME type (`AndroidStorage.hx:232`) but nothing extracts it — `haxe.zip` is never used in `source/`. Add "Import mod (.zip)" to the SAF picker, extract into `mods/<folder>/`, reject traversal/absolute entries (same rules as §6 #65), validate `pack.json` before enabling, then reload the list. This is the only practical install path on a phone without a file manager.

### INTENTS / EXTERNAL INTEGRATION

- **[P3] Phoenix URI / deep-link system** — PARTIAL: Android registers the `phoenix://` scheme and forwards intents (`PhoenixCore.handleNewIntent` → `AndroidIntents.onDeepLink`); per-screen routing UI still to do — Add a platform-independent URI routing system for directly opening songs, charts, mods, replays, menus, and other engine resources (e.g. `phoenix://song/bopeebo?difficulty=hard`, `phoenix://mod/whitty/song/lo-fight`, `phoenix://screen/freeplay`). Android should register the `phoenix://` scheme and forward incoming intents to Haxe; expose parsed URI data to Haxe/Lua/HScript and keep the system extensible for other platforms. ([#93](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/93))

### NOTIFICATIONS

- **[P3] Finish or remove `AndroidNotification`.** It exposes a channel, `requestPermission()` for Android 13+ and `notify()/cancel()`, but no Haxe caller posts anything (only the Media3 notification is live). Either wire it to opt-in events — "chart backup saved", "crash log exported", "update available" (§12.6 auto-updater is still a non-goal) — or delete it as dead code alongside §1's Flash/AIR cleanup.

### DISCORD / EXTERNAL SERVICES

- **[P3] Discord RPC reconnect.** `DiscordClient.check()` runs once from `ClientPrefs.loadPrefs()`, so if Discord starts after the game or restarts, presence stays off until Phoenix is relaunched. Add bounded reconnect/backoff on `onDisconnected` (`DiscordClient.hx:95`) with a visible toggle, and keep the `request[0].username` AIR guard from §5 #85.

### NATIVE BRIDGE / ARCHITECTURE

- **[P2] Bridge contract check.** There are 64 `JNI.createStaticMethod` sites in `source/android/platform/`, each binding a Java method by string name *and* signature. A Java rename or signature edit still compiles and fails only at runtime as a silent no-op. Add a test (next to `tests/java/.../PhoenixMediaBridgeStateTest`) or a generated table that parses both sides and fails CI on a mismatch, then list every method in `docs/ANDROID_PLATFORM.md`.

## 12. CODENAME ENGINE (CNE) PARITY — DIFFERENCES NOT YET IMPLEMENTED

Added from the supplied CNE-vs-vanilla/Psych comparison, filtered against the current tree. CNE-like features Phoenix already has (runtime Lua/Python, note skins, hxvlc video, Discord RPC, `funkin.vis`, Aseprite/multi-atlas support, custom volume tray, Windows titlebar colors, opponent/both-sides gameplay, P1/P2 vocal split, etc.) are intentionally omitted. Priorities reflect payoff for Phoenix, not blind CNE cloning; anything marked **breaking** needs an importer/compatibility flag before it lands.

### 12.1 SCRIPTING & FULL-ENGINE SOFTCODING

- **[P1] Scripted states/substates.** No `data/states/StateName.hx` loader exists. CNE can softcode every state/substate; Phoenix menus, pause, game over, transitions, credits, freeplay, etc. remain source-only. `CustomSubstate` is only a scripted substate helper, not full state replacement.
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
- **[P2] Multi-format audio.** `Paths.SOUND_EXT` is only `mp3` on web/Flash and `ogg` elsewhere. Add flac/opus/wav (and per-format fallbacks) like CNE.
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
- **[P3] Low Memory Mode.** Current optimization options include GC/cache toggles, but not CNE-style appearance/low-memory profiles.
- **[P3] Localization / translations.** No language key system or locale files.
- **[P3] Lagless GitHub contributors + mod credits.** Credits are static; add cached GitHub contributor fetching and per-mod credit integration.
- **[P3] Complete mouse support in base menus.** Freeplay/Story/Mods have partial wheel/click support; main menu/credits/etc. still need full mouse navigation.
- **[P3] Free gamemode keybind.** Not implemented.

### 12.5 RENDERING, SHADERS, MODCHARTS & 3D

- **[P2] FunkinModchart-style advanced modcharts.** Phoenix has Lua sprite/text/tween helpers, but no dedicated modchart library/runtime.
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
- **[P2] Hold-to-confirm and larger touch targets.** Deleting a mod/save/chart, "Exit to menu" and "Reset all settings" are single taps today, several with small hitboxes on mobile. Require a held press (or a second confirmation) and enlarge the touch area without changing the art.
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
- **[P3] Shader warm-up.** First use of a stage/song shader (including runtime shaders in `RuntimeShaders.hx`) can hitch on the first bop. Compile the shaders a stage declares on the loading screen and cache the compiled program where the backend allows it.
- **[P3] Device benchmark mode.** A fixed, mod-free stage/chart that runs ~60 s and reports average, 1% low and worst frame plus device info — reachable without F3/F6, which do not exist on Android. Reuses `FrameProfiler.exportLog()`; this is a *test run*, not the live counter in §12.4.

## 19. DIAGNOSTICS, SUPPORT & SAFE MODE

`CrashHandler` catches errors, writes text logs and shows a summarized-reason screen, but recovery is still manual: the next launch re-enters the same mod/save, Android users can't easily reach `logs/`, and support requests have to ask for versions by hand.

- **[P1] Safe Mode after repeated crashes.** Count unclean starts, then offer "start with all mods disabled", "start with fresh prefs", "start with default resolution/framerate" *before* `InitState` loads mods. A single bad `pack.json`/script currently turns into a crash loop the player must fix by editing files.
- **[P2] "Copy diagnostics" action.** One button producing a redacted, pasteable block: engine version (`VERSION` in `project.hxp`), commit (`HaxeCommit`), target, `SystemInfo` CPU/RAM, GPU/driver (#96), save path, mod list + order, non-default prefs, last N log lines. Offline only — the recent update flow is deliberately repo-based (§0), so no auto-upload.
- **[P2] Crash bundle export.** Alongside the log, write a `.zip` (crash text, `modsList.txt`, each mod's `pack.json`, prefs, screenshot) to a user-reachable folder — critical on Android where `logs/` is buried in app storage. Depends on §6 #70's target guard and pairs with §11 FILES.
- **[P2] Log rotation and redaction.** `logs/` accumulates a file per crash and per profiler export with no cap. Rotate by size/age and strip usernames/absolute paths before a log leaves the machine.
- **[P3] Per-mod "why did it break?" report.** In the mods menu, show last load error, invalid `pack.json`, blocked script rule (§6 sandbox) and missing-asset count per mod, instead of requiring a log read.
- **[P3] Deep-linkable diagnostics.** Once the §11 URI routing layer lands, add a read-only `phoenix://diagnostics` route so support can ask a user to tap one link and screenshot the result.

## 20. TESTING & RELEASE VERIFICATION

There is real infrastructure to extend: `tests/test_*.py` (static/source guards, run in `checks.yml`), `tests/haxe/*Spec.hx` (layout, chart timing, mod security, pooling) and host-JVM Java tests for the Media3 bridge and SAF policy. There is no compatibility corpus, no save/chart round-trip guarantee and no performance gate.

- **[P2] Mod compatibility corpus.** A tiny fixture set (standard-layout `pack.json` variants, a Psych chart, a shader mod, a noteskin, Lua/Python/HScript scripts, a broken mod) loaded by a headless harness in CI. Every §12.2 format change needs this to prove old mods still load.
- **[P2] Save-migration fixtures.** Once §13 lands, ship fixture saves (old version, missing fields, truncated, newer-than-engine) and assert load/migrate/backup behaviour in the existing Python + Haxe suites.
- **[P2] Chart round-trip golden tests.** Save → load → save must be structurally identical for notes, events, BPM changes and `mustHitSection` (including the compressed path in `ChartingSaveLoad.saveLevel`). Silent field drops currently only show up in-game, and §12.4 may replace sections entirely.
- **[P3] Broaden the Haxe specs.** Add `Paths` resolution order, `Mods.parseList`/`updateModList`, `Highscore.formatSong` namespacing and replay determinism to the modules already covered by `run-layout.sh` / `run-charting-timing.sh` / `run-pool-stats.sh`.
- **[P3] First-run smoke test.** Boot with an empty save path, assert Title is reached, the save is created, no mod loads, and `flashing == null` triggers `FlashingState`. Run it on the Android emulator job from §10 as well as desktop CI.
- **[P3] Performance baseline gate.** Keep a `FrameProfiler` export for a fixed chart/build and fail when average or 1% low regress past a threshold, making the low-end promise testable instead of anecdotal.

---

## TOP 5 (do these first)
1. Commit + push the two uncommitted Android fixes (`CopyState.hx` ThreadPool, `PlatformUtilNative.hx` utsname) — they ARE the Android CI fix.
2. Resolve local NDK mismatch (install 27.0.12077973/r27 or fix the NDK 28 libc++ redefinition) so Android builds locally → green. ([#64](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/64))
3. HashLink target: install working `lime.hdll`, build, re-enable CI `hl` job. ([#63](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/63))
4. Kill `Paths.hx`/`BuildingEffect.hx` production trace spam.
5. Path-traversal + keystore-secret hardening (security). ([#65](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/65))
