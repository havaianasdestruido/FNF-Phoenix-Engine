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

---

## 27. FUNKINAVI V2 SOURCE REUSE REVIEW

Source: [ThatOneSillyGuyDon/FunkinAVI-V2-Source](https://github.com/ThatOneSillyGuyDon/FunkinAVI-V2-Source) — shallow-cloned and read in full on 2026-11-21, compared against this tree at `443ae01`. Same own-audit style as §23/§24/§25/§26: only differences Phoenix does **not** already have are listed, everything else is cross-referenced or dropped. Nothing was built or run.

Two things to get out of the way before the list, because both change the plan:

- **Their `LICENSE` is a placeholder** — the file literally says `SORTING OUT LICENSE STUFF!!! BRB LOL!`. So nothing here can be pasted. Every entry below is written as *"reimplement from the described behaviour, with credit to FunkinAVI V2"*, and the author should be asked before anything ships that is more than a re-derived idea. This does not block the work; it does block copying.
- **Their repo is not ahead of us on modding API or options**, so do not go in expecting a treasure chest. Counted by grepping both trees for `registerFunction(`/`Lua_helper.add_callback(` and `new Option(`: **205** Lua functions vs our **362**, **42** `ClientPrefs` fields vs our **216**, **26** option rows in 4 categories vs our ~120 in 10 + Mobile. Their callback set is not a superset either: every AVI callback name exists here, and we have `onStart`, `onStop`, `onClose`, `onCreate`, `onDestroy`, `onPause`-adjacent hooks and the resume-countdown callbacks they lack. What they *do* have is a handful of **systems we never built** (defined in 27.1–27.3) plus a large amount of **song-specific content** (`ModchartFile`'s 17-song hardcoded modchart switch, `CreditsData`, `embeddedFiles/Modchart.hx`, their song-specific event cases) which is out of scope by the same rule as §23/§24.

Also worth recording so nobody re-audits it: several AVI systems that *look* like features are inert — `ChartingState.undo()`/`redo()` are empty stubs (we already have real undo/redo + autosave), `ModsMenuState` install/delete is entirely commented out, `SimpleQuaternion.transformVector` returns its input, `unused/ButtonRemapSubstate` is empty, `CamUtils.updateCamera` computes shake offsets and then has the assignments commented out, and `ChartingState:628` adds a `'Song Offset:'` label with **no stepper under it** (their per-song offset is a dead label — there is no `offset` field in their `Song.hx` at all, so there is nothing to port there).

### 27.1. Modchart and script tooling

This is where the real gap is. Our `source/modchart/` is renderer-free, headless-testable and has 36 registered modifiers — more than their modifier table — but it is **closed**: modifiers exist only as compiled classes.

- **[P1] Custom modifier plugin scripts (`customMods/*.hx`).** Their `modcharting/ModchartFile.hx:263` `CustomModifierScript` parses an `.hx` file with `hscript`, injects `Modifier`, `ModifierSubValue`, `BeatXModifier`, `NotePositionData`, `NoteMovement`, `PlayfieldRenderer`, `ModchartUtil`, `FlxG/FlxTween/FlxEase`, `Paths`, `Conductor` and `ClientPrefs`, and calls back into it through the modifier hooks. Files are discovered by `FileSystem.readDirectory()` on the `customMods/` folder sitting next to the chart (`ModchartFile.hx:69-80`), then started by name: `startMod(name, modClass, type, pf)` with `type` ∈ `player`/`opponent`/`lane`/`` (all) (`ModchartFuncs.hx:94-142`). Their `Modifier` base has five overridable hooks — `noteMath`, `strumMath`, `curPosMath`, `noteDistMath`, `setupSubValues` — plus per-mod `subValues` (`Modifier.hx:14-86`).

  Our equivalent is a compile-time registry: `modchart/ModifierRegistry.hx:93 register()` is `static` (not public), `create()` returns `null` for anything unknown, and `modchart/Modifier.hx` exposes only `render(pos, params)` / `visuals(data, params)` / `shouldRun(params)`. `ModchartManager` offers `addModifier(name, field)` — no way to supply an instance from outside Haxe.

  What to build (and the shape matters, because it has to stay testable): make `ModifierRegistry.register(name, cls)` **public**; add a `modchart/ModifierScript.hx` that subclasses `Modifier` and forwards `render`/`visuals` to an `hscript.Interp`, reusing the existing `psychlua/HScript` sandbox rules (`ModSecurity`, `ScriptSecurityScanner`) rather than their raw `new Interp()`; load `mods/<mod>/data/<song>/customMods/*.hx` (our chart path convention is `Paths.json(folder/song)`, so the folder resolves the same way theirs does); and expose `addModifierScript(name, source)` + `setModTargetLane`/`setModPlayfield` equivalents in Lua/Python/HScript. Keep `ModchartVec3`/`ModchartParams` renderer-free so `tests/haxe/run-modchart.sh` can assert a script modifier's output numbers. Sub-values: our lane variants are already "just longer percent names" (`PercentStore.normalize` + `Modifier.getPercentLane`), so do **not** copy `Map<String, ModifierSubValue>`; expose `getPercent('drunkX')` as the script-side spelling and document it. Credits: FunkinAVI V2 (`CustomModifierScript`, `Modifier` hook names) + `hscript` (already a dependency). Effort: **M**. Risk: an unsandboxed `.hx` plugin is arbitrary code execution — gate it behind the existing script-sandbox opt-out, not a new pref.

- **[P2] Data-driven modchart files (`modchart.json`) and a timeline editor.** Their `ModchartJson` is three arrays — `modifiers: [[name, modClass, type, pf, lane]]`, `events: [[set|ease, data, repeat]]`, `playfields: Int` — loaded from `data/<song>/modchart.json` (`ModchartFile.hx:17-23,60-107`), and `ModchartEditorState.hx` (2142 lines) edits it with modifier/playfield/lane steppers (`:1240-1350`), a playfield-count stepper (`:766`), and a `FileReference` save dialog (`:2036-2052`). Their `set(beat, "0.5,drunk,0.2,drunk2")` / `ease(beat, time, ease, "...")` bulk-string forms exist specifically so a modchart file can be a list of tuples (`ModchartFuncs.hx:222-260`).

  We have the *authoring half* already: `editors/ModchartLabState` + `modchart/lab/ModchartLabExport` writes `addModifier`/`modSet`/`modEase`/`modRepeater` **script** calls (docs: `docs/MODCHART.md` § Modchart lab), which is a better deliverable than a bespoke JSON for most authors. What is genuinely missing is the path where a mod ships a modchart **without a script**, and the inverse: our manager has no `(de)serialise` at all. Suggested scope, deliberately smaller than theirs: a `modchart/ModchartFile.hx` with their three-array schema (accept their field order/indices so an existing AVI modchart loads), `load(songFolder)` / `save(path)`, a `apply(json)` that maps entries onto `addModifier`/`setPercent`/`set`/`ease`/`repeater`, the `customMods/` discovery from 27.1, and a **second export format** in `ModchartLabExport` (they can already emit Lua/Python; add `json`) so the lab becomes the editor instead of porting a 2k-line state. Also add `removePlayfield(idx)` to `ModchartManager` — `addPlayfield()` exists (`ModchartManager.hx:18`) with no counterpart, so a script that adds fields leaks them for the whole song. Credits: FunkinAVI V2 (schema + editor idea). Cross-ref §12.5 (modchart rendering), §23.1 (modifier gaps), §21.1 (modchart lab, DONE). Effort: **M**.

- **[P2] Sustains that follow the modifier chain in 3D (`SustainStrip`).** Their sustain bodies are rebuilt per frame as a triangle strip whose vertices are run through the *same* perspective projection as the note heads (`modcharting/PlayfieldRenderer.hx:340-393`, `constructVertices(noteData, thisNotePos, nextHalfNotePos, nextNotePos, flip, reverseClip)`), so a sustain bends with `reverse`/`invert`/`confusion` instead of staying a straight sprite. `NotePositionData.noteDist` decides the next sample point, and the strip is clipped when the incoming angle is between 90° and 270°.

  Here, `play/helpers/PlayStateModchart.hx:248` iterates `[state.notes, state.sustainNotes]` but the transform only moves/rotates the sustain sprite as a rigid body — a bent or reversed modchart visibly detaches the hold body from the head. This needs `FlxStrip` (we ship none; their `FlxStrip` is a `flixel` vendor patch) or a hand-rolled draw via `FlxDrawTrianglesItem` — and we *do* already patch that (`source/source-haxelib-patches/flixel/FlxDrawTrianglesItem.hx`), so the plumbing is plausible. Do not copy their per-frame `new SustainStrip` lazy allocation blindly: cache one strip per note and reuse, and keep the vertex math in a renderer-free `modchart/SustainStripGeom.hx` so `tests/haxe/run-modchart.sh` can assert vertex positions for a reversed note. Default on (it only changes anything when a bend modifier is active), with the existing modchart toggle as the off switch. Credits: FunkinAVI V2 / Nebula_Zorua (Schmovin). Effort: **L** — this is the one item that wants §12.5's renderer work first.

- **[P2] A script host inside the chart editor.** Their `states/editors/EditorLua.hx` (249 lines) is a **separate, minimal** Lua state for the editor preview, exporting `getProperty`, `setProperty`, `getPropertyFromGroup`, `setPropertyFromGroup`, `removeFromGroup`, `getColorFromHex`, `setGraphicSize`, `scaleObject`, `updateHitbox`, and setting `inChartEditor = true` plus `curBpm`/`bpm`/`scrollSpeed`/`crochet`/`stepCrochet`/`songLength`/`songName`/`screenWidth`/`screenHeight`/`downscroll`/`middlescroll`. `EditorPlayState` then runs a notetype's script for one timer tick and kills it (`EditorPlayState.hx:126-136`).

  Ours is the opposite: `inChartEditor` is set to a hardcoded `false` in all three hosts (`psychlua/FunkinLua.hx:200`, `HScript.hx:335`, `PythonScript.hx:177`), and the editor never runs a script. That matters because notetype scripts that *only* do their work when `inChartEditor` is true (a common Psych pattern) currently render as plain notes in our editor, which makes notetype editing guesswork. Cheapest useful version: give `EditorPlayState` the same three-way host we already have for gameplay (`FunkinLua`/`PythonScript`/`HScript` with a restricted function set) and flip `inChartEditor` to `true` for those instances, so the existing `custom_notetypes/*.lua` scripts behave the same in editor and game. Their `EditorLua` is a fork of Psych's, so prefer our own hosts over porting it. Credits: FunkinAVI V2 (the `inChartEditor` split is the idea). Effort: **M**. Do **not** ship their `inChartEditor=true` for *song* scripts — that only applies to the editor's own instances.

- **[P3] `tweenModifier` / `tweenModifierSubValue` / `setModEaseFunc` naming.** Their modchart Lua has three sugar calls we do not: `tweenModifier(mod, val, time, ease)` (a `setPercent` tween by seconds, not beats), `tweenModifierSubValue(mod, sub, val, time, ease)`, and `setModEaseFunc(name, ease)` (pin the default ease a modifier uses for its own internal tweening). We have `modEase(name, beat, length, value, ease, player, field)` which covers the beat-domain case. Add the three as aliases on `psychlua/callbacks/ModchartCallbacks.hx` + `psychlua/pystdlib/PyModchartLib.hx`, mapping seconds→beats via `Conductor.crochet`, so AVI/Psych modcharts port over. Sub-value calls map to our lane-suffixed percents (27.1 above). Effort: **S**.

- **[P3] `set`/`ease` with an `argsAsString` bundle.** See 27.2's file format — the string form is only worth adding if we take the file format. Ship them together or not at all.

### 27.2. Engine, platform, audio and per-song data

Very little here: most of what their `backend/` does, we do better or differently, and their per-song data lives in hardcoded tables we must not copy. The genuine items, in rough cost order:

- **[P2] `ALSOFT_CONF` for OpenAL Soft (desktop).** `backend/ALSoftConfig.hx` is a 28-line `@:keep` class with a static `__init__()` that resolves `plugins/alsoft.ini` (Windows), `Resources/plugins/alsoft.conf` (mac) or `plugins/alsoft.conf` (Linux) next to the binary and calls `Sys.putEnv("ALSOFT_CONF", path)`. Nothing else in the repo uses it — it exists purely so a shipped ini can raise OpenAL Soft's resampler quality and mixer settings, which is the "cheap audio quality" lever on desktop. We have no equivalent (`project.hxp` has no `ALSOFT_CONF`/`alsoft` hits, and there is no plugin folder in `assets/`).

  Reimplement: the `Sys.putEnv` class is trivial (same shape, guard `#if desktop`), but the value is the **shipped ini** and the packaging — `project.hxp` has to copy `plugins/alsoft.ini` next to the binary on Windows and into `Resources/` on mac, and `BUILDING.md`/`SIZE.md` have to mention it. Pick settings conservatively (`resampler=hq`-class only) so low-end machines do not get *worse*; test on the oldest Windows box in §1's matrix. Toggle: a `ClientPrefs` bool or an `--no-alsoft` flag rather than a save-file setting, since the env var has to be set before audio init. Credits: FunkinAVI V2 (`ALSoftConfig`), OpenAL Soft upstream for the ini keys. Effort: **S** (code) + **S** (packaging).

- **[P2] Menu audio spectrum bars (`SpectrumWaveform`).** Their `gameObjects/ui/SpectrumWaveform.hx` (193 lines) is a `FlxSpriteGroup` that reads the playing `FlxSound`'s decoded buffer and draws N lerped bars (`updateSamples` pokes `@:privateAccess sound._sound.__buffer.data.buffer`; `updateWaveform` lerps each bar toward the sample and caps at `maxHeight`), with alignment enums and a `SpectrumDesign` for rounded/other shapes. Used in `FreeplayState:255`, `GeneralMenu:101` and `FreeplayCategories:75` — i.e. every menu has reactive bars.

  We have the *hardware* half and never used it in menus: `funkin.vis` is a patched haxelib (`source/source-haxelib-patches/funkin/vis/dsp/SpectralAnalyzer.hx`, `project.hxp:953`) and `stages/objects/ABotSpeaker.hx` already drives sprites from a `SpectralAnalyzer` with a `volumes[]` cache. Build a `objects/SpectrumBars.hx` on `SpectralAnalyzer` (proper FFT + log bands, no `__buffer` poking — their approach breaks the moment audio is streamed or on HTML5) and put it on Freeplay + Main Menu behind `ClientPrefs.menuSpectrum` (bool, default on) with `menuSpectrumColor` + `menuSpectrumBars` — that is the "colourful thing needs a colour option / preset" rule from the top of this file: presets (Rainbow / Note colours / Fixed) plus a custom hex. Cap the band count when `lowQuality` or `adaptivePerformance` has kicked in, and skip it entirely when menu music is off. Credits: FunkinAVI V2 (`SpectrumWaveform`, original by `mr_chaoss` per their header). Effort: **M**.

- **[P3] Per-sprite `dynamicContent` update hook.** Their `flixel/FlxSprite.hx:220,769-770` adds `public var dynamicContent:Dynamic = {}` and calls `if (dynamicContent.update != null) dynamicContent.update(elapsed);` at the top of `update()`. It is a 3-line vendor patch that lets a plain sprite carry Lua/HScript-owned per-frame logic without a group or a substate. We ship a `FlxSprite` patch dir already, so this is cheap; the caveat is that our own `PlayState` does not route per-sprite `update()` for notes (they are driven by helpers), so the hook is only useful for mod-created sprites. Add it to `source/source-haxelib-patches/flixel/FlxSprite.hx` and document it in `docs/` as a modder convenience. Effort: **S**.

- **[P3] Localised, floating video sprites.** Their Lua `startVideo(videoFile, vis, x, y, scaleX, scaleY)` (`FunkinLua.hx:2164`) plays a video into a `VideoSprite` at an arbitrary position/scale (`VideoShit.hx:49-77` shows the shape), including `destroyOnUse` and `:no-audio`/`:input-repeat=65535` options (`gameObjects/video/VideoSprite.hx:19-20`). Ours is a full-screen song cutscene only: `GameCallbacks.hx:306` registers `startVideo(videoFile)` and forwards to `PlayState.startVideo(name, library, callback, forMidSong, canSkip, loop, playOnLoad)` (`PlayState.hx:2064`), which is a cutscene, not a prop. Add `createVideoSprite(file, x, y, ?scaleX, ?scaleY, ?muted, ?loop)` returning a handle, on top of the existing `hxvlc` path, so background TVs/screens become possible. Credits: AVI, hxvlc upstream. Effort: **M**.

- **[P3] A second Discord presence button + large image from the script API.** `DiscordClient.hx:206-209` fills only `presence.buttons[0]`; they fill `[0]` and `[1]` (`discord/Discord.hx:95-108`) and their `changePresence` accepts a large image key too. Add `buttons[1]` support to `DiscordClient.changePresence` (config-driven: source repo + community link, so it is not hardcoded to AVI's URLs) and extend the Lua/Python `changePresence(details, state, smallImageKey, hasStartTimestamp, endTimestamp)` with optional `largeImageKey` + `button1Label/button1Url/button2Label/button2Url`, keeping the current signature valid. Effort: **S**.

- **[P3] Animated health icons and per-character icon behaviour.** Their `CharacterFile` carries `animatedIcon`, `intenseIcon` and `iconBops` (`gameObjects/Character.hx:19-25,187-190`) and `HealthIcon.changeIcon(char, isAnimated, isShakeable, canBop)` switches to a Sparrow atlas with `icon neutral`/`icon losing` prefix animations, shakes at 2.7/2/0.1, and optionally bops on the beat. Ours is single-atlas frames only: `objects/HealthIcon.hx:53-88` divides the PNG width by 150, plays the frames as one animation, and has no atlas, shake or bop path — their own bop scaling is even commented out on their side (`PlayState.hx:11985`), so only the *atlas + intent fields* are worth taking. Add three optional character-file fields (`animated_icon`, `intense_icon`, `icon_bops`), load an atlas when present, and keep the static path as the default. This is a **data-format** addition, so it belongs with the §12.2/§13 character-file work and needs the character editor rows too. Credits: AVI (fields) — Psych has a similar `animated` icon convention, check it first. Effort: **M**.

- **[P3] Per-song vocal suffixes (`voiceSfx1`/`voiceSfx2`).** Their `SwagSong` has `voiceSfx1`/`voiceSfx2`, defaulting to `"Player"`/`"Opponent"`, fed straight into `Paths.voices(song, diff, suffix)`; the chart editor exposes them as `Player Suffix` / `Opponent Suffix` inputs (`ChartingState.hx:395-396,596-600,625-626`) which is how a song can ship `Voices-BF-Clean-hard.ogg`.

  We have almost this and stop one step short: the suffix exists and is per-**character** (`CharacterFile.vocals_file`, `objects/Character.hx:36`, consumed at `play/helpers/PlayStateChartLoader.hx:66-69`), so two songs sharing a character cannot ship different vocals, and `data/Song.hx`'s `SwagSong` has no `voiceSfx` field (`:15-45`). Add `@:optional var voiceSfx1/voiceSfx2` to `SwagSong`, prefer song → character → `'Player'`/`'Opponent'` in the loader, and add the two text inputs to the editor's Song tab next to `specialAudioName` (`editors/charting/ChartingUISections.hx`). Read `voiceSfx`-less charts exactly as today. Effort: **S**.

- **[P2] Data-driven freeplay song cards.** Their `data/cardData/<song>.json` drives `gameObjects/ui/SongCard.hx` (475 lines): font + size + colour + scale + alpha + alignment + offset, custom art or Sparrow animation (`isAnimated`, `animName`, `animFramerate`, `isLooped`), separate player/opponent icon art with per-icon offset/scale/alpha, and card alpha/scale/offset/isScreenCenter (`backend/TypedefUtilities.hx:26-80`). Our freeplay row is a fixed `Alphabet` + icon pair (`states/FreeplayState.hx:70-89,308`) with no per-song customisation at all, and no `data/cardData/` convention.

  This is the single most useful *content-adjacent* thing in their tree for us, because a mod can make a song look distinct without shipping a whole freeplay state. Do it as data, not as their class: add `data/SongCardData.hx` (`@:optional` everything, unknown keys preserved) read from `data/cardData/<song>.json` per song folder, apply in `FreeplayState` only for the selected row, and add the fields to the **Week/Song editor** rather than a new editor. Toggle/option per the house rule: `ClientPrefs.songCards` (bool, default on) so a low-end build or a purist can keep plain rows; art/colour values are the customisation. Credits: FunkinAVI V2 (`SongCardData`), Psych for the freeplay-card precedent. Effort: **M**. Cross-ref §21.2 (freeplay filter, DONE), §12.2 (`meta.json` is the broader answer — check it does not subsume this before building both).

- **[P2] Per-song unlock conditions.** Their `backend/data/GameData.hx` has one `FlxSave("gameProgression")` with a *named* lock per song/episode (`episode1FPLock`, `huntedLock`, `mercenaryLock`, … `:70-146`), `unlockEverything()`, and a `canAddX` flag per hidden song, plus a locked freeplay menu button and a hidden song that only appears when a counter is met (`MainMenu.hx:201,216`) and the `AskQuestionToThatGuy`/random-encounter flow. All of it is hardcoded per song, which we must not copy — but the *concept* is missing here: we gate **weeks** only (`StoryMenuState.weekCompleted` + `WeekData.startUnlocked`/`weekBefore`, `FreeplayStateHelpers.weekIsLocked`), and Freeplay shows every song in an unlocked week.

  Generalise: `@:optional unlock: {week?:String, song?:String, achievement?:String, deaths?:Int}` in the song's metadata (or a `freeplayLock` field in `WeekData`), evaluated by a renderer-free `backend/SongUnlocks.hx` over the existing saves, with a `ClientPrefs.unlockAll` debug switch (already the shape of `RecoveryBoot`/`MemoryProfiles` forced-save patterns). Effort: **M**. Cross-ref §13 (save data/migration — the new keys belong there) and §12.2 (`meta.json`).

- **[P3] Per-song pause presentation.** Their pause menu shows a per-song album art, a per-song credits block (`PauseData = {settings: [infoText, offX, offY]}`, sourced from `embeddedFiles/CreditsData.hx` per song at `PauseSubState.hx:937-960`), and cycles a random pause track from their OST by index with a printed track name (`:520-548`). Ours: `ClientPrefs.pauseMusic` (`:157`) picks one track for the whole game and `PauseSubState.hx:111-137` shows song name / difficulty / blueballs only.

  Take the **data** idea, not the tables: `data/pause/<song>.json` (or fields in the song's metadata) with `info` text, `art` image, and an optional `music` override; fall back to the current layout when absent. Two new prefs so it obeys the house rule: `pauseArt` (bool, default on) and `pauseCredits` (bool, default on). Do not port `CreditsData` (content) or the per-song `colorSetup` switch (content). Effort: **S**.

### 27.3. Checked, already covered, or deliberately not taken

Nothing here needs work; recorded so the next pass does not re-audit it.

- **Song speed retiming — already done, and better.** Their `set_playbackRate` sets `FlxAnimationController.globalSpeed` and rescales `Conductor.safeZoneOffset` (`PlayState.hx:3691-3692`). Ours already does the equivalent and more: `PlayState.set_playbackRate` (`:1955-1975`) sets `FlxG.animationTimeScale`, `Conductor.safeZoneOffset = (ClientPrefs.safeFrames/60)*1000*value`, and pitches vocals + inst together; `PlayStateCamera`/`PlayStateEvents` additionally multiply `holdTimer` by `singDurMult` for pitch-shifted charts. No gap. (Note the spelling difference is the fork: `FlxG.animationTimeScale` on our pinned `flixel-JS-Engine`, `FlxAnimationController.globalSpeed` on stock Flixel — same idea, so do not add a second global-speed path.)
- **GPU texture caching.** Their `useGPUCaching` pref + `flixel/graphics/GraphicCacheSprite.hx` (unused by anything in their tree) vs ours: `ClientPrefs.cacheOnGPU` (`:275`) is already honoured in `backend/Paths.hx:1128` (premultiplied texture upload, surface released) with a row in `options/GraphicsSettingsSubState.hx:58`, a forced entry in `MemoryProfiles`, and a rating-path special case. Superset.
- **Epilepsy / shaking / arrow hue / mechanics prefs.** `epilepsy` → we have `flashing` + `flashIntensity` + `showPhotosensitivityWarning` (+`WarningSettings`, `AccessibilitySubState`); `shaking` → `reducedMotion` + `cameraFxIntensity` (`backend/CameraEffects.hx`); `arrowHSV` → we have the note colour palette / colorblind preset / luminance contrast; `mechanics` → a per-gameplay mashing switch with no equivalent, and it only gates *their* song gimmicks (content) — the generic version is §21.3's per-song gimmick toggle idea, not this.
- **`pauseCountdown`** → §21.3 **DONE** (`resumeCountdown`).
- **`FlxSoundGroup`** → we already patch `flixel/sound/FlxSound.hx` with a `group(default,set):FlxSoundGroup` field (`:163,762`) on top of stock Flixel's class. No gap.
- **`FlxText` markup (`applyMarkup` + `FlxTextFormatMarkerPair`).** They vendor-patched it into `flixel/text/FlxText.hx:281`; we ship no such patch and no call site. It is upstream Flixel API in modern versions, so check the pinned `flixel-JS-Engine` fork (`setup/unix.sh:17`) before writing anything — if absent it is a small patch and a `TextCallbacks` wall (P3), if present it is just documentation.
- **`MemoryRate.obtainMemory()`** → we have `backend/MemoryLedger` + `Gc.memInfo64` usage throughout and a RAM graph in the debug overlay. `CamUtils.updateCamera` is dead code (all the shake assignments are commented out).
- **`InputFormatter`** → we have the same class and function (`backend/InputFormatter.hx:7`, `getKeyName`) used by `ControlsSubState`.
- **`animateatlas/*` (vendored flxanimate fork + `AtlasFrameMaker`).** We take `flxanimate` as a haxelib (`project.hxp:955`) with a Psych adapter (`flxanimate/PsychFlxAnimate.hx`) and atlas support in the character editor. Their copy is a 2023 fork of the same library with `JSONData2020`/`tilecontainer`; do not vendor it.
- **`backend/nSwitch/{Snd,SndTV}.hx`** (1288 + N lines) → a `faxe`-based Switch audio backend, gated on `if='switch'` in their `Project.xml:140`. Switch is not a Phoenix target (§1 covers Windows/Linux/mac/Android/web); skip entirely.
- **`backend/embeddedFiles/*` and `ModchartFile`'s 20-song switch** → hardcoded song content (modchart JSON strings, chart/event tables, week data). Out of scope by the same rule as §23/§24.
- **`backend/song/ChartParser.hx`** → a 12-line `FlxStringUtil.imageToCSV` PNG-chart reader, called only from a commented-out line in their `PlayState.hx:4785`. Dead, and the direction is wrong (§26: charts stay JSON).
- **`gameObjects/ui/FlxTextAlphabet.hx`**, **`TypedefUtilities.hx` (`SongMetadata`, `PauseData`)** → covered by our `Alphabet`/`flixel-ui` and our data typedefs; `SongMetadata` is just a per-song freeplay record (see the song-card and unlock entries above for the parts worth having).
- **GameJolt, `MainMenu`'s book/unlock cutscene, `AskQuestionToThatGuy`, `VideoShit`, `secrets/`, `bullshit/`, `exclude/`** → content/joke states, out of scope.
- **`Options`/`ModsMenu`/`ChartingState` parity in general** → we are ahead: real undo/redo + autosave, Copy/Paste Section, a working mods list with reorder (their install/delete is commented out), a filter/search freeplay with stars, 7 pause rows vs their 4, and event coverage that is ours (their event `switch` is bigger, but the extras are all song-specific: Birthday, Bless, Cycled Sins, Delusional, Laugh Track, Lunacy, Malfunction, Mercy, Philly Glow, Dadbattle Spotlight, `Tween Camera Pos`).
- **Their Lua/Python/HScript API** → 205 vs our 362 functions, and the only AVI-side names we lack are either commented out in their own source (`getGlobals` — `FunkinLua.hx:640` is inside a `/* … */` block) or spelled differently here (`openCustomSubstate`/`closeCustomSubstate`, `runHaxeCode`, `addHaxeLibrary`, `setPropertyAdvanced` all exist on our side). Do not "port" API surface we already superset.

### 27.4. Suggested order

1. **27.1 custom modifier plugins** (P1, unblocks every AVI/Psych modchart mod) — then 27.1's `removePlayfield` + 27.1's JSON/export pair, since they share the loader.
2. **27.1 editor script host** (small, fixes notetype authoring for every existing Psych mod).
3. **27.2 `ALSOFT_CONF`** and **27.2 spectrum bars** (both small and independent).
4. **27.2 song cards** + **27.2 unlock conditions** together — same metadata file, same freeplay screen, one migration.
5. **27.1 `SustainStrip`** last: it wants §12.5's renderer, and it is the only item here with real regression risk.
6. Everything else is P3 and can ride along with the section it cross-references.
