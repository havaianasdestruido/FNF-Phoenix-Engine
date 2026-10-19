# Phoenix Engine — TODO / Roadmap (large feature & cleanup backlog)

Generated from full repo audit. Priority: `[P0]` critical/blocker, `[P1]` high, `[P2]` medium, `[P3]` nice-to-have. Sections grouped by system. Bold = biggest payoff. Section 12 is a filtered Codename Engine (CNE) comparison: only CNE differences that Phoenix has **not** implemented (or has only partially implemented) are listed there.

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


### LIFECYCLE / BACKGROUND


### INPUT / CONTROLLERS


### DISPLAY / RENDERING


### PERFORMANCE / DEVICE STATE

- **[P2] ~~Android thermal status API~~ REMOVED** — Intentionally not implemented: thermal monitoring offers little benefit for a game of FNF's scope, and `PowerManager.ThermalStatusListener` did not compile under the project's Android toolchain.

### FILES / MODS


### INTENTS / EXTERNAL INTEGRATION

- **[P3] Phoenix URI / deep-link system** — PARTIAL: Android registers the `phoenix://` scheme and forwards intents (`PhoenixCore.handleNewIntent` → `AndroidIntents.onDeepLink`); per-screen routing UI still to do — Add a platform-independent URI routing system for directly opening songs, charts, mods, replays, menus, and other engine resources (e.g. `phoenix://song/bopeebo?difficulty=hard`, `phoenix://mod/whitty/song/lo-fight`, `phoenix://screen/freeplay`). Android should register the `phoenix://` scheme and forward incoming intents to Haxe; expose parsed URI data to Haxe/Lua/HScript and keep the system extensible for other platforms. ([#93](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/93))

### NOTIFICATIONS


### DISCORD / EXTERNAL SERVICES


### NATIVE BRIDGE / ARCHITECTURE


## 12. CODENAME ENGINE (CNE) PARITY — DIFFERENCES NOT YET IMPLEMENTED

Added from the supplied CNE-vs-vanilla/Psych comparison, filtered against the current tree. CNE-like features Phoenix already has (runtime Lua/Python, note skins, hxvlc video, Discord RPC, `funkin.vis`, Aseprite/multi-atlas support, custom volume tray, Windows titlebar colors, opponent/both-sides gameplay, P1/P2 vocal split, etc.) are intentionally omitted. Priorities reflect payoff for Phoenix, not blind CNE cloning; anything marked **breaking** needs an importer/compatibility flag before it lands.

### 12.1 SCRIPTING & FULL-ENGINE SOFTCODING

- **[P1] First-class standalone HScript mods.** `setup/unix.sh:21` and `setup/windows.bat:13` already install CodenameCrew's `hscript-improved` as haxelib `hscript`, but `source/psychlua/HScript.hx:179-242` only exposes it through Lua (`runHaxeCode`, `runHaxeFunction`, `addHaxeLibrary`). Need direct `.hx`/`.hscript` script discovery, lifecycle, callbacks, and scoping without requiring a Lua parent.
- **[P1] Scripted states/substates.** No `data/states/StateName.hx` loader exists. CNE can softcode every state/substate; Phoenix menus, pause, game over, transitions, credits, freeplay, etc. remain source-only. `CustomSubstate` is only a scripted substate helper, not full state replacement.
- **[P1] Cancellable event-object API.** Current script hooks pass raw arguments and use `Function_Stop` returns. Add CNE-style event objects (`event.note`, `event.score`, `event.cancel()`), `onGamePause` with exclusion list, `onBopZoom`, `onSplashShown`, `onHealthIconAnimChange`, input-system events, and stage/character data events.
- **[P1] Missing script scopes.** Add scripted transitions (`MusicBeatTransition` equivalent), shader scripts, custom options/controls scripts, dialogue/cutscene scripts, and scripted asset libraries. Existing global/song/character/stage/notetype/event scripts do not cover these.
- **[P2] HScript module system.** Imports, mod-root modules/redirects, public variables, static variables, and ScriptPack-like sharing. Current HScript integration only has `addHaxeLibrary()` plus `PlayState.variables`.
- **[P2] Managed `Script.fromString`-style runtime scripts.** `HScript.execute()` can run strings, but there is no public API for creating, owning, updating, and destroying runtime script instances.
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

## TOP 5 (do these first)
1. Commit + push the two uncommitted Android fixes (`CopyState.hx` ThreadPool, `PlatformUtilNative.hx` utsname) — they ARE the Android CI fix.
2. Resolve local NDK mismatch (install 27.0.12077973/r27 or fix the NDK 28 libc++ redefinition) so Android builds locally → green. ([#64](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/64))
3. HashLink target: install working `lime.hdll`, build, re-enable CI `hl` job. ([#63](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/63))
4. Kill `Paths.hx`/`BuildingEffect.hx` production trace spam.
5. Path-traversal + keystore-secret hardening (security). ([#65](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/65))
