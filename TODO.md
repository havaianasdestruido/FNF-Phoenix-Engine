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
- **[P3] Device benchmark mode.** A fixed, mod-free stage/chart that runs ~60 s and reports average, 1% low and worst frame plus device info — reachable without F3/F6, which do not exist on Android. Reuses `FrameProfiler.exportLog()`; this is a *test run*, not the live counter in §12.4.

## 19. DIAGNOSTICS, SUPPORT & SAFE MODE

`CrashHandler` catches errors, writes text logs and shows a summarized-reason screen, but support requests have to ask for versions by hand.

- **[P2] "Copy diagnostics" action.** One button producing a redacted, pasteable block: engine version (`VERSION` in `project.hxp`), commit (`HaxeCommit`), target, `SystemInfo` CPU/RAM, GPU/driver (#96), save path, mod list + order, non-default prefs, last N log lines. Offline only — the recent update flow is deliberately repo-based, so no auto-upload. `backend.DiagnosticsReport` (built for `phoenix://diagnostics`) already assembles that text, so what is left is the button, plus running the result through `backend.LogUtils.redact` so a copied block is no more identifying than a saved log — the deep-linked page only *warns* about usernames in paths.
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

## 27. AUMSUM FUNKIN PARITY — DIFFERENCES NOT YET IMPLEMENTED

Source: [AumSum-Funkin-Team/AumSum-Funkin](https://github.com/AumSum-Funkin-Team/AumSum-Funkin), **Apache-2.0** (license-compatible, so everything here is portable), last commit `32b5132` (2022-10-11). It is a fork of **Psych Engine 0.6.2** (`pack.json` version `0.6.2`, `Project.xml` `0.2.8`) — 114 `.hx` under `source/` against Psych's 99, `+6876` diff lines over 58 files, 14 files that do not exist upstream at all. So rather than diffing it against Phoenix (two unrelated trees by now), it was diffed against `ShadowMario/FNF-PsychEngine` tag `0.6.2` first, and only what survived that filter was checked against this tree. Read in full on 2026-11-21; nothing was built or run.

Scope, per the brief: **engine capabilities only** — scripting APIs, options, editor/tooling and engine-level content. AumSum's own songs, weeks, characters, icons, fonts, menu art and its `Progression.hx`/story flags are its mod content and are deliberately absent from this list. Its `Modding.md` is a stale 12-line polymod stub and its `README`/`CHANGELOG` are stock Psych text, so the code is the only evidence used.

What AumSum is not: it has **no** engine-level feature set Phoenix lacks wholesale. Almost every Psych-0.6.2 → 0.7/0.6.3 feature Phoenix already has (note types with `extraData`, `strumsBlocked`, `Note.extraData`, `camOther`, shader API + `.frag/.vert` loading, `Change Scroll Speed`/`Change Song Name`, pause `End Song`/`Skip Time`/`Leave Charting Mode`, scroll-wheel navigation, custom `FlxUIInputText`, dialogue typewriter, `addAnimationByPrefix`, `directoryFileList`, chart-editor playback rate, chart-editor undo, ~360 Lua functions). Everything left below is a narrow, verified gap.

### 27.1. Event payloads & the chart editor

- **[P1] Optional `value3` on chart events.** AumSum's event pipeline carries a third value end to end: `EventNote.value3` (`source/Note.hx:18`), a 5th slot in the chart JSON (`source/PlayState.hx:2523`, `:2625`), `triggerEventNote(name, v1, v2, ?value3)` (`:3492`), the Lua hook `onEvent(name, v1, v2, value3, strumTime)`, `triggerEvent` growing an `arg3` (`FunkinLua.hx:1539`), and the chart editor's `needsValue3` list + `value3InputText` box shown only for the selected event (`editors/ChartingState.hx:95-97`, `:1107-1112`). Phoenix is stuck at two: `EventNote` is `{strumTime, event, value1, value2}` (`objects/Note.hx:14-19`), `PlayStateEvents.triggerEventNote` takes a `strumTime:Float` as its 4th parameter (`play/helpers/PlayStateEvents.hx:84`) — so the slot is occupied and cannot grow — and the loader reads only `subEvent[0..2]` (`play/helpers/PlayStateChartLoader.hx:414-424`). This is not a cosmetic extra: AumSum uses it to move `Change Scroll Speed`'s easing into the chart (`PlayState.hx:3849`) so a speed change can ease instead of snapping, which is exactly what our `Change Scroll Speed` cannot express (`PlayStateEvents.hx:429-443` handles `val2` as a duration, never an ease). Port as: `value3:Null<String>` on `EventNote`, 5th JSON slot accepted, `?value3` threaded through `triggerEventNote`, `onEvent` and Lua `triggerEvent` (keep the 4-arg order so existing scripts do not break — append, do not insert), a "Value 3" box in the chart editor that appears only for events that declare it, and `setTheNeedOfValue3` (AumSum `FunkinLua.hx:461`) renamed to something documented so a custom-event `.lua` can request the field. Then read `value3` as a `LuaUtils.getFlxEaseByString` name in `Change Scroll Speed` when present. Default: events without a third value behave exactly as today. Effort: M. Credit: AumSum Funkin.

- **[P2] Lua scripting inside the chart editor (per-notetype editor scripts).** `editors/EditorLua.hx` (268 lines, AumSum-only) is a small standalone Lua state bound to the editor with nine functions: `getProperty`, `setProperty`, `getPropertyFromGroup`, `setPropertyFromGroup`, `removeFromGroup`, `getColorFromHex`, `setGraphicSize`, `scaleObject`, `updateHitbox` (`EditorLua.hx:60-`). Its only consumer is the **test-play** state: for every note type in the section it starts `custom_notetypes/<type>.lua`, waits 0.1 s and kills it (`editors/EditorPlayState.hx:117-127`) — i.e. a custom note type can finally *be drawn* in test play exactly as it draws in the real song, which is the one thing a charter cannot check today. Phoenix has no editor-side script host at all: `ChartingState` loads nothing at all (`editors/ChartingState.hx:816`, `:1452` switch straight to `new editors.EditorPlayState(...)`, and no `LUA_ALLOWED`/`HSCRIPT_ALLOWED` import exists in either editor file), and `EditorPlayState`/`EditorPlayStateHelpers` contain no Lua, Python or HScript call whatsoever. Port the *capability*, not the hack: give `EditorPlayState` the real script hosts (`FunkinLua`/`PythonScript`/`HScript` on the current mod's `custom_notetypes/<type>` and `custom_events/<name>`, same paths the song uses at `play/PlayState.hx:1761-1783`) plus the `noteTypeMap`/`eventPushedMap` bookkeeping AumSum collects before dropping it (`EditorPlayState.hx:131-133`). Sandbox them like any other script (§6) rather than trusting the file. Option: "Editor scripts in test play" (default on, off switch for charts whose scripts assume a full stage). Effort: M–L. Credit: AumSum Funkin (`EditorLua`).

- **Difficulty dropdown in the chart editor — cross-referenced, no separate entry.** AumSum replaces the free-text field with a `FlxUIDropDownMenuCustom` over the known difficulties, labelled "Difficulty:" (`editors/ChartingState.hx:604-617`, `:657-664`). Phoenix still has a `UI_songDiff` input box reading arbitrary text (`editors/charting/ChartingUISections.hx:268`), which silently creates a new difficulty folder on a typo. Tracked generically in **§12.3 "In-engine song/difficulty creation"** — this is the concrete form a port should take, so build it there rather than opening a second entry.

- **Custom chart/meta property UI in the editor — cross-referenced.** AumSum has no equivalent either, so there is nothing to port; the work stays in **§12.3 "Custom property editing in Charter"**.

- **"Section" instead of "Beat" on the section counter — not a gap.** A one-line wording fix AumSum made to its own test-play HUD (`f63cecc`, "Thing to show sections said beats"): `sectionTxt.text = 'Beat: ' + curSection` → `'Section: ' + curSection`. Phoenix already reads `'Section: ' + curSection` (`editors/EditorPlayState.hx:296`), so **this is not a gap** — recorded only so the next pass does not re-open it.

### 27.2. Scripting APIs

- **[P2] `getColorFromRgb(r, g, b)` and `getDominantColor(tag)` in Lua.** Two colour helpers missing from the ~360 we expose: `FlxColor.fromRGB` for the first and `CoolUtil.dominantColor(sprite)` for the second (`source/backend/CoolUtil.hx:468` already implements it — only the script binding is absent, AumSum `FunkinLua.hx:1399`, `:1404`). The dominant-colour one is the interesting half: it lets a script tint HUD text, pops or sustains to the character's average colour instead of a hard-coded constant, and it is the exact primitive a "match the art" custom-event wants. Register both in Lua **and** Python/HScript so the three hosts stay symmetrical (Phoenix keeps them in lockstep; `pystdlib/PyScoreLib.hx:81` has the `getColorFromHex` precedent). Effort: S. Credit: AumSum Funkin.

- **[P2] Window geometry from scripts: `moveWindow(x, y)` and a script-callable resize.** AumSum's `ModchartFunctions.hx` is three functions, but two of them are the only way a mod can touch the OS window's position or the game's internal resolution from script: `moveWindow(x, y)` → `Lib.application.window.move(x, y)`, and `camZoom(w, h)` → `FlxG.resizeGame(w, h)`. Phoenix has the machinery and does not expose it: `backend/ModchartFunctions.hx` does not exist, `FlxG.resizeGame` is only called from the Flixel patch and from Options → Graphics (`options/GraphicsSettingsSubState.hx:211`, where the comment is explicit that `resizeGame` alone does not resize cameras — so a script version has to re-lay-out cameras the way that option does), and `psychlua/callbacks/WindowCallbacks.hx` is ten functions about transparency/alpha/colour-key/click-through and nothing about position or size. Port as `moveWindow(x, y)` (desktop only, refuse on mobile/web with a message, clamp to the available displays) and `setGameResolution(w, h)`/`resetGameResolution()` built on the *camera-aware* path from Graphics, not the bare `resizeGame`. Both default off-limits until a script calls them (no default behaviour change). Effort: M. Credit: AumSum Funkin.

- **[P2] OS titlebar theme from scripts (dark / light / opacity alias).** AumSum's `CppAPI.hx` exposes `darkMode()`, `lightMode()`, `setWindowColorMode(Bool)`, `setWindowOppacity(Float)` to Lua so a script can flip the native chrome to match a dark song or an in-game cutscene. Phoenix *has* the implementation and keeps it to itself: `system/Window.hx` (`darkMode`, `matchSystemTheme`, `redrawFrame`) is called exactly once, from `Main.hx:268`, and `backend/WindowColorMode.hx` still holds the legacy `setWindowColorMode`/`setDarkMode`/`setWindowBorderColor`/`setWindowTitleColor` entry points — none of which any script can reach (`WindowCallbacks.hx` has ten functions, none of them this). Wire the existing calls into `WindowCallbacks` (plus Python/HScript): `setWindowColorMode(dark)`, `setWindowOpacity(0..1)` as the correctly spelled alias of the existing `setWindowAlpha`, and `getWindowColorMode()`. Windows-only per `#if windows`, with the existing "not available on this platform" trace on the others. Note §1's `[P3]` about deleting the `WindowColorMode` *flash stubs* — that is about dead AIR paths, not about these real native calls, so the two do not conflict. Effort: S. Credit: AumSum Funkin.

- **[P3] `getGlobals(luaFile)` — investigate, do not port.** AumSum's copy of this function is **commented out** (`FunkinLua.hx:1317`), as are `getPropertyAdvanced`/`setPropertyAdvanced`, so there is no working implementation upstream to port and nothing to gain. Phoenix already has the safer pair (`getGlobalFromScript`/`setGlobalFromScript`, `psychlua/callbacks/ScriptCallbacks.hx:107-180`, mirrored in `PyScriptLib.hx:115`). No action beyond this line.

### 27.3. First boot on weak hardware

- **[P2] Hardware gate with "play anyway" on first launch (desktop).** `SpecsDetector.hx` (AumSum-only, 64 lines) is a pre-`InitState` state that checks `Capabilities.supports64BitProcesses` and physical RAM ≥ 4096 MB, then either continues silently or shows a native `MessageBox` — "Your PC does not meet the requirements… Do you want to play anyway?" — where "No" is `Sys.exit(0)`; the verdict is cached in `FlxG.save.data.cachestart` so the box appears once. Phoenix has every input this needs already (`debug/system/SystemInfo.hx:46` `logicalCPUCount()`, `:50` `totalPhysicalMemory()`, plus `backend/Native.hx:113` `getSystemInfo()` for CPU/GPU strings) and nothing that uses them at startup: there is no pre-`InitState` state and no notification of any kind. Do **not** copy AumSum's behaviour — a modal that blocks the game and can call `Sys.exit` is hostile on a machine the player cannot upgrade, and Phoenix's whole identity is running on those machines. Instead make it the trigger for the existing plan: on first run, if the device is below a threshold, apply the low-end preset automatically and *say so in-game* with a dismissible notice, then let the player opt into the benchmark (§18 `[P3]`). That is **§18 `[P1]` "First-run performance profile"** — this entry exists only to name AumSum's `SpecsDetector` as a second source for it and to record the native-message-box approach as rejected. Toggle: the notice, and the whole auto-detect, in Options → Optimization.

### 27.4. Menu & title content hooks

- **[P3] `title.json` GF scale and antialiasing keys.** AumSum's `TitleData` gained `gfscalex`, `gfscaley` and `gfantialiasing`, applied straight to the dancer (`TitleState.hx:50-52`, `:333-334`), so a mod can ship a title screen where the dancer is not the stock size and not smoothed. Phoenix's `TitleData` stops at `titlex/titley/startx/starty/gfx/gfy/backgroundSprite/bpm/endY` (`states/TitleState.hx:29-40`) and the fallback literal at `:135` matches, so a mod that reuses an AumSum-style `title.json` gets the dancer at 1× with global antialiasing. Cheap and additive: three optional fields, defaulted when absent. Effort: S. Credit: AumSum Funkin.

- **[P3] Per-JSON `noAntialiasing` for menu characters.** AumSum's `MenuCharacter` honours `noAntialiasing` from `menucharacters/<name>.json` (both `true` → off and `false` → follow the pref, `source/MenuCharacter.hx:90-93`). Phoenix hard-assigns `antialiasing = ClientPrefs.globalAntialiasing` in `changeCharacter()` (`objects/MenuCharacter.hx:36`) and its `MenuCharacterFile` typedef has no such field (`:9-16`), so a pixel-art menu character is always smoothed when global AA is on. Add the optional field with the same tri-state semantics. Effort: S. Credit: AumSum Funkin.

### 27.5. Mod folders & the mod list

- **[P3] Reserve a `haxescript/` folder (legacy alias only).** AumSum's `HAXE_EXTENSION` build autoloads global "HaxeScript" from a dedicated `haxescript/` folder (preload, `mods/haxescript/`, active mod, each global mod — `PlayState.hx:895-905`), and its own second pass looks for a file literally named `.hxs` (`:1317`) with a bare `hscript.Parser`/`interp` — no `Paths`, no callbacks, no error reporting, and the extension check can never match a real filename, so that pass is dead. Phoenix folds HScript into `scripts/` (`play/PlayState.hx:915-968` scans `scripts/`; `psychlua/HScript.hx:118` accepts `.hx` and `.hscript` only) and `ModPathPolicy.RESERVED_MOD_FOLDERS` (`backend/ModPathPolicy.hx:41-45`) contains neither `haxescript` nor `haxe`. Two real consequences: an AumSum-style mod that drops files in `mods/<mod>/haxescript/` loads nothing, and a mod *named* `haxescript` is legal here and would collide if we ever reserved the name. So: keep `scripts/` as the only autoload path (one path, one set of semantics — do not clone AumSum's duplicate), add `haxescript` and `haxe` to the reserved list so the name cannot be taken, and if compatibility ever matters, scan `haxescript/` as a silent alias after `scripts/` with the existing base-name dedupe. Do not copy the `.hxs` pass. Effort: S. Credit: AumSum Funkin (folder name only).

- **[P3] A third field in `modsList.txt`: per-mod "runs globally".** AumSum's `ModsListEntry` is `{dirName, globalEnabled, disabled}` and the file line grows to `folder|enabled|globalEnabled` (`c0cedaa`, `source/Mods.hx:100-140`), so a player can keep a mod enabled for its own content while stopping it from overriding the main-menu background — the mix of `pack.json`'s `runsGlobally` with a user override. Phoenix's parser reads `dat[0]` and `dat[1]` only (`backend/Mods.hx:212-231`) and `runsGlobally` is a `pack.json` field the *author* sets (`:60`), with no UI and no override in `ModInfoSubState` (it displays the flag at `:140`). Add the optional third field, default "inherit `pack.json`", and expose it as a second toggle next to the enable switch. Keep it optional both ways so an existing two-field file keeps working and a three-field file opened in an older build is not corrupted. Note this is a *compatibility/UX* gap, not the CNE addon priority work — that is **§12.6**. Effort: S–M. Credit: AumSum Funkin (and the Psych PR it came from).

### 27.6. Typography & timing ranges

- **[P2] Latin-1 glyphs in the `alphabet` spritesheet.** `objects/Alphabet.allLetters` already lists `á é í ó ú à è ì ò ù â ê î ô û ã ë ï õ ü ä ö å ø æ ñ ç š ž ý ÿ ß` (`objects/Alphabet.hx:414-420`), `AlphabetFontRenderer.PROBE` includes `ÄÁç`, and `AlphabetFont.supports()` accepts every code point ≥ 32 (`:246-251`) — but the shipped atlas has **zero** non-ASCII `<SubTexture>` names (`assets/preload/images/alphabet.xml`), so with the default `Alphabet` spritesheet style a Portuguese, Spanish, French or German menu string renders `?` for every accented letter, while the same string is correct on the font path. AumSum has 176 of them (inherited from Psych's `d3ea0a5` "Psych latinchar support"). Two honest routes: (a) draw and add the glyphs to the atlas, which is asset work and the reason this has not been done, or (b) make `Alphabet` fall back per character to the font renderer when the atlas has no animation for it, which is code work and fixes mod-supplied alphabets too. (b) is the better fit for a game whose UI text is player-visible and often localized — but it must respect the style the caller asked for, so prototype it on one screen first. "Phoenix is a Brazilian engine" makes this less cosmetic than it looks. Effort: M (b), L (a). Credit: Psych Engine upstream (AumSum just carries it).

- **[P3] Widen the note-offset range to −500 ms.** `NoteOffsetState` clamps `ClientPrefs.noteOffset` to `0…500` (`options/NoteOffsetState.hx:31-32`, enforced at `:326-347`), so a player whose output chain runs *late* can only push notes later; AumSum widened the minimum to `-500` (`e20b2c0`), letting an offset go negative and compensate both ways. One-line change to `delayMin` plus the bar's bounds — the `FlxBar` at `:184` already reads `delayMin`/`delayMax`, and the clamp helper at `:347` already uses both. Keep `delayMin`/`delayMax` as the single source so the bar, the stepper and the clamp cannot drift. Effort: S (XS really). Credit: AumSum Funkin.

### 27.7. Checked and deliberately not taken

- **`Progression.hx`** — `beatMainWeek`/`badEnding`/`goodEnding`/`beatHell` globals and a `weekProgress` map. Story progress for AumSum's own campaign; Phoenix's save schema (§13) is the place for any progress model, and a per-mod global of this shape would freeze a mod's story into the engine. Not a capability.
- **`HelperFunctions.hx`** — `truncateFloat`, `erf`, `getNotes`, `getHolds`, `getMapMaxScore`, `wife3`. No call sites anywhere in AumSum's tree and none of it is registered to any script host, so this is dead code, not an API. (`getTotalNotes`/`getMaxScore` do not exist in its Lua either — do not attribute them.) If a `wife3` accuracy model is ever wanted that is an accuracy/score change and belongs with the §22 accuracy presets, not here.
- **`Signal.hx`** — a 16-line `connect`/`disconnect`/`trigger` array wrapper duplicating `flixel.util.FlxSignal`, which Phoenix already uses. Nothing to gain.
- **`DumbKidLol.hx`** — an empty/placeholder class in the `default` package. No.
- **`Snd.hx` / `SndTV.hx`** — no call sites; dead experiments. Do not report these as features in any future pass.
- **`PlayerSettings.hx`** — present in Psych 0.6.2 itself (`diff` against the tag is empty), so it is not an AumSum contribution; Phoenix already has its own `backend/PlayerSettings.hx`.
- **Pause → "Configure Settings" (`7d2de92`)** — Phoenix is ahead: its pause menu already has an `Options` row (`states/substates/PauseSubState.hx:31`) and `OptionsState` returns to the song through `PauseSubState.inPause` (`options/OptionsState.hx:250-253`). AumSum's version restarts the song from scratch on the way back (`new PlayState()`), which would lose the run.
- **Chart-editor playback rate (`ee415ed`)** — already present and richer here: `playbackSpeed` 0.25–4 via `[`/`]`, `Alt` to reset, and it pitches both vocal tracks (`editors/ChartingState.hx:1850-1859`, the `sliderRate` row at `editors/charting/ChartingUISections.hx:1612-1615`).
- **Chart-editor undo** — AumSum has none; Phoenix already has undos (`editors/ChartingState.hx:88-89`). Not a gap in either direction.
- **Freeplay/Story `(N/total)` counters** — checked and absent from AumSum too: `scoreText` in `StoryMenuState` gets no index prefix (`:102`, `:254`) and neither tree has a `curSelected+1`-style counter. Do not attribute.
- **`splashSkinFramesMap`, `strumsBlocked` + `parseKeys`, `Note.extraData`, `ClientPrefs.shaders` + Lua `shadersEnabled`, `camOther`, `PlayStateShaders` + `.frag`/`.vert`, mouse-wheel menu navigation, `CustomFlxInputText`, dialogue typewriter, `addOffset`/`playAnim`/`addAnimationByPrefix`, `directoryFileList` + `SandboxPath` case folding, `MonitorRefreshRate`, `MemoryProfiles`/`LowMemory`, menu mouse navigation, FPS counter, UI scale** — all present in Phoenix already, most of them more developed than AumSum's copies; several are tracked in §12.4/§16/§18 and are not repeated here.
- **`hxvlc`, `PlatformSupport` capability tags, results screen, `ImGui` console, strumline editors** — Phoenix has these; AumSum does not.
