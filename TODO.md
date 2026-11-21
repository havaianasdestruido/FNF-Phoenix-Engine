# Phoenix Engine — TODO / Roadmap (large feature & cleanup backlog)

Generated from full repo audit. Priority: `[P0]` critical/blocker, `[P1]` high, `[P2]` medium, `[P3]` nice-to-have. Sections grouped by system. Bold = biggest payoff. Section 12 is a filtered Codename Engine (CNE) comparison: only CNE differences that Phoenix has **not** implemented (or has only partially implemented) are listed there.

Sections 13–20 are a second backlog pass written against the current tree. Every entry there was checked against §0–12: anything already listed is **cross-referenced, not repeated**, and each item names the file/behaviour that proves it is still missing. They target Phoenix's stated identity — low-end devices, easy Lua/Python/HScript modding, Android-first platform work and Psych/JS compatibility — rather than generic engine cloning.

§27 is the same kind of filtered comparison for **Mixtape Engine** (`Z11Coding/Mixtape-Engine`, reviewed 2026-11-21): engine systems, mod APIs, options and tooling only — no weeks/songs/characters/stages — with the dead code in that fork explicitly listed so it is not mistaken for features.

_quick reminder that everything i say here that is a "port" of [x] feature of the [y] engine, i will port WITH THE APROPRIATED CREDITS!!!_

_every feature ported MUST be enabled by default (unless specified beforehand) and MUST have a toggle to enable/disable or to change its options_

Examples of options:

- Colorful [thing].
- - Must make the color be customizable, or atleast have some presets

_keep in mind i will only port stuff if their license is compatible with mine (Apache 2.0 AFAIK)_

_i accept suggestions too_

---

## 0. PRIORITY-ish / UNCATEGORIZED

- On the bottom right of the screen, show the commit's git commit short id, and on top of it, show how many commits it is behind, where it change colors depending if the build is too old.
- - Green: 1-10 commits
  - Yellow: 11-25 commits
  - Orange: 26-50 commits
  - Red: 51-100 commits
  - It should fade colors depending on the git commit, dont just use the same color for the range, make it be a "rainbow-ish" pattern.

- Add those:
- - flixel.addons.effect.transition ofr states transistions, [just like in this demo](https://haxeflixel.com/demos/Transitions/).
  - ~~Loading screens with a FlxPieDial in the bottom left corner.~~ **DONE** — `backend.LoadingDialLogic` + `objects.LoadingPieDial` wired into `states.LoadingState` and `mobile.CopyState`, enabled by default (`ClientPrefs.loadingPieDial`, `ClientPrefs.loadingPieDialColor`) with toggles in Options -> Visuals and UI. Spec: `bash tests/haxe/run-loading-dial.sh`.
  - ~~Port the "pointing mouse sprite at button" thingy from [this demo](https://haxeflixel.com/demos/Cursor/).~~ **DONE** — `backend.PointingCursorLogic` + `objects.PointingCursor` park a finger sprite on the hovered/selected menu button (`FlxUICursor` pick/anchor math). Off by default; enable it and choose its style and color in the Super Secret Debug Menu. Wired into Main Menu, Story, Freeplay, Pause, Options. Spec: `bash tests/haxe/run-pointing-cursor.sh`.
  - ~~Add pretty much all filters from FlxG.camera.filters & FlxG.game.filters to modding API.~~ DONE — `backend.ScreenFilters` + `psychlua.callbacks.FilterCallbacks` expose the six OpenFL filters (`addBlurFilter`, `addGlowFilter`, `addDropShadowFilter`, `addColorMatrixFilter`/`addColorFilter`, `addConvolutionFilter`, `addDisplacementMapFilter`, plus the generic `addFilter`) with a named per-target registry (`removeFilter`, `clearFilters`, `hasFilter`, `get/setFilterProperty`, `getFilterPresets`) in Lua, Python and HScript. Targets are cameras or `'global'` for `FlxG.game` (the `FlxGame` patch makes `filters` behave like `FlxCamera.filters`); a sprite is not a filter target in Flixel. A sprite target is refused with a message pointing at the shader/chainable APIs.
  - - ~~add all these too in modding api: flixel.addons.effects.chainable~~ DONE — `backend.ChainableEffects` wraps a sprite in a `FlxEffectSprite` in place and exposes shake, wave, glitch, rainbow, outline and trail (`addSpriteShakeEffect`, `addSpriteWaveEffect`, `addSpriteGlitchEffect`, `addRainbowEffect`, `addSpriteOutlineEffect`, `addSpriteTrailEffect`, the generic `addChainableEffect`, and `remove/get/clear` + `setChainableEffectsEnabled`). Same registration object for all three languages; tests in `tests/haxe/run-screen-filters.sh`; docs in `docs/SHADERS.md`; runnable tour in `example_mods/scripts/FiltersExample.lua`.
  - Add flixel.addons.effects.FlxClothSprite as a easter egg, [just like in this demo.](https://haxeflixel.com/demos/FlxClothSprite/)
  - Add tooltips to all parts of the engine that uses `flixel-ui`, [just like on this.. uhh. demo right over here.](https://haxeflixel.com/demos/Tooltips/)

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
  - ~~game filter thing (dautonic stuff and other filster like the "gameboy" one and the "invert" one)~~ DONE (mod side) — the colour-matrix presets cover it: `addColorFilter(target, name, 'gameboy' | 'invert' | 'sepia' | 'greyscale' | 'nightvision' | 'sepiacold' | the three colour-blindness simulations | 'identity')`, or `addColorMatrixFilter` with a raw 20-float matrix. `getFilterPresets()` lists them from a script. An in-engine Options menu toggle for it is still open.
  - ~~their cool icons~~ DONE — the Mic'd Up and Vanilla health-icon sets ship as selectable styles (`ClientPrefs.iconStyle`, Options → Visuals and UI → Health Icon Style; `backend.IconStyle` + `HealthIcon` fallback chain). See [Mic'd Up icons](docs/MICD_UP_ICONS.md).
  - ~~the difficult icons redrawed~~ DONE — `assets/preload/images/menudifficulties/` (except Phoenix-only `jshard`) are crops of Mic'd Up's redrawn `difficulties.png` atlas. See [Mic'd Up icons](docs/MICD_UP_ICONS.md).
  - cool modes
  - - Marathon
    - Endless
  - brightness & gamma option
  - Engine logo watermark
  - CHAOS mode, Dual Arrow mode, Dual CHAOS mode
  - micd up ranking thing (S, A, etc..)
 
- Port these cool stuff from Troll Engine:
  - [source/funkin/api/Github.hx](https://github.com/troll-slaiyers/FNF-Troll-Engine/blob/main/source/funkin/api/Github.hx) - Utils for in-game update screen and other social stuff
  - https://github.com/troll-slaiyers/FNF-Troll-Engine/tree/main/flixel/flixel-ui/img - port their dark flixel-ui system too.

- Port these cool stuff from Doido Engine:
  - settings fully centered instead of being on the left
   
- Port the C++ GDI payloads from Slushi Engine:
- - https://github.com/Slushi-Github/Slushi-Engine/tree/260410345801c84ac188e0b3c73e6b97e94de59c/funkinscsource/slushi/windows
 
- add mario madness modifiers: https://github.com/Dewott2501/Mario-Madness/tree/main/source/modchart/modifiers _(checked against the tree: only two are actually missing, see §23.1)_

- Variable key count / multikey charts (1K–10K). Reviewed against **Psych Engine Extra Keys +**, which is the only fork with a working implementation: see §25.1. That implementation is 2022-era code, so this is a rewrite, not a port.
#### Rebuilding how the MODDING API works and adjusting it to be able to also support other languages (Common Modding API)

Should include exposing almost ALL game screens thought the Modding API. (By screen I mean like the Freeplay page, Mods page, etc.)

- Should contain all in-game screens. (only exclude critical ones like the update screen and the mods picker screen)

- Mods should be able to change assets placement, size, change its assets, or even just toggle it off

- Should not bloat the whole engine

- Making 99,9% of all engine aspects modifiable by softmods. (Python & Lua)

- Adding all upstream-upstream Psych Engine 1.0 new features/commits, keeping in mind that our codebase was refactored.

- Resizing ALL backgrounds to half it's size and just zoom them 2x (gama baja optimization)

- Adjusting for lower Android SDK target (I want to play on my Android 5.0 phone), but only on a new experimental branch.

---

## 1. BUILD / TOOLCHAIN (all targets green)

- **[P0] HashLink target blocked.** `lime.hdll` missing locally, HL wasn't verifiable, HL agent dead-ended. Install a compatible HashLink (`lime.hdll` + `lime-hdiowrap`), fix any compile errors, re-enable the `hl` CI job in `.github/workflows/main.yml`. ([#63](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/63))
- **[P0] CI Android build.** ([#64](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/64)) Local Android can't be validated: NDK **28.1.13356709** fails on `aarch64-linux-android-strip` (NDK 28 ships only `llvm-strip.exe`; wrapper copy was made but build still fails) and NDK 28 libc++ has a `__posix_l_fallback.h` redefinition bug. Android CI now explicitly pins NDK **27.0.12077973 (r27)**. Options:
  - Install NDK 27.0.12077973 locally (matches CI) to reproduce `#if mobile` errors faithfully.
  - Or fix the NDK 28 header conflict (locale redefinition) instead of pinning old NDK.
  - Re-run android build to green, then commit + push.
- **[P3] Remove dead Flash/Air code paths** — `officialBuild` feature flag never applied (`project.hxp`), unused `renderAll`/`ULTRA_OPTIMIZED` experiments, `WindowColorMode` flash stubs (trace-only). ([#78](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/78))

## 2. GAMEPLAY / PSYCH SYNC (P3 imports)

- **[P3] Missing funkin.vis cross-target** — `SpectralAnalyzer` patched; check hacking shaders (`Glitch`, `Chromatic`, `Malmo`?) compile on flash/air (`#if desktop` guard audit). ([#79](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/79))

### 2.1. 4th WALL BREAKING

Follow-ups to the opt-in `-DMETA_HORROR` effects ([`docs/META_HORROR.md`](docs/META_HORROR.md)):

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

- **[P3] iOS** — likely needs `#if ios` nuances (video/hxvlc below). ([#80](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/80))

## 4. VIDEO / AUDIO

- **[P3] Offsync long-session** — `MusicBeatState`/`Conductor` saved to same-tick; watch for drift on `sustain` notes w/ `playbackRate != 1`. ([#83](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/83))

## 6. SECURITY

- **[P0] Path traversal** — `WeekData`, `Mods`, `SSPlugin` read user JSON; `Paths.modsJson` splices `songName` into paths. `CoolUtil` mod asset walker uses `FileSystem` unguarded non-sys target? Audit brings up `#if (!target)` correctness. Ensure mod names are sanitized (`..`/absolute) before `FileSystem.exists`. ([#65](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/65))
- **[P3] No signature/webhook secrets** — `ChartingSaveLoad`/`WeekData` parse `JSON` without try/catch around `File.getContent` (some are). ([#86](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/86))

## 8. PERFORMANCE / MEMORY

- **[P3] `cast` / `Reflect.field` in per-frame paths** — `ChartChartingUI`/`Conductor` use `Reflect.field(ClientPrefs, ...)` in window accessors; cache static before loop. ([#90](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/90))
- **[P2] Chart load cost is unmeasured** — every song start (and every practice-mode retry) re-reads, re-parses and re-sorts the chart JSON: `data/Song.hx:169` (`File.getContent` → `Json.parse` → `onLoadJson`) then `play/helpers/PlayStateChartLoader.hx` (one 26-field object per head, per jack and per sustain segment, then `FlxSort`). The packed-storage/binary-cache spec that would remove it, and the baseline that gates it, are in [§26](#26-binary-charts-and-the-gpu-note-backend-js-engine-fork-review).

## 10. CI / REPO HYGIENE

- **[P1] .github CI android emulator `CopyState`** — the Android job in `main.yml` only builds the APK and checks its manifest and native libs; nothing boots it on an emulator, so `CopyState` and first-run startup are never exercised in CI. ([#72](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/72))

## 11. ANDROID NATIVE / PLATFORM INTEGRATION

### MEDIA / AUDIO

- **[P3] Media3 progress vs. engine clock.** `PlayStateAndroidMedia.refreshPlaybackState()` pushes a rate-aware position, but `PhoenixMediaBridgeStateTest` has no position/rate case that asserts it.

### INTENTS / EXTERNAL INTEGRATION

- **[P3] Phoenix URI / deep-link system** — two pieces left: `phoenix://replay/<id>` is reserved and only answers "not implemented" (it needs the replays in §14), and parsed URI data only reaches the Haxe static `DeepLinks.onDeepLink`; no Lua/Python/HScript callback is fired for it. ([#93](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/93))

### DISCORD / EXTERNAL SERVICES

- **[P3] Discord RPC reconnect.** The bounded reconnect/backoff in `DiscordClient` has no visible toggle of its own, and `DiscordClient.retryConnection()` (manual retry once the five attempts run out) has no caller; add the option row next to Discord Rich Presence.

## 12. CODENAME ENGINE (CNE) PARITY — DIFFERENCES NOT YET IMPLEMENTED

Added from the supplied CNE-vs-vanilla/Psych comparison, filtered against the current tree. CNE-like features Phoenix already has (runtime Lua/Python, note skins, hxvlc video, Discord RPC, `funkin.vis`, Aseprite/multi-atlas support, custom volume tray, Windows titlebar colors, opponent/both-sides gameplay, P1/P2 vocal split, etc.) are intentionally omitted. Priorities reflect payoff for Phoenix, not blind CNE cloning; anything marked **breaking** needs an importer/compatibility flag before it lands.

### 12.1 SCRIPTING & FULL-ENGINE SOFTCODING

- **[P1] Cancellable event-object API.** Current script hooks pass raw arguments and use `Function_Stop` returns. Add CNE-style event objects (`event.note`, `event.score`, `event.cancel()`), `onGamePause` with exclusion list, `onBopZoom`, `onSplashShown`, `onHealthIconAnimChange`, input-system events, and stage/character data events.
- **[P1] Missing script scopes.** Add scripted transitions (`MusicBeatTransition` equivalent), shader scripts, custom options/controls scripts, dialogue/cutscene scripts, and scripted asset libraries. Existing global/song/character/stage/notetype/event scripts do not cover these.
- **[P2] HScript module system.** Mod-root modules/redirects and ScriptPack-like sharing. Standalone HScript currently stops at native `import`, public/static variables, `addHaxeLibrary()` and `PlayState.variables` sharing.
- **[P2] Managed `Script.fromString`-style runtime scripts.** A general cross-language runtime-script manager (Lua/Python too, outside PlayState). Today only `HScript.fromFile(name, ?code)` creates an owned instance from a file or a raw string, and it lives in `PlayState.hscriptArray`.
- **[P2] Script hot reload.** Mods menu reload currently restarts/reloads states through `ModsMenuHelpers.reload`; CNE-style test builds can hot-swap scripts without restarting the relevant context.
- **[P3] NDLL / compiled native scripting.** No `.ndll` loader, bridge, or API exists.
- **[P3] Continue PlayState decomposition.** Phoenix already split helpers, but CNE's rewritten gameplay core is much smaller; see §8 for the existing perf/allocation backlog.

### 12.2 DATA, ASSET & FILE STRUCTURE

- **[P2] XML definitions for characters, stages, weeks, and dialogue.** Phoenix still uses Psych-style JSON (`assets/preload/characters/*.json`, `assets/preload/stages/*.json`, `assets/preload/weeks/*.json`). The only XML assets are Sparrow atlases/UI sheets.
- **[P2] CNE song folder layout.** Need `songs/<name>/meta.json`, `songs/<name>/charts/<difficulty>.json`, `songs/<name>/song/`, and `songs/<name>/scripts/`. Phoenix uses `data/<song>/<song>-<difficulty>.json` plus `assets/songs/<song>/Inst.*` / `Voices.*`.
- **[P2] `meta.json` metadata.** Add a real metadata file that syncs freeplay/difficulties/charts and carries custom fields.
- **[P2] Global charts folder.** CNE supports global `data/charts/`; Phoenix only resolves per-song JSON paths.
- **[P2] Custom chart/character properties.** Expose CNE-style `SONG.meta.customValues` and `char.extras`; current `SwagSong`/`CharacterFile` use fixed fields.
- **[P2] True song variations.** `specialAudioName` only swaps an audio suffix; add variation metadata, chart selection, and freeplay preview behavior.
- **[P2] Extra audio formats (flac/opus/wav).** `Paths.SOUND_EXTENSIONS` only resolves `.ogg` → `.mp3` per file; flac/opus/wav support is another entry in that list plus a decoder check per target.
- ~~**[P2] Unlimited vocals per strumline.** Phoenix supports separate P1/P2 vocal files, but not CNE's arbitrary per-strumline vocals.~~ **DONE** — charts declare any number of extra vocal stems via `extraVocals` (`[{name, file, side}]`, with CNE-style `vocalsSuffix`/`strumline`/`type` aliases), parsed by `data.ExtraVocals` and loaded/played back by `play.helpers.PlayStateExtraVocals`. Each stem resolves its own `Voices-<file>[-<difficulty>].ogg` (native and web), follows its strumline side's miss-muting (`player`/`opponent`/`none`), joins every pause/seek/resync/pitch path, honors the Vocal Volume Override, and is scriptable from Lua/Python/HScript (`getExtraVocalNames`, `set/getExtraVocalVolume`, `set/getExtraVocalPitch`). The Chart Editor and editor playtest preview the stems with per-side volume/mute controls. Enabled by default; toggle in Options -> Gameplay Settings -> Extra Vocal Stems. See [Extra vocals](docs/EXTRA_VOCALS.md). Spec: `bash tests/haxe/run-extra-vocals.sh`.
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
- ~~**[P2] Stage Editor.** `MasterEditorMenu` has no stage editor.~~ **DONE** — `editors.StageEditorState` plus `data.StageEditorCore` (Psych-compatible `objects` graph, undo, filters). `PlayStateStageObjects` spawns the JSON at runtime; vanilla stages stay compact. Spec: `bash tests/haxe/run-stage-editor.sh`. Docs: `docs/STAGE_EDITOR.md`.
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
- **[P2] CNE/modern chart parser and rhythm-game chart import.** Psych v1 conversion exists, but CNE's extensible chart format and modern FNF parser are absent. Extend the importer to support StepMania `.sm`/`.ssc` simfiles as a separate compatibility path, including mine rows (inspired by the [Rudyrue/custom-psych comparison](https://github.com/ShadowMario/FNF-PsychEngine/compare/main...Rudyrue:custom-psych:main)). Preserve chart timing, player side, holds/rolls, and mine semantics; never silently discard unsupported hazards. Define an explicit conversion or playable mine behavior, add fixture-based tests, and verify the implementation's license/credit requirements before porting code.
- **[P2] Camera zoom multipliers / bop events.** No `camGameZoomMult`, `camHUDZoomMult`, configurable lerp speeds, sprite/text angle/zoom factors, or `onBopZoom`.
- **[P2] True local co-op.** Phoenix has `bothSides`, but one player still hits both sides; `PlayerSettings.player2` is not wired into gameplay input. Add real P2 controls and rebinds.
- **[P3] Gitaroo easter-egg toggle.** Not present.
- **[P3] Desktop audio-device hotplug.** Android audio focus/interruptions are done; desktop headphone/device-change recovery is missing.
- **[P3] Advanced FPS counter.** Add 1% lows, selectable/copyable diagnostics, and a true uncapped mode. Current option is merely capped at 1000 FPS.
- **[P3] Localization / translations.** No language key system or locale files.
- **[P3] Lagless GitHub contributors + mod credits.** Credits are static; add cached GitHub contributor fetching and per-mod credit integration.
- **[P3] Complete mouse support in base menus.** Freeplay/Story/Mods have partial wheel/click support; main menu/credits/etc. still need full mouse navigation.
- **[P3] Free gamemode keybind.** Not implemented.

### 12.5 RENDERING, SHADERS, MODCHARTS & 3D

- **[P2] Modchart `ArrowShape` / `PathModifier` ports and a skew-capable renderer.** The native modchart runtime (`source/modchart/`, see [`docs/MODCHART.md`](docs/MODCHART.md)) only ports offset-based modifiers, and `skewX`/`skewY` are stored but not drawn because Flixel sprites cannot shear.
- **[P3] Real 3D support (FoxLite/Away3D equivalent).** `ThreeDEffect`/`ThreeDShader` are shader effects, not a 3D scene/renderer.

### 12.6 MOD PACKAGING, VERSIONING & RUNTIME CONFIG

- **[P1] Addon system with load priority.** Phoenix has normal mods and `pack.runsGlobally`, but no CNE-style addons that layer over core/other mods with explicit before/after priority.
- **[P2] `modpack.ini` / API versioning.** `pack.json` lacks API/engine version metadata and outdated-mod warnings.
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

There is exactly one persistent store: `FlxG.save` bound as `funkin` in `InitState.hx:34`. `ClientPrefs.save()` copies every static field into it by reflection, and `Highscore` (`songScores`, `songRating`, `weekScores`), `Achievements` and the playtime counter all live in the same blob; only keyboard binds got a separate `controls_v2` file. There is no schema version, no backup, no atomic write and no full export.

- **[P1] Save schema version + migrations.** `ClientPrefs.loadPrefs()` reflects every class field and assigns whatever the save contains; a renamed, retyped or removed field silently keeps a stale value or falls back to the default, and the reverse direction (opening a newer save in an older build) writes unknown keys back unchanged. Add a `saveVersion` key, an ordered rename→convert→drop migration chain, and a spec that loads a fixture from each older layout.
- **[P2] Split the monolithic save.** Prefs, highscores, achievements and playtime share one `funkin` file, so one truncated flush loses everything. `controls_v2` already proves the pattern; give scores/achievements/prefs their own FlxSaves (or namespaced keys) and make "reset only my scores" possible without wiping settings.
- **[P2] Atomic, verified writes.** `FlxSave.flush()` rewrites in place. On Android a kill mid-flush can leave a truncated file and the next boot quietly starts from defaults. Write to a temp file, verify it parses, then rename, and keep one `.bak` so a failed boot can offer the previous save.
- **[P2] Profile slots.** Everything is global per install. Content creators and co-op/competitive testing need named profiles under `CoolUtil.getSavePath()` (e.g. `profiles/<name>/`), with create/duplicate/rename/delete and a "current profile" indicator. Must migrate the existing save into `profiles/default/` so nobody loses progress (§13 P1).
- **[P2] Export/import a save bundle.** A JSON (or zip) with prefs, scores, achievements, binds, engine version and mod list, so players can move Android ↔ desktop or to a new phone without root. Export is manual; import shows exactly what will be overwritten and never happens automatically.
  Still missing: scores, achievements and the mod list. `backend.SettingsBackup` ("Export/Import Settings (.json)") only carries prefs, gameplay modifiers, keybinds and audio volume.
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
- **[P3] Poll-rate and key-rollover audit.** `PlayStateInput` reads `FlxG.keys`/`firstJustPressed` once per frame; on high-polling keyboards and multiple keys per frame, presses can merge or drop. Test with a 1000 Hz device, document the behaviour, and avoid per-frame allocations in the hot path (§8). The measuring tool exists: the input tester (`states/InputTestState`, `phoenix://input`, also Options → Gameplay → Input Tester) shows, as the game receives them, how many presses land inside one frame, how many taps go down and come back up inside one, and how many inputs each device reports at once. Checked while building it: outside controller mode, keyboard presses are already judged from stage `KEY_DOWN`/`KEY_UP` events (`PlayState.hx:1757-1758`, `PlayStateInput.onKeyPress`), the same events the tester times; what is read once per frame is held notes, controller mode, gamepads and the touch lanes (`PlayStateInput.handleKeyInput`). Still open: the run on a 1000 Hz device, writing down what it shows, and the hot-path allocations.
- **[P3] Android TV / remote navigation.** D-pad-only navigation and Back handling across Main Menu, Freeplay, Mods and Pause, a leanback launcher entry, and a UI that is usable without a touchscreen. TV boxes are a real low-end target for this engine.

## 16. ACCESSIBILITY & COMFORT

`ClientPrefs.flashing` is honoured one call site at a time (`Philly.hx:84-225`, `PlayStateEvents.hx:542`), and the warning in `TitleState.hx:171` → `FlashingState` is once-per-install. Options has no accessibility category (`OptionsState.hx:35`).

- **[P1] Central `reducedMotion` preference.** `ClientPrefs.reducedMotion` gates beat bops, event zooms/shakes and character screen shake, but per site. Still to do: camera scroll, menu tweens and stage flashes, moved into one helper that stages/scripts can query. The option row is tracked in §21.4.
- **[P2] ~~Add an Accessibility options category~~ DONE** — `options/AccessibilitySubState.hx` (`Options -> Accessibility`, alongside `Visuals and UI`) gathers photosensitivity, reduced motion, camera effects intensity, high contrast, stage dim, colorblind note palettes, luminance contrast, lane glyphs, visual beat indicator, dialogue comfort rows, UI scale, and hold-to-confirm in one place. Spec: `bash tests/haxe/run-accessibility.sh`.
- **[P2] ~~High-contrast / colorblind note palettes~~ DONE** — `backend.Accessibility` + `objects.NoteColors` + `play.helpers.PlayStateAccessibility`: named `noteColorblindPreset` palettes (`None` / `Deuteranopia` / `Protanopia` / `Tritanopia`, normal + pixel + Daltonized quants without overwriting custom `arrowRGB`/`arrowRGBPixel`/`quantRGB`), `forceLuminanceContrast` (monotonic WCAG relative-luminance bands across all four lanes + crisp dark borders), ASCII `laneGlyphs` (`<`, `v`, `^`, `>` for `vcr.ttf`), and `highContrast` (menu backdrop/description contrast, HUD score backing strip, thicker HUD text borders, and a 45% minimum stage-dim floor). Spec: `bash tests/haxe/run-accessibility.sh`.
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
  Guards must read the PRESSED-bound twins (`controls.ACCEPT_P` / `controls.RESET_P`), never
  `controls.ACCEPT` / `controls.RESET`: those are bound as JUST_PRESSED, so a guard fed one of
  them drew a single frame of bar and cancelled on the next frame ("held Exit to game and
  nothing happened"). `HoldToConfirmCallSitesSpec` scans every guard for this.
  Docs: `website/docs/subsystems/options-menu.md`, `website/docs/subsystems/mobile.md`.
  Specs: `bash tests/haxe/run-hold-to-confirm.sh`, `bash tests/haxe/run-hold-to-confirm-typecheck.sh`.
- **[P3] Re-openable photosensitivity warning.** `showPhotosensitivityWarning` is now exposed in Options -> Visuals and UI / Accessibility and re-arms `FlashingState` for the next Title visit (`FlxG.save.data.photosensitivityWarningPending`), while `FlashingState` also honours `reducedMotion` / `flashIntensity`. Still open: a quick "Reduce flashing" toggle in the pause menu.
- **[P3] ~~Visual beat indicator~~ DONE** — `ClientPrefs.visualBeatIndicator` + `play.helpers.PlayStateAccessibility`: optional screen-edge pulse on countdown ticks and song beats (suppressed on pause, cutscenes, seeks, and FFmpeg renders), scaling down alpha and keeping bar thickness fixed when `reducedMotion` is enabled. Spec: `bash tests/haxe/run-accessibility.sh`.

## 17. MODDER TOOLING & SCRIPT SAFETY

Modding is a core promise (Lua + Python + HScript, `ModSecurity`, `ScriptSecurityScanner`, `CustomSubstate`, custom events/notetypes), but the authoring loop is still "run the game, read a log". `Mods.getPack()` parses `pack.json` with `tjson`, and `pack.json` only understands `name`, `description`, `restart`, `color`, `runsGlobally`, `scriptSandbox` and `scriptSandboxAllowlist`.

- **[P1] Script execution budget / watchdog.** Lua (`FunkinLua`), Python (`PythonScript`) and HScript (`HScript`) callbacks run inline on the main thread. A `while true do end` freezes the frame with no log, and on mobile there is no console. Add a per-callback instruction/time budget, abort with `file:line`, disable only the offending script for the session (assets stay), and surface the event in the mods menu.
- **[P2] Mod linter CLI (`tools/`).** Validate `pack.json` schema, unknown/duplicate folders (reusing `Mods.ignoreModFolders`), assets referenced by character/stage/week JSON, duplicate achievement IDs, difficulty names, and Lua/Python/HScript syntax before shipping. This is also what makes the §20 compatibility corpus possible.
- **[P2] Dependency and conflict metadata.** Add `id`, `version`, `requires` and `conflicts` to `pack.json`, with a resolve/report step before enabling. Without stable ids, `modsList.txt` is ordered by folder name and "requires ModX ≥ 1.2" is impossible. (Distinct from the CNE addon load-priority work in §12.6.)
- **[P2] Script error overlay with actions.** Show `file:line`, traceback and the offending snippet, with "reload script", "disable for this session" and "open folder". Today a failing script traces to a log or takes the state down; pairs with the §19 diagnostics work.
- **[P2] Path resolution debugger.** `Paths.modFolders()` silently returns the first hit across active mod → global mods → loose `mods/` → `assets/`. Add an overlay/console command that prints every candidate for a key, whether it exists, and which mod won, plus a grouped "missing assets" list. This is the natural complement to the `Paths` trace cleanup (#68).
- **[P3] Asset hot reload (desktop).** Watch the active mod's `images/`, `sounds/`, `music/` and `data/` and reload images/audio/charts without restarting the state. Complementary to the script hot reload in §12.1 — one covers code, this covers assets.
- **[P3] Mod scaffold generator (`tools/new-mod.py`).** Produce `pack.json`, the standard content folders and starter `scripts/`, `custom_events/`, `custom_notetypes/` from `docs/TemplateScript.lua`/`.py`, so a new mod starts valid instead of with a typo'd folder name.

## 18. LOW-END PERFORMANCE & FRAME PACING

Phoenix's identity is "runs on weak devices", yet configuration is manual: `ClientPrefs` defaults are desktop-oriented and Options exposes dozens of toggles. Existing infrastructure to build on: `SystemInfo` (logical CPU count, physical RAM, page size), `FrameProfiler` (F3 overlay, F6 CSV/log export, `setStateName`), `PoolStats`, `Paths.clearUnusedMemory()`/`clearStoredMemory()` and the `dumpExclusions` list.

- **[P1] First-run performance profile.** Use `SystemInfo` plus the GPU/driver detection from open issue #96 to pick an initial preset (framerate, `lowQuality`, `shaders`, `cacheOnGPU`, `dynamicSpawnTime`, GC flags, splash limit), tell the player it was applied, and keep every value editable. Today a low-end phone starts with desktop defaults and the player has to find Optimization by hand.
- **[P2] Texture/atlas memory accounting.** `backend.MemoryLedger` logs estimated asset RAM/VRAM totals per area and per mod, but nothing lists the loaded `FlxGraphic`s (size, source, owning mod/stage) or the biggest atlases, and nothing warns when a stage exceeds a budget. Complements the §0 downscale work — you cannot tell whether a stage is over budget today.
- **[P2] Frame pacing and high-refresh support.** `ClientPrefs.framerate` is the gameplay rate; `backend.FramerateController` writes both `FlxG.updateFramerate` and `drawFramerate` (raised first when growing) and hands the value to `FrameProfiler.setTargetFps`. Add display-refresh detection, recommended values (60/90/120/144) and a separate update rate, so a 120 Hz panel doesn't run gameplay logic at 120 Hz with a different feel — and so the offsync risk in §4 #83 stays measurable. The non-gameplay side of the same problem (the menu cap this rate should not leak into) is done: `ClientPrefs.menuFramerate` and `ClientPrefs.focusLostFramerate`, Options -> Graphics, implemented next to the menu-cap half of this work in §21.3.
- **[P2] Preload/streaming policy.** Preload only the active stage and its characters; add "preload next song" for week runs, and verify `Paths` tracking actually releases the previous stage (graphics *and* cached sounds) when switching mods/songs. Debug builds can assert on tracked-vs-loaded counts.
- **[P3] ~~Device benchmark mode~~ DONE** — a fixed, mod-free test run in **Options → Optimization → Device Benchmark** (above the per-frame toggles, next to Free Memory Now). The chart is generated in code (`backend.BenchmarkChart`: 120 BPM, 30 bars, seeded-LCG deterministic, 500 notes across both sides with sustains, chords and a 16th-run finale), played on the built-in `stage` stage with botplay forced on; a deterministic 60 s synth (`tools/generate_benchmark_inst.py` → `assets/songs/phoenix-benchmark/Inst.ogg`) is bundled and also kept in compact CI builds (`project.hxp` songs list + `tests/assets/builtin-assets.txt`). Mods are suppressed for the whole run via `RecoveryBoot.modsDisabled()` (checked by `Paths`, `Mods` and the script diagnostic), so nothing under `mods/` — including a mod-shipped `stages/stage.json` — can shadow the run; the flag clears in `PlayState.destroy()` on every exit path. Measurement starts when the instrumental starts (`FrameProfiler.reset()` at `Conductor.songPosition >= 0`), not at state creation; leaving early discards the run. End-of-song diverts to `Benchmark.finish()` before any highscore/stat/achievement bookkeeping, exports via `FrameProfiler.exportLog('benchmark_<ts>.log')`, and lands on `states.BenchmarkResultsState` (one page: average FPS, 1% low, 0.1% low, worst frame, p50/p95, dropped frames, spikes, plus OS/GPU/driver/CPU/RAM and engine/commit, copyable with A/Enter/C for bug reports; Esc/B back to options, R to rerun on desktop). The pause menu drops Restart Song / Change Difficulty while active. Reachable with no F3/F6 keys, Android-safe. Spec: `bash tests/haxe/run-benchmark.sh`.

## 19. DIAGNOSTICS, SUPPORT & SAFE MODE

`CrashHandler` catches errors, writes text logs and shows a summarized-reason screen, but support requests have to ask for versions by hand.

- **[P2] "Copy diagnostics" action.** One button producing a redacted, pasteable block: engine version (`VERSION` in `project.hxp`), commit (`HaxeCommit`), target, `SystemInfo` CPU/RAM, GPU/driver (#96), save path, mod list + order, non-default prefs, last N log lines. Offline only — the recent update flow is deliberately repo-based, so no auto-upload. `backend.DiagnosticsReport` (built for `phoenix://diagnostics`) already assembles that text, so what is left is the button, plus running the result through `backend.LogUtils.redact` so a copied block is no more identifying than a saved log — the deep-linked page only *warns* about usernames in paths.
- **[P3] ~~Per-mod "why did it break?" report.~~ DONE** — `backend.ModHealth` records, per mod folder, the last script load error (all four runtimes), an invalid `pack.json` (`Mods.getPack()`), the rule ids of scripts the §6 sandbox blocked before they ran *and* guarded calls it refused inside a script that did load (`ModSecurity.report()`, `reportSecurityRuntime()`), and the distinct images/sounds/atlases that did not load (`Paths`). The Mods menu badges the row (`!` break, `?` assets only) and prints a count-only line under the description; Mod Info gains a **WHAT BROKE** block with the offending paths and messages, flattened to one line and wrapped by `ModInfoFlow.problemsBlock()` so a broken script cannot draw outside the panel. The report is per session and per folder (`keepOnly()` on menu build, `Mods.forgetHealth()` after a `.zip` import). Specs: `bash tests/haxe/run-mod-health.sh`. Guide: `docs/MOD_HEALTH_REPORT.md`. Original entry kept below.

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

Read `docs/research/psych-fork-engine-changes.md`, §24 (JS-Engine `whoisitlolxd` fork triage, 2026-11-19), §25 (Psych Engine Extra Keys + review) and §26 (JS-Engine binary-chart / "GPU note backend" review, 2026-11-19).

---

## TOP 3 (do these first)
1. Resolve local NDK mismatch (install 27.0.12077973/r27 or fix the NDK 28 libc++ redefinition) so Android builds locally → green. ([#64](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/64))
2. HashLink target: install working `lime.hdll`, build, re-enable CI `hl` job. ([#63](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/63))
3. Path-traversal hardening (security). ([#65](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues/65))

## 21. PLAYER-FACING SCREENS, SUBSTATES & OPTIONS (idea review)

The remaining ideas below are tracked alongside completed items. Overlaps with existing entries are cross-referenced, not repeated.

### 21.1. New states

- **[P1] Results screen (`states/ResultsState`).** `PlayStatePlayback.endSong()` currently goes straight back to `FreeplayState` / `StoryMenuState`. After a song or week, show score, accuracy, judgement breakdown, max combo, peak NPS, FC tier and a histogram of hit offsets. The totals already exist on `PlayState`; only per-hit offsets need recording (via `play.helpers.HitTiming`). Roadmap link: the Mic'd Up S/A rank (§0) would live on this screen.
- **[P2] ~~Player stats (`states/StatsState`, `backend/PlayerStats`)~~ DONE** — Awards → Player Stats shows lifetime playtime, songs finished, notes per judgement, deaths, full combos, and the most-played songs and mods. With achievements disabled, Awards opens stats directly. `PlayerStats` seeds older saves from the playtime badge; `PlaytimeTracker` keeps counting after the badge unlocks. Specs: `bash tests/haxe/run-player-stats.sh`.
- **[P3] ~~Modchart lab (`editors/ModchartLabState`)~~ DONE** — the renderer-free half lives in `modchart/lab/`
  (`ModchartLabCatalog` for the knobs of all 34 modifiers, `ModchartLabTrack` for per-percent
  automation on loop-local beats, `ModchartLabExport` + `ModchartLabExportOptions` for the
  Lua/Python fragment); `editors.ModchartLabState` is the screen, reachable from Editors →
  **Modchart Lab**. Dragging a percent records a keyframe snapped to the 16th-note grid, the
  looping clock replays the tracks through the real `ModchartManager`/`PlayField.transform`
  chain (no `PlayState`, no song files), and `C` copies `addModifier`/`modSet`/`modEase` calls —
  optionally wrapped in a `modRepeater` callback — as Lua or Python, with a file fallback when
  the clipboard is blocked. Known limits (absolute-time modifiers are phase-shifted, one
  playfield, `skew` stored but not drawn, `vibrate` is random) are documented. Docs:
  `docs/MODCHART.md` (§ Modchart lab). Specs: `bash tests/haxe/run-modchart-lab.sh`,
  `bash tests/haxe/run-modchart-lab-typecheck.sh`; both run in `checks.yml`.
- **[P3] ~~Input tester (`states/InputTestState`, `phoenix://input`)~~ DONE** — `backend.InputTestLogic`
  is the renderer-free half (what each device holds now and held at most, press gaps, chords,
  presses per frame, taps that went down and up inside one frame, the hold-to-leave gesture);
  `states.InputTestState` is the page, opened by `phoenix://input` (alias `phoenix://screen/input`)
  and by Options → Gameplay → **Input Tester**. Keys are timed from the stage key events gameplay
  judges presses from; gamepads and touches are polled once per update. No tap navigates: leaving
  is a one second hold on Back with nothing else held on that device, and the page binds, saves
  and writes nothing. It has not been run in a built game yet. Docs: `URI.MD` (§ `phoenix://input`),
  `website/docs/subsystems/deep-links.md`. Specs: `bash tests/haxe/run-input-test.sh` (runs in
  `checks.yml`) and `bash tests/haxe/run-input-test-typecheck.sh` (needs the game haxelibs). It is
  the measuring tool for the poll-rate and key-rollover audit in §15.
- **[P2] Extras hub (`states/ExtrasState`).** A menu listing custom screens that enabled mods declare in a new `menus` list in `pack.json`. `ModState` screens can only be opened by a script calling `switchCustomState` (`states/ModState.hx`), so each mod currently has to build its own entry point, for example by overlaying `MainMenuState`. Needs `backend.Mods` parsing of `menus` and a platform-support check for each entry.

### 21.2. New substates

- **[P1] Quick options (`QuickOptionsSubState`, from pause).** Change settings that can apply live (offsets, hitsound, track volumes, flashing, camera zooms) without leaving the song. Today choosing Options from `PauseSubState` switches to `OptionsState` and reloads `PlayState` from the start on return, which loses the run and is slow on weak devices.
- **[P2] Practice loop (`PracticeLoopSubState`, from pause).** Mark a start and end point, pick a playback rate and loop that part with score saving off. The seek code already exists behind `Skip Time` in `PauseSubState`, which is only added inside the `PlayState.chartingMode` branch (and not while the song is still starting).
- **[P2] Mod report (`ModReportSubState`, from Mods menu and after a `.zip` import).** One page per mod: whether it opted out of the script sandbox, which rules it allowlists, blocked scripts by file and line, and Lua functions it calls that Phoenix does not implement. Today security findings only reach the debug console and the log when a script loads. Player-facing counterpart to the mod linter CLI in §17 and the per-mod report in §19.
- **[P2] ~~Freeplay filter (`FreeplayFilterSubState`)~~ DONE** — F (or the FILTER button, or the right shoulder
  button) opens a page over Freeplay: order by name, mod, best accuracy or unplayed (never played first, then
  the played ones by best accuracy), show one mod (all mods / base game / a single folder), a favourites-only
  switch, star or unstar the highlighted song, and highlight a random song out of whatever the filter keeps.
  Stars are keyed by mod + song name and stored in their own `freeplay_filter` save
  (`backend.FreeplayFilterStore`), so a truncated `funkin` flush cannot cost them; the filter itself is
  renderer-free (`backend.FreeplayFilter`) and is what the existing search box now uses too (every word has to
  match the song or its mod name). The highlighted song keeps its place when it survives a re-filter, an empty
  result says so instead of indexing nothing, and the personal-best block shows `* FAVOURITE`. Spec:
  `bash tests/haxe/run-freeplay-filter.sh` (orders, mod filter, stars, random pick, `Highscore` →
  best-accuracy fold; runs in `checks.yml`). Known limit: `Highscore` keys carry no mod id (§13), so two mods
  with the same song name still share one accuracy record.
- **[P3] Photo mode (`PhotoModeSubState`, from pause).** Hide the HUD, pan and zoom the game camera freely, and save a shot through the existing `backend/Screenshot` / `backend/SSPlugin` path. Fits the creator tooling the engine already ships.

### 21.3. New options

- **[Done] Lane underlay (`laneUnderlayAlpha`, percent, default 0, Visuals and UI).** A dark strip behind the player's strums so notes stay readable over busy stages. It is one stretched sprite, so it is cheap on low-end devices. `play.helpers.PlayStateLaneUnderlay` stretches a 1x1 black quad across the player's lanes (measured from the live strums, formula fallback before the countdown creates them), drawn on the notes camera (`camNotes`, or `camHUD` with Distant Notes off) below the notes, strums, sustains and splashes; 0% (the default) hides it and the per-frame path is one comparison. Spec: `bash tests/haxe/run-lane-underlay.sh` (runs in `checks.yml`).
- **[Done] Resume countdown (`resumeCountdown`, bool, default on, Gameplay).** Count 3-2-1 after unpausing instead of resuming instantly. Matters most on phones, where thumbs leave the hitbox to press Resume. `play.helpers.PlayStateResume` reuses the intro-countdown art/sounds; only the unpause call sites in `PauseSubState` mark the intent (`resumeCountdownWanted`), and `PlayState.closeSubState()` defers the resync/`onResume` to the GO tick via `ResumeCountdownMath.shouldRun` (running song only: `paused` && `!startingSong` && `canResync` && not FFmpeg). Exposed to Lua/Python/HScript as `onResumeCountdownStart` (`Function_Stop` skips the countdown) and `onResumeCountdownTick(count)`; `resumeCountdownActive` is published read-only to scripts, and `onResume` still fires at the true resume. Docs: `docs/TemplateScript.*`, `website/docs/modding/script-hooks.md`. Spec: `bash tests/haxe/run-resume-countdown.sh` (runs in `checks.yml`).
- **[Done] Menu FPS cap (`menuFramerate`, int, default 60, Graphics).** Menus currently render at the gameplay framerate, which can be set up to 1000, so they drain battery for nothing. A companion row can expose the focus-lost rate, which is hard-coded to `60` in `states/InitState.hx` (`FlxG.game.focusLostFramerate`). Roadmap link: next to the frame-pacing work in §18. `ClientPrefs.menuFramerate` (default 60) is applied by `backend.FramerateController` on every `MusicBeatState.create()`; only `play.PlayState` keeps `framerate`. Companion **Focus Lost Framerate** row (`ClientPrefs.focusLostFramerate`, default 60) replaces the `InitState` hard-code. Spec: `bash tests/haxe/run-menu-framerate.sh` (runs in `checks.yml`).
- **[Done] Adaptive performance (`adaptivePerformance`, bool, default off, Optimization).** Reacts during a song to sustained low FPS by disabling note splashes, rating popups, then camera bops, notifying the player and requesting rate-limited garbage collection where supported. The changes are song-local; the first-run profile in §18 remains a separate, one-time preset.

### 21.4. Quick win before any new option

- **[P1] ~~Expose eight preferences that are read but have no menu row~~ DONE** — Exposed `reducedMotion`, `showPhotosensitivityWarning`, `dialogueSpeedMult`, `instantDialogueAdvance`, `dimDialogueBackground`, and `hideDialogueBox` in `options/VisualsUISubState.hx` and `options/AccessibilitySubState.hx`, and `safeMode` (filtered by `PlatformSupport.FILESYSTEM`) and `disableAprilFools` in `options/MiscSettingsSubState.hx`. Spec: `bash tests/haxe/run-accessibility.sh`.

## 22. NEW OPTION IDEAS (three lists, merged)

Thirty option ideas from three separate lists. Five options appeared in two lists, so they are merged into 25 entries (both names stay in the title): 22 new options in §22.1–22.5, none of which repeats §21.3, and three additions to existing entries in §22.6. Checked against the tree at `b0a5429`, which is also where the line numbers come from: none of the proposed keys exists in `backend/ClientPrefs.hx` (`startFullscreen` and `metronome` only appear in `source/` as the `Main.game` launch field and a chart-editor checkbox). Where a list's premise did not match the code, the entry says what is there instead, after "Checked:". Effort is quoted where a list estimated it: S = a preference, one `Option` row and a few call sites; M = also a small helper/object or a layout pass. The third list gave no keys, types or estimates, so its entries leave them open. The priority tags are a reading of the lists' own recommendations, which are kept in §22.8.

### 22.1. Audio

- **[P2] ~~Master volume (`masterVolume`, percent, default 100%, a new Audio category or Misc).~~ DONE** — `backend.VolumeCurve` (the tray's log curve, shared), `ClientPrefs.masterVolume` as a mirror of `FlxG.sound.volume` (kept out of the save and the backup through `saveBlackList` / `loadBlackList` / `SettingsBackup.NOT_PREFERENCES`), a live row in the new **Options -> Audio** (`options/AudioSettingsSubState.hx`, also in Misc, openable with `phoenix://menu/audio`) that follows the volume keys and the tray every frame. Specs: `bash tests/haxe/run-volume-curve.sh`, `bash tests/haxe/run-master-volume.sh`. Original entry kept below.

- **[P2] Master volume (`masterVolume`, percent, default 100%, a new Audio category or Misc).** No options menu has a volume row. `FlxG.sound.volume` only changes through the volume keys (`volume_up` / `volume_down` / `volume_mute`, with the `objects/CustomSoundTray` popup) and through a settings import (`backend/SettingsBackup.hx:146`), so a player on a gamepad or a touchscreen cannot set it in-game. Every `FlxSound` multiplies by it, so one row covers music, vocals, hitsounds and the pause track. Checked: the value is already saved and restored, which one list missed. `ClientPrefs.saveSettings()` and `loadPrefs()` round-trip it through the `flixelSound` list (`ClientPrefs.hx:367`, `:405`, `:464`), the tray stores it too (`CustomSoundTray.hx:121`) and `SettingsBackup` exports it (`:205`). So do not store it twice: `Option` binds to a `ClientPrefs` field by name, so give it one that mirrors `FlxG.sound.volume` and is kept out of the save and the backup (`saveBlackList` / `loadBlackList` in `ClientPrefs.hx:366-368`, `SettingsBackup.NOT_PREFERENCES`). The row has to use the tray's curve (`CustomSoundFrontEnd.changeVolume()` stores a log-scaled value, so half the tray is a `FlxG.sound.volume` of about 0.03) and has to follow the volume keys, or it goes stale. Two lists rank this first; with persistence already in place it is a convenience row, hence P2. Effort: S.
- **[P3] ~~Menu music volume~~ DONE** — `ClientPrefs.menuMusicVolume` (percent, default 100 %,
  Options → Visuals and UI) scales only the menu theme, so gameplay stems, vocals and
  hitsounds keep their own level while the volume keys still apply on top; `menuMusicFade`
  (default on) fades the theme out during the loading screen instead of cutting it when a
  song starts. `backend.MenuMusic` owns the track and `backend.MenuMusicLogic` holds the
  renderer-free rules: `Paths.playMenuMusic(force, volume)` claims the started sound, the 18
  direct `FlxG.sound.playMusic(Paths.music('freakyMenu…'))` call sites (7 editors,
  `GameOverSubstate`, `NoteOffsetState`, `VisualsUISubState`, `RenderingDoneSubState`, the Lua
  `endSong` callback) go through the helper, and the hardcoded ramps/volume targets in
  `MainMenuState`, `FreeplayState`, `CreditsState`, `OptionsState` and `TitleState` ask
  `MenuMusic` first. `PlayState.create()` calls `MenuMusic.forget()` when it takes the music
  channel over. Spec: `bash tests/haxe/run-menu-music.sh`. Docs:
  `website/docs/subsystems/audio.md`.
- **[P3] Metronome (`metronome`, string: Off / Count-in / Always, default Off, Gameplay or the Audio category).** `assets/shared/sounds/Metronome_Tick.ogg` ships, but only the chart editor plays it (`editors/ChartingState.hx:1964`). Add a `beatHit` path in `PlayState` with three modes: off, during the count-in only, or through the whole song. Scale the tick with `playbackRate` and skip it during `startOnTime` seeks. The list pitches it for practising muted, on a silent phone or with latency; the tick shares the game's audio output, so on a muted device that job belongs to the visual beat indicator in §16, whose pref exists but is not wired (§22.7). The interactive latency test in §15 needs the same tick. Effort: S–M.

### 22.2. Window, stage and effects

- **[P2] Window mode / fullscreen on start (`windowMode`, string: Windowed / Borderless / Fullscreen, Graphics, `onlyOn([PlatformSupport.DESKTOP])`).** F11 is the only fullscreen toggle in `source/` (`backend/FunkinGame.hx:24`, native desktop only), the game always starts windowed (`startFullscreen: false`, `Main.hx:51`) and nothing remembers the choice. The small version is a `startFullscreen` bool, default off. The full version is the three-way row, which gives players borderless without exclusive-fullscreen artifacts. Apply it through `lime.ui.Window` / `FlxG.fullscreen` after prefs load, and persist the mode, including when F11 changes it. Watch two interactions: `backend/TransparentWindow.hx` leaves fullscreen when it is enabled and suspends itself while fullscreen, and `CoolUtil.checkForOBS()` drops out of fullscreen to read `tasklist` and then goes back. Effort: S for the bool, M for the three-way row.
- **[P2] ~~Stage dim / stage brightness~~ DONE** — `play.helpers.PlayStateStageDim` +
  `play.helpers.StageDimMath`: one screen-fixed black quad (`scrollFactor` 0, `makeGraphic(1,1)`,
  so pixel stages work and nothing is loaded from disk) routed to `camGame` only, so the stage
  and the characters dim while the notes, strums and HUD stay bright — notes live on `camNotes`
  when Distant Notes is on and on `camHUD` otherwise. Layering is enforced at runtime, not just at
  creation: the quad is created after `createPost()`/`onCreatePost` and `syncLayer()` re-appends it
  whenever a stage prop or event sprite lands above it, with `insert(members.length, …)` so it
  cannot drift into a `null` hole left by a character swap. `StageDimMath` recomputes the size
  when `camGame` zooms or `doTwist` rotates it (rotated views need the tilted bounding box).
  `ClientPrefs.stageDim` (0–0.9, 90% cap so the stage never goes fully black) is exposed in
  Options → Visuals and UI. The 0% default hides the quad and costs one comparison per frame.
  Docs: `website/docs/subsystems/playstate.md`, `website/docs/architecture/preferences-and-save-data.md`.
  Specs: `bash tests/haxe/run-stage-dim.sh`, `bash tests/haxe/run-stage-dim-typecheck.sh`.
- **[P2] Camera effects intensity (`cameraFxIntensity`, percent, default 100%, Visuals and UI until the Accessibility category in §16 exists).** `reducedMotion` already gates beat bops (`PlayState.hx:3183`, `:3256`), event zooms and shakes (`PlayStateEvents.hx:323`, `:415`) and character shakes (`PlayStateNotes.hx:416`, `:623`, `:673`), but only as on or off. `camZooms` is a bool, and `camBopIntensity` is a `PlayState` field that only the bop event sets (`PlayStateEvents.hx:222`). One 0–100% multiplier lets players keep a little motion instead of none. Apply it at those sites and in a `shake()` override on `backend/PsychCamera`, which does not have one today. Keep `reducedMotion` as the master off switch; the slider refines it. Related: the zoom multipliers in §12.4. Effort: M.
- **[P1] Flash intensity (`flashIntensity`, percent, default 100%, Visuals and UI until the Accessibility category in §16 exists).** `flashing` is only on or off. A 0–100% dial that scales flash alpha and duration lets photosensitive players keep the cue without the punch, which is more useful than another toggle. Precedence: `flashing = false` forces 0, otherwise the percentage applies. There are few camera flash sites: `stages/Philly.hx:181` and `:227`, `states/TitleState.hx:520` and `:672`, `play/helpers/PlayStateCamera.hx:322`, and the script callbacks (`psychlua/callbacks/GameCallbacks.hx:240`, `psychlua/pystdlib/PyCameraLib.hx:33`). Checked: two of them ignore `flashing` completely today, the 4 s white flash that ends the title intro (`TitleState.hx:672`) and the 1 s white flash in `tankmanStep()` (`PlayStateCamera.hx:322`), and script flashes are passed through as they are. Route every site through one helper; that gap is why this is P1. Pairs with `reducedMotion`. Effort: S–M.

### 22.3. Notes and playfield

- **[P2] Note and strum scale / independent note size (`noteScale`, int %, 50–150, default 100, Visuals and UI).** One multiplier for notes and receptors that keeps the field proportional and leaves the rest of the HUD alone. It helps on small phones and 1440p desktops and supports the low-end downscale goal in §0. Checked: the scale is hard-coded as `0.7` at five sites, not three (`objects/Note.hx:215`, `:356`, `:416`, `:671` and `objects/StrumNote.hx:121`), and pixel notes are sized by `PlayState.daPixelZoom` instead (`Note.hx:334`, `StrumNote.hx:86`). `Note.swagWidth` is a `static final` `160 * 0.7` (`Note.hx:124`) that also sets lane spacing (`StrumNote.hx:153`), sustain centring (`Note.hx:447`, `:463`) and splash placement (`NoteSplash.hx:48`), so it has to become a computed value. The existing UI Scale (`uiScalePercent`) only resizes the options menus. Include a preview so lanes cannot overlap. Effort: S–M.
- **[P3] Lane spacing.** Increase or decrease the distance between the player's lanes independently of note size, for different screen sizes and preferences. Spacing is not a separate value today: `StrumNote.postAddedToGroup()` steps each lane by `Note.swagWidth` (`StrumNote.hx:153`), which is the note width. It needs the same `swagWidth` split as the note scale above, so build it with or after that entry.
- **[P3] Hold note transparency.** Set the opacity of sustain bodies separately from note heads, so dense hold patterns are easier to read. No pref covers it. Sustain pieces are created with `multAlpha: 1` (`play/helpers/PlayStateChartLoader.hx:286`) and drawn at `strum.alpha * multAlpha` (`objects/Note.hx:433`), so `multAlpha` on those pieces is the hook.
- **[P2] Hit error bar / hit timing meter (`hitErrorBar`, bool, default off, Gameplay).** A small HUD object that keeps the last 15 or so hit offsets and draws them as a strip of dots under the strums, early on one side of a centre mark and late on the other, with the offset in milliseconds. The signed value already exists: `noteTimingDiff` (`PlayState.hx:2916`, set in `PlayStateRating.hx:109`) and `HitTiming.classify()`. The only feedback today is one popup per hit (`showMS` and `earlyLateRatings`, Options -> Optimization). A strip shows a consistent bias ("always 12 ms late"), which gives `NoteOffsetState` and `ratingOffset` something to be tuned against. Hide it with `hideHud` and flip its position for downscroll. The Results screen in §21.1 wants the same per-hit offsets for its histogram, so record them once. Effort: M.
- **Key count above 4: see §25.1.** Every row in this subsection assumes four lanes. The note-scale and lane-spacing entries have to land first, because they replace the same `Note.swagWidth` constant (`objects/Note.hx:124`) that a key count would generalise.

### 22.4. Timing and song flow

- **[P2] ~~Accuracy presets (`accuracyPreset`, string: Vanilla / Psych / Kade / ITG / Custom, Gameplay).~~ DONE** — `backend.AccuracyPresets` + `ClientPrefs.accuracyPreset` (default `'Psych'`) + `options/GameplaySettingsSubState.hx`: writes `perfectWindow`, `sickWindow`, `goodWindow`, `badWindow` (cap raised to `165.0` ms for Vanilla `150` ms) and `safeFrames` (`<= 10.0` on all built-in presets so highscores save), dynamically refreshes neighbour `minValue`/`maxValue` bounds and labels, calls `Conductor.recalculateTimings()`, and switches to `'Custom'` via `AccuracyPresets.detect()` whenever an individual row is edited. Spec: `bash tests/haxe/run-accuracy-presets.sh`.
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
- **~~`gamepadDeadzone` is declared and never read~~ DONE** — `backend.GamepadDeadzone` (`2%`–`90%`, default `15%`) + `ClientPrefs.applyGamepadDeadzone()` applies `ClientPrefs.gamepadDeadzone` to `FlxG.gamepads.globalDeadZone` on boot (`InitState`), preference load, live option edits (`Options -> Gameplay -> Gamepad Deadzone`), and settings backup import; per-controller/per-trigger calibration remains in §15. Spec: `bash tests/haxe/run-accuracy-presets.sh`.
- **~~Five accessibility prefs are declared and never read~~ DONE** — Implemented `noteColorblindPreset`, `laneGlyphs`, `forceLuminanceContrast`, `highContrast`, and `visualBeatIndicator` in `backend.Accessibility`, `objects.NoteColors`, `play.helpers.PlayStateAccessibility`, and `options.BaseOptionsMenu`, and exposed all five in `Options -> Accessibility` and `Options -> Visuals and UI`. Spec: `bash tests/haxe/run-accessibility.sh`.
- **~~§21.4 re-checked: still open~~ DONE** — All eight preferences (`reducedMotion`, `dialogueSpeedMult`, `dimDialogueBackground`, `instantDialogueAdvance`, `hideDialogueBox`, `safeMode`, `showPhotosensitivityWarning`, and `disableAprilFools`) now have `Option` rows. Spec: `bash tests/haxe/run-accessibility.sh`.
- **[P3] ~~Mute is not restored on launch~~ DONE** — Fixed `importantMap["flixelSound"]` to `["volume", "muted"]` (migrating legacy `FlxG.save.data.mute` on load and keeping both keys synced), flushed `CustomSoundTray` changes to `FlxG.save`, notified `FlxG.sound.volumeHandler` on mute changes, and added live `Mute Audio` (`masterMuted`) checkbox rows in `Options -> Audio` and `Options -> Misc`. Spec: `bash tests/haxe/run-master-volume.sh`.
- **[P3] ~~`perfectWindow` has two defaults~~ DONE** — Settled `GameplaySettingsSubState` `'Perfect! Hit Window'` on `15.0` ms (`AccuracyPresets.DEFAULT_PERFECT`) to match `ClientPrefs.perfectWindow`, alongside the `Accuracy Preset:` (`Vanilla` / `Psych` / `Kade` / `ITG` / `Custom`) row in §22.4. Spec: `bash tests/haxe/run-accuracy-presets.sh`.

### 22.8. Suggested order

The lists' own recommendations, unchanged. The eight rows in §21.4 are free and come before any of these.

1. Cheapest and most visible: Master volume, Pause on controller disconnect, Flash intensity.
2. Smallest changes (about one call site, a `ClientPrefs` field and a row): Accuracy presets, Countdown style, Master volume, Achievement popups.
3. Most noticeable to players: Window mode, Hit error bar, Touch control scale.
4. Best fit for the engine's low-end and accessibility identity, with no per-frame cost: Camera effects intensity, Stage dim.
5. The third list's first three, chosen for clear benefit without a new system: Lane underlay (§21.3), Hit error bar, Stage dim.

Ship the larger ones as separate PRs.

---

## 23. MARIO'S MADNESS REUSE REVIEW

Source: [Dewott2501/Mario-Madness](https://github.com/Dewott2501/Mario-Madness) (Psych 0.4.2 base, Apache 2.0, so compatible with ours; port with credits). Compared by reading its source against a clean Psych 0.4.2 checkout and against this tree; nothing was built or run. Most of that repo is song-specific hardcoding (28 stages, per-song "Triggers <Song>" events, the warp-map story mode) and is **not** reusable. Only the generic pieces are listed here, and each one names what proves it is still missing in Phoenix.

### 23.1. Modchart modifiers (narrows the entry in §0)

Their modifiers are by Nebula_Zorua (Schmovin/Andromeda style). Checked against `source/modchart/modifiers/` and `ModifierRegistry.hx`: 13 of their 15 already exist here under the same or another name (flip is in `Invert.hx`, alpha is in `Stealth.hx`, infinite path is `Infinite.hx`, center rotate is `CenterRotate.hx`). Still missing:

- **[P2] `PathModifier`.** Notes follow an arbitrary list of points instead of a straight lane (`source/modchart/modifiers/PathModifier.hx` upstream). No `path` modifier is registered here. Effort: M.
- **[P2] `PerspectiveModifier`.** Projects note and receptor positions through a camera with a field of view, which is what makes z movement look 3D. No `perspective` or `fov` name is registered here; check first whether `ModchartVec3`/`PlayField` already project z, and if so only expose the FOV as a modifier. Effort: M.

### 23.2. Shaders

~~None of these names exist in `source/shaders/`~~ **DONE** — all nine ship as a `Shader` + `Effect` pair next to the existing ones. Each is registered in `psychlua/callbacks/EffectCallbacks.hx` inside its `ClientPrefs.shaders` guard, which is the shaders toggle: with it off nothing is registered at all. Lua, Python and HScript reach the same functions because both other hosts inherit `FunkinLua.registeredFunctions` (`PythonScript.hx:379`, `HScript.hx:246`), so one registration covers all three. Each name is also in `shaders.ShaderWarmupRegistry`, so a stage JSON can precompile one on the loading screen (`"shaders": ["crt", "oldtv"]`). Every shader extends `backend.FlxFixedShader` (the OpenGL ES rewrite, like `DistantNoteShader`); credits and the full list of local changes are in each shader class's doc comment, as the porting rule at the top of this file asks.

- **[P2] ~~`CRTShader`~~ DONE** — `shaders.CRTShader` + `CRTEffect`, Timothy Lottes' public-domain CRT via Mario Madness: curved screen (`curve`), scanline reconstruction (`scanlineHardness`, `pixelHardness`, `resolutionScale`), RGB shadow mask (`mask`) and vignette (`vignette`, which the port source did not have). `addCRTEffect`. Emulated resolution now follows the render target instead of a fixed 512×448, and alpha is preserved so it can sit on `camHUD`. Eleven fetches per pixel: documented as the expensive one.
- **[P2] ~~`OldTVShader` and the title screen's `TVStatic`~~ DONE** — `shaders.OldTVShader` + `OldTVEffect` (rolling picture-offset bar, black/white sploches, static; the 48-tap smear is now 16 taps behind `blur`, off by default) and `shaders.TVStaticShader` + `TVStaticEffect`, from `TitleScreenShaders.TVStatic` by @Ne_Eo_Twitch. `addOldTVEffect`, `addTVStaticEffect`. The upstream `uvec3`/`U`-suffix hash would not compile on WebGL1, so it is float-based here.
- **[P3] ~~`RippleShader`~~ DONE** — `shaders.RippleShader` + `RippleEffect` (shadertoy XtsSzN). Four turbulence octaves instead of eight: the port source ran twelve 3D simplex evaluations per pixel, which is not survivable on a low-end phone. `addRippleEffect`.
- **[P3] ~~`SilhouetteShader`~~ DONE** — `shaders.SilhouetteShader` + `SilhouetteEffect`. Takes a `FlxColor`, a hex string or a colour name through `CoolUtil.colorFromString`, and works per sprite: `addSilhouetteEffect('boyfriend', 'red')`. `amount` is clamped, so the upstream wrap-around `update()` is gone.
- **[P3] ~~`MosaicShader` and `SMWPixelBlurShader`~~ DONE** — `shaders.MosaicShader` + `MosaicEffect`. Upstream's `SMWPixelBlurShader` is only a strength-setting wrapper around the same shader, so it is `MosaicEffect.setStrength()` plus an `addSMWPixelBlurEffect` alias: one pair, both names. Block size is clamped to ≥1 px in the shader and in the effect, which removes the documented "0 turns the screen black" divide-by-zero. `addMosaicEffect`.
- **[P3] ~~`BrightnessContrastShader`~~ DONE** — `shaders.BrightnessContrastShader` + `BrightnessContrastEffect`. `addBrightnessContrastEffect('game', 0.65, 1.1)` is the shader-side version of the stage dim in §22.2: on `camGame` only, so notes and HUD stay bright, one fetch per pixel, and no overlay sprite to layer. Fully transparent pixels keep their RGB, or a HUD filter would come back as a grey box.
- **[P3] ~~`VCRBorder` / `VCRMario85`~~ DONE** — compared with `VCRDistortionShader` first, as asked. It already curves (`perspectiveOn`) and vignettes (`vignetteOn`), but only as part of its seven-fetch glitch chain, so the frame alone was genuinely missing: `shaders.VCRBorderShader` + `VCRBorderEffect`, two fetches, no glitch (`addVCRBorderEffect`). `VCRMario85` is not covered either — its steady simplex-noise tape wobble is a constant offset where VCRDistortion's is a burst plus a vertical roll — so it ships as `shaders.VCRFuzzShader` + `VCRFuzzEffect`, named for what it does rather than for the song, with `vcrmario85` kept as a registry key (`addVCRFuzzEffect`). Its duplicate alpha fetch is gone and each pass is skipped when its uniform is 0.
- `BloomShader` was not duplicated. The previously skipped song-specific `CamDupeShader`, `AngelShader`, `YCBUEndingShader` and `TwoDinThreeD` are now ported as shader/effect pairs; their callbacks and warm-up names are documented in `docs/SHADERS.md`.
- Added while doing it: **`shaders.EffectTicker`**, the frame clock the animated effects register on. Inside a song it reuses `PlayState.shaderUpdates`; anywhere else it uses `FlxG.signals.postUpdate` and clears on `preStateSwitch`. The older effects push onto `PlayState.instance.shaderUpdates` unconditionally, so they cannot be built outside a song — and the title screen is exactly where `TVStatic` belongs. `PlayState.destroy()` never nulls `instance`, so the ticker also checks `FlxG.state`.
- Docs: `docs/SHADERS.md` ("Retro screen effects", with the parameter table), `website/docs/subsystems/shaders.md` ("Mario Madness ports"), `example_mods/scripts/RetroShadersExample.lua` (runnable tour, in the style of `ModchartExample.lua`). The generated Lua/Python API reference picks the new functions up from the `//` comments above each registration.
- Specs: `bash tests/haxe/run-retro-shaders.sh` (in `checks.yml`). It generates its `FlxFixedShader` stub from the `uniform` declarations in the sources, so a Haxe field the GLSL never declares fails to compile, and the spec checks the other direction (a uniform no constructor initialises), the GLSL ES 1.00 traps (`uvec`, `U` literals, `texture()`, `1.` literals, non-constant loop bounds), every clamp, the ticker routing and the registration.

### 23.3. Generic chart events

Checked against `play/helpers/PlayStateEvents.hx`. `Set Cam Zoom` is already accepted as an alias there.

- **[P2] `Add Subtitle` event.** Value 1 is the text, value 2 a colour name or a `0xFF…` hex. Shows a caption line on the HUD camera; an empty text clears it. No subtitle code exists anywhere in `source/`. This also serves accessibility (§16): add a toggle and a size option. Effort: S.
- **[P3] `Camera Zoom Chain` and `Screen Shake Chain` events.** Repeat a zoom bump or a shake a set number of times at a beat interval from a single event, instead of one event per hit. No match in `source/`. Effort: S.
- **[P3] `Show Song` event.** Pops the song title and author card at a chosen moment rather than only at song start. Compare with `objects/CreditsPopUp.hx` first and reuse it.

### 23.4. Gameplay and data

- **[P2] Generic dodge control.** They add a `DODGE` action (Space by default) to `Controls` and `ClientPrefs.keyBinds`, used by attack events. Here the only dodge code is hardcoded in the Blazin handlers (`stages/objects/PicoBlazinHandler.hx`, `DarnellBlazinHandler.hx`); there is no bindable action. Add the bind (keyboard, gamepad and a mobile extra button), a `keyDodge`-style Lua/HScript/Python query, and a `Dodge Attack` event that scripts can listen to. Effort: M.
- **[P3] Per-character camera zoom and extend in the stage file.** Their stage JSON carries `[x, y, camX, camY, zoom, extend]` for each character, so the camera zooms differently on each singer and drifts in the sung direction by `extend` pixels. `data/StageData.hx` here only has `camera_boyfriend`/`camera_opponent`/`camera_girlfriend` offsets. Add optional fields so old stage files keep working. Effort: M.
- **[P3] `idleReturn` character flag.** Return to idle as soon as a sing animation finishes instead of waiting for the hold timer. No `idleReturn` field in `objects/Character.hx` or the character editor. Effort: S.
- **[P3] Second instrumental track.** A stage-keyed alternate instrumental (`instALT`) kept in sync with the main one so events can crossfade between two mixes. Generalise it as an optional `Inst-alt` file per song rather than per stage. Effort: M.

### 23.5. Performance

- **[P2] Cap script `onUpdate` calls per second.** They call Lua `onUpdate`/`onUpdatePost` at most 60 times per second (`PlayState.maxLuaFPS`), accumulating `elapsed` between calls, so an uncapped or 240 fps game does not run every script four times as often. No equivalent here (no `maxLuaFPS` or similar in `source/`). Fits §18. Make it an option (off, 60, 120, match refresh) and apply it to Lua, HScript and Python alike; scripts that need every frame must be able to opt out. Effort: S.

### 23.6. Checked and already covered (do not port)

- **VRAM-only bitmaps** (`OptimizedBitmapData`, from Codename Engine): covered by `cacheOnGPU` in `backend/Paths.hx`.
- **Tracked asset cache and GC on state switch:** already in `backend/Paths.hx` (later Psych versions of the same code).
- **Shader cache reset on window resize:** already in `Main.hx`.
- **Decimal step/beat and BPM lookup helpers:** already in `backend/Conductor.hx` and `MusicBeatState.hx`.
- **Windows desktop effects** (wallpaper, taskbar, hiding other windows, transparency): covered by `backend/MetaHorror.hx` and `FlxTransWindow.hx` (§2.1).
- **Health drain:** already in `objects/Character.hx` and `PlayStateEvents.hx`.
- **Custom note types** (poison, bomb, coin, bullet and so on): hardcoded there; here they belong in `custom_notetypes` scripts, so nothing to port in the engine. **DONE** — ported as ready-to-use Lua scripts in `example_mods/custom_notetypes/` (11 files + readme, credits in each header): poison, bad poison, bomb, coin, ring, water, boo, bullet, bullet bill, jumpscare and invisible notes; the song/stage-specific mechanics (Luigi lives, gun ammo, the rising flood, the Somari ring rules, jumpscare overlay art, `Bullet2`) are documented as deliberately excluded, with the hooks to re-add them marked inline. Engine note support needed no port; one generic robustness fix while wiring them up: `set_texture` keeps the current skin (the missing atlas is logged once by `Paths.initNote`) when a mod swaps in a texture whose sparrow atlas is absent, instead of nulling the sprite's frames — flixel's placeholder would be swapped in on the next draw, hiding the note entirely. (The pooled-note reset for `flipY`/`multAlpha` already exists at the end of `setupNoteData()`; no change needed there.) The example scripts deliberately call no file-read callbacks, so they run under the default mod sandbox.
---

## 24. JS-ENGINE FORK TRIAGE — `whoisitlolxd/js-engine-if-the` (2026-11-19)

**Source:** <https://github.com/JordanSantiagoYT/FNF-JS-Engine/compare/main...whoisitlolxd:js-engine-if-the:main> — fork `whoisitlolxd/js-engine-if-the` at `ce5fb8c` vs upstream `JordanSantiagoYT/FNF-JS-Engine` merge-base `fbe4490` (2025-01-02). At review time: **108 commits ahead, 993 behind** `main`; review covers the 36 files in that diff (≈6.9k lines, 5 font binaries + 6 meme assets). Fork author self-notes `i don't know hx but i'm trying` / `GOD I HATE HAXE` — treat as experimental/meme fork, not upstream-quality.

**Method:** fetched `fbe44905...ce5fb8c` diff + `ClientPrefs`/`PlayState`/`ChartingState`/`PauseSubState`/`OptimizationSubState` inspection; checked each idea against current Phoenix tree at `e71839d` to avoid duplicates (§0–23).

### 24.1 Useful — carry forward (small, self-contained, no asset/license cost)

- **[P3] Chart editor — `One Key-ify` + `Randomize Notes` (fork `source/editors/ChartingState.hx:1237`).** Two `FlxButton`s next to `Duet Notes`/`Mirror Notes` that operate on the current section (`_song.notes[curSec].sectionNotes`): set every `note[1]=0` or `note[1]=FlxG.random.int(0,3)`. Phoenix has `Duet`/`Mirror` in `editors/charting/ChartingUISections.hx:636,660` but not these. Port as proper editor actions: clone the section-notes handling used by `Duet` (respect `mustHitSection` lane offset for opponent lanes, clean sustain tails via `ChartingUIGrid.setupSusNote`, push an undo snapshot, call `updateGrid(false)`). Fork has dead branches (`if(note[1]>3) note[1]=4` after `note[1]=0` never fires; `Randomize` has `>3 -> 3..7` dead on 0..3); drop them. Default off, no pref needed — just editor buttons. Effort: S. Credits: `whoisitlolxd` (idea) — port with attribution if shipped.

- **[P3] Chart-editor preview cap tied to `ClientPrefs.maxNotes` (fork `ChartingState.hx:3760,3788,4102`).** Fork caps `curRenderedNotes`/`nextRenderedNotes` with `if(length < ClientPrefs.maxNotes)`. Phoenix already has the *gameplay* limiter (`backend/ClientPrefs.hx:325` `maxNotes`, `options/OptimizationSubState.hx:161` `Max Rendered Notes`, `play/helpers/PlayStateNotes.hx:201` `limitNC < noteLimit` + `amountOfRenderedNotes/skippedCount` metrics) which supersedes the fork's gameplay `coolNoteCap` idea (see §24.2). What Phoenix lacks is the *editor* equivalent: a 10k-note spam chart still tries to draw every note/sustain in the tab grid (`editors/charting/ChartingUIGrid.hx:329,366,400` + `ChartingState.hx` `curRenderedNotes/nextRenderedNotes` groups) and can freeze low-end devices. Add an editor-only `maxNotes` preview gate that reuses the same pref (`0 = unlimited`): when capped, draw the first N notes/sustains, show `Showing 256/4300 notes (cap 256) — raise in Options → Optimization` in the editor status bar, and keep chart data untouched (fork incorrectly mutates `sectionNotes` length check only). Keep `autoSaveLength` at 240 s already done in Phoenix; fork's 90→240 change is not a separate TODO.

### 24.2 Already covered / superseded in Phoenix — no action needed

- **Rendered note cap / `coolNoteCap` / `maxNotes` (fork `source/ClientPrefs.hx:121`, `OptimizationSubState.hx:99`).** Phoenix **DONE** superset via `ClientPrefs.maxNotes` (0 = unlimited, 1..99999), `OptimizationSubState` row with `Adaptive Performance` and pool-stats (`play/helpers/PlayStateNoteHelpers`, `debug/PoolStats`), and `PlayStateNotes.spawnNotes`/`updateNote` capping + `amountOfRenderedNotes` metrics. Fork's `coolNoteCap2`/`runNoteThingBefore`/`screwTheNoteSorting` are redundant/half-baked toggles — do not add.
- **`gugugagamode` / `Lanky` / `nothing1..20` prefs (fork `ClientPrefs.hx:171`).** Dummy bools for a joke `FunSettingsSubstate` — no gameplay effect. No Phoenix equivalent needed.
- **Gameplay limiter widening (fork `GameplayChangersSubstate.hx`)** — raises `scrollspeed`/`healthloss`/`drainlevel` to `1048576` etc. — not a feature; Phoenix keeps sane clamps.

### 24.3 Do not port — meme, harmful, or lower-quality than Phoenix

- **Meme assets & branding:** `assets/funny/`, `assets/splash/` (`lankybox.png`, `wega.png`, `RIMON.png`, `BECAUSE SPRUNKI KILLED MY GRANDMA OKAY.png`, `Coughing.ogg`, `lankybox jumpscare.ogg`), `source/TitleState.hx` camera wobble (`angle ±5` on every beat + `tween zoom+angle`), `MainMenuState.hx` triple `versionShit` watermark + `windowNamePrefix = "JS Engine MODIFIED"`, `CrashHandler.hx` fork URL spam. Keep out.
- **`FunSettingsSubstate.hx` (96 lines, 20 dummy `Bool`s) + `OptionsState.hx` `Fun` entry.** Joke menu with one real button that plays a jumpscare sound and never cleans up (`FlxSound` leak in fork). No value over existing Phoenix `OptionsState` categories.
- **`debug/FPSBg.hx` (52 lines).** Translucent `drawRect(0,0,300,55)` behind FPS. Phoenix `debug/FPSCounter` + `MemoryProfiles` already handle low-end HUD; the card is trivial to recreate if ever wanted — not a TODO.
- **`source/LoadingState.hx` commenting out `#if NO_PRELOAD_ALL` (`//#if`/`//#end`).** Breaks the `skipSongPreload` memory-profile path (`backend/LowMemory`, `backend/Paths.clearUnusedMemory`) — harmful on low-end Android.
- **`source/PauseSubState.hx` anti-cheat removals** (`//if(botplayLockout)`, `//PlayState.playerIsCheating=true` + `trace` comment, random `Coughing` on every `update`), `GameplayChangersSubstate` anti-cheat comment removal (`// here at peakneilevator we despise anti-cheat`), `PauseSubState` `Enter Charting Mode` injection outside `chartingMode` branch. Keep Phoenix's `antiCheatEnable` gate.
- **`source/PlayStateOLD.hx` (6944 lines).** Full copy of pre-fork `PlayState` as `PlayStateOLD` — backup file, not a feature.
- **`setup/unix.sh` / `windows.bat` pinning `hxdiscord_rpc` to `1951871`.** Phoenix tracks `hxdiscord_rpc` via haxelib; no pin needed.
- **Random `FlxG.sound.play(Paths.sound('Coughing'))` in `ChartingState.update` (`1/100000` per frame) and `PauseSubState.update`/`SuperSecretDebugMenu.update` (`1/1000`).** Noise, not a feature.
- **`source/GameplaySettingsSubState.hx` `safeFrames > 99999999` guard** and `GameplayChangersSubstate` `maxValue = 1048576` widening. Do not raise limits — Phoenix's `AccuracyPresets` (`§22.4`) already manages timing windows with bounded `minValue`/`maxValue` refresh.

---

## 25. PSYCH ENGINE EXTRA KEYS + (EK+) REUSE REVIEW

Source: [dopadream/FNF-PsychEngine-EKPlus](https://github.com/dopadream/FNF-PsychEngine-EKPlus), read through the GitHub compare [ShadowMario/main...dopadream:FNF-PsychEngine-EKPlus:main](https://github.com/ShadowMario/FNF-PsychEngine/compare/main...dopadream:FNF-PsychEngine-EKPlus:main): 23 commits, all July 2022, 72 files, +3172/−2111. That compare reports `behind_by: 1214` and a 2022 merge base, so the fork sits on a ~0.6.3-era Psych and its diff is written against files that no longer exist here (`source/Note.hx`, `source/PlayState.hx`, `source/StrumNote.hx` are now `objects/Note.hx`, `play/` and `play/helpers/`). Apache 2.0 like ours, so license-compatible; credit tposejank, dopadream and RhysRJJ as its own `CreditsState` does. It is not one of the 18 repos in `docs/research/psych-fork-engine-changes.md` — this section is that review. Compared by reading the diff against this tree; nothing was built or run.

Almost everything is either already here in a newer form or is welded to code that has been rewritten since, so nothing is cherry-pickable. One feature is real, and it is the one the fork is named after.

### 25.1. Variable key count (1K–10K) — the only feature worth taking

**[P2] Multikey / extra keys.** EK+ lets a chart declare its lane count and plays it: 1K to 10K (`Note.ammo`), with per-count keybind sets, per-count note scaling and positions, an editor stepper plus a `Change Mania` event, and android hitboxes for each layout. Nothing like it exists here: the whole game is hardcoded to four lanes. Verified sites, all of which have to stop assuming 4:

- `play/helpers/PlayStateNoteHelpers.hx:257` — `generateStaticArrows` is `for (i in 0...4)`, and every later strum/HUD loop counts `playerStrums.length` from it.
- `play/helpers/PlayStateChartLoader.hx:191` and `:328` — `songNotes[1] < 4` / `> 3` decide whether a note is the player's or the opponent's; the second lane block then starts at `4`.
- `objects/StrumNote.hx:92` and `:123` — `switch (Math.abs(noteData) % 4)` picks the receptor animation; `:153` steps lanes by `Note.swagWidth`.
- `objects/Note.hx:124` — `swagWidth` is a `static final` `160 * 0.7`, and `:126` `colArray` holds exactly the four arrow names.
- `play/helpers/PlayStateNotes.hx:382`, `:606` — light-strum bookkeeping indexes `strumsHit[(noteData % 4) (+ 4)]`, i.e. four lanes per side in one array.
- `objects/NoteColors.hx:39` — `laneRGB` already wraps any lane index over the palette length (`:47`), but the palettes it wraps are four entries (`backend/ClientPrefs.hx:338`, `:345`) and only those four are editable (`options/helpers/NotesSubStateHelpers.hx:93`), so 5K+ would silently repeat the colours.
- `editors/charting/ChartingUIGrid.hx:211-226` — the editor grid places notes with `daNoteInfo % 4`.
- `data/Song.hx` — `SwagSong` has no lane-count field at all.
- `backend/ClientPrefs.hx:457-460` — exactly one bind per direction (`note_left`/`note_down`/`note_up`/`note_right`), no groups.
- Already generic, no change needed: `modchart/PlayField.hx:20` (`keyCount`) fed from `play/helpers/PlayStateModchart.hx:60` with `playerStrums.length`, so once the strum group grows the modchart layer follows.

What a real port needs, in the order that keeps the game playable between steps:

1. **Format.** `@:optional var keyCount:Int` in `SwagSong` plus a reader that also accepts EK+'s `mania` field (theirs is 0-based: `mania` `0` = 1 lane … `9` = 10 lanes, and its keybind table still lists an unused 11-lane set as `note_elev1`–`note_elev11`), because charts made for that fork exist in the wild with `mania` in the JSON. Write `keyCount` on save; keep reading `mania` for compatibility.
2. **Lanes.** Replace every site above with the count. This is the step that needs §22.3's note scale and lane spacing first: both replace the same `Note.swagWidth` constant this has to generalise, and doing it twice means two migrations.
3. **Skins.** EK+ names lanes by letter (`A`…`R`) and carries a table of magic numbers per count (`keysShit`, `ammo`, `scales`, `lessX`, `separator`, `xtra`, `posRest`, `gridSizes`, `offsets`, `pixelScales`) that is then sprinkled through `Note`, `StrumNote`, the editor and both option substates. Do not copy that shape. Require a noteskin whose animation names are lane-indexed (`note0`…`noteN`, or the existing `arrowLEFT`-style names plus a mapping in the skin's `readme`), and fall back to the shipped 4-arrow skins when `keyCount <= 4`.
4. **Opponent mapping.** Keep the Psych convention (player notes `0..N-1`, opponent `N..2N-1`); EK+'s diff is literally `<4` → `< Note.ammo[mania]`. Same for `PlayState.opponentChart` and the `bothSides` path.
5. **Keybinds.** EK+ hand-writes ~50 `note_*` entries into `ClientPrefs.keyBinds` plus ten labelled sections in `options/ControlsSubState.hx`. Generate the groups from the count instead, and feed the same source to `ControlsSubState` and the mobile pad.
6. **Colours.** Half-done already: `NoteColors.laneRGB` wraps any lane index over the palette length, so a 5K+ chart would repeat the four colours rather than crash. What is missing is the editing side (`options/helpers/NotesSubStateHelpers.hx:93` only offers the four entries) — either let a skin/preset define a longer palette, or document that it repeats, and keep `noteColorblindPreset`/`forceLuminanceContrast` applying on top.
7. **Editor.** A `keyCount` stepper in the Song tab, a grid and preview that draw `keyCount * 2` lanes, and the `Change Mania` event (value 1 = lanes) for gimmick charts — the event must not move existing notes' times.
8. **Mobile.** EK+'s `keyboardMode` bool swaps the keyboard for on-screen hitboxes per count. Here that is `mobile/MobileControls` + `backend.MusicBeatState.addVirtualPad`, so it needs a per-count hitbox layout, not a bool.
9. **Art.** No 5K–10K receptor or note art ships in this tree (`assets/shared/images/noteskins/` is four-arrow skins only). EK+'s 18-letter atlas is usable as a stopgap with credit, but a Phoenix-style noteskin per count is the better deliverable.
10. **Docs + spec.** `docs/` page plus `website/docs/`, and a `tests/haxe/run-*.sh` spec (house rule): assert every 4-lane site above is derived from the count, that a chart with no field still loads as 4K, and that EK+'s `mania` maps to the right lane count.

Effort: **L** (weeks, and it wants the §22.3 geometry work first). Risk: touches spawn, input, strum layout, editor, modchart lanes, mobile pad and score/HUD — the step order above is the safe one.

### 25.2. Small cherry worth taking

- **[P3] Dynamic camera movement toggle (`camMovement`).** EK+ adds a bool to `ClientPrefs` and a row in `options/VisualsUISubState.hx`: with it off, the camera stops panning toward whoever is singing. Here that pan is unconditional: `play/helpers/PlayStateCamera.hx:38` `moveCamera()` sets `camFollow` to the character's midpoint at `:61-67`, and `moveCameraSection()` (`:16`) calls it on every section change. The neighbours already exist, so the row belongs beside them: `Camera Zooms` (`ClientPrefs.hx:140`, `options/VisualsUISubState.hx:455`) and `Camera Effects Intensity` (`options/VisualsUISubState.hx:462`), and it is an accessibility row for §16 next to `reducedMotion`. Implementation: when off, keep a stage-default `camFollow` (or lerp to the section's own centre) and skip the per-character midpoint and `cameraPosition` offsets. Must not fight explicit camera events — `play/helpers/PlayStateEvents.hx:344-347` writes `camFollow` and sets `isCameraOnForcedPos`, so the forced position has to win. Default **on** (today's behaviour), per the porting rule at the top of this file. Effort: **S**.

### 25.3. Checked and already covered (do not port)

- **`Danger Note`, `Kill Note` and their atlases.** Hardcoded `switch` cases in their `Note.hx` with dedicated DANGER/KILL assets and splashes. Here note types are data (`backend/NoteTypesConfig`, `objects/Note.hx:260-269` only calls `applyNoteTypeData`), the splash texture is already per type (`noteSplashData.texture`, `:129-139`), and §23.6 already ships eleven ready-made types in `example_mods/custom_notetypes/`. Nothing to port in the engine. If the two art sets are ever wanted, they extend that example mod and need the fork's artists credited — that is art work, not an engine entry.
- **`Set Camera Zoom` event.** Already covered: `editors/ChartingState.hx:108`, `:117`, `:176` — `Set`, `Add` and `Tween Camera Zoom`.
- **`SUtil.hx`** (android external-storage path, permission prompts, "copy `assets/` and `mods/` into internal storage or the game exits", crash file + alert). Superseded by `backend/Paths`, `mobile/` and the crash stack (`backend/CrashHandler`, `backend/CrashBundle`) — their model only existed because 2022-era android builds read game data from the APK.
- **Loading screen art** (`loadingFunkers`, `loadingLoader`, `butt_graph*`, `promptbg`). The screen already exists (`states/LoadingState` + `objects/LoadingPieDial`, §0 DONE); these are skins for it, and mod-side.
- **`keyboardMode` and the extra keybind rows on their own.** Only meaningful with §25.1; `mobile/MobileControls` + `addVirtualPad`/`addMobileControls` already covers the "on-screen instead of keyboard" idea.
- **Achievements grid art, philly `win0`–`win4`, credits icons.** Song/mod-specific art, not engine.
- **Their behaviour changes are regressions here, not features:** the `lowPriority` sort in hit detection is deleted (we rely on it for Psych's low-priority note types), the `ghostTapping` branch is inverted, `clientPrefs.opponentStrums` alpha handling is dropped in `EditorPlayState.generateStaticArrows`, the score popup is only inserted when `combo >= 10 || combo == 0` (so the animation is skipped at low combo), and the `NO_PRELOAD_ALL` guards are stripped from `LoadingState`, which would re-check every asset on every state switch.

---

## 26. BINARY CHARTS AND THE GPU NOTE BACKEND (JS ENGINE FORK REVIEW)

Source: [amogosgaming/FNF-JS-Engine-GPU-and-binary-JSONs](https://github.com/amogosgaming/FNF-JS-Engine-GPU-and-binary-JSONs) vs `JordanSantiagoYT/FNF-JS-Engine` `main` — 6 commits, 10 files, **+1585 / −0**, all files brand new. Read in full on 2026-11-19 against this tree (same sibling audit style as [`docs/research/psych-fork-engine-changes.md`](docs/research/psych-fork-engine-changes.md)); nothing was built or run here. Sibling of the `whoisitlolxd` fork triage in §24, and like it this is a review of an upstream JS Engine fork branch, not of Psych.

What it is: `tools/chart_compiler/chart_compiler.cpp` (861 lines) is a standalone C++17 CLI — hand-written JSON reader plus a bounded external merge sort (1M-record runs, 64-way fan-in, writes `.partial` then renames) — that turns a Psych `chart.json` + `events.json` into a headerless `notes.bin` of 12-byte little-endian records (`uint64` ms timestamp, `uint16` sustain ms, `uint8` lane with bit 7 = must-hit, `uint8` note type) plus a `song_info.json` manifest; `native/psychgpu/src/mapped_note_buffer.cpp` (315 lines) is a `MappedNoteBuffer` that maps that file read-only (`CreateFileMappingW`/`MapViewOfFile`, `mmap` elsewhere) with no copies or per-query allocations and answers binary-search range queries. Both ship their own CMake build and a standalone `assert()` test.

Why not just merge it: **the branch touches no Haxe at all and is 81 commits behind JS Engine `main`**, and its own README defers "the Haxe/hxcpp extern and game build wiring" to a "Component 3" that does not exist — so nothing in the game can read a `notes.bin`. There is also no GPU in it despite the name: no shader, vertex buffer, instancing or batching anywhere in the diff. Our note *spawning* is already a cursor walk over a pre-sorted array (`play/helpers/PlayStateNotes.hx:178-221` advances `notesAddedCount`), so there is no per-frame scan to fix. What is worth taking is the storage and tool-shape ideas, re-targeted at our loader:

### 26.1. Measure first (gates everything below)

- **[P1] Chart-load baseline.** Time three separate things on `bopeebo-easy` and on a ~20k and a ~100k note stress chart, through `FrameProfiler` (F3 overlay, F6 export) and `PoolStats`: (a) read + `Json.parse` + `onLoadJson` conversion in `data/Song.hx`, (b) `PlayStateChartLoader.generateSong` allocation and the `unspawnNotes`/`eventNotes` sorts (`:375`), (c) `Paths.initNote` atlas/frames work for the skins involved. Put the numbers in the issue; this is also the data the "[P3] Performance baseline gate" in §20 wants. **If (c) dominates, everything in §26.2 is the wrong fix** and the work belongs in §18 and §12.5 instead. Effort: S.

### 26.2. Worth taking

- **[P1] Packed note timelines (replace the fat preload object).** `objects/Note.hx:21` `PreloadedChartNote` is a 26-field Haxe object — 4 `String`s (`noteType`, `animSuffix`, `noteskin`, `texture`), 12 `Bool`s, 9 `Float`s, 1 `Int` — and `PlayStateChartLoader` builds one per head (`:230-249`), one per jack note, and one per sustain *segment* (`:300-322`), so a hold-heavy chart allocates several times the note count in objects that all die on state exit. Store the timeline as structure-of-arrays over `haxe.io.Bytes` / `Vector<Float>` / `Vector<Int>` (lane + flags packed into one `Int`, string fields as indices into a per-chart table) and materialise a `PreloadedChartNote` view only for notes that actually spawn or can be judged. Pure Haxe, so cpp, HashLink and web all keep working with no extern and no CMake — this is where their idea genuinely helps us, and it feeds `docs/LOW_MEMORY_MODE.md` and §18 directly. Effort: M.
- **[P2] Compiled-chart cache (stop re-parsing on every load).** Emit the packed timeline + the sparse event list from §26.1(b) into a per-chart cache on first play, keyed by a hash of the source JSON text so a stale file can never be read silently; write it next to the chart where `assets/` is writable and into the save dir otherwise (see `backend/RenderPaths.hx` for the "Windows only creates the last path segment" trap). `Song.loadFromJson` takes one extra branch: cache hit → skip parse/alloc/sort; miss → current path, then write. `ChartingState` must always take the JSON path (the charter needs sections), and the cache must be deletable at any time — it is derived data, not a save format. Toggle, default on, per the rule at the top of this file; `--no-chart-cache` for §20's golden tests. Effort: L.
- **[P2] Complete the record instead of copying their 12 bytes.** Widening to 32 bytes + a string table is what makes the format usable for Phoenix, because their record cannot express the fields our loader reads: `gfNote`, `noAnimation`/`noMissAnimation`, `hitCausesMiss`, `ignoreNote`, `lowPriority`, `blockHit`, `parentST`/`parentSL`, per-note skin/texture, `sustainLength` beyond 65535 ms (they chain `0xff` continuation records instead), or sub-millisecond `strumTime` (they `std::round` to ms, which fights the decimal hit windows and Early & Late in `docs/EARLY_LATE.md`). Their note type is also a `uint8` resolved from a dictionary in `song_info.json`, so any type they have not seen — i.e. every `example_mods/custom_notetypes/` script — compiles to "normal note" *silently*. Strings by reference have no such failure mode. Lane width is the other thing to settle at design time: their `uint8` lane byte spends bit 7 on must-hit (127 lanes max) and their `mustHitSection` resolution is `rawLane % lanesPerSide` with a fixed four lanes per side, so the format assumes the answer to §25.1 (variable key count) is 4. Store the lane as an `Int16` and derive the side at load time instead. Effort: M.
- **[P2] Pre-baked ms timelines, sections kept.** Their two good ideas are (1) sorting once offline instead of per song start and (2) resolving `mustHitSection` into the lane byte at compile time, with BPM changes emitted as generated `__bpm_change` sparse events so the runtime never converts beats to time. Do the same *inside* our cache. Sections, however, stay: `play/PlayState.hx:3441-3480` still reads `SONG.notes[curSection]` for `changeBPM` and pushes `mustHitSection`, `altAnim`, `gfSection` and `curSection` to Lua, and `crossFade`, `typeOfSection` and `sectionBeats` are per-section fields with no home in a headerless record. A record-only format would break scripts and the charter, which is exactly the §12.8 caution about Psych/JS compatibility. Effort: M.
- **[P2] Steal their tool hygiene, not their build.** Copy into whatever chart tool we ship under `tools/` (§17's proposed `tools/new-mod.py` is the same shape): write `.partial` then rename atomically; `--keep-temp` to keep merge chunks when a chart is malformed; validate "file length divisible by record size" and name the offending file in the error; and make the record size a compile-time assertion so adding a field to `PreloadedChartNote` breaks the build instead of silently shifting every offset in existing caches. Their standalone native test is the right pattern too — `tests/native/run.sh` already compiles C/C++ units with no Haxe/Lime/Android dependencies, so a format test belongs there (or in `tests/haxe/` for the pure-Haxe version, which is what §20's round-trip fixtures would call). Effort: S.
- **[P3] `findVisibleRange`-shaped queries — only with a batched note renderer.** Their `findFirstAtOrAfter`/`findFirstAfter` pair returning a half-open index range for an inclusive time window is the correct API for "give me the notes on screen at t" *if* notes are ever drawn as one batched/instanced quad pass instead of per-sprite Flixel objects. Land it together with that renderer (and the skew-capable renderer in §12.5), never as a standalone "performance" change, because spawn cost is already amortised and the rendered-note cap side of high-NPS cost is `ClientPrefs.maxNotes` (§24.2, done). Effort: L.

### 26.3. Checked and deliberately not taken

- **Do not merge the branch as-is.** Two CMake projects with no consumer, no game-build wiring and no CI job that builds either — dead code in `native/` + `tools/` that still has to be maintained across rebases.
- **No mandatory offline compile step for mods.** A format that must be produced before a song can play breaks the drop-a-folder-into-`mods/` workflow (§12.8), and shipping a compiled CLI per platform would outgrow what CI does today (`.github/workflows/main.yml` builds Windows + Android only) — a `SIZE.md` / `BUILDING.md` problem we do not have. Our cache is always self-built at runtime and always optional.
- **No new native/CMake dependency in the game build.** mmap through hxcpp needs an extern plus `build.xml` include wiring (see `source/utils/build.xml`) and a hand-written path per target; the Haxe cache in §26.2 gets most of the benefit with none of that, and hxcpp `Bytes` already avoids the parse+GC cost that motivates `mmap` in the first place.
- **Nothing gained on the web target**, which is a stated Phoenix goal ("FIX HTML5/WEB!!!" in §0): no `mmap`, no `sys.io.File`, and embedded charts come from `Assets.getText`. Every path here must degrade to "parse the JSON" under `#if !sys`.
- **`notes.bin` is not a chart format and not a save.** Round-tripping stays JSON (the §20 golden tests, including the compressed path in `ChartingSaveLoad.saveLevel`), and §12.2's `meta.json`/global-charts work is where an on-disk *format* change belongs — a cache must not become a second source of truth for charts.
- **Do not inherit the name.** Nothing in that diff renders on the GPU; calling a packed-array cache "GPU notes" would make §18 and §12.5 harder to reason about, not easier.

---
## 27. MIXTAPE ENGINE (`Z11Coding/Mixtape-Engine`) — FULL FEATURE GAP REVIEW (2026-11-21)

**Source:** <https://github.com/Z11Coding/Mixtape-Engine> at `2213dc8` (2026-07-31). **Apache 2.0**, same licence as this tree, so porting is allowed — but see §27.8, because a lot of what is in there is third-party code with its own credits (Nebula + 4mbr0s3 2's notefield system, skedgyedgy's Artemis plugin API, `tentools` for GameJolt, `haxe.ui` for the cursor helper, plus a pile of Codename Engine macros). 456 `.hx` files, `flixel` 5.6.1, `hscript-iris`, `hxvlc` 1.9.2, `ClientPrefs.data` + `StageData` + script note types — i.e. a **Psych 1.0-era fork** (`version="0.2.8"` in `Project.xml`) that has been heavily hacked on. The interesting parts are `source/psychlua/*` (≈250 Lua callbacks), `source/backend/*` (~110 files), `source/objects/playfields/*`, `source/states/editors/*` and `source/options/*`.

**Method.** Cloned at that commit and diffed file-by-file against this tree. Three passes: (1) every Lua callback name in both trees extracted and compared (≈250 names there vs ≈370 names here across Lua/Python/HScript); (2) every `ClientPrefs` field and every options-menu row compared; (3) every subsystem that exists there and not here read end-to-end, and the dead/never-imported ones separated from the shipped ones (Haxe only compiles what is reachable from `Main`, which is how ~9k lines of `PlayStateCache` and `EditorLua` never break their build). Nothing was built or run.

**Scope, per the request:** engine systems, data formats, mod-facing APIs, options and tools only. **No content** — no characters, no character/stage/song/week/dialogue assets, no skins art, no note-type scripts. Where something is *structural* support for content (dual character slots, extra audio stems) it is listed and explicitly marked as structure only. Duplicates of §0–§26 are cross-referenced instead of repeated.

**Verdict.** There is nothing here big enough to merge wholesale, and several headline systems are either already beaten by Phoenix or unfinished (Twitch/YouTube, Archipelago, Undertale, and their HScript/macro experiments are all dead code — §27.7). What is worth taking is roughly two dozen self-contained things, plus **one genuinely original gameplay mode** (Mix-Up vs. a simulated human AI — §27.3.1) and **one missing Psych 1.0 mod feature** (per-mod `settings.json` + `getModSetting()` — §27.1.1). Ordered list at the end.

---

### 27.1 MODDING API — what to add to Lua / Python / HScript

Each item below must land in **all three** script languages to keep Phoenix's parity rule (Lua `source/psychlua/callbacks/*.hx`, Python `source/psychlua/pystdlib/*.hx`, HScript `source/psychlua/HScript.hx`). Mixtape only ever had Lua + HScript, so every entry here is a rewrite, not a copy.

#### 27.1.1 [P1] Per-mod settings contract — `data/settings.json` + `getModSetting()`

Psych 1.0 ships this and Mixtape has it; **Phoenix stubbed it out**. In Phoenix the whole mod-settings feature is present as commented-out code: `source/states/ModsMenuState.hx:307-325` has the settings button inside a `// not yet` block, `source/states/ModsMenuState.hx:19` imports `options.ModSettingsSubState` commented out, `options/ModSettingsSubState.hx` does not exist, and `Mods.getPack()` (`source/backend/Mods.hx:147`) reads `pack.json` only. There is no `getModSetting` anywhere in `source/`.

Mixtape's version, all of it reusable as a spec:

- `source/options/ModSettingsSubState.hx` — builds a real `BaseOptionsMenu` from an array of option objects (`name`, `description`, `save`, `type`, `options`, `keyboard`/`gamepad` for keybinds), saved per mod folder into `FlxG.save.data.modSettings[folder]`.
- `source/psychlua/LuaUtils.hx:120-180` — `getModSetting(saveTag, ?modName)` lazily loads `mods/<mod>/data/settings.json` with `tjson`, applies declared defaults (including `{keyboard, gamepad}` pairs for `keybind`/`key` types), caches into the same save slot, and falls back safely when the file is missing.
- `source/psychlua/FunkinLua.hx:1586` + `source/psychlua/HScript.hx:160` — the callback itself.
- `source/states/ModsMenuState.hx:238-253, 796-830` — `ModItem.settings`, enabled/disabled state of the button, and the entry point into the substate.

Work here: `Mods` gets a `settings` loader, `ModsMenuState` re-enables the button, a new `options/ModSettingsSubState.hx`, `getModSetting` in the three script backends, and `ClientPrefs`-style save-slot migration in `SettingsBackup` (§13). Default ON (it is opt-in per mod by the mere existence of the file — a mod without the file behaves exactly as today). This is also the concrete missing half of the "Psych 1.0 features" bullet in §0. Effort: **M**.

#### 27.1.2 [P2] Script-side object creation and method calls (`createInstance`, `addInstance`, `instanceArg`, `callMethod`, `callMethodFromClass`)

Mixtape: `source/psychlua/ReflectionFunctions.hx:135-240`. `createInstance(var, className, args)` does `Type.createInstance`, registers the object under a script variable, and can be added to the state (`addInstance`), with `instanceArg` letting a scripts' own object be passed into Haxe constructors; `callMethod`/`callMethodFromClass` call arbitrary methods with reflected args.

Phoenix has none of these on purpose-ish — reflection is the sandbox boundary (`backend/ModSecurity`, `backend/ScriptSecurityScanner`), and `createInstance` is exactly the kind of thing the scanner flags. So this is **not** a straight port: add it behind an allowlist of constructors (`objects.Alphabet`, `FlxSprite`, `FlxText`, `FlxTimer`, `FlxTween`, `ModchartSprite`, the modchart classes in §27.1.3) plus an explicit per-mod "advanced API" opt-in, and keep the scanner's existing rules. Skip `getGlobals` — it is commented out in Mixtape too (`source/psychlua/FunkinLua.hx:406`). Effort: **M**, risk: **security review required**.

#### 27.1.3 [P2] HScript object API for gameplay classes

Mixtape exposes the gameplay/modchart classes as HScript globals so scripts can *construct* them (`source/psychlua/HScript.hx:329-338`):

```haxe
set("NoteObject", objects.NoteObject);  set("PlayField", objects.playfields.PlayField);
set("NoteField",  objects.playfields.NoteField);  set("ProxyField", objects.proxies.ProxyField);
set("ProxySprite", objects.proxies.ProxySprite);  set("ModManager", backend.modchart.ModManager);
set("Modifier", backend.modchart.Modifier);  set("EventTimeline", backend.modchart.EventTimeline);
// …NoteModifier, SubModifier, ModEvent/SetEvent/EaseEvent/CallbackEvent/StepCallbackEvent, FlxPoint
```

Phoenix's HScript preset (`source/psychlua/HScript.hx:587-668`) injects a fixed list of statics (`FlxG`, `PlayState`, `Paths`, `ClientPrefs`, `MetaHorror`, `Native`, …) and `addHaxeLibrary` is the only way to reach anything else — so a script can call `addModifier`, but cannot build a `Modifier`/`NoteField`/proxy graph by hand. If §27.3.9 (playfield architecture) or §27.1.2 lands, expose the equivalents: `Modifier`, `ModchartManager`, `PlayField`, plus the new modifiers in §27.2. Effort: **S–M** (mechanical once the classes are stable).

#### 27.1.4 [P2] Modchart "queue" API — `queueSet`, `queueSetP`, `queueEase`, `queueEaseP`, `addBlankMod`

Mixtape `source/psychlua/FunkinLua.hx:271-317`: queue a mod value change for *the next step* instead of immediately, with a blank-modifier registration helper. Phoenix's `modchart/ModchartManager.hx` and `ModchartEventManager` cover the immediate forms (`modSet`, `modAdd`, `modEase`, `modRepeater`, `modCallback`, `addModifier`, `setPercent`) and `ModchartLabState` covers authoring, but there is no "apply at step N" queue and no way for a script to register a *blank* custom modifier that later gets values. Add both to the shared modchart layer so all three languages get them at once. Effort: **S**.

#### 27.1.5 [P3] Script-VM quality-of-life callbacks (small, all one-liners)

Missing in Phoenix, present there (file:line = Mixtape):

| Callback | Mixtape | Behaviour | Phoenix status |
| --- | --- | --- | --- |
| `setVar` / `getVar` | `FunkinLua.hx:474-479`, `HScript.hx:138-143` | per-song shared variable store on `PlayState.variables` | absent; only `setOnScripts` (broadcast a global) and `PersistentValue` (survives songs) exist |
| `get` / `set` | `FunkinLua.hx:243-249` | aliases of `getProperty`/`setProperty` | absent (trivial aliases) |
| `getColorFromName` / `getColorFromString` | `FunkinLua.hx:878-879` | `FlxColor.fromString` (`red`, `#ff0000`, `0xff00ff`) | only `getColorFromHex` (`callbacks/GameCallbacks.hx`) |
| `setTextHeight` / `setTextAutoSize` | `TextFunctions.hx:50-67` | height + word-wrap auto-size | `callbacks/TextCallbacks.hx:32,42` has size/width only |
| `getSoundPitch` / `setSoundPitch` | `FunkinLua.hx:1565-1577` | read/write `FlxSound.pitch` with optional pause | `callbacks/SoundCallbacks.hx` has volume/time only |
| `eraseSaveData(name, field?)` | `ExtraFunctions.hx:135` | delete a whole save slot | `callbacks/SaveDataCallbacks.hx:12-40` has init/flush/get/set only |
| `crawlDirectory(dir, ext)` | `FunkinLua.hx:255` | recursive file listing (used by their cache & custom notetypes) | `backend/Paths.hx` has no crawler; `directoryFileList` is one level |

Effort: **S** for the whole table; no behaviour change, so no toggles needed (they are additive APIs, per the rule at the top of this file).

#### 27.1.6 [P3] Extra gameplay callback hooks

Mixtape fires eight hooks Phoenix does not (all verified as actually called, not just declared):

| Hook | Mixtape evidence | What it gives mods | Phoenix equivalent |
| --- | --- | --- | --- |
| `onChangeMania(new, old)` | `states/PlayState.hx:5485`, `backend/PlayStateCache.hx:3523` | react to mid-song lane-count change (only useful with §25.1) | none |
| `onEventPushed(event, v1, v2, time)` | `states/PlayState.hx:5305` | inspect every chart event *before* it fires | none |
| `onModifierRegister` / `onModifierRegisterPost` | `states/PlayState.hx:2557-2558` | register custom modifiers at the right moment | partially: `addModifier` + `onCreatePost` ordering works today |
| `onReceptorGeneration` / `onReceptorGenerationPost` | `states/PlayState.hx:1879-1888`, `:3526` | build/alter receptors before and after the default pass | none (strums are already built in `onCreatePost`) |
| `onSpawnNotePost(note)` | `states/PlayState.hx:5696` | act on a note right after it spawns | only `onSpawnNote` (pre) exists |
| `onSkipIntro(time)` | `states/PlayState.hx:6464` | clean up when the player skips the intro | none |
| `onSongRestart()` | `states/PlayState.hx:6024` | distinguish restart from fresh create | none |
| `onRestartCountdown()` | `states/PlayState.hx:2700-2706` | cancel/alter the post-death countdown | Phoenix has `onResumeCountdownStart`/`Tick` (different path) |

Effort: **S** each, **M** for the pair that needs new seams (`onReceptorGeneration*`). All default-on.

#### 27.1.7 [P3] Window scripting API gaps

Mixtape's `source/psychlua/WindowFunctions.hx` + `backend/window/{Window,WindowUtils,CppAPI}.hx` give scripts: `windowX/Y/Width/Height/Title` getters, `windowSetPos`, `windowSetSize`, `windowReset`, `windowPopup(msg,title)` (native alert), `setWindowTitle`, `setWindowPrefix`, `setWindowSuffix`, `setWindowOppacity`, `setWallpaper`, `hideTaskbar`/`restoreTaskbar`, `hideWindows`/`restoreWindows`, `setTransparency(color)`/`resetTransparency`, `sendNotification(title, desc)` (Windows toast).

Phoenix already has a *better* Windows layer in `backend/MetaHorror.hx` + `psychlua/callbacks/MetaHorrorCallbacks.hx` (`setWindowTitle`/`restoreWindowTitle`, `setAlwaysOnTop`, `setMetaWindowAlpha`, `setMetaWindowColorKey`, `hideTaskbar`/`restoreTaskbar`, `hideAllWindows`/`restoreAllWindows`, `setWallpaper`/`restoreWallpaper`, `flashTaskbar`, `getOpenWindowTitles`, `captureDesktop`, clipboard, system volume) — so what is actually missing is narrow: **window geometry (x/y/w/h, set pos/size, reset), title prefix/suffix, a native `windowPopup` alert, and shell notifications/toasts**. Add them to `WindowCallbacks.hx` (transparency lives there already) rather than importing their C++ shim. Effort: **S**.

#### 27.1.8 [P3] Cursor mode get/set

Mixtape `source/backend/Cursor.hx` (596 lines, wraps `haxe.ui`'s `CursorHelper`) + `FunkinLua.hx:260-270` `getCursorMode`/`setCursorMode`: scripts pick a *named* cursor graphic instead of supplying a file. Phoenix has `changeCursor(path, visible, loadDefault, scale, xOffset, yOffset)` (`callbacks/MiscCallbacks.hx:67`), which is strictly more expressive for mods, and `objects/PointingCursor` for the menu finger. Do **not** port the class; if the named-mode convenience is wanted, ship a small table of built-in cursor presets on top of the existing `changeCursor`. Effort: **S** (or skip).

---

### 27.2 MODCHART — nine modifiers Phoenix does not have

Phoenix's registry has 36 modifiers (`source/modchart/ModifierRegistry.hx:3-39`: drunk, tornado, reverse, beat, bounce, boost, bumpy, centerrotate, confusion, counterclockwise, drugged, fieldrotate, incomingangle, infinite, invert, localrotate, opponentswap, radionic, receptorscroll, rotate, sawtooth, scale, schmovindrunk, schmovintipsy, schmovintornado, skew, spiral, square, stealth, tipsy, transform, vibrate, waveshit, wiggle, zigzag, zoom, …). Mixtape has 20 and nine of them are **not** in that list:

| Mixtape modifier | File | What it does | Port value |
| --- | --- | --- | --- |
| `Path` / `CustomPath` / `InfinitePath` | `backend/modchart/modifiers/{Path,CustomPath,InfinitePath}Modifier.hx` | move notes along an author-supplied curve/path in the field, optionally looping forever | **[P2] the valuable one** — a real, scriptable "note path" family that Phoenix lacks; pairs with the 3-D/perspective work in §12.5 |
| `ColumnRotate` | `ColumnRotateModifier.hx` | rotate a single lane's receptor+notes around its own axis | [P3] (`LocalRotate`/`CenterRotate`/`FieldRotate` are different pivots) |
| `Accel` | `AccelModifier.hx` | per-step acceleration of scroll | [P3] |
| `Alpha` | `AlphaModifier.hx` | per-field/per-lane note alpha | [P3] (`stealth`/`invert` are all-or-nothing) |
| `Perspective` | `PerspectiveModifier.hx` | per-modifier perspective skew (Phoenix has a global `setModchartPerspective`) | [P3] |
| `Flaccid` | `FlaccidModifier.hx` | scales hold-note *lengths* (not positions) | [P3] |
| `Swap` | `SwapModifier.hx` | swaps lane N with lane M | [P3] (`opponentswap` swaps sides, not lanes) |

Implement against `modchart/Modifier.hx` + `PercentStore` so `setPercent`/`modSet`/`ease` work for free, register in `ModifierRegistry`, add to `ModchartLabState`'s knob list and the docs in `docs/MODCHARTS.md`. Effort: **S** each, **M** for the Path family (needs a curve parser).

---

### 27.3 GAMEPLAY SYSTEMS

#### 27.3.1 [P1] Mix-Up Mode + the AI Player (single-player vs. a simulated human)

This is the most distinctive thing in Mixtape and the only *new game mode* worth having. Two pieces:

1. **`source/backend/AIPlayer.hx` (377 lines).** Builds a "play map" per chart section: for every note it decides a hit offset (or a miss) from a probability table, then returns an array aligned with the chart. Seven profiles (`case 0..6`), from "First Time Playing FNF" (`ratingChance = [0,0,0,70,95]`, ~6.5 % random misses) to "Boyfriend getting freaky on a friday night" (`[100,0,0,0,0]` = frame-perfect). The offsets feed the existing judgement code, so the AI produces real judgements, combo, score, accuracy and rank.
2. **`mixupMode` in `states/PlayState.hx:280, 750-755, 792, 6159-6190`.** When on (and not `bothMode`), the AI plays the *opponent* side, the HUD switches to a two-column "you vs. them" score display (`playerScoreTxt` / `opponentScoreTxt`; the shared low-health warning recolours all of them red at `:6144-6155`), the AI's rating/FC is computed alongside the player's, and scores are stored under a mode-suffixed key (`saveMod`, `:769-791`, which already carries the modifier/mode string). Surfaced as an option pair in `source/options/OtherSettingsSubState.hx:147-172`: **Mix-Up Mode** (bool) and **Opp. Difficulty** (string: `Baby Mode / Easier / Normal / Harder / Hardest / Average FNF Player / Dont`, mapped one-to-one onto `AIPlayer.diff` `0..6` at `PlayState.hx:793-820`).

Why it is cheap here: Phoenix already has botplay (`cpuControlled`), per-side strum groups, `opponentplay`/`bothsides` changers, `PlayStateRating`/`Conductor.judgeNote`, and a second score/`ratingFC` path in `ResultsState`. The new code is the offset generator + the second HUD column + one save key.

Defaults: **Mix-Up Mode off by default** (explicitly pre-declared exception to the "new features on by default" rule — it replaces normal scoring); **Opp. Difficulty = Normal**. Must not save scores while botplay is active (Phoenix already gates that), and must skip the AI when `opponentplay`/`bothsides` is set. Credit `Z11Coding` for the profile tables. Effort: **M**.

#### 27.3.2 [P2] Chart modifiers Phoenix is missing

Mixtape's `Chart Modifier` gameplay changer (`source/options/GameplayChangersSubstate.hx:63`) offers `Normal, Random, RandomBasic, RandomComplex, Flip, Pain, 4K Only, ManiaConverter, Stairs, Wave, Trills, Sequential, Mirror, Skip, Amalgam` (plus `SpeedRando`/`SpeedUp` lower in the file). Phoenix has `Random Mode`, `Stair Mode`, `Wave Mode`, `Flip Mode`, `One Key`, `Jack Amount`, `Troll Mode` (`source/states/substates/GameplayChangersSubstate.hx`) — `Flip` is their name for what Phoenix already does with `flip` (`play/helpers/PlayStateChartLoader.hx:172`, `abs(lane - 3)`), so the genuinely new ones are **`Trills`, `Sequential`, `Skip`, `Pain`, `RandomComplex`, `Amalgam`**, plus the highscore separation they do (`source/backend/Highscore.hx:269-281` appends the modifier to the save key so a mirrored run cannot beat a normal one). §23.1 already covers the Mario's Madness modifier set — do these in the same pass and do not duplicate the transform code. Default `Normal`; per-modifier highscore keys on. Effort: **M**.

#### 27.3.3 [P2] Three gameplay changers Phoenix lacks: GF Mode, Showcase Mode, Loop Mode

- **GF Mode** (`gfMode`) — play the girlfriend character on the player side: `states/PlayState.hx:752-753, 1410, 1592, 1662-1668`. Uses her animations, her health icon and her `Char` offsets; `playAsGF` also changes which icon the health bar follows. Phoenix has no GF play path at all (`playAsGF` does not exist anywhere in `source/`).
- **Showcase Mode** (`showcase`) — both sides autoplay but the HUD/score stays visible for recording: `states/PlayState.hx:5842` (`playfield.autoPlayed = cpuControlled || getGameplaySetting('showcase')`). Phoenix's botplay stamps a `BOTPLAY` label (`play/PlayState.hx:1685`) plus an optional watermark; a clean "record it" mode is a different thing.
- **Loop Mode / Loop Challenge** (`loopMode`, `loopModeC`, `loopPlayMult`) — restart the song on finish, and in challenge mode multiply `playbackRate` by 1.05 every loop (`:7013-7016`), until the player dies. Phoenix has a `loopTheSong` script call but no changer or UI.

All three are ~1 row each in `GameplayChangersSubstate` + a few branches in `play/PlayState.hx`. Defaults off (mode-type, pre-declared). Effort: **S** each.

#### 27.3.4 [P2] Input-system compatibility layer

Mixtape lets the player pick a whole *input ruleset* (`ClientPrefs.inputSystem`, `source/backend/ClientPrefs.hx:166`; option in `options/GameplaySettingsSubState.hx:23`): `Native, BEAT! Engine, Kade Engine, ZoroForce EK, Mic'ed Up Engine, Andromeda Engine (legacy), YoshiEngine, Kade Engine Community`. It is not cosmetic — `objects/playfields/PlayField.hx:283`, `objects/Note.hx:731`, `states/PlayState.hx:4035-4069, 9894` branch on it to change hold-hit ownership, sustain re-hit rules, antimash and note-selection priority.

Phoenix already ships pieces of several of these as separate booleans (`More Spammable Inputs`, `No Ascend RNG`, `Ghost Tapping`, `EZ Spam`, `antiCheatEnable`, `complexAccuracy`, `noMarvJudge`, the accuracy presets in `backend/AccuracyPresets.hx`). So: build it as **named presets over the existing knobs** (a "compatibility profile" that sets several prefs at once and is labelled with the engine it emulates), not as a second input pipeline. That keeps §15's input work single-source. Default `Native` (= today). Effort: **M**.

#### 27.3.5 [P2] Sustain / hold rendering controls

Mixtape exposes four knobs Phoenix lacks (`source/objects/playfields/NoteField.hx:36-52, 358`; options in `options/GraphicsSettingsSubState.hx:76-94`):

- **Hold Subdivisions** (`holdSubdivs`, default 2 → `holdSubdivisions = value + 1`): how many pieces a long hold is chopped into; raises quality, costs draw calls.
- **Optimize Holds** (`optimizeHolds`, default **on**): skip off-screen/short hold segments.
- **Draw Distance Multiplier** (`drawDistanceModifier`, default 1): scale spawn/lifetime distance — the low-end-device knob.
- **Guitar Hero sustains** (`guitarHeroSustains`): sustain sprite style (stretchy GH-style vs. Psych tiles).

Phoenix has `Old Sustain Note Style` and `noteSpawnTime`, but no subdivision count, no hold optimiser and no draw-distance multiplier. All four are self-contained in `objects/Note.hx`/`StrumNote.hx`/`play/helpers/PlayStateNotes.hx`. Defaults: optimize **on**, subdivisions **2**, multiplier **1.0**, GH style **off**. Effort: **S–M**.

#### 27.3.6 [P2] HUD skin packs (`uiSkin`)

Mixtape ships six switchable HUD skins for combo numbers and judgement popups (`Bedrock`, `BEAT!`, `BEAT! Gradient`, `Psych Engine`, `Mixtape Engine`, `Base Game`) resolved by `getUiSkin()` at `source/backend/PlayStateCache.hx:5987-6040`, selected in `options/VisualsUISubState.hx` and preloaded in `cachePopUpScore()`. Phoenix can restyle rating *files* (`ratingSpriteList`, `Rating Style`) and combo text (`ScoreTxt Style`, `showCombo`), but has no coherent "HUD skin" concept where numbers + judgements + combo font come as one set with per-skin fallbacks. Add a `uiSkin` pref + a `HUD/<skin>/` path scheme with the existing `base` fallback (the shipped `HUD/base/` art stays the fallback, so a mod only overrides the pieces it wants). Content stays mod-side; only the resolver and option go in. Default: current look. Effort: **M**.

#### 27.3.7 [P3] Extra chart audio tracks (`SONG.extraTracks`)

Mixtape's `SwagSong.extraTracks:Array<String>` (`source/backend/Song.hx:49`) loads and time-syncs additional instrumental stems and starts/stops them with the song (`states/PlayState.hx:5140-5142`, `backend/ChartCache.hx:557`, editor support in `ChartingStateOG.hx:535`). Phoenix only has Inst + Voices (+ player/opponent/gf vocal split). Related to §12.2's "Unlimited vocals per strumline" — this is the *simpler* half (extra instrumentals, one player), so do it first and let the vocal work reuse the loader. Default off per mod (data-driven). Effort: **M**.

#### 27.3.8 [P3] Dual character slots (structure only — no characters listed)

`SwagSong` there has `player4`/`player5` next to `player1`/`player2` (`source/backend/Song.hx:26-30`), `StageData` gains `boyfriend2`/`opponent2` + their camera offsets + `_editorMeta` (`source/backend/StageData.hx:12-33`), and `PlayState` keeps a second character map per side (`source/states/PlayState.hx:1169`, `boyfriendMap2`/`dadMap2`). This is the data/lifecycle support for two-on-two setups — it is listed *only* because it is a format change (`Song`/`StageData`/editor saves), not because of any character content. If it is taken, it goes in beside §12.2's stage-graph and custom-values work. Effort: **M**.

#### 27.3.9 [P3] PlayField / NoteField / ProxyField architecture — only with §25.1

Mixtape replaced the monolithic `PlayState` note handling with three classes (`source/objects/playfields/PlayField.hx:19-60` documents the split; credits: **Nebula** and **4mbr0s3 2**): `PlayField` owns notes/judgement and a per-field `ModManager`, `NoteField` renders, `ProxyField` clones a `NoteField` cheaply so the same notes can be drawn many times (the classic "infinite notefield" effect) without paying modifiers twice. Field control can also be handed between players.

Phoenix's `modchart/PlayField.hx` is a *math* object (percents, receptors, perspective), not a notefield: notes/strums live in `play/helpers/*` against `PlayState` singletons. Porting the architecture is a large refactor that only pays off together with §25.1 (variable key count) and §27.3.8 — do it as part of that work or not at all, never as a standalone "performance" change (§26's lesson). Effort: **L**; explicitly **not** recommended on its own.

---

### 27.4 NEW OPTIONS (grouped, with defaults)

Everything below is a row Phoenix does not have. Values are Mixtape's defaults; the "on by default" house rule applies to behaviour-neutral ones, while mode-changing ones are pre-declared off.

**Gameplay**

| Option | Pref | Default | Category | Notes |
| --- | --- | --- | --- | --- |
| Input System | `inputSystem` | `Native` | Gameplay | §27.3.4 — presets over existing knobs |
| Mix-Up Mode | `mixupMode` | **off** | Misc/Gameplay | §27.3.1 |
| Opp. Difficulty | `aiDifficulty` | `Average FNF Player` | Misc | §27.3.1, only shown when Mix-Up is on |
| Showcase Mode | `showcase` | off | Gameplay changers | §27.3.3 |
| GF Mode | `gfMode` | off | Gameplay changers | §27.3.3 |
| Loop Mode / Loop Challenge / Challenge Mult. | `loopMode`/`loopModeC`/`loopPlayMult` | off / off / 1.05 | Gameplay changers | §27.3.3 |
| Hold Subdivisions | `holdSubdivs` | 2 | Graphics | §27.3.5 |
| Optimize Holds | `optimizeHolds` | **on** | Graphics | §27.3.5 |
| Draw Distance Mult. | `drawDistanceModifier` | 1.0 | Graphics | §27.3.5 |
| Guitar Hero Sustains | `guitarHeroSustains` | off (on there) | Visuals | §27.3.5 — off here is a pre-declared exception: it changes the sustain art identity, and `Old Sustain Note Style` already owns that slot |
| In-Game Rating | `inGameRatings` | off | Visuals | judgement popups onto `camGame` instead of `camHUD` (`PlayState.hx:8730, 8742`) — useful for screen recordings |
| HUD Skin | `uiSkin` | current | Visuals | §27.3.6 |
| Show Keybinds on Start Song | `showKeybindsOnStart` | **on** | Visuals | overlay of the player's binds at countdown (Mixtape `objects/playfields/PlayField.hx:718`) — Phoenix has per-control hints in Controls only |
| Start Hidden | `starHidden` | off | Visuals | start with `camHUD.alpha = 0`, fade in on first note (`PlayState.hx:620, 2040`) |

**Graphics / performance / caching**

| Option | Pref | Default | Notes |
| --- | --- | --- | --- |
| Cache Graphics / Music / Videos | `graphicsPreload2`/`musicPreload2`/`videoPreload2` | off | the only cache rows there that are actually read (`states/CacheState.hx:122`); pre-decode into the persistent cache (§27.5.1) |
| Experimental Caching | `experimentalCaching` | off | enables saving the cache between sessions |
| Save Cache | `saveCache` | off | row exists there but nothing reads it — implement for real (write the warm cache to disk) |
| Cache Charts | `cacheCharts` | off | row exists there but nothing reads it — implement for real (`backend/ChartCache.hx`/`JSONCache` already keep parsed charts in RAM) |

The cache options belong together with a real **Cache Settings** menu + `CacheState` progress screen (§27.5.1), not as loose rows in Misc — Phoenix already has `OptimizationSubState`, so put the toggles there and the manager screen one level deeper.

**Misc / support**

| Option | Pref | Default | Notes |
| --- | --- | --- | --- |
| Show Crash Dialogue | `showCrash` | **on** | show the in-game crash state vs. only write the `crash/` bundle and print to the log; Phoenix always does both today (`backend/CrashHandler.hx:216-264`), so this adds a headless/kiosk/CI mode |
| Ignore Tween Errors | `ignoreTweenErrors` | **on** (off there) | wrap `FlxTween` completions so one bad mod tween cannot take the song down — direct win for §17's robustness goal |
| Allow Force Quit | `allowForcedExit` | **on** | keeps the window-close / Back-button quit path alive instead of soft-locking (Mixtape `Main.hx:431`); Phoenix handles quitting but exposes no pref |
| Silent Volume Keys | `silentVol` | off | volume keys change volume without the sound-tray blip (`FunkinSoundTray`) |
| Allow Username Detection | `username` | **on** | replaces the `USERNAME` token in dialogue text with the OS user (`cutscenes/DialogueBoxPsych.hx:388` there) — a streamer/privacy toggle, and the same idea should also gate `getDesktopUsername` (`backend/MetaHorror.hx:545`) here |

---

### 27.5 TOOLS, SCREENS AND PLATFORM

#### 27.5.1 [P2] Cache manager screen + persistent asset cache

`source/states/CacheState.hx` (624 lines) with a progress bar, driven by `options/CacheSettings.hx`; the actual caching is `backend/GPUBitmap.hx` (creates textures that live only in VRAM and drops the RAM copy — the original Smokey/Rozebud `GPUBitmap`), `backend/ImageCache.hx`, `backend/JSONCache.hx`, `backend/ChartCache.hx` and `CachePreload.hx` (`Paths.crawlDirectory` macro). Phoenix has `cacheOnGPU` (`backend/ClientPrefs.hx:275`) for the VRAM half and `LowMemory`/`MemoryProfiles` for eviction, but nothing that persists a warm cache between launches, and no screen to build/clear it. This is the biggest low-end-device win in the whole review: on a 2 GB Android device, re-decoding every sprite atlas at every boot is the first thing to fix. Default off (disk cost), with size readout and a one-click clear. Effort: **M**.

#### 27.5.2 [P3] Zip-archive mods and the packer

`source/backend/util/ZipUtils.hx` (335 lines) — create/read/extract zip archives with progress callbacks, banned-name filtering (`.git`, `.vscode`, …), `Compress`/`Uncompress` helpers and a `.ycemod` convention; `yutautil/ZipAccess.hx` — read a single entry out of a zip without extracting; `JSEZip` — the simple unzip used by their updater. Phoenix *imports* a zip in `ModsMenuState` (extract-then-install, `source/backend/Mods.hx:242`) and has no packer. Add: (a) read-from-zip in `Paths` so a mod can ship packed, (b) a `tools/pack-mod.py`-style packer, (c) the banned-name policy applied to imports. Cross-ref §12.2 P3 (".pack bundles") — same feature, their implementation is the reference. Effort: **M**.

#### 27.5.3 [P3] Command-line switches

`source/backend/CommandLineHandler.hx`: `-help`, `-mod <name>`, `-modfolder <path>`, `-addonsfolder <path>`, `-nocolor`, `-nogpubitmap`, `-livereload`, `-playtest`. Phoenix parses only `-troll` (`source/Main.hx:60`) plus the diagnostic/VLog flags (`backend/DiagnosticsReport.hx:95`, `backend/VLog.hx:245`) — and `-mod <name>`/`-playtest` are exactly what a modder's launcher or CI wants (headless boot of one song/mod). Effort: **S**.

#### 27.5.4 [P3] Native helpers worth cherry-picking

- `sendNotification(title, desc)` — Windows shell toast (`backend/window/CppAPI.hx` → `WindowsData`), §27.1.7.
- `backend/util/NativeAPI.hx` — file attribute get/set/append (hidden/read-only), console alloc + ANSI colours, dark title bar. Phoenix covers message boxes (`backend/WindowNative.hx:38`, `backend/Windows.hx:109`) and dark title (`backend/WindowColorMode`), so only the file-attribute + console-colour helpers are new — useful for a mod manager, not for players. Effort: **S**.
- `backend/ALSoftConfig.hx` — sets `ALSOFT_CONF` to a shipped `alsoft.ini`/`alsoft.conf` to raise OpenAL Soft quality. Treat as an experiment: measure against Phoenix's existing audio path (`backend/SongAudioStreaming`, `VolumeCurve`) before changing anyone's output. Effort: **S**.

#### 27.5.5 [P3] RTX (shader) parameter editor

`source/states/editors/RTXEditor.hx` — a slider playground that live-edits a shader's uniform values, so a modder can dial in values before writing them into a script. Phoenix has the shader API and `ModchartLabState`; it has no uniform-tweaking tool. Tiny, editor-only, no player risk. Effort: **S**.

#### 27.5.6 [P3] GameJolt service integration (only as a *service*, not as content)

`source/backend/gamejolt/GameJolt.hx` (752 lines, on `tentools`) + a toast manager wired into `source/Main.hx:36, 137, 299`; the Options entry is commented out (`options/OptionsState.hx:10`). Provides auth, trophies (achievements), score tables, and session start/ping/close. **Caveat: it does not compile as committed** — `authDaUser` (`:107-118`) switches to a `GameJoltLogin` state that is defined nowhere in the tree (no `class GameJoltLogin`, no file), so their own build must be excluding or patching this; treat it as a reference design, not copyable code, and expect to write the login screen from scratch. Phoenix's only related work is the "GameJolt browser" idea in §0 and the `GJClient` snippet note; the Achievement *system* is already here (`backend/Achievements.hx`), so what is missing is a remote-sync backend + login screen. If taken, gate it hard: no network call without explicit opt-in (§19's analytics rule), and treat the API keys as build-time secrets, not repo files. Effort: **L**.

---

### 27.6 CHECKED — ALREADY HERE (do not port)

- **Accuracy: wife3.** Already implemented: `source/play/helpers/PlayStateRating.hx:121` calls `EtternaFunctions.wife3` per note, feeding `ResultsState`. Their `Wife3` class (`PlayStateCache.hx:113`) is the same Etterna formula; no option needed beyond the existing `Accuracy Preset` (`ClientPrefs.hx:443`).
- **Achievements.** `backend/Achievements.hx` is the same Psych 1.0 code (hidden, `maxScore`/`maxDecimals` progress, per-mod IDs, popup) — nothing to take.
- **Chart editor.** Phoenix's `editors/ChartingState.hx` + `editors/charting/*` already exceed their two editors (`ChartingStateOG`/`ChartingStatePsych`): events, waveform, sections, undo, autosave, note-type pickers, playtest. Their `EditorLua` (scriptable editor) is **dead code** — never referenced (§27.7).
- **Other editors.** `WeekEditorState`, `CharacterEditorState`, `DialogueEditorState`, `DialogueCharacterEditorState`, `MenuCharacterEditorState`, `NoteSplashDebugState` (their `NoteSplashEditorState`), `MasterEditorMenu`, `EditorPlayState` all exist here (`source/editors/`). **Stage editor** is the one that does not — it is already tracked as **[P2] in §12.3**; their `StageEditorState.hx` (2.5k lines, `PreloadListSubState`, `_editorMeta`) is the reference implementation, not a new entry.
- **Shader / effect API.** Phoenix is a superset: `initLuaShader`, `setSpriteShader`, camera shaders, typed get/set for bool/int/float arrays, `setShaderSampler2D`, `tweenShaderFloat` (+ arrays) — `psychlua/callbacks/ShaderCallbacks.hx`. Their `ShaderFunctions.hx` has no tweening and no camera path.
- **Filters + chainable effects.** §0 DONE entries (`backend/ScreenFilters`, `backend/ChainableEffects`) already cover `flixel.addons.effects.chainable` and the OpenFL filter set, in all three languages. Nothing to take from their `ShadersHandler`.
- **Window / meta-horror toolkit.** Phoenix's `backend/MetaHorror` + `MetaHorrorCallbacks` is larger than their `backend/window/*`: wallpaper (set/restore/kill wallpaper apps), taskbar hide/restore, hide/restore all windows, colour-key transparency, window alpha, always-on-top, taskbar flash, clipboard, system volume/mute, desktop capture, openFile, typeText, persistent values. Only the geometry/prefix/toast gaps in §27.1.7 remain.
- **Save data + file API.** `initSaveData`/`flushSaveData`/`getDataFromSave`/`setDataFromSave` (`callbacks/SaveDataCallbacks.hx`) plus the *larger* file set (`checkFileExists`, `saveFile`, `deleteFile`, `getTextFromFile`, `directoryFileList` — `callbacks/FileCallbacks.hx`) vs. their `ExtraFunctions.hx`. Only `eraseSaveData` + `crawlDirectory` are missing (§27.1.5).
- **Camera, flash, fade, tween, sound, text, sprite, property APIs.** Compared name-by-name; Phoenix has ~370 unique callbacks vs ~250 there, including newer ones they lack (`addCamera`/`removeCamera`, `addPlayfield`, all the effect shorthands, `getPropertyAdvanced`, `captureDesktop`, `gdi*`, `vibrate`, `applyWindowTransparency`, `changeCursor`, `typeText`, `openFile`, `isRecording`, …). No wholesale gaps.
- **PsychUI widget kit** (`backend/ui/PsychUI{Box,Button,CheckBox,DropDownMenu,InputText,NumericStepper,RadioGroup,Slider,Tab}`). Internal editor chrome for their Psych-chart-editor; Phoenix has its own editor UI (`objects/ui/CustomFlxUI`, `EditorTooltips`). Porting a second widget toolkit buys nothing.
- **Freeplay UX.** Their `CategoryState` (All/Base/mods/secrets categories) + `searchBar` is *less* than Phoenix's `FreeplayFilter` (`states/FreeplayState.hx:44`: order, mod filter, favourites, stars, revision-based rebuild) + `MusicPlayer` (`source/music/MusicPlayer.hx`).
- **Mods menu + `pack.json`.** Phoenix already parses `pack.json` (`Mods.getPack`, `Mods.hx:147`), shows metadata in `ModInfoSubState`, and has global-mod handling (`pack.runsGlobally`). §12.6 P2 covers API/version metadata.
- **Pause music / menu tracks.** Both have a picker (`Pause Screen Song:`); their extra tracks are content.
- **Note types.** Data-driven in both (`backend/NoteTypesConfig`); their `Hurt/No Animation/Alt/Beatbox/GF Sing/Ghost/EX` list is a subset of what Phoenix ships in `example_mods/custom_notetypes/` (§23.6).
- **Gamepad/keyboard query API.** `keyboardJustPressed/Pressed/Released`, `anyGamepad*`, `gamepadAnalogX/Y`, `gamepadJustPressed/Pressed/Released` already exist here (`callbacks/InputCallbacks.hx`).
- **Localization, latency calibration, multikey, auto-updater, stage editor** — already tracked in **§12.3** (translations, stage editor), **§15/§16** (interactive latency test), **§25.1** (1K–10K mania; Mixtape adds nothing new beyond 18K ceilings, `4K Only`/`ManiaConverter` modifiers and a `Change Mania` event, which §25.1 step 7 already requires) and **§12.6 P3** (in-app updater; theirs does download → `JSEZip.unzip` → relaunch in `states/UpdateState.hx:350`, which is the implementation sketch that entry was missing).

---

### 27.7 UNFINISHED OR DEAD THERE — do NOT treat as features

This matters because a naive diff makes Mixtape look twice as large as it is. Verified by checking reachability from `Main` (Haxe only compiles referenced modules) and by reading the code:

- **`source/streaming/*` (Twitch IRC, YouTube, "offline", a `SelectState`).** No entry point: `Main.streamMethod` does not exist, nothing switches to these states, and `SelectState` lists a Discord option that has no implementation. Idea only.
- **`source/archipelago/*` (multiworld randomizer: `APEntryState`, `APConnectingSubState`, `GameState`, YAML import via `ap.Client`/`yaml`).** Only imported by two popup objects; `FreeplayState.archipelago` is never set. Never wired, and the libs (`ap`, `yaml`) are not in `Project.xml`.
- **`source/undertale/*` (`SOUL`, `BATTLE`, `BULLETPATTERN(X)`, `DamageCalculator`, `UnderTextParser`, `MSOUL`).** Gated behind an undeclared `UNDERTALE` define; `BATTLE.hx` even has a top-level `if (isGenocide)` outside any function. Would not compile if enabled.
- **`source/latency/LatencyState.hx`.** Imports `funkin.data.notestyle.*`, `funkin.play.notes.*`, `funkin.ui.*` — Psych 1.0 packages that do not exist in that tree. Dead paste.
- **`source/backend/PlayStateCache.hx` (7,974 lines)** — a second, package-`states` copy of `PlayState` in a `backend/` file. Never imported, so never compiled. Reference material at best.
- **`backend/modules/*`** (`SaveState` reflection serializer, `MathSolver`/`MathSolver2` toy parsers, `Container`, `Number`, `Variable`, `EventFunc`, `SyncUtils` (blocking `Http`/`Timer` "wait" helpers), `TimeFormat`, `ForceCrashPlugin`/`MemoryGCPlugin`/`EvacuateDebugPlugin`) — none referenced.
- **`backend/Threader`** + `Threader copy.hx` — macro-spawned threads with a blocking queue. Used in exactly two places (`Main.hx:91` for `init`, `:209` for `CommandPrompt`); do not extend it, the blocking `wait()` helpers in `SyncUtils` are what make it stack-overflow-prone.
- **`yutautil/*`** — `@:importFrom` macro that downloads Haxe source at build time (supply-chain hazard), `SaveSystem` (unused), `ZipAccess` (unused, but the only clean read-from-zip helper — see §27.5.2).
- **Codegen experiments, none referenced:** `states/ScrambleVars.hx`, `states/DebugMacro.hx`, `Corruptor`, `DataStorage`, `MemoryMap`, `StateMap`, `StateCollector`, `CompileTracer`, `TraceOnChange`, `VoidFall`, `ExpressionWrapper`, `GlobalVariableWrapper`, `HoldableVariable`, `NullFloat`, `Table`, `Translate`, `SwitchStateMacro`, `ImportStuff`, `ReflectCheck`, `RawPointerTypes`, `IterSingle`.
- **`states/editors/EditorLua.hx`** — a scriptable-editor Lua VM with 9 callbacks, never instantiated.
- **`backend/FNFC.hx`** — a chart-archive format stub whose loader is entirely commented out.
- **`backend/AudioThing.hx`** — a custom OpenAL playback path (effects/filters/aux) imported in `import.hx` but never used; `ALSoftConfig` (§27.5.4) is the only useful fragment.
- **`source/flixel/MotionBlur.hx` + `MotionBlurUtil.hx`** — sprite-based motion blur, never used (a *shader* motion blur also exists in `shaders/Shaders.hx:220` and is commented out in `PlayState.hx:638`).
- **`objects/AnimatedGif` (`backend/gif/`)** — full GIF decoder, zero references.
- **Joke/skip files:** `states/editors/SexEditorState.hx` (14 lines of ASCII art), `source/unused/` (`PlayStateOld`, `PlayStateNewOld`, `FunkinLuaNew`, `Hitbar`, `JudgmentManager`, `Snd`, `PlayField`), `test_*.hx` files left in `backend/` (8 of them: `test_ChanceSelector`, `test_ClientPrefs`, `test_JSONCache`, `test_MusicBeatState`, `test_TransitionState`, plus three under `backend/modules/`).
- **Preference fields with no reader.** Verified by grepping every field name outside `ClientPrefs.hx`: `noParticles`, `imagesPersist`, `beatSky`, `gotit`, `progression`, `loadCustomNoteGraphicschartEditor`, `convertEK`, `antimash`, `wife3`, `saveCache`, `cacheCharts` are all stubs — some have an options row, some are exported to scripts (`noParticles`, `antimash` in `FunkinLua.hx:203, 213`), none change behaviour. `saveCache`/`cacheCharts` are kept in §27.4 only as *features to implement properly*; the rest should simply not be copied. Lesson for this repo: "the pref exists" is not evidence a feature works — check the reader.
- **Their own regression risks if anything *is* copied:** the `PlayState` there is an 8k-line single class with duplicated logic; `CacheState.hx` contains two `class CacheState` declarations behind `#if sys`/`#else`; `Objects.playfields` coexists with `unused/PlayField.hx`; and the `FlxSprite3D` file declares `package onjects` (typo) with `import math.Vector3` (wrong package).

---

### 27.8 LICENSING / CREDITS FOR WHATEVER GETS PORTED

Apache 2.0 on both sides, so no licence conflict — but the *code* is not all Z11Coding's, and the Apache grant does not erase attribution:

- **PlayField/NoteField/ProxyField** — "credit me (Nebula) and 4mbr0s3 2 … at least credit 4mbr0s3 2 since he did the cool stuff of this system (hold note manipulation)" (`objects/playfields/PlayField.hx:53-58`). Add both to `CreditsState`.
- **AI Player / Mix-Up Mode** — `Z11Coding`. Profile names are jokes; keep the tables, rename the labels if shipped.
- **Artemis integration** (`backend/ArtemisIntegration.hx`) — by **skedgyedgy**, API 1.3, <https://github.com/skedgyedgy/Artemis.Plugins.FNF>. Not proposed above (it is a stream-overlay socket plugin with a hardcoded `modpack-mixup` path and no error handling), but if a websocket/overlay API is ever wanted, that is the upstream to read — with credit and without the hardcoded mod.
- **GPUBitmap** — "Originally written by Smokey, additional development by Rozebud".
- **GameJolt** — `tentools` (already a haxelib Phoenix does not use).
- **Cursor** — wraps `haxe.ui`'s `CursorHelper`; if the named-mode idea is taken, either add the haxelib or (better) keep it file-based with `changeCursor`.
- **Codename Engine imports** (`IterSingle`, `NullFloat`, `StateMap`, `SwitchStateMacro`, `Translate`, …) — `Codename` credits required if any of that ever lands; §12 already treats CNE as a separate review.
- **Kade/Mic'd Up/BEAT! input rules** — §27.3.4 emulates *behaviour*; check each engine's own licence/credits before copying constants, and credit the engine name in the option description.

---

### 27.9 SUGGESTED ORDER

1. **[P1] Mix-Up Mode + AI Player** (§27.3.1) — new mode, no assets, no refactors, biggest visible payoff.
2. **[P1] `data/settings.json` + `getModSetting()` + ModSettingsSubState** (§27.1.1) — closes a real Psych 1.0 mod-API hole (the commented-out button in `ModsMenuState`).
3. **[P2] Persistent asset cache + Cache Settings screen** (§27.5.1) — the low-end-device win, and it makes every later graphics option cheaper to test.
4. **[P2] Sustain rendering knobs** (§27.3.5) + **crash/tween toggles** (§27.4 misc) — small, low-risk quality/robustness wins.
5. **[P2] Chart modifiers + highscore separation** (§27.3.2) — pair with §23.1 in one pass.
6. **[P2] Missing modchart modifiers, Path family first** (§27.2) — pairs with the 3-D work in §12.5.
7. **[P2] HUD skin resolver** (§27.3.6), **GF/Showcase/Loop changers** (§27.3.3), **input presets** (§27.3.4).
8. **[P3] Script API smalls** (§27.1.4–27.1.8) and **HScript object API** (§27.1.3) once the classes above are stable.
9. **[P3] Zip mods** (§27.5.2), **CLI switches** (§27.5.3), **RTX editor** (§27.5.5).
10. Everything in §27.6/§27.7: **leave it**. Only revisit PlayField architecture (§27.3.9) as part of §25.1, and GameJolt (§27.5.6) if a hosted leaderboard/trophy service is actually wanted.

---

## 28. CHEESE ENGINE (`whenkenas/Cheese-Engine`) PARITY — DIFFERENCES NOT YET IMPLEMENTED

**Source:** [whenkenas/Cheese-Engine](https://github.com/whenkenas/Cheese-Engine) at `368242a` ("xddmain adsasdasdaskdpoasd", 2026-07-19), `gitVersion.txt` = `1.61`. A Psych Engine fork by **Chris** (whenkenas) whose stated goal is "an engine with V Slice + Codename + Psych Engine features, and trying to fix bugs!" — it is *not* an upstream Psych fork, it is a third-party fork layered on top of Psych Engine (upstream credit: ShadowMario, Riveren, plus bbpanzu / crowplexus / KadeDev / SqirraRNG / MAJigsaw77 / superpowers04 / CheemsAndFriends and others).

**License:** Apache 2.0 — **identical to Phoenix's**, so ports are license-compatible. Per the rule at the top of this file, anything ported from here must ship **enabled by default with a toggle**, and must carry **explicit credit to `whenkenas` / Cheese Engine** (and to the upstream Psych authors where the code is really theirs).

**Method:** full clone + read of `source/` (7,929 lines in `backend/`, 7,973 in `psychlua/`, 7,420-line `ChartingState.hx`, 3,345-line `StageEditorState.hx`, 3,242 in `backend/ui/`), diffed against this tree. The Lua/HScript API surface was extracted mechanically from both engines (`Lua_helper.add_callback` vs `Convert.addCallback` / `registerFunction` / `python.set`) and compared as sets: **Cheese registers 300 script callbacks, Phoenix 380, and 77 exist only in Cheese** — every one re-verified against this tree to rule out a renamed equivalent before it was listed here.

**Section numbering:** this was drafted as §27 while main already carried a §27 (the Mixtape Engine review, `383c761c`); it is merged as **§28**. Overlap with §27 is cross-referenced rather than repeated: the per-mod `settings.json` + `getModSetting()` contract is **§27.1.1's** item, and §28 only records Cheese as a second reference for it.

**Scope filter applied (per request):** engine/mod-specific **content** is excluded — Cheese's week-specific work (the per-week "Hey!" animations, Dad Battle spotlight, Philly Glow, Kill Henchmen, hair physics, Christmas-tree bopping, Thorns HUD hiding, the spooky background girls), its character/song art, and its "at least one change to every week" pitch. Those are not engine features. What remains below is engine-level: **modding APIs, scriptable state control, editor tooling, options/preferences, UI systems, and platform features.** Cheese's `defaultEvents` list is treated the same way — the *specific* events (`Dadbattle Spotlight`, `Philly Glow`, `Kill Henchmen`, `BG Freaks Expression`, `Trigger BG Ghouls`) are week content and are **not** ported; only the *generic* engine events are (§28.3).

### 28.1 SCRIPTING API GAPS — the biggest win

**~70 Cheese-only script callbacks (77 by raw set difference), verified absent from Phoenix.** Most are small and mechanical; the whole set is a few days of work and closes a real "my mod can't do X" gap. All must be registered in **all three languages** (Lua / Python / HScript) via the existing `psychlua/callbacks/*` split, since Phoenix's whole identity is cross-language parity.

The count is a *raw* set difference (Cheese 300 callbacks vs Phoenix 380, mechanically extracted from both trees), so it **over-states** the true gap by the handful of names Phoenix already provides under a different name. Those renames were checked by hand and are called out where they matter: `openCustomSubstate` / `closeCustomSubstate` / `insertToCustomSubstate` exist in Phoenix as `switchCustomState` / `openCustomSubstate` / `closeCustomSubstate` / `insertToCustomSubstate` / `openModSubState` / `customStateExists` (`psychlua/CustomSubstate.hx`, all three languages — see §28.2), `removeFromGroup` exists but `addToGroup` does not, and the achievement callbacks (`unlockAchievement`, `getAchievementScore`, `setAchievementScore`, `addAchievementScore`, `isAchievementUnlocked`, `achievementExists`) all exist in Phoenix via `backend/Achievements.hx:277-329` under `Convert.addCallback` / `python.set` — the raw diff missed them because Phoenix registers them outside `psychlua/`.

- **[P1] Camera read/write API.** `getCameraZoom`, `setCameraZoom`, `getCameraScroll(X/Y)`, `setCameraScroll(X/Y)`, `getCameraScrollRawX/Y`, `getCameraFollowX/Y`, `setCameraFollowPoint`, `addCameraFollowPoint`, `addCameraScroll`. Phoenix can tween cameras but a script cannot *read* the live zoom/scroll/follow point, nor set a follow point directly. This is the single most-requested capability in the group. Note Phoenix already has camera *shader* setters (`setCameraShaderFloat` etc. exist in both) — the gap is the camera transform itself, not the shaders.
- **[P1] State navigation API.** `switchState`, `switchStateDirect`, `openSubState`, `closeSubState`, `resetState`. Phoenix **already has** the script-state half of this — `psychlua/CustomSubstate.hx` registers `switchCustomState`, `openCustomSubstate`, `closeCustomSubstate`, `insertToCustomSubstate`, `openModSubState` and `customStateExists` for Lua, Python and HScript (see §28.2 for what is still missing there). What is genuinely absent is the **engine-screen** navigation: a script cannot `switchState("FreeplayState")`, `openSubState("GameOverSubstate")` or `closeSubState()` — there is no callback that takes a state *name* and drives `FlxG.switchState` / `FlxG.state.openSubState` / `FlxG.state.closeSubState`. `resetState` (a full `FlxG.resetState()`) is also missing. Cheese's `switchState` / `openSubState` / `closeSubState` are exactly this, and they are what a "mod replaces the Freeplay screen" workflow needs. Note the security angle: these must go through the existing `backend/ScriptSecurity` policy, because switching to an arbitrary state is a much bigger capability than a property setter.
- **[P1] Group & instance manipulation API.** `addToGroup`, `addInstance`, `createInstance`, `callMethod`, `callMethodFromClass`, `instanceArg`, `addBehindBar`. Phoenix has `removeFromGroup` (so the remove half exists) but **not** `addToGroup` — an odd asymmetry: a script can take an object out of a group but cannot put one in, so a mod cannot place its own object into the HUD, a strumline or a stage group. `addInstance` / `createInstance` / `callMethod` / `callMethodFromClass` / `instanceArg` are a general reflection surface; Phoenix deliberately has a narrow, safe scripting surface, so if this is added it must go through `backend/ScriptSecurityScanner` / `backend/ModSecurity` so a mod cannot call arbitrary engine methods. **Do not** add these as unguarded reflection. `addBehindBar` adds an object to the **loading screen's** behind-bar layer, which is the missing hook for custom loading art.
- **[P2] Global variable & save access.** `getVar`, `setVar`, `getSave`, `setSave`, `flushSave`. Phoenix's `PlayState.variables` map is reachable only from HScript; a mod in Lua/Python cannot read/write a shared global or poke the save blob directly. `getSave`/`setSave`/`flushSave` are thin wrappers over `FlxG.save` and are safe to add behind the existing `SaveDataCallbacks` policy.
- **[P2] Instance-returning helpers.** `instanceArg`, `addInstance`, `createInstance`, `callMethod`, `callMethodFromClass` — a general reflection surface (`callMethod` invokes a method on a named object). Phoenix deliberately has a narrow, safe scripting surface; if this is added, it must go through the existing `ScriptSecurityScanner` / `ModSecurity` policy in `backend/` so a mod cannot call arbitrary engine methods. **Do not** add these as unguarded reflection.
- **[P2] FlxAnimate symbol API.** `makeFlxAnimateSprite`, `loadAnimateAtlas`, `addAnimationBySymbol`, `addAnimationBySymbolIndices`. Phoenix has `Paths.loadAnimateAtlas` and the `flxanimate` haxelib, but **no script callback for symbol-based animation** — a mod cannot add a symbol animation to a character atlas at runtime. `addAnimationBySymbolIndices` additionally accepts a comma-string of indices.
- **[P2] Colour & math helpers.** `getColorFromName`, `getColorFromString`, `getColorFromHex` (Phoenix has `getColorFromHex` only), `lerp`, `flxLerp`, `flxRandomInt`, `flxRandomFloat`, `flxRandomBool`. The `flx*` aliases are the Flixel-flavoured names; Phoenix uses unprefixed `getRandomInt` etc. Provide **both** spellings so ports of Cheese mods work unmodified.
- **[P2] Sound pitch & music state.** `getSoundPitch`, `setSoundPitch`, `isMusicPlaying`, `getCurrentSong`, `songExists`. Phoenix can play/pause/fade sounds but cannot **pitch-shift** a playing sound from a script — a notable gap for a rhythm game (sound-test pitch, "tape" effects, speed-run audio).
- **[P2] Score & highscore read API.** `getHighscore`, `getHighscoreMisses`, `getHighscoreRating`, `updateScoreText`. Phoenix's `backend/Highscore.hx` stores these but exposes no script callback; a "stats overlay" mod cannot read them.
- **[P2] Song/difficulty metadata read API.** `getDifficulties`, `getDifficultyName`, `getSongDifficulties`, `getSongsFromWeek`, `getDifficulties`. A mod cannot enumerate what the base game ships — needed for "random song from all difficulties" mods and for building custom freeplay screens.
- **[P2] Locale/translation script API.** `getTranslationPhrase`, `setTranslationPhrase`, `getFileTranslation`, `setFileTranslation`. Phoenix has **no translation system at all** — there is no `backend/Language.hx`, no phrase table and no `.lang` support; the only trace is `ClientPrefs.locale` (a locale *string* pref, `backend/ClientPrefs.hx:63`), with no engine behind it. This is therefore not "add a script callback to an existing translator" but the **tail end** of the localisation work §12.4 lists as a **[P3]** ("Localization / translations — no language key system or locale files"). Cheese's `backend/Language.hx` (127 lines) + its `.lang` file convention (§28.5) is a small, self-contained shape to adopt; add the script callbacks **after** the translator exists, not before.
- **[P3] Mod preference read API.** `getModSetting` — lets a mod read a value from the mod-settings menu so its own options screen and its gameplay code agree. Pairs with the mod-settings screen in §28.5. **Already covered by §27.1.1** (Mixtape's per-mod `settings.json` contract) — this is a cross-reference, not new work; implement it once, there.
- **[P3] Text box sizing API.** `setTextAutoSize`, `setTextHeight`. `setTextHeight` sets `FlxText.fieldHeight` directly; Phoenix's `TextCallbacks` has `setTextSize`/`setTextWidth` but not the height field.
- **[P3] Hold-cover property API.** `getHoldCoverProperty`, `setHoldCoverProperty`, `updateHoldCoverHitbox`. Lets a mod restyle the hold cover (the cap sprite on sustains) at runtime. Phoenix ships hold covers but does not let scripts mutate them.
- **[P3] Asset-loading progress API.** `getLoaded`, `getLoadMax` — exposes the loading-screen counters so a loading-bar mod can render its own progress instead of the engine's.
- **[P3] Score text refresh.** `updateScoreText` — forces the HUD score label to re-render after a script changed the score directly.
- **[P3] Build-target introspection.** `getBuildTarget` — a script can tell whether it is running on desktop/Android/web. Useful for platform-conditional mods (e.g. skip touch-only UI on desktop).
- **[P3] Script-host plumbing.** `setOnHScript`, `setOnLuas`, `setOnScripts`, `callOnHScript` — invoke a named function across every loaded script of a given language. Phoenix loads many scripts at once but has no "broadcast to all my scripts" primitive, which is how a mod does "pause everything" or "apply a theme".

### 28.2 SCRIPTED STATES — Cheese's headline feature, and where Phoenix actually stands

**Cheese's implementation.** Cheese ships `backend/HScriptStateLoader.hx` (`HScriptState`) and `psychlua/LuaStateLoader.hx` (`LuaState`, `LuaStateLoader`, `LuaStateScript`, `LuaStateCustomSubstate`), wired through `backend/StateManager.switchState()`: a mod can drop `data/states/<Name>.hx` **or `data/states/<Name>.lua`** into its folder and the engine will **run that file as a whole screen** (its own `create` / `update` / `stepHit` / `onCloseSubState` hooks, its own camera, its own substate stack) instead of the compiled class. Cheese resolves scripts in this priority: mod-compiled Haxe state → mod HScript state → mod Lua state → engine HScript state → engine Lua state → compiled class → `TitleState` fallback. The README advertises this as "**States in HSCRIPT and LUA**" and points at a `readme.txt` in the mod folder.

**Where Phoenix actually stands (verified, and further along than the headline suggests).** Phoenix already has the *whole* scripting surface Cheese has here, in **all three languages**: `psychlua/CustomSubstate.hx` registers `switchCustomState`, `openCustomSubstate`, `closeCustomSubstate`, `insertToCustomSubstate`, `openModSubState` and `customStateExists` for **Lua, Python and HScript** alike, and `psychlua/StateScripts.hx` backs them with `states/ModState.hx` and `states/substates/ModSubState.hx` — a blank `MusicBeatState` / `MusicBeatSubstate` whose behaviour comes entirely from `data/states/<name>.hx`. `MusicBeatState.loadStateScripts()` / `MusicBeatSubstate.loadStateScripts()` (`backend/MusicBeatState.hx:252-262`, `backend/MusicBeatSubstate.hx:25-35`) load and dispatch the scripts for **every** engine screen, so a mod can already hook any state.

So the remaining gaps are narrow and specific:

- **[P1] Lua/Python state files — the real gap.** `StateScripts.SCRIPT_EXTENSIONS` is `['hx', 'hscript', 'hxs']` (`psychlua/StateScripts.hx:20`) and `StateScripts.load()` is wrapped in `#if HSCRIPT_ALLOWED` (`:151`). So a state can be written in **HScript only**; a **`.lua` or `.py` state file is silently ignored**. Cheese's headline feature is specifically the *Lua* half (`psychlua/LuaStateLoader.hx`, 2,915 lines) and Phoenix has no equivalent. This is the single biggest item in this section: add `.lua` / `.py` to the extensions and give `StateScripts` a per-language loader, so `data/states/MyMenu.lua` becomes a real screen. Phoenix's `psychlua/LuaFunction.hx` / `PythonScript.hx` already have the runtime pieces; the missing part is the **state-level** wiring (the `LuaState` / `LuaStateScript` equivalent of `states/ModState.hx`).
- **[P1] The script screen must be able to *be* an engine screen.** Phoenix's `ModState` **replaces** a screen wholesale (it is a blank state that runs the script's hooks), which is the right model — but there is no way for a script to **replace `MainMenuState` itself**. Cheese can: `StateManager.switchState("MainMenuState")` finds the mod's HScript/Lua file and runs *that* instead of the compiled class. Phoenix's `StateScripts` are loaded as *hooks on top of* whichever state is running (`MusicBeatState.loadStateScripts()` is called by the real `MainMenuState`), so a mod can hook the main menu but not **replace** it. §0's "expose almost ALL game screens through the Modding API" needs the replace case, not just the hook case. Design note: a *replace* must not silently break the game's own `MainMenuState` internals (the Phoenix main menu has engine behaviour a mod must be able to call into) — a hybrid "script state that can call the original" is the safe shape.
- **[P2] Script screen resolution order across mod folders.** Phoenix's `StateScripts.collectFiles()` (`:76-100`) already searches `assets/preload/data/states/` → **every global mod** → `mods/data/states/` → the active mod's `data/states/`, across all three extensions, and `load()` runs *every* file it finds. Cheese instead picks **one** script by priority. Phoenix's "run all of them" is arguably better for stacking mods, but it means a mod cannot *replace* another mod's state — the two models need to be reconciled deliberately, not by accident.
- **[P2] Compiled Haxe state inside a mod.** Cheese's `StateManager.getStateClass()` first tries `states.mods.<sanitizedModName>.<StateName>` — a **compiled Haxe class shipped inside a mod** — then the engine's `states.<StateName>`, then `options.<StateName>`. Phoenix resolves compiled mod states differently; check `source/headers/States.hx` before porting so the two do not conflict. The *sanitised-name* rule (spaces, `.`, `!`, `-`, `'`, `&` → `_`) is worth copying verbatim — it is what makes a mod folder name usable as a Haxe package segment.
- **[P3] Script-side "return state" plumbing.** Cheese stores a `returnState` so a script screen can hand control back where it came from; Phoenix's `StateScripts.switchState(name, data)` passes an opaque `data` blob instead, which covers the common case but not "remember and go back".
- **[P3] Scripted state *transitions*.** Cheese's `backend/CustomFadeTransition.hx` is a **gradient wipe** transition (a `FlxGradient` sliding over a black bar, with a `finishCallback`) that a script can open and chain. Phoenix's transitions are the Flixel defaults plus `backend/FlxTransWindow.hx`; there is no script-callable custom transition. §12.1 already lists "scripted transitions" as a missing script scope — Cheese's is a concrete, small implementation to draw from.

### 28.3 CHART EVENTS — the generic verbs Cheese has that Phoenix lacks

**Both engines already have chart-embedded events.** This is not a "build it from scratch" item. Phoenix stores them in `songJson.events` (`data/Song.hx:17`, `:52`, with a legacy migration from negative-lane notes at `:78-104`), loads them into `PlayState.eventNotes:Array<EventNote>` (`play/PlayState.hx:238`, via `play/helpers/PlayStateChartLoader.hx:425`), sorts them by time (`PlayStateChartLoader.hx:376`) and dispatches them in `play/PlayState.hx:2732-2741` via `triggerEventNote(event, value1, value2, strumTime)` — the **same `[time, [[name, value1, value2]]]` shape** Cheese uses. The dispatcher lives in `play/helpers/PlayStateEvents.hx` (496 lines).

**Measured delta.** Phoenix implements **26** event names; Cheese implements **28**. The set difference (`phx` vs `chz`, both extracted from source) is:

- **In Cheese but not Phoenix — 15 names.** `Target Camera`, `Target Follow Pos`, `Flash Camera`, `Play Sound`, `Video Player`, the four skin swaps (`Change Note Skin`, `Change NoteStrum Skin`, `Change Hold Cover Skin`, `Change Note Splash Skin`), and the three `(STEPS)` variants (`(STEPS) Set Cam Zoom`, `(STEPS) Target Camera`, `(STEPS) Target Follow Pos`). One more name in the raw diff, `Set Cam Zoom`, is **already covered** — Phoenix handles both spellings in one `case` (`PlayStateEvents.hx:273`: `case 'Set Camera Zoom', 'Set Cam Zoom'`).
- **In Phoenix but not Cheese — 16 names.** `Camera Bopping`, `Camera Twist`, `Change Note Multiplier`, `Change Song Name`, `Credits Popup`, `Enable Bot Energy`, `Disable Bot Energy`, `Set Bot Energy Speeds`, `Enable Camera Bop`, `Disable Camera Bop`, `Fake Song Length`, `Popup`, `Popup (No Pause)`, `Rainbow Eyesore`, `Tween Camera Zoom`, `Windows Notification`.

So **Phoenix is already ahead on the event set** (26 vs 28, and ahead on the ones that are not in Cheese at all). The gap is not "more events" — it is **the specific verbs below, plus the authoring side**.

- **[P1] `Target Camera` and `Target Follow Pos` — camera *locking*.** Phoenix has `Camera Follow Pos` (`PlayStateEvents.hx:335`) and `Set/Add Camera Zoom` (`:273`, `:294`), but **no event that moves the camera to a target**. Cheese's `Target Camera` takes a target (a character, a strumline index, or an absolute `X, Y`) **optionally offset** (`BF, 300`), plus a tween spec (`easeName, duration`) and the rule that it **overrides `mustHitSection` until the tween completes**; `Target Follow Pos` **locks** the camera follow point to a target or position and **stays locked until cleared with an empty value**. This is the "lock the camera onto the singer for a verse" authoring feature, and the lock/unlock semantics are the interesting part: without a lock, every section change snaps the camera back.
- **[P2] `Flash Camera`.** A full-screen colour flash as a chart event: duration + a **named or hex colour** (`white`, `black`, `red`, `green`, `blue`, `yellow`, `cyan`, `magenta`, `purple`, `orange`, `pink`, `lime`, `gray`, `brown`). Phoenix has camera flashes at runtime (`backend/CameraFlash.hx`, and `cameraFlash` is exposed to scripts) but **not as a chart event**, so a chart cannot script its own flash timing.
- **[P2] `Play Sound` as a chart event.** Name + volume (0–1). Phoenix's `play/helpers/PlayStatePlayback.hx:422` already iterates `state.eventNotes`, so the dispatch point exists — the handler does not.
- **[P2] The four skin-swap events.** `Change Note Skin`, `Change NoteStrum Skin`, `Change Hold Cover Skin`, `Change Note Splash Skin` — each takes a skin name/path and a target of **BF / opponent / both**. These are the ones most mods want *without writing a line of code*: today Phoenix can swap the note skin only through the Options pref (`ClientPrefs.noteSkin`), not per-section from the chart. Note the interaction with §28.1's missing hold-cover property API — the hold-cover swap needs `get/setHoldCoverProperty` from the same change.
- **[P2] `Video Player` as a chart event.** Plays a video on a named camera (`game` / `hud` / `other`) and layer, with four flags: can-skip, mid-song, loop, play-on-load. Phoenix has `objects/VideoSprite.hx` and the hxvlc video support, and `backend/` video plumbing, so the runtime exists; the *chart-event* trigger does not.
- **[P3] The `(STEPS)` camera variants.** `Set Cam Zoom`, `Target Camera` and `Target Follow Pos` each have a second form whose tween duration is expressed in **steps** instead of seconds, so a camera move lands on the beat grid. This is a genuinely better authoring model than seconds and is cheap to add once the base camera events exist (a step count × the section's beat length = the duration).
- **[P3] Cheese's camera-lock semantics as a spec.** Worth copying verbatim when implementing `Target Camera` / `Target Follow Pos`: the camera **stays locked** until the event is cleared with an empty value or a `Target Camera` event overrides it, and the override wins only until its tween completes. Phoenix's camera is otherwise driven by `mustHitSection` every section, so the lock needs an explicit override flag on the camera owner — that is the actual implementation work, not the event handler.

**Authoring side — Phoenix is already ahead.** Phoenix's chart editor has a full **Events tab** (`editors/ChartingState.hx:518`, UI built by `editors/charting/ChartingUISections.hx:1259 addEventsUI`), and it is *more* capable than Cheese's in one specific way:

- Phoenix's Events tab discovers **custom event scripts** from a `custom_events/` folder — scanned across the base `mods/custom_events/`, the active mod's `mods/<mod>/custom_events/` and **every global mod's** `custom_events/` (`ChartingUISections.hx:1268-1294`), each `.txt` file becoming an event whose **file content is the event description** (`state.eventStuff.push([fileToCheck, File.getContent(path)])`, shown in `state.descText`). Cheese hard-codes its event list in `ChartingState.defaultEvents` with the descriptions inline. **Phoenix's mechanism is the better one** — a mod can ship a new event without touching the engine — and it should be the model for anything added here.
- Phoenix has an **event dropdown** (`eventDropDown:CustomFlxUIDropDownMenu`, `editors/ChartingState.hx:934`), **value 1 / value 2 input fields** wired into the event data (`ChartingState.hx:1181-1190`: `curSelectedNote[1][curEventSelected][1] = value1InputText.text`), **multi-event selection within one event note** (`curEventSelected`, `ChartingEvents.changeEventSelected`), event notes in the grid (`ChartingUIGrid.hx:231-236` reads `eventName` / `eventVal1` / `eventVal2`), and the `EventNote` type itself (`objects/Note.hx:14`, with the fields at `:108-111`).
- Phoenix's `EventNote` and the runtime `songJson.events` shape already match Cheese's, so the *event data model* is done.

So the authoring gaps are narrow, and they are about **ergonomics and the missing verbs**, not about building the UI:

- **[P2] Event column toggle and event locking in the grid.** Cheese's `SHOW_EVENT_COLUMN` (a static toggle, `states/editors/ChartingState.hx:111`) and `lockedEvents` let the author collapse the event column out of the grid and lock it while placing notes. Phoenix's editor shows events in the grid (`editors/charting/ChartingUIGrid.hx:231-236`) but has no equivalent hide/lock switch — add it as a toggle in the new View tab.
- **[P2] Per-event special-case input widgets.** Cheese changes the input widgets per event (a FlxEase-name dropdown for the tween events, a boolean selector, a colour-name field for `Flash Camera`, a video-options field for `Video Player`). Phoenix has a generic "value 1 / value 2" text pair. A generic pair is the right minimum; per-event widgets become worth it only once the tween/camera/flash events in the list above exist.
- **[P3] Codename-event import compatibility.** `backend/CodenameEventCompat.hx` converts Codename's `{time, name, params}` event array into the engine's `[time, [name, ...params]]` shape, sorting by time and grouping same-time events. Phoenix has no such importer, so CNE charts with events cannot be loaded at all. This is an **importer**, not a runtime feature — it belongs with §12.2's "CNE song folder layout" work. Phoenix's `data/Song.hx:78-104` already has a legacy event migration, so the target shape exists.
- **[P3] Codename character import compatibility.** `backend/CodenameCharacterCompat.hx` reads CNE's XML character format (including the `icon` attribute) into the engine's character shape. Same story: importer, belongs with §12.2.

### 28.4 EDITORS & TOOLING

- **[P1] Chart-editor toys / character stage-posers.** Cheese's `ChartingState` has a `toyGroup` of `Toy` objects (GF, BF, and a pixel-BF toy) that can be dragged around the editor to **pose the stage characters while charting**, and the pose is **replayed live in the chart preview** (`gfToy.performPose(animName, sustainLength, noteColor)`) — the editor's live preview shows GF and BF actually hitting the pose the author just dragged them into. This is a genuinely good authoring tool: it removes the "change the stage JSON, reload, guess" loop. Phoenix has `editors/EditorPlayState.hx` and `ChartingUIWaveform` but no interactive stage poser. Port as a **toy/poser layer** in the editor grid, on by default, with a toggle in the editor's View menu.
- **[P1] Discover note types from `custom_notetypes/` instead of a hardcoded list.** This is a smaller and sharper version of what Cheese does, and it is a real gap:
  - Phoenix's editor note-type dropdown is populated from a **hardcoded static array**, `editors/ChartingState.hx:71-81` (`noteTypeList` = `''`, `Alt Animation`, `Hey!`, `Hurt Note`, `GF Sing`, `No Animation`, `Cross Fade`, `GF Cross Fade`) — the comment even says *"Used for backwards compatibility with 0.1 - 0.3.2 charts, though, you should add your hardcoded custom note types here too"*. The dropdown is then built from it (`ChartingUISections.hx:994-998`).
  - But Phoenix already ships **11 real custom note types as Lua scripts** in `example_mods/custom_notetypes/` (`Bad Poison`, `Bomb Note`, `Boo Note`, `Bullet Bill`, `Bullet`, `Coin Note`, `Invisible Note`, `Jumpscare Note`, `Poison Note`, `Ring Note`, `Water Note`), and `backend/NoteTypesConfig.hx` already knows how to parse and apply a note-type property file (`loadNoteTypeData` `:17`, `applyNoteTypeData` `:61`).
  - The gap: the **editor cannot assign any of them**. The runtime can apply a note type, but the author cannot pick one from the dropdown, because the dropdown only knows the 8 hardcoded names. So the feature is half-built and effectively unusable from the editor.
  - Cheese does the scan: `states/editors/ChartingState.hx:5083` loads `custom_notetypes/` from the mod folders (`loadFileList('custom_notetypes/', exts)`) and merges those with its built-in defaults, and `backend/NoteTypesConfig.hx` parses `custom_notetypes/<name>.txt` into `property.path = value` assignments applied to a `Note` by reflection (including array indexing — `extraData.foo = 1` — and dotted paths, with `:` **and** `=` separators, and typed values: string / bool / null / int / float, via `_interpretValue`).
  - So: make the editor dropdown **discover** `custom_notetypes/` across the base mods folder, the active mod and every global mod (the same folder list the Events tab already uses for `custom_events/`, `ChartingUISections.hx:1268-1274`), merge with `noteTypeList` for backwards compatibility, and make sure `backend/NoteTypesConfig` is pointed at the same discovery list. This makes 11 shipped note types usable, and makes third-party ones usable for the first time.
- **[P2] Fine strum-time editing is already there — but it is a text field, not a nudge.** Phoenix's Note tab has `strumTimeInputText` (`editors/ChartingState.hx:914`, built at `ChartingUISections.hx:987`), a free-text **millisecond** timestamp for the selected note or event, with a tooltip saying exactly that (`ChartingUISections.hx:989`). So the "millisecond precision" authoring Cheese advertises is **already implemented** in Phoenix, and in a more flexible form (free text) than Cheese's stepper. Cheese's `strumTimeStepper` (`states/editors/ChartingState.hx:4570`) is the *nudge-by-step* variant. The gap is therefore only the **stepper** form — a +/- nudge that moves the selected note by a fixed step (e.g. 1 ms / 5 ms / 1 beat) without retyping the number — which is a small ergonomic addition on top of the existing field, and a better fit for a touch screen than typing milliseconds.
- **[P2] Decimal BPM is already supported — no action.** `data/Song.hx:18` and `:53` declare `var bpm:Float` / `public var bpm:Float`, and the editor's BPM steppers are float-valued (`ChartingUISections.hx:462` `CustomFlxUINumericStepper(..., 1, Conductor.bpm, 0, 999999, 1)`). Cheese's "BPM can now have decimal values" is already true here. Listed only so the audit record shows it was checked and deliberately dropped.

- **[P2] Chart editor "View" menu.** Cheese's editor has a `PsychUIBox` with `['File', 'Edit', 'View', 'Chart']` tabs; the **View** tab holds the toys toggle and other display toggles. Phoenix's editor has a different tab layout (`Song`, `Section`, `Note`, `Events`, `Charting`, `Data`) and no View tab, so the display-only toggles (toys, show note-type labels, event column, event lock) have no home. The **View** tab is the natural container for the two new toggles this section proposes — the toy/poser layer (§28.4 toys) and the event column show/lock — so add the tab once and hang both off it.
- **[P2] Event-column toggle + event locking in the grid.** `SHOW_EVENT_COLUMN` and `lockedEvents` let the author collapse the event column out of the grid and lock it while placing notes.
- **[P2] Editor picker with icons.** Cheese's `states/editors/EditorPickerSubstate.hx` is a **graphical editor chooser** (a list of editors, each with an icon) instead of a text menu; it explicitly credits Codename's team for the idea. Phoenix's `editors/MasterEditorMenu.hx` is a plain text list. Port the icon-bearing picker (the icons are Cheese's/Codename's art — redraw or use Phoenix's own, do not copy the PNGs without checking their licence).
- **[P3] Stage editor that exports Lua.** Cheese's `StageEditorState` (3,345 lines) can **export the stage it is editing as a Lua script** (`generateLuaScript()` emits `makeLuaSprite`, `setBlendMode`, `setScrollFactor`, `scaleObject`, `setProperty` calls into `function onCreate()`), and can load a stage back from an existing Lua file (`loadLuaStageIfExists`). It also exposes a "Name (for Lua/HScript)" field, i.e. the editor output is *addressable by name* from scripts. Phoenix has **no stage editor at all** (already noted in §12.3) — but the **Lua export** and the **named-stage addressability** are separable, cheap, and valuable, and can be added on top of whatever stage editor gets built. The README also says Haxe and JSON export are planned there, which is exactly the direction §12.2 wants.
- **[P3] Note-splash editor and hold-cover editor.** Cheese has `NoteSplashEditorState` and `HoldCoverEditorState`; Phoenix has `editors/NoteSplashDebugState.hx` (a debug view, not an editor). The hold-cover editor in particular pairs with the §28.1 hold-cover property API.

### 28.5 OPTIONS, PREFERENCES & UI

- **[P1] Mod settings screen driven by the mod.** Cheese's `options/ModSettingsSubState.hx` reads a mod's own option list and renders it as a real options menu, storing each value in a per-mod map (`FlxG.save.data.modSettings[folder]`), with full **keybind** support inside it (a mod can ship a KEYBIND option and have the engine's key rebinder handle it).
  > **Duplicate of §27.1.1 (Mixtape) — do not implement twice.** §27.1.1 already specifies this exact feature from the Psych 1.0 / Mixtape side: the same commented-out button in `ModsMenuState`, the same missing `options/ModSettingsSubState.hx`, the same `FlxG.save.data.modSettings[folder]` save map, the same `getModSetting()` callback, and the same "keybind support" requirement. Cheese's implementation is a **second independent reference** for the same spec and is worth reading alongside §27.1.1's Mixtape one, but the work item itself is §27.1.1's. This entry is kept only as the cross-reference. Note also §21's "Per-mod settings profiles" ([TODO.md](TODO.md)), which is a *different* feature (per-mod engine preferences, not mod-defined options) and must not be conflated with either.
  **Phoenix has the plumbing but the feature is switched off.** `states/ModsMenuState.hx:308-325` contains the settings button and the `openSubState(new ModSettingsSubState(curMod.settings, curMod.folder, curMod.name))` call **entirely inside a `/* ... */` block labelled `// not yet`**, and the import at `states/ModsMenuState.hx:19` is likewise commented out (`// import options.ModSettingsSubState;`). The `ModSettingsSubState` class **does not exist** in the tree. Separately, `ModsMenuState.hx:934-950` has the loader for `mods/<folder>/data/settings.json` also commented out — but `ModItem.settings:Array<Dynamic>` (`:925`) and `ModItem.pack` (`:927`) are still declared, and `ModItem.new` still calls `Mods.getPack(folder)`, so the data side is half-there.
  So the work is: (a) write `states/substates/ModSettingsSubState.hx` (Cheese's is a fair reference — it also renders the option's own `description` string, which is what makes a mod's settings screen readable); (b) uncomment/replace the `data/settings.json` loader in `ModItem.new`; (c) uncomment the button and the import, keeping the "not yet" placement — the button should only be enabled when the selected mod actually has settings, as the commented code already does; (d) add the per-mod save map (`FlxG.save.data.modSettings[folder]`) — note Phoenix's save is one monolithic blob (§13), so this needs the namespace discipline §13 asks for.
  This is the natural home for the `getModSetting` script callback in §28.1, and it is the mechanism that makes the "every ported feature must have a toggle" rule in this file enforceable **by the mod author** — a mod can expose its own toggles instead of shipping a wiki page.
- **[P2] Per-mod window colour & theme override.** Cheese reads `pack.json`'s `windowColor` (string or array) and applies it to the native window (`Main.hx:574-597`), with `ClientPrefs.allowModWindowColor` gating it, plus `windowTheme` (`PC Theme` / other) and `uiTheme`. Phoenix already has the **primitives** — `backend/WindowColorMode.hx` exposes `setWindowBorderColor`, `setWindowTitleColor`, `setDarkMode`/`setLightMode` — but nothing ever calls them from a mod: `backend/Mods.getPack()` parses `pack.json` via TJSON and returns the raw object, and no code path reads a `windowColor` key out of it. So the work is small: read `windowColor` from the active mod's pack, feed it to the existing `WindowColorMode` calls, and re-apply on mod switch. Worth upgrading §12.6's "Mod-supplied window title/icon" **[P3]** to a **P1** with the colour included.
- **[P2] Mod-supplied window icon and EXE name.** Cheese's `backend/ModSelectorSubstate.hx:316-363` sets the native window icon from the active mod's `pack.png` (falling back to `icon.png`), and the README advertises "Custom EXE Icon & Name — Edit with pack.png and pack.json". Phoenix's icon is a compile-time asset set once in `Main.hx:261` (`Lib.current.stage.window.setIcon(Image.fromFile(iconPath))`) and never changes with the active mod. Extends §12.6's "mod-supplied window title/icon" item with the actual mechanism — the `setIcon` call already exists, it just needs to be re-run with the mod's `pack.png` when the mod changes.
- **[P2] Detailed ranking HUD overlay.** Cheese's `ClientPrefs.data.detailedRanking` adds a live HUD text block in `PlayState` (`Note Hits / Sicks / Goods / Bads / Shits`) with a `vcr.ttf` format, toggleable in Options → Visuals. It is a **five-line diagnostics overlay**, not a new scoring system — the README's "Detailed RANKING" is marketing for exactly this.
  Phoenix has every counter it would display — `play/PlayState.hx:315-317` (`sicks` / `goods` / `bads`), `:471` (`songHits`) and `play/helpers/PlayStateRating.hx` (`perfects` / `poorRatings`) — but **no overlay**: there is no `detailedRanking` symbol anywhere in the tree. So this is a cheap, self-contained HUD addition over existing counters, and it is a good companion to Phoenix's existing `debug/` overlays. It should be a pref (`ClientPrefs.detailedRanking`, default **off**) with an Options → Visuals toggle, and it must respect the existing `hideHud` pref the way Cheese's does (`PlayState.hx:721` in Cheese gates the text on `!hideHud && detailedRanking`).
- **[P2] In-game TAB mod switcher with per-mod modes.** Cheese opens `backend/ModSelectorSubstate.hx` from `MainMenuState` on **TAB**, and the selector offers **four modes** beyond "one mod at a time": each installed mod, plus **`MODS + FNF SONGS`**, **`ALL MODS`**, and **`DISABLE MODS`** — i.e. mods can be *layered* over the base game rather than replacing it, and the base game can be kept alongside them. The substate also renders a per-mod icon.
  Phoenix §12.3 lists "In-game TAB mod switcher" as a **[P3]** and §12.6 lists the **addon system with load priority** as a **[P1]** — Cheese's mod-mode selector is a concrete, cheap UI for a first slice of that: the "MODS + FNF SONGS" / "ALL MODS" / "DISABLE MODS" modes are exactly the "mods layered over base game" case, and Phoenix already has `pack.runsGlobally` (global mods) so the machinery is partly there. Note the priority inversion: §12.6 wants the *addon priority system*, Cheese offers the *mode picker* — do the picker first, the priority rules after.
  Implementation notes for this tree: Phoenix currently **blocks TAB globally** (`states/InitState.hx:32` — `FlxG.keys.preventDefaultKeys = [TAB]`), and TAB is already bound in `states/AchievementsMenuState.hx:321` and `states/StatsState.hx:198`, so the new binding must be scoped to the Main Menu and must not steal TAB from those screens. The switcher also needs to be reachable on **touch** platforms, where TAB does not exist — Phoenix's `mobile/` input layer has no TAB equivalent, so the mod switcher needs a touch-reachable entry point as well (the Mods menu button in the main menu is the obvious candidate).
- **[P3] Mirror Chart gameplay changer.** Cheese's `options/GameplayChangersSubstate.hx` has an **`Opponent Mode`** (`opponentmode`) and a **`Mirror Chart`** (`mirrorchart`) toggle — the latter mirrors the player's chart onto the opponent's strumline. Phoenix's `states/helpers/GameplayChangersHelpers.hx` has 24 options and includes `Play as Opponent` (`opponentplay`) and `Play Both Sides` (`bothsides`), but there is **no mirror-chart option** anywhere in the tree (verified: no `mirrorchart` / `opponentmode` symbol exists). Mirroring is not the same as "play as opponent" — the first changes *which notes* the opponent gets, the second changes *which side you control* — so this is a genuine, small, standalone gameplay changer to add next to the existing ones.
- **[P3] UI theme system.** Cheese's `ClientPrefs.data.uiTheme` ('Default' / 'Cheese') is threaded through the whole UI layer (`backend/ui/AnimScrollList.hx`, `backend/ui/PsychUIBox.hx` both branch on `isCheese`). The **theme-switch plumbing** is the portable part: a single `uiTheme` pref read by every UI widget, so a theme can be added without touching each screen. Phoenix has `objects/ui/CustomFlxUI.hx` but no such global theme switch. Port the *mechanism* (a `UiTheme` backend that widgets query), not Cheese's "Cheese" theme art.
- **[P3] Developer-mode shortcut to the editors.** Cheese has `options/DeveloperSettingsSubState.hx` with a `developerMode` flag that enables developer shortcuts (e.g. press 7 in `PlayState` to open the Editor Picker). Phoenix has `options/SuperSecretDebugMenu.hx` and `states/DiagnosticsState.hx`, and its `editors/MasterEditorMenu.hx` is already the editor picker — but there is **no `developerMode` pref** anywhere in the tree (verified) and no in-game shortcut that jumps from `PlayState` into the editor menu. The portable piece is the **shortcut**, gated behind a pref so it cannot fire during normal play.
- **[P3] Note-colour screen — already ported, no action.** Cheese's `options/NotesColorSubState.hx` (716 lines) is a full note-colour editor: colour wheel, colour gradient, colour palette, hex entry, clipboard copy/paste and a live four-lane preview in both normal and pixel modes. Phoenix's `options/NotesSubState.hx` already has **all of it** — `colorWheel` (`:45`, loaded at `:175`), `colorGradient` + `colorGradientSelector` (`:161-166`), `colorPalette` (`:44`), `hexTypeLine`/`hexTypeNum` (`:35-36`), `copyButton`/`pasteButton` (`:39-40`, wired at `:153-159`), `onPixel` (`:32`) and `lime.system.Clipboard` (`:12`). This one is **done**; it is listed here only so the audit record shows it was checked and deliberately dropped, not overlooked.
- **[P3] Language sub-state with a `.lang` discovery flow.** Cheese's `options/LanguageSubState.hx` scans **mod folders** for `*.lang` files (`Mods.directoriesWithFile(Paths.getSharedPath(), 'data/')`), reads each file's first line as the human-readable language name, and builds a language list dynamically. Phoenix's §12.4 lists "Localization / translations" as a **[P3]** open item with no key system; Cheese's **`.lang` file + first-line display name** convention is a cheap, adoptable format — the *whole* localisation feature can be scoped as: (a) a `.lang` file format (first line = display name, then `key = value` pairs), (b) a scanner over the base mods folder + the active mod + every global mod, (c) a `getTranslationPhrase` / `setTranslationPhrase` script API (§28.1), and (d) a language picker sub-state. Cheese's `backend/Language.hx` (127 lines) is a small, self-contained reference for all four parts.

### 28.6 PLATFORM & SYSTEM-LEVEL FEATURES

- **[P2] Sticker transition system.** Cheese's `substates/StickerSubState.hx` implements a **sticker wipe** between states: stickers are chosen per mod from `sounds/stickersounds/keys/*.ogg` (each sticker has its own key sound), a `StickerTransitionSprite` slides in, plays its sound, and hands off to the target state. There are three sticker **modes** (`StickerSubState.stickerMode`, e.g. `'random'`), and the whole thing is scriptable: `switchStateWithStickers(state, mode)` / `switchStateWithStickersByName(name, mode)` exist in **both** Cheese's Lua and HScript APIs. Phoenix has **zero** sticker references in the whole tree. This is a high-impact, self-contained, very "FNF modding"-shaped feature: it is the transition most FNF mods actually want, it is data-driven (drop PNGs + OGGs in the mod), and it is fully script-driven.
- **[P2] Mod-overridable custom sound tray art.** Phoenix §12 claims "custom volume tray" as already present, and it *is* present: `objects/CustomSoundTray.hx` is a hand-drawn `FlxSoundTray` replacement with 11 bar images, a volume box, and the three distinct `Volup` / `Voldown` / `VolMAX` sounds — that part is already a port of Cheese's `backend/FunkinSoundTray.hx`, and it even has the `VolMAX` touch at `:145`.
  The gap is narrower and worth stating precisely: the **sounds** are mod-resolvable (`CustomSoundTray.hx:62-64` uses `Paths.resolveSoundAsset("sounds/soundtray/Volup", null, 'shared')`, so a mod can override them), but the **graphics are hardcoded to engine assets** — `Assets.getBitmapData('assets/soundtray/images/volumebox.png')` (`:25`), `.../bars_10.png` (`:34`) and `.../bars_$i.png` (`:47`) all read the engine's own `assets/` path directly and never consult `Paths.image(...)` / `Paths.mods(...)`. Cheese resolves the *same* images through a per-mod lookup (`backend/FunkinSoundTray.hx:_getImageData` checks the active mod, then every global mod, then the engine) — so a mod in Cheese can restyle the volume popup, and in Phoenix it cannot.
  Fix: route the tray graphics through `Paths.image('soundtray/volumebox', 'shared')` (or equivalent mod-aware resolver) so the existing `Paths.modFolders` override chain applies, and add the tray image/sound folder to the mod-override list. Small, but it is the difference between "the engine drew a tray" and "the mod drew a tray".
- **[P3] Window theme presets.** Cheese sets the window theme (`ClientPrefs.data.windowTheme`, e.g. `'PC Theme'`) from `Main.hx:530-597` via the `hxWindowColorMode` haxelib, on top of the per-mod `windowColor` (§28.5). Phoenix's `backend/WindowColorMode.hx` already provides `setDarkMode()` / `setLightMode()` and the border/title colour setters, but there is **no user-facing theme preset** — nothing in `options/` exposes "PC theme / dark / light" as a choice, and nothing reads a `windowTheme` pref. So the portable piece is a small **Options → Visuals** entry that offers the presets the backend already supports. Low priority, and it pairs with the per-mod colour above.
- **[P3] Advanced FPS counter with memory graphs.** Cheese's `debug/FPSCounter.hx` + `debug/StatsGraph.hx` draw a **live graph** of FPS, **GC memory** and **task memory**, with `gcMem`/`gcMemPeak`/`taskMem`/`taskMemPeak` read from the native layer, in three modes (simple / advanced / "isSimplier"), and it is drawn on a raw `openfl` `Sprite` (not a Flixel object) so it costs nothing.
  Phoenix §12.4 already lists "Advanced FPS counter — 1% lows, selectable/copyable diagnostics, and a true uncapped mode" as a **[P3]**. What Phoenix has today is a **text** FPS readout with a memory *number* (`debug/FPSCounter.hx:160-161` prints `MemoryUtil.formatMemory(memory)` and optionally the peak), plus a separate `debug/RamGraph.hx` (a compact gameplay-only RAM history panel, sampled twice a second). So the gap Cheese fills is narrower than "add an FPS counter": it is (a) a **graph of the FPS curve** rather than a single number, (b) a **separate GC-memory graph** vs Phoenix's task/RAM graph, and (c) the **peak-memory** readouts side by side with current. Phoenix's `debug/mem/GetTotalMemory` and `backend/MemoryLedger.hx` / `backend/MemoryProfiles.hx` are already positioned to feed all three. The raw-`openfl`-`Sprite` trick (draw the counter outside the Flixel display list) is also worth copying — it costs nothing per frame, which matters for the low-end target.
- **[P3] `ALSoftConfig` / ALSA config passthrough.** Cheese ships an `alsoft.txt` that Lime copies to `plugins/alsoft.ini` (Windows) or `plugins/alsoft.conf` (Linux) at build time, to configure the OpenAL audio backend. A small but real low-end-Android/Linux audio-compat lever that costs one file in the build config.
- **[P3] Audio-device-switch fix.** Cheese has `backend/AudioSwitchFix.hx` (56 lines) — a focused fix for audio output device switching, credited upstream to `yoshicrafter29`. Phoenix §12.4 already lists "Desktop audio-device hotplug" as a **[P3]** open item, so this is a concrete, small, upstream-attributed implementation to draw from rather than a from-scratch design. The `AudioSwitchFix` name and the actual fix need to be read before porting; do not assume the Phoenix hotplug item is already satisfied.
- **[P3] Multithreaded asset cache.** Cheese gates a **multithreaded** asset cache behind the `MULTITHREADED_LOADING` define (`backend/ThreadedCache.hx`, 83 lines). Phoenix has **no** `ThreadedCache` and no `MULTITHREADED` define anywhere in the tree — its loading is `backend/PhoenixPreloader.hx` plus `backend/Paths.clearUnusedMemory` / `backend/LowMemory`. Threading the cache is a real low-end-device win (§18), but it must be done carefully: Cheese's `ThreadedCache` was written against Psych's loader, and Phoenix's low-memory path (`docs/LOW_MEMORY_MODE.md`) is stricter than Psych's, so a naive port can regress the `NO_PRELOAD_ALL` / memory-profile behaviour.
- **[P3] Cursor loader.** `backend/CursorLoader.hx` (59 lines) — resolves and loads the software/system cursor, and Cheese exposes it in Options. Phoenix has **no** cursor-loader module at all (its cursor handling is scattered across `backend/MusicBeatState.hx`, `backend/MetaHorror.hx` and `backend/AndroidTVPolicy.hx`), so this is a genuine gap rather than a duplicate — but it is a small, low-impact one.

### 28.7 EXPLICITLY NOT PORTED (week / mod / song content)

Per the request, the following Cheese features are **content**, not engine features, and are deliberately **out of scope**:

- **All the per-week changes** in the Cheese README ("at least one change to every week"): the Dad Battle spotlight, the "Hey!" animations for BF/GF/Skid & Pump, Thunder's light flash and camera zoom, the Monster transition, Philly Nice's BF "Hey!", Blammed's colour flash, Week 4's hair physics, the Henchmen dying, the Christmas-tree/BF/GF bopping, GF's slower head bob on Winter Horrorland, the Thorns HUD hiding, and the spooky background girls on Thorns. These are **week/song-specific content**, hard-coded in Cheese's stage files, and Phoenix's §25.1-style approach (data-driven) is the right way to get equivalent behaviour if it is ever wanted — as **generic chart events** (§28.3), not as engine features.
- **The specific `defaultEvents` entries that only exist to serve that content**: `Dadbattle Spotlight`, `Philly Glow` ("No, i won't add it to other weeks."), `Kill Henchmen` ("For Mom's songs, don't use this please, i love them :("), `BG Freaks Expression`, `Trigger BG Ghouls`, `Set GF Speed` (a Fresh-specific hack), `Alt Idle Animation` in its Week-4 form, and `Hey!`. The **generic verbs** these ride on (`Play Animation`, `Screen Shake`, `Flash Camera`, `Set Property`, `Target Camera`) *are* in scope in §28.3.
- **Cheese's art and audio**: the `CheeseEngineLogo`, the `MainMenu/ModSelector/*` background/box/rayo atlases, the sticker PNG/OGG packs, the custom sound-tray bars, the note-splash/note-skin/hold-cover additions, the V Slice FPS counter skin, the editor-picker icons, and the `docs/img/*.png` screenshots. Phoenix must ship its own art for any of these it adopts.
- **Cheese's branding**: the `CHEESE_ENGINE` define, the `cheeseEngineVersion` string, the `versionShit` watermark, and the `TitleState`/`MainMenuState` splash art. Phoenix keeps its own identity.
- **Cheese's engine fork as a base.** Cheese is itself a fork of Psych Engine with 89 commits; porting *ideas* is fine, but merging its `source/` wholesale would import Psych's older architecture over Phoenix's refactored `play/`, `editors/charting/`, `psychlua/callbacks/` and `backend/` layout. Every item above is scoped as a **targeted port into Phoenix's structure**.

### 28.8 SUGGESTED ORDER

1. **§28.1 script API gaps** — highest payoff per unit of work, ~70 callbacks (the raw 77-entry delta minus the handful Phoenix already has under another name), mechanical, and immediately makes existing mods portable. Do it in one pass across all three languages, with the `ScriptSecurityScanner` policy applied to the reflection-flavoured ones (`callMethod`, `createInstance`, `getPropertyFromClass`) and to the state-navigation ones (`switchState`, `openSubState`).
2. **§28.2 Lua/Python scripted states** — closes the "modders want their own screen" gap and is the prerequisite for §0's "expose all screens to the modding API".
3. **§28.4 note-type discovery in the editor** — the cheapest item in the whole section and it unlocks a half-built feature: Phoenix already ships 11 custom note types and a runtime that can apply them, but the editor's dropdown only knows 8 hardcoded names, so **none of the 11 can be assigned from the editor**. One folder scan + one dropdown fix.
4. **§28.3 the missing chart-event verbs** — `Target Camera` / `Target Follow Pos` (camera locking), `Flash Camera`, `Play Sound`, `Video Player` and the four skin-swap events. The event *system* and its *editor UI* already exist in Phoenix, so these are handler-level additions. Unblocks §12.2's chart-format work and the CNE event importer.
5. **§28.5 TAB mod-mode switcher** — the first slice of §12.6's addon-priority work. (The mod-settings half of §28.5 is **§27.1.1's** item and is listed in §27.9's order, not here.)
6. **§28.6 stickers + mod-overridable sound tray** — high-impact, self-contained, data-driven.
7. **§28.4 editor toys / poser** — the one authoring tool here that is a genuine green-field build; do it after the items above, since it is the largest and the least blocked.
8. **§28.7** — nothing to do; this section exists so the exclusions are on record and are not re-litigated.

---

*Section 28 added by an audit of `whenkenas/Cheese-Engine` @ `368242a` (v1.61) against this tree. The API sets of both engines were extracted mechanically (300 Cheese vs 380 Phoenix callbacks) so the 77-entry delta is measured rather than guessed; every callback listed as "missing" was then re-verified absent here **by name**, and the handful that turned out to exist under a different name are called out inline rather than silently counted as gaps. Several candidate items were **dropped during verification** because Phoenix already has them — the note-colour screen (§28.5), decimal BPM and millisecond strum-time editing (§28.4), the chart-event editor UI and the `custom_events/` discovery mechanism (§28.3), and the custom sound tray (§28.6, narrowed to the mod-override gap) — and those are recorded inline as "already done" so the audit trail shows they were checked, not overlooked. Nothing in this section was built or run.*
