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

Read `docs/research/psych-fork-engine-changes.md`, §24 (JS-Engine `whoisitlolxd` fork triage, 2026-11-19), §25 (Psych Engine Extra Keys + review), §26 (JS-Engine binary-chart / "GPU note backend" review, 2026-11-19) and §27 (D.C.E. / NovaFlare Engine 1.2.2 review, 2026-11-21).

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

## 27. D.C.E. / NOVAFLARE ENGINE REVIEW — WHAT IT HAS THAT PHOENIX DOESN'T (2026-11-21)

**Source:** [D-C-LushiFu/D.C.E.](https://github.com/D-C-LushiFu/D.C.E./tree/main) at `062d77f` ("Update README.md", the 1.2.2 tree). Read by cloning the repo and comparing `source/`, `source-codename/`, `source-originFunkin/`, `assets/`, `Project.xml` and `hmm.json` against this tree; nothing was built or run. Every item below was grep-checked against Phoenix `source/` — "missing" means no file, class, pref or callback with that name/behaviour exists here, "partial" names the Phoenix piece that already covers part of it.

**What D.C.E. actually is (provenance matters for credits).** Two layers, both Apache-2.0 (its `LICENSE` matches ours, so porting is license-compatible under the rule at the top of this file, *with credits*):

1. **NovaFlare Engine 1.2.2** (NF crew: beihu235, MaoPou, Chiny, TieGuo, Careful_Scarf_487, MengQi, AZjessica, Ben Eyre, Als, blockDDDdark) — a Chinese Psych 0.7.3-lineage engine. The repo's initial commit is already the whole engine; claims in its old README: Psych mods 0.7.3–1.0.4, V-Slice 0.8.4 and Codename 1.0.1 mod support, HScript-iris-improved, render-thread separation, Immix/NovaGC work.
2. **The LushiFu delta** (D.C.LushiFu, solo) — commits `fa57ac6` (1.2.1: +23/−0 new, 52 modified source files) and `e2fe78a` (1.2.2: 144 files, +32787/−4823): editor Chrome UI, full i18n + CJK fonts, immersive self-drawn window, mobile editor-key customisation over a local HTTP server, the visual keybind screen, the frosted-glass Options rewrite, the Mods-menu rewrite, the `KeyChange (MoreKey)` mid-song key-count event, the NoteSplash system redo, plus the standalone installer (`cac4455`) and two vendored-Flixel `FlxSound` null-guard fixes (`e0d80d5`, `4484863`). The current `README.md` is a one-line joke, so the code and the two long commit messages are the only reliable spec — treat any port as "reimplement from their code", not "cherry-pick" (their tree uses a completely different package layout: `games/`, `general/`, `developer/`, `scripts/`, `states/<name>State/` vs our `play/`, `backend/`, `editors/`, `psychlua/`, `states/`).

**Headline verdict.** Phoenix's *scripting surface is already bigger* (375 registered Lua functions vs their 228, plus Python via Hython, which they don't have at all) and Phoenix has *more bundled chart content* (the JS-Engine `-jshard/-expert/-insane/-noob/-erect/-nightmare` difficulty sets on almost every song; D.C.E. ships only Easy/Normal/Hard). D.C.E. wins on five axes Phoenix has nothing for: **(a) whole-engine compatibility layers** (a runnable Codename Engine and a runnable Origin/V-Slice Funkin' inside the same binary), **(b) class-based HScript modding** (`class`/`package`, scripted states/sprites, global + module scripts), **(c) a real localisation system**, **(d) replay recording/playback as a first-class feature**, and **(e) mid-song key-count changes with editor parity**. Then a long tail of options, HUD widgets, editor tooling and platform work. Biggest payoffs are bold.

### 27.1. Mod APIs — Lua

Phoenix check first, to avoid porting what we have: of their 228 Lua functions, all but the 25 below already exist here under the same name (in `psychlua/callbacks/*` via `FunkinLua.registerFunction`, vs their monolithic `scripts/lua/FunkinLua.hx` 2250 lines + `set()`). The genuinely missing ones:

- **[P2] Sound pitch get/set in Lua: `setSoundPitch(tag, pitch)` / `getSoundPitch(tag)`.** Missing here — `psychlua/callbacks/SoundCallbacks.hx` has volume/time/fade but no pitch (grep `pitch` = 0 hits). Theirs is in `scripts/lua/FunkinLua.hx`. Add to `SoundCallbacks` + the Python mirror (`psychlua/pystdlib/`), clamped to the same range `PlayState.playbackRate` uses. Effort: S.
- **[P2] Named shader-effect tween/remove in Lua: `tweenEffectFloat(effect, uniform, duration, from, to)`, `tweenEffectInt(...)`, `removeEffect(camera, effect)`.** Missing (we have `tweenShaderFloat`/`tweenShaderFloatArray` and `clearShadersFromCamera`, but no per-effect tween by tag and no single-effect removal from one camera). Theirs: `scripts/lua/ShaderFunctions.hx`. Port onto our `Effect`/`modchartShader` registry in `psychlua/callbacks/EffectCallbacks.hx`. Effort: S.
- **[P2] The four shader effects Phoenix doesn't ship: `addBulgeEffect` (pinch/bulge), `addRadialBlurEffect` (zoom blur), `addBrightEffect`, `addChromaticEffect`.** Their GLSL lives in `general/shaders/CustomShaders.hx` (`BulgeShader`, `RadialBlurShader`, `BrightShader`, `ChromaticAberration*`). Phoenix status: no `Bulge`/`RadialBlur` anywhere; `addBrightnessContrastEffect` and `addChromaticAbberationEffect` *[sic]* already cover the last two under different names — so only port **Bulge + RadialBlur** as new `shaders/` effects + `EffectCallbacks` registrations (+ Python), and alias the other two names for NovaFlare-mod compatibility. Effort: S–M.
- **[P2] Reflection/instancing in Lua: `createInstance`, `callMethod`, `callMethodFromClass`, `addInstance`, `instanceArg`.** Missing as Lua functions (only the security scanner mentions them, `backend/ScriptSecurityScanner.hx:98`). Theirs: `scripts/lua/ReflectionFunctions.hx`. **Do not port as-is:** unrestricted `Type.createInstance`/`Reflect.callMethod` from Lua contradicts `backend/ModSecurity.hx`'s sandbox. If wanted, add them behind the existing privileged-class allowlist (`FunkinLua.allowClassAccess`) so a mod must opt in per class. Effort: M.
- **[P3] `readJson(path)`, `getGlobals()`, `setVar(name, value)`, `eraseSaveData(name)`.** All missing. `readJson` = parse a mod JSON file into a table (gate it through the same path policy as `FileCallbacks`); `setVar` writes `PlayState.variables` (HScript has the equivalent, Lua doesn't); `eraseSaveData` completes the `init/flush/get/setDataFromSave` set in `SaveDataCallbacks.hx` (needs a confirm-free but mod-scoped delete — only its own save name). Effort: S each.
- **[P3] Name-parity aliases (cheap NovaFlare-mod compat): `noteTweenScale` (we split it into `noteTweenScaleX/Y`), `setTextAutoSize`, `setTextHeight`, `addChromaticEffect`/`addBrightEffect` (see above).** One-line aliases in the relevant `callbacks/` files; document them as aliases, don't duplicate logic. Effort: S.
- **[P3] HScript-only-in-theirs bridge functions exposed to Lua: `virtualPadPressed/JustPressed/JustReleased(button)`.** In D.C.E. these exist only on the HScript side (`scripts/hscript/HScript.hx:459-483`, alongside `addVirtualPad`/`addVirtualPadCamera`/`removeVirtualPad`). Phoenix has no script-facing virtual-pad query at all. Add to `InputCallbacks` + HScript preset + Python, reading the same mobile-controls state `MobileControls` uses. Effort: S. (Cross-ref §15 input backlog.)

### 27.2. Mod APIs — HScript, scripted classes, global/module scripts (**biggest modding gap**)

This is the largest real difference. Phoenix HScript (`psychlua/HScript.hx`, 1134 lines, `hscript-improved`) is a *function-hook* system: scripts get preset globals and `on*` callbacks. D.C.E. (NovaFlare) runs **hscript-iris-improved** (`hmm.json`: `hscript-iris-improved` + `hscript-improved` for the Codename layer) and treats HScript as a near-Haxe language. Phoenix has none of the following (grep `ScriptedState|ScriptedSprite|stageScripts|ScriptedModule` = 0 hits):

- **[P1] `class` / `package` / `import` support in mod HScript, with an explicit class registry.** Their `scripts/init/InitScriptData.hx` (283 lines) registers ~140 classes by dotted name (`backend.*`, `objects.*`, `states.*`, `editors.*`, `stages.*`, `shaders.*`, `psychlua.*`, `animateatlas.*`, `vlc.MP4Handler`, …) so a mod can `import states.PlayState;` or subclass engine types; `scripts/hscript/HScript.hx:278` resolves imports through `interp.imports`, and `crowplexus/hscript/proxy/flixel/util/ProxyFlxColor.hx` shows the abstract-proxy trick needed for `FlxColor.fromRGB`-style statics. Phoenix step 1 (no new lib): publish the same *registry document* for the classes our interp already seeds, generated from the preset code so it can't drift. Step 2: evaluate `hscript-iris-improved` (CodenameCrew lineage, same family as our `hscript-improved` pin) behind a pref, default off until the §20 golden tests pass on it. Effort: M (registry) / L (parser swap).
- **[P1] Scripted classes: `ScriptedState`, `ScriptedSubstate`, `ScriptedSprite`, `ScriptedSpriteGroup`, `ScriptedGroup`, `ScriptedBaseStage`** (`source/scripts/scriptClasses/`, loaded from `.hx` class files, with `HScriptState`/`HScriptSubstate` hosts in `scripts/stages/`). A mod ships a real state/sprite *class* instead of a hook script + `switchCustomState` string plumbing. Phoenix's `states/ModState.hx` + `StateScripts` only switch by name. Port as: a `Scripted*` base set in `psychlua/` that wraps our `HScript` instances, discovered in the mod folders below, with the same sandbox scan Lua gets. Effort: L.
- **[P1] Global scripts + Modules.** Two parallel systems, same hook set: `scripts/stages/GlobalHandler.hx` runs every `.hx` in `stageScripts/globals/` and forwards `FlxG.signals` (`pre/postStateSwitch`, `preStateCreate`, `gameResized`, `pre/postGameReset`, `pre/postGameStart`, `pre/postUpdate`, `pre/postDraw`, `focusGained/Lost`) to `onStateSwitch/onUpdate/onDraw/…`; `scripts/stages/modules/ModuleHandler.hx` does the same for compiled-style module classes (`.hxc`/`.hxs`, `Module` base class with `active` flag, `scripts/stages/modules/Module.hx`). Their mod template (below) gives every mod `stageScripts/{globals,modules,states,substates,options}/` folders, and `docs/stageScripts/*/TemplateScript.hx` documents state/substate hooks Phoenix never calls (`onOpenSubState(Post)`, `onCloseSubState(Post)`, `onOutroStart`, `onResize`, `onDraw(Post)`, `onClose(Post)`). Phoenix equivalent today: none — a script only lives inside `PlayState` or a custom state. Add a `GlobalScript` host that loads `scripts/globals/*.hx` (+ `.lua`/`.py` for parity with our three-language identity) at `InitState`, wires the same `FlxG.signals`, and is reloadable from the Mods menu. Effort: L. **This is the single highest-leverage modding port in this section** — it's what lets a mod change menus, not just songs.
- **[P2] Per-folder state scripts: `stageScripts/states/<State>.hx`, `stageScripts/substates/<Sub>.hx`, `stageScripts/options/*.hx`.** Any engine state can be patched/extended by dropping a script named after it (options scripts only get `onCreate/onDestroy`). Implement on top of the GlobalScript host: `MusicBeatState.create()` looks up scripts for its own class name. Effort: M (after the item above).
- **[P2] HScript→Lua bridging: `createGlobalCallback(name, fn)`, `createCallback(name, fn, ?lua)`, `addHaxeLibrary(name, ?package)`, `runHaxeCode`/`runHaxeFunction`, `setHaxeSyntaxFix` + the `x = new Foo` → typed-var syntax fixer** (`scripts/hscript/HScriptBase.hx:20-160`). Phoenix HScript can call Lua-ish globals but cannot *register* a Lua callback or import a class by name from inside a `.hx` string. Port `createGlobalCallback`/`createCallback` onto `FunkinLua.customFunctions`/`addLocalCallback`, and `addHaxeLibrary` behind the §27.1 privileged-class allowlist. Skip `fixSyntax` — it's a crutch for their looser parser. Effort: M.
- **[P2] Full preset parity for HScript:** they seed `Application`, `File`/`FileSystem`, `Json`, `Countdown`, `ErrorHandledRuntimeShader`, `FlxAnimate`, `getModSetting`, `game`/`controls`, `customSubstate(Name)`, `buildTarget`, `Function_StopLua/StopHScript` (`scripts/hscript/HScript.hx:312-608`). Phoenix seeds more *song* state but fewer *engine* classes. Diff the two preset lists when doing the registry item above and seed what's missing (notably `Countdown` and a read-only `Application`). Effort: S.
- **[P2] Per-mod settings, end-to-end: `data/settings.json` → in-game page → `getModSetting(saveTag, ?mod)` in Lua *and* HScript.** D.C.E.: `options/base/ModSettingsSubState.hx` + `LuaUtils.getModSetting` (`scripts/lua/LuaUtils.hx:142`), saved under `FlxG.save.data.modSettings`. Phoenix is *half* done and currently broken: `states/ModsMenuState.hx:934` parses `data/settings.json` into `ModItem.settings` and `:314` opens `ModSettingsSubState` — **but no such class exists anywhere in `source/`** (the import at `:19` is commented out), so that button cannot resolve from this tree. Implement the substate (reuse their save shape: per-folder map in its own save, per §13's "don't grow the `funkin` blob" rule), add `getModSetting` to Lua/Python/HScript, and add a `run-*.sh` spec that the class exists and round-trips a setting. Effort: M.
- **[P3] `oldHscriptVersion` pref** (BOOL, default off) — run mod `.hx` through the legacy Psych HScript semantics for pre-1.0 mods. Only meaningful after the iris item; Phoenix's version-split today is `inChartEditor`/deprecated-warning flags, not a compat parser. Effort: M.
- **Checked, no port needed:** achievement Lua API (`get/set/addAchievementScore`, `unlockAchievement`, `isAchievementUnlocked`) exists in both (`backend/Achievements.hx` `addLuaCallbacks`); `addHScript`/`addLuaScript`/`callScript`/`getGlobalFromScript`/`setGlobalFromScript` exist in both. Their `docs/TemplateScript.lua/.hx` hook lists match ours except the state/global hooks in §27.2 and `onKeyChange` in §27.3.

### 27.3. Gameplay & chart format

- **[P1] `KeyChange (MoreKey)` event — change key count mid-song.** The LushiFu headline feature (`games/backend/KeyChange.hx` 182 lines + `KeyChangePoint.hx`, `PlayState` integration ~10 sites, ChartingState parity). Format: a normal Psych event `[time, [["KeyChange", "6", "0.5"]]]` (name matched case/space/punctuation-insensitively, also `Key change(more key)`; value1 = keys 1–10 incl. `"7K"`; value2 = transition seconds, 0 = instant, blank = 0.5 s, cap 10 s). Charts are written in *segments*: notes before the first event use the chart's `mania`, each later segment uses the new count (player lanes `0..K-1`, opponent `K..2K-1`). Implementation shape worth copying: the event is **kept out of the one-shot event queue** (`makeEvent` returns early) and driven by a timeline state machine (`updateKeyChangeState` + `maniaAt(time, points, baseMania)`) so seeking/restarting backwards restores the right count; on switch it rebuilds strums with a staggered fade-in, rebuilds the keyboard viewer, drops now-out-of-range notes under documented rules, and calls **`onKeyChange(1, targetKeys)`** to scripts. Phoenix today: fixed 4 lanes everywhere; §25.1 (EK+) already plans static 1K–10K (`keyCount`/`mania` field, per-count binds/skins, `Change Mania` editor event) — **this item is the dynamic half of §25.1, not a duplicate**: do §25.1's static plumbing first, then this event on top, sharing `maniaAt`-style segment resolution between `PlayState` and the charter. Their `assets/shared/data/extrakeys.json` (per-count lane maps, inner/border/outline colours, pixel colours, scales, `maxKeys: 9` meaning mania 9 = 10K) is a ready-made data table for §25.1 step 3 — credit EK+/NovaFlare shape, don't copy their magic-number layout into `Note.hx`. Effort: L.
- **[P2] Static multikey data model (their side of §25.1).** `Song.hx:63` `mania:Int = 3` (0-based) + `ExtraKeysHandler` + `games/backend/Section.hx` parsing that branches on `Song.chartEngineVersion` (`Pe-0.7.3` vs `Pe-1.0.4` detection, `Song.hx:187-265`). Phoenix `data/Song.hx` has no `mania`/`keyCount` field at all. Covered by §25.1 items 1–2 — cross-reference only; their version-detection approach (sniff format, branch lane maths) is the part to copy, since EK+ charts in the wild carry `mania`.
- **[P2] Replay system: record every run, play it back, browse replays in Freeplay.** Entirely missing here (grep `class Replay|ReplaySave` = 0; §14 only *plans* determinism work). Theirs: `games/backend/Replay.hx` (636 lines) records per-frame pressed/released lanes + per-note judgements (`strumTime, noteData, hitDiff, rating, isSustain`), a `StateRecord` header (song, difficulty, mod dir, score/accuracy/FC/counts, `mania`, `safeFrames`, offsets, gameplay-settings JSON, `replayVersion`), integrity verification, and AES-encrypted save files (`server/util/EncryptUtil.hx`, AES-256-CBC — **note: hard-coded key in source, so it's obfuscation, not security; do not copy the key or claim encryption**). Playback (`PlayState.replayMode`) re-judges from the *recorded* judgements (`getRecordedJudgment` overrides `noteDiff`/rating) with resync thresholds for `songSpeed`/`playbackRate` drift, a replay watermark overlay (`objects/ReplayOverlay.hx`, pref-gated), and input blocked via `general/backend/KeyBlocker.hx`. UI: Results screen "save replay / watch replay" flow (`substates/ResultsScreen.hx:430-614`, async save with progress polling) and a per-song replay browser in Freeplay (`ReplayRect` list, sort modes, `states/freeplayState/objects/replay/ReplayRect.hx`). Prefs: `replayQuality` (store judgements vs inputs only), `showReplayWatermark`. Phoenix port shape: renderer-free recorder next to `HitTiming` (we already record hit offsets for §21.1's results histogram), JSON (not AES) files under the save dir, `replayVersion` from day one, playback through the existing `bothSides`/`practice` score-suppression path so replays never touch `Highscore`. This also gives §14 its determinism test corpus. Effort: L. **Second-biggest payoff in this section.**
- **[P2] `TimingSystem` — a monotonic song clock independent of the audio device** (`games/backend/TimingSystem.hx`, 130 lines): position from `lime.system.System.getTimerNano()` with 32-bit wrap compensation, pause accumulation, and *two* multiplicative rates (`ratePrimary × rateSecondary` — playback rate vs song-speed changer kept separate). Phoenix derives position from `FlxG.sound.music.time` + Conductor, which drifts on Bluetooth/underruns (we have `audioLatencyOffset`/`bluetoothAudioOffset` prefs compensating after the fact). Port as an *optional* clock source behind a pref (default: current behaviour until measured — §18's frame-pacing work is the gate), feeding `Conductor.songPosition`. Effort: M.
- **[P2] Computed difficulty rating (`games/backend/diffCalc/DiffRating.hx`, osu!-mania-style strain).** Per-column strain with 400 ms sections, decay weights, peak-weighted sum → a single star number, shown in Freeplay's detail panel (`FreeplayState.hx:848`). Phoenix freeplay shows personal bests but no computed difficulty. Pure function over `SwagSong` — port as a renderer-free `backend/DiffRating` + `tests/haxe/run-*.sh` spec with hand-computed fixtures, cache by chart hash (recomputing per selection change will jank low-end). Respect `playOpponent`/`flipChart` lane resolution like theirs does. Effort: M.
- **[P2] Fifth judgement tier: Marvelous.** `marvelousWindow: 15` ms + `marvelousRating` (count it) + `marvelousSprite` (show `marvelous.png`), `Rating.loadDefault()` gains a 5th entry, PlayState FC logic special-cases it (`PlayState.hx:1532-1543`). Phoenix: `perfectWindow` exists in `ClientPrefs` but there is no 5th *counted/displayed* tier or art (`backend/PlayerStats.hx:257` only maps the name). Port as an opt-in tier above Sick: pref `marvelousRating` default **on** per the house rule, window from the existing `perfectWindow`, greyed-out when accuracy presets (§22.4) don't define it. Needs `PlayerStats` + results-screen wiring. Effort: M.
- **[P2] Persistent play-as-opponent + opponent fixes.** Phoenix has the per-run `opponentplay` gameplay changer; D.C.E. adds it as a *persistent* pref (`playOpponent`) with the plumbing done properly: `cpuControlled_opponent` as a separate bot flag, health bar reversed (`leftToRight`), middle-scroll mirroring, `opponentCodeFix` (opponent uses fixed sing/hit code paths), `botOpponentFix` (default on), `healthDrainOPPO` + `healthDrainOPPOMult` (opponent drains *your* health when they hit, ×0.5 default). Port the two fix toggles + drain pair into `GameplaySettingsSubState` (they're modifiers, not global prefs), and make the changer's opponent mode reuse them. Effort: M.
- **[P3] `flipChart`** (mirror player lanes, 4K only in theirs — `lane = lane - (lane-1.5)*2`; generalise to `K-1-lane` when §25.1 lands), **`fixLNL`** (fix long-note length, 0/1-style backend toggle in `games/` note setup), **`guitarHeroSustains`** (hold sustains GH-style: no need to hold after head hit — Phoenix reads the name nowhere), **`saveScoreBase`** (`Score` vs rating-based score base, STRING pref), **`compulsionPause`** + `compulsionPauseNumber` (force-pause every N songs? — pause-menu enforced break with on-screen pause button `pauseButton`, mobile default on). Each is a small pref + one call site; add as Gameplay-changer rows where they're per-run (`flipChart`, `guitarHeroSustains`) and prefs where they're global. Effort: S each.
- **[P3] HUD widgets: `KeyboardViewer` + `JudgementCounter` as engine objects.** `games/objects/KeyboardViewer.hx` (448 lines: live key-press display fed from the real keybind table, rebuilds on `KeyChange`, prefs `keyboardAlpha/TimeDisplay/Time/BGColor/TextColor`, positioned from `comboOffset[4..5]`) and `games/objects/JudgementCounter.hx` (65 lines, per-tier counts on HUD, pref `judgementCounter`). Phoenix shows judgement counts only on results/stats screens. Port both as opt-in HUD objects (default on, alpha 0 = hidden), text colours from a small preset list like theirs. Effort: M.
- **[P3] Per-song preload manifest: `data/<song>/preload.json`.** `states/loadingState/backend/DataPreload.hx` reads `{ "images/spraycanAtlas/": 3, "sounds/Darnell_Lighter": 3, … }` (path-prefix → count/filter flags) plus stage-JSON `preload` blocks, so a song declares assets to warm instead of relying on script `precache*` calls. Phoenix `LoadingState` preloads by hard-coded steps + the song hook at `:489`. Add manifest support to that hook (mods + base songs, e.g. their `2hot/preload.json`). Effort: S.
- **[P3] Static preload by script-source scanning: `ScriptExprTools` + `DataPreload.preloadScript`.** They *parse* (not run) every Lua (via `luahscript` AST) and HScript file a stage/song will load, extract literal `precacheImage/Sound/Music`, `makeLuaSprite`, `startDialogue`, … arguments, and preload exactly those (`states/loadingState/backend/ScriptExprTools.hx`, `DataPreload.hx:341-490`). Phoenix runs scripts and discovers assets lazily (first-use hitch on low-end). Port the idea with our existing parsers (Lua: a literal-scan over the `ModSecurity`-scanned buffer; HScript: `hscript` AST walk), never executing mod code at preload time. Effort: M.
- **[P3] `NoteTypesConfig` txt property sheets.** `custom_notetypes/<name>.txt` lines like `property.sub = value` applied to notes (`games/backend/NoteTypesConfig.hx`) — a no-code way to make note types. Phoenix note types are Lua-only (`example_mods/custom_notetypes/`). Add the txt path as a fallback when no `.lua/.py/.hx` exists for the type name. Effort: S.

### 27.4. New options (complete pref diff)

Their `ClientPrefs` (`general/backend/ClientPrefs.hx`, 145 fields) vs ours (216). Everything Phoenix already has under the same or another name is excluded. **Every row below ships with a toggle/row in the named Phoenix substate and defaults ON where it's a feature** (house rule); pure-behaviour fixes default to their value. Grouped by their options category (`options/groupData/*.hx`, 10 groups):

| Pref (theirs) | Type / default | What it does | Phoenix status → where it goes |
|---|---|---|---|
| `framerate` (TPS) + `drawFramerate` (FPS) + `lockRender` + `renderThread` | INT 24–2000 / INT 24–2000 / BOOL on / BOOL on | Split logic rate from draw rate; render on a separate thread (`general/backend/thread/ThreadEvent.hx`, `ViewportScaleMode`) | **Missing** (single `framerate` + `menuFramerate`). Graphics + Optimization. See §27.7 — measure first |
| `resolution` | STRING `720P` (preset list) | Render-resolution presets decoupled from window size | Partial (`resolution` exists but is window-size). Graphics |
| `gameQuality` | INT 0–3 (mobile 0) | One quality tier driving several effects at once | Partial (`lowQuality` + Memory Profiles). Optimization — fold into `MemoryProfiles` as a 4th axis, don't add a rival pref |
| `colorblindMode` | STRING `None` + filter list | Full-screen colour-blindness filter (`general/shaders/ColorblindFilter.hx`) | Partial — §0's colour-matrix presets already simulate 3 deficiencies for *scripts*; no player pref. Visuals and UI, reuse `ScreenFilters` presets |
| `gcFreeZone`, `quotaGCIncreace` *[sic]*, `gameplayGC` | BOOL on / FLOAT 1 / BOOL off | GC tuning: free-zone, quota multiplier, GC during gameplay | Partial (`enableGC`, Memory Profiles). Optimization, expert-only rows |
| `autoOrientation` | BOOL off (mobile) | Allow portrait/landscape auto-rotate | Missing. Mobile options |
| `showFPS` extras: `fpsDisplayMode` (`TPS`/`FPS`), `fpsScale`, `rainbowFPS`, `memoryType`, `showWatermark`, `watermarkScale` | mixed | FPS counter shows TPS or FPS, resizable counter + watermark | Partial (FPS counter + `RamGraph` exist; no TPS/FPS switch, no watermark scale). Graphics — small rows |
| `mainMusic`, `optionMusic`, `pauseMusic` | STRING (`None`/`None`/`Tea Time`) | Pick menu / options / pause music from bundled tracks | Partial (`daMenuMusic`, `pauseMusic` name exists, no *options-screen* music or picker lists). Audio — one picker row each |
| `hitsoundType` values | STRING | Their hitsound set differs (check `assets/shared/sounds/` before porting names) | Have (`hitsoundType` exists) — content diff only, §27.6 |
| `noteRGB`, `splashRGB`, `noteColorSwap`, `dynamicColors`, `arrowHSV` | BOOL on / on / off / on / per-lane HSV | RGB-palette notes/splashes toggleable, swap note colours P1↔P2, HSV offsets per lane | Partial (`arrowRGB`/`quantRGB` exist; no swap, no HSV row, splash RGB not separable). Notes substate |
| `noteSkin` list + `splashSkin` list | STRING | Their lists add `Stepmania` notes and `Future` splashes | Content, §27.6 (Phoenix lists: Future/Chip/Classic notes; Diamond/Electric/Sparkles/Vanilla/Classic splashes) |
| `uiScale` | FLOAT 1 | Global UI scale | Have as `uiScalePercent` — no action |
| `customFade`, `customFadeText`, `customFadeSound` | STRING `Move` / BOOL on / FLOAT 0.5 | Pick the state-transition style + its sound/text | Partial (`backend` fade exists, not selectable). Visuals and UI |
| `skipTitleVideo`, `loadingScreen`, `resultsScreen` | BOOL off / off / on | Skip title video; use the *visual* loading screen vs instant load; show results vs straight-to-menu | Partial (we always load via `LoadingState`, always show results §21.1). Misc rows — `loadingScreen` is really "show loading art", rename ours accordingly |
| `loadThreads` | INT (mobile 2 / desktop 4) | Preload worker count | Missing (fixed thread use in `LoadingState`). Optimization, expert row, clamp by core count |
| `useFlixelCoords` | BOOL on | Stage/character coords in Flixel vs Psych origin for mod stages | Missing — mod-compat pref. Misc (Modding) |
| `audioDisplayQuality`, `audioDisplayUpdate` | INT 1–4 / INT 0–200 ms | Spectrum-visualiser resolution/refresh (`AudioDisplay`) | Missing. Goes with the visualiser item in §27.5 |
| `theme` (`Circle`/`Straight`/`None`), `songInfo` (position), `enableBpmZoom`, `enableRecordRotation` | STRING/BOOL | Song-info HUD style/placement in PlayState; beat-zoom in menus; rotating record icon while a song plays | Missing (vestigial in theirs too — `theme`/`songInfo` are only read in a few spots). P3, only with a song-info HUD port |
| `developerMode`, `deepDebug`, `devConScale` | BOOL off / off / FLOAT 1.5–1.8 | Unlock dev console + deep-debug overlays, console scale | Partial (Super Secret Debug Menu exists, no pref-gated console). See §27.5 console item |
| `consoleButtonX/Y`, `consoleX/Y/W/H` | FLOAT −1 | Remember console + LOG-button geometry | Missing. Automatic (save on drag), no row |
| `adjustMobileEditorKeys`, `emkDefaultsVersion` | BOOL off / INT | Enable the mobile editor-key system (§27.5) + template versioning | Missing. Mobile/Maintenance |
| `showKeybinds` | BOOL off | Show current keybinds on the gameplay HUD (with `KeyboardViewer`) | Missing. Gameplay row |
| `gameOverVibration` | BOOL off (mobile) | Vibrate on game over | Partial (`hapticFeedback` exists, not on death). Mobile row, wire to `AndroidHaptics` |
| `storageFolder` | STRING (preset list) | Choose the save/app-data folder name (`general/backend/device/AppData.hx`) | Missing. Maintenance — careful: changing it orphans saves; needs §13 migration handling |
| `filesCheck`, `githubCheck`, `screensaver`, `checkForUpdates`, `discordRPC` | BOOL | Startup file-integrity check, GitHub check, disable screensaver while playing | Partial (`checkForUpdates`, `discordRPC`, `screensaver` exist; no integrity check). Maintenance — `filesCheck` must only *report*, never delete (§19 safe-mode tie-in) |
| `language` | STRING `English` | Whole-UI language (§27.7) | **Missing** (`locale` pref exists but is read nowhere). Language row/panel |
| `prefsVersion` (120), `performanceDefaultsVersion` (8) | INT | Save-schema + perf-defaults migration versions | Partial (we have `saveVersion` for one purpose). Adopt their two-version split in §13's migration work |

Their remaining prefs (`downScroll`, `middleScroll`, `ghostTapping`, `noReset`, `healthBarAlpha`, `comboStacking`, `camZooms`, `scoreZoom`, `hideHud`, `opponentStrums`, `timeBarType`, `ratingOffset`, `noteOffset`, `safeFrames`, the four judgement windows, `splashAlpha`, `controlsAlpha`, …) already exist here — checked, no action.

### 27.5. Screens, menus & HUD

- **[P1] Options screen redesign: frosted-glass single panel + dual-orientation sidebar.** Their `options/OptionsState.hx` (2534 lines) replaces Psych's category states with: one panel, a sidebar that is *either* vertical (left) *or* horizontal (top) with a 3-stage expand animation, 12 category icons (`assets/shared/images/menuExtend/OptionsState/icons/`), settings *search* (`tapToSearch`), and a real backdrop blur (downscale → separable blur → saturate/haze → upscale, `blurSmall`/`saturateSmall`) drawn on `general/shapeEx/Slab.hx` — a single-quad "slab" invented because their 9-slice `RoundRect` seams tore during size tweens (the header comment is a good post-mortem; our `Slab` equivalent would also fix any future panel resizing). Phoenix: classic `BaseOptionsMenu` category list. Port the *interaction model* (one panel, searchable, sidebar remembers orientation), not the blur at full res — on low-end, blur the already-downscaled menu BG only, with a `lowQuality` fallback to a flat translucent slab. Effort: L.
- **[P2] Language panel with flags + native names + per-language sample text** (`options/objects/LanguagePanel.hx`, `LanguageGroup` pinned above all other categories). Replaces a text list of language names with flag cards; selecting re-renders the whole options screen (`changeLanguage()` walk). Goes with §27.7. Effort: M.
- **[P2] Freeplay redesign: detail panel + computed stars + replay browser + play history.** Their `states/freeplayState/FreeplayState.hx` (1671 lines, decomposed into `objects/song/SongRect`, `objects/detail/{DetailRect,DataDis,StarRect}`, `objects/down/{PlayButton,BackButton,FuncButton}`, `objects/select/SearchButton`): left song list, right detail card (composer/mapper credits from week JSON song tuples — note their `week1.json` songs carry extra `["Funkin Sound Team", …]` credit fields ours don't), BPM/song-length/played-count icons (`menuExtendHide/freeplay/*.png`), difficulty rects with `DiffRating` stars (§27.3), a function bar (`options/mod/changer/editor/reset/random`), text search with match counts, and the replay list (§27.3). Phoenix freeplay already has search/filter (§21.2 DONE) and personal bests — port only: **detail card + credits fields, DiffRating stars, replay tab**. Effort: M–L.
- **[P2] Results screen with hit-offset graph + replay actions.** Their `substates/ResultsScreen.hx` (1267 lines) is a *substate* over PlayState (song doesn't unload): per-judgement rows with ms windows, a drawn hit-distribution graph (`graphNoteDraw`), percent-rate breakdown, and Save Replay / Watch Replay / Back buttons with the async-save flow. Phoenix §21.1 plans a results *state* — prefer their substate shape (cheaper on low-end, keeps the song loaded for "retry" and for replay saving) and merge the two plans: implement §21.1 as this substate, including the histogram §21.1 already wants. Pref `resultsScreen` (default on) gates it. Effort: M (shared with §21.1 — do not do both).
- **[P2] Mods menu rewrite + `ModInfoPopup`.** Their `states/modsMenuState/ModsMenuState.hx` (2508 lines; HTML prototype `NewModsMenuState.htm` in-repo) adds a mod info panel (name/description/icon/version from `pack.json`) and an easter-egg achievement for opening it with nothing selected (`self_deception`, §27.6). Phoenix `ModsMenuState` (1139 lines) + `ModInfoSubState` cover part of this — diff before porting; the info-panel layout and the "no mod selected" empty state are the takeaways. Effort: M.
- **[P2] `SelectGameSubState` — boot into another engine.** Options → Interface → "Select Game" switches the *whole game* into Origin Funkin' (bundled V-Slice 0.8.4 code, `source-originFunkin/`, 546 files) or Codename Engine (`source-codename/`, 360 files, isolated state chain, desktop only), saving NovaFlare prefs first and restoring on exit (`options/base/SelectGameSubState.hx`, `codenamechain.CodeNameMode.canEnter()` guard). Phoenix has no equivalent — our §12 CNE work is *format* parity inside Phoenix, theirs is *running the actual other engines*. Honest assessment: **do not port wholesale** (two extra engines ≈ +8 MB source, a second asset pipeline, and §12.8's non-goals). The portable slice is smaller: a `compat/` launcher that, when a mod declares `engine: "codename"` in `pack.json`, warns "needs Codename — not playable here" instead of failing obscurely. Effort: S (warning) / XL (real port, not recommended).
- **[P3] Main-menu / freeplay audio visualiser.** `general/objects/AudioDisplay.hx` (348 lines, waveform/spectrum bars) + `AudioCircleDisplay.hx` (211, circular variant), used on the main menu (`MainMenuState.hx:147`) and in freeplay (their 1.2.0 changelog), quality/refresh prefs in §27.4. Phoenix menus are silent visually. Port `AudioDisplay` only, capped by `lowQuality`/Memory Profiles (it's a per-frame FFT — gate it). Effort: M.
- **[P3] Extra states: `PassState` (admin login gate), `PirateState` (anti-piracy ban screen), `ScaleSimulationState` (strum-scale self-test across key counts), `ServerConnectState` (Nakama login/register).** Verdicts: `ScaleSimulationState` — port as a debug/self-test page (it exercises §25.1 layout maths headlessly-ish; ties to §20). `PirateState`/`PassState` — **do not port** (ban screens and an admin password gate stored in plaintext `FlxSave` — see §27.8). `ServerConnectState` — see the online item in §27.7.
- **[P3] Title/menu tweaks:** double-click-to-skip-intro (0.35 s window, anti-misclick), customisable title intro text in full UTF-8, main-menu display changes. Phoenix title skip is single-press. Effort: S.

### 27.6. Bundled content diff

- **Songs/weeks:** identical base game (Tutorial, Weeks 1–7, Weekend 1) — *except* two chart-only orphans in theirs, `assets/shared/data/ridge/ridge.json` and `smash/smash.json`, with **no audio under `assets/songs/`** and no week referencing them (Weekend/PSX leftovers). **Do not port blind** — either they're unplayable without Inst/Voices or they resolve audio from the Origin-Funkin layer; verify upstream provenance/licensing before touching. Phoenix-only content (don't regress): the JS difficulty sets and `anti-cheat-song`.
- **Note/splash skins:** theirs adds noteskin **`Stepmania`** (`NOTE_assets-Stepmania`) and a top-level **`NOTE_assets`/`NOTE_alter`** pair used by the redone NoteSplash system, splash list adds `Future`. Phoenix already has Diamond/Electric/Sparkles/Vanilla/Classic splashes and Future/Chip/Classic notes. Port: `Stepmania` noteskin only (+ `list.txt` entries), credit NovaFlare. Effort: S.
- **Fonts (content + i18n enabler):** `Lang-ZH.ttf` (14 MB CJK), `dialogueFont.ttf` (14 MB), `chillax.ttf` (their Latin UI font), `montserrat.ttf`, `Revolin.ttf`, `FPS.ttf`, `loadScreen/loadText.ttf`. Porting all = +30 MB — **against `SIZE.md` goals**. Only port with the language system (§27.7) and subset/on-demand per language.
- **Language packs:** `assets/shared/language/{Chinese,English,Portuguese (Brazil)}` full trees (17 groups: `main, mainmenu, options, optionTips, gameplay, freeplay, pause, charting, editors, character, menuchar, controls, dialogue, dialoguechar, mods, notesplash, stage, week`) + joke pack `I Dont Like Haxe` (partial) + `JustSay` txt glossaries. Content port = the file format + English/Chinese trees; PT-BR is partial in theirs (no `dialogue/mods/notesplash/stage/character` groups).
- **Week-JSON song credits:** their week songs are 5-tuples (`[name, icon, colour, composer, [artists…]]`) feeding the freeplay detail card. Phoenix weeks use 3-tuples. Extending ours is a data migration — do it with the freeplay detail item, with a tolerant parser (missing fields = "Unknown").
- **Achievements:** one new, `self_deception` ("open Mod Info with nothing selected"). The rest match Psych's list (Phoenix additionally has `weekend1_nomiss`, `wowza`, `mr_robot`, `lol`). Port the one, with the Mods info panel. Effort: S.
- **`main-view.xml`** (`assets/shared/data/main-view.xml`, HaxeUI layout for a main view) — unused experiment on their side (HaxeUI libs are in `hmm.json` for the Codename layer). No port.

### 27.7. Editors & developer tooling

- **[P1] Self-drawn editor chrome for *every* editor: MenuBar + StatusBar.** The LushiFu centrepiece: `ChartEditorMenuBar/StatusBar`, `CharacterEditorMenuBar/StatusBar`, `DialogueEditorMenuBar` (2393 lines) + `DialogueEditorStatusBar`, `DialogueCharacterEditorMenuBar` (2404) + StatusBar, `NoteSplashEditorMenuBar` (2405) + StatusBar, `StageEditorMenuBar/StatusBar`, shared `EditorChromeUI`/`EditorInputStyle`, all talking to a desktop `WindowChromeManager`/`WindowControlBar` (§27.8). Native FlxUI widgets survive only as hidden data sources; every stepper/dropdown/slider/checkbox is custom-drawn with hover descriptions. Phoenix editors are stock Psych FlxUI tab boxes (`editors/ChartingState.hx` + `charting/` helpers, etc.). Port incrementally, one editor at a time, starting with the charter (biggest user base): MenuBar (File/Edit/View/… dropdowns) + StatusBar (cursor note, BPM, snap, undo depth) as a shell around the existing `ChartingUIGrid`, keeping FlxUI underneath like they do. Effort: L per editor; charter first.
- **[P1] A real NoteSplash editor.** Theirs: `developer/editors/NoteSplashEditorState.hx` (rewritten, ~1370 lines changed in 1.2.2) editing splash skins/animation with the new `NOTE_assets`/`NOTE_alter` skins. Phoenix has only `editors/NoteSplashDebugState.hx` (a debug previewer — theirs was *deleted* in favour of the editor, `NoteSplashDebugState.hx | 543 ----`). Port as a full editor state in `MasterEditorMenu` (which §12.3 already wants a Stage Editor + NoteSkin Editor added to — do this one first, it's the only one with a reference implementation). Effort: L.
- **[P2] Stage-editor undo/clipboard/import parity.** Their Stage editor: 50-deep JSON-snapshot undo (`Ctrl+Z`), `Ctrl+C/X/V`, Delete-confirm dialog (`StageEditorConfirmSubstate`), multi-PNG/arbitrary-path asset import, tutorial overlay, and — importantly — *global-state hygiene on exit* (restoring `Paths.currentLevel`, `StageData.forceNextDirectory`, `Mods.currentModDirectory`, song statics; the original leaked the week folder into the whole game's image resolution). Phoenix has no stage editor (§12.3) — when it's built, build it with these from day one. Their Character editor adds `Ctrl+S` quick-save + `F1` help; charter adds section swap/duet/mirror/copyBeat to the menu bar (Phoenix has Duet/Mirror buttons already, §24.1 — menu placement only). Effort: M (on top of §12.3's stage editor).
- **[P2] Mobile editor-key customisation + in-game HTTP editor server.** Wholly new system (no Phoenix analogue): `mobile/objects/EditorMobileKeys.hx` (persistence, 3-level file fallback, template cache), `EditorMobileKeyData.hx` (key registries/semantics for 9 editors), `EditorMobileKeyDefaults.hx` (APK-bundled templates), `EditorMobileKeyOverlay.hx` (runtime overlay on its own HUD camera, 0.8 s mtime hot-reload), and `mobile/server/EditorKeyServer.hx` — an embedded HTTP server on `127.0.0.1:1146–1165` (auto-fallback ports; accept-thread never touches `FlxG`) serving a full visual editor page (`EditorKeyPage`, generated HTML; prototypes `mobile-key-editor.html` in-repo) where you drag keys, record combos, configure Switch-style parent keys, and it writes `<Editor>NewFuckingButtonMobile.json` *[their filename]* back to the game. Entry: Maintenance → `adjustMobileEditorKeys`, `-emk` launch flag. Phoenix mobile controls are fixed layouts (`MobileControls`, `MobileOptionsSubState`). Port the *overlay + JSON schema* first (Effort: M), the HTTP server second (Effort: M, **bind 127.0.0.1 only, no auth token needed if loopback-only — document that; never expose on LAN**).
- **[P2] Visual keybind screen.** `options/base/KeyBindsSubState.hx` (669 lines, new in 1.2.1): category tabs, a drawn real-keyboard diagram, dual binding slots, TAB to switch slot, per-key-count highlight colours; replaces `ControlsSubState` as the Options entry (their old `ControlsSubState`/`NewControlsSubState` remain as data tables, ESC-cancel unified at 2.0 s). Phoenix `ControlsSubState` is a text list. Port the keyboard diagram + dual-slot model; it becomes *required* UI once §25.1 lands (per-count binds need somewhere to live). Effort: M.
- **[P2] Developer console with memory + draggable LOG button.** `developer/console/Console.hx` (openfl `Sprite` overlay console: filterable, pausable, copyable, maximisable log view, 1500-line cap, thread-safe pending queue), `TraceInterceptor`/`TraceServer`, `ConsoleToggleButton` (5 px drag-vs-click threshold), geometry persisted (§27.4). Plus `developer/display/`: `FPSCounter`/`FPSViewer`/`ExtraCounter` with a tabbed `GraphMonitor` (Update TPS / Draw FPS / App Mem / GC Mem graphs, `DataCalc` sampling memory on a worker thread). Phoenix has `debug/FPSCounter`, `RamGraph`, `FrameProfiler` — the *gap* is the interactive console and the combined graph monitor. Port the console (gate: `developerMode` pref, default off — it's a dev tool, exempt from the default-on rule), and add TPS/FPS/App/GC tabs to our existing graph code instead of porting `GraphMonitor` whole. Effort: M.
- **[P3] HTML-prototype-first workflow.** `NewOptionState.htm`, `NewModsMenuState.htm`, `chart-editor-mockup.html`, `mobile-key-editor.html`, `note-color-style-editor.html` + design docs (`docs/设置界面重做记录.md`, `NovaFlare-MenuBar-架构报告.md`, `NovaFlare-Editors-ChromeUI-接入分析.md`, `docs_language_chrome_survey.md`) — they prototype UIs as standalone HTML, then port to Haxe. Worth adopting as *process* for the §27.5 options/freeplay ports (cheap mockups before Haxe), not as code. No effort line; link from the relevant issues.
- **[P3] One-click installer (`NovaFlareEngineInstaller/`).** A Haxe-built single-`.exe` installer embedding a RAR payload (`make_payload_rar.bat` auto-packs the build, excluding saves/mods/crash/logs; embedded UnRAR 7.00; SHA256-verified in their commit) + `NovaSetup/` one-click build scripts. Phoenix ships zips + `setup/`. Port only if releases move to installers — Windows-only today, so P3. Effort: M.

### 27.8. Engine, platform & runtime

- **[P1] Localisation system (`Language` + `.lang` files + font fallback).** The other LushiFu headline. `general/backend/language/Language.hx` (178) + `lang/Parser.hx` (714) + `CustomLangGroup.hx`: `Language.get('fontName', 'main')`-style lookups over `language/<Lang>/<group>/<group>.lang` (`key => value` lines), ~30 files de-hardcoded from `vcr.ttf`, an OpenFL **asset-manifest fallback** so languages list correctly inside an Android APK (no directory listing), and `options/FontFallback.hx` (417 lines, *shipped as a binary `.hx` blob in their repo — treat as untrusted, reimplement*: secondary-font fallback so accented/CJK glyphs don't blank in mixed text). Enabling piece: `general/objects/Alphabet.hx` rewritten from per-letter sprites to per-character TTF `FlxText`. Phoenix: `locale` pref exists but **nothing reads it** (§12.4 already lists "Localization / translations" as missing — this is the reference implementation for that line). Port order: (1) `Language.get` + English files extracted from current strings for Options/menus only, (2) `fontName` per language + FontFallback reimplementation, (3) editors/menus group by group. **Do not port their `Alphabet` rewrite wholesale** — our Alphabet art styles (`alphabetStyle` pref) are a feature; add a TTF mode instead. Effort: L.
- **[P2] TPS/FPS split + render thread.** `framerate` = logic TPS (default 1000), `drawFramerate` = draw FPS, `lockRender`, `renderThread` (their README claims first TPS >1000 and thread-separated rendering; code: `ClientPrefs.hx:26-29`, `ThreadEvent`, `ViewportScaleMode`, `Main.hx`). Phoenix caps at a single 1000 FPS. **Measure before porting** (§18 method): if draw and update are both cheap on our stress chart, the split buys nothing on low-end and the thread adds sync bugs (their own commit history is full of render-thread-adjacent crashes). Take the *pref split* (logic vs draw cap) first — it's small — and only thread rendering behind `renderThread` default **off** until profiled. Effort: M (split) / XL (thread).
- **[P2] NovaGC / Immix GC (custom hxcpp).** Their `hxcpp` is a fork (`hxcpp-4.3.2-new`) with a rewritten GC; `docs/HXCPP_*` is ~400 KB of design/audit docs (`HXCPP_GC_REWRITE_MASTER_PLAN`, `…_ZGC_*`, parity checklists), plus in-engine `general/backend/gc/GCManager.hx` and the `gcFreeZone`/`quotaGCIncreace`/`gameplayGC` prefs, and a `legacy_gc_compare` build dir + `WindowsZGCBuild.yml` CI job for A/B builds. Phoenix uses stock FunkinCrew hxcpp + `enableGC`/Memory Profiles. **Not a cherry-pick — it's a runtime fork.** Only path: a spike that builds Phoenix against their hxcpp on Windows, runs §20's stress suite + §18 profiling, and compares GC pause histograms; adopt only if it wins *and* the fork's maintenance story is acceptable. Effort: XL (spike: M). Their GC *prefs* (free-zone/quota) map onto hxcpp env knobs and can be taken independently in Optimization. Effort: S.
- **[P2] Immersive self-drawn window (desktop).** `general/backend/device/Native.hx` (+~970 lines in the delta: runtime `WS_CAPTION`/`WS_THICKFRAME` strip/restore, `SetCapture` manual drag, window-rect animation, whole-window fade, resolution-confirm dialog on its own thread), `WindowChromeManager` (hides the OS title bar per-screen, viewport reconciliation), `general/objects/WindowControlBar.hx` (custom title bar: AUTO_HIDE top-edge reveal in menus, CONSTANT in editors). Their comments record that pure `SetWindowPos` animation broke SDL→OpenGL presentation; final design = real SDL fullscreen + `ShowWindow` + synced `borderless`. Phoenix has window *effects* (`TransparentWindow`, `WindowMode`, MetaHorror) but a stock title bar. Port behind `windowMode` as a new "Immersive" mode, Windows-first, editors-CONSTANT/menus-AUTO_HIDE like theirs. Effort: L.
- **[P2] Embedded-engine compatibility layers (assess, don't blindly port).** `CODENAME_ENGINE_COMPAT`: the full Codename source (360 files) on the classpath, entered as an isolated state chain from `SelectGameSubState`, with `HSCRIPT_ABSTRACT_SUPPORT`/`CUSTOM_CLASSES`/`GLOBAL_SCRIPT`/`SOFTCODED_STATES`/`TRANSLATIONS_SUPPORT` defines so Codename mods run unmodified. `ORIGIN_FUNKIN_COMPAT`: full V-Slice 0.8.4 (546 files incl. its own `funkin/` framework, Animate atlas, Newgrounds/Discord APIs). Phoenix's §12 instead reimplements CNE *formats* natively. Their approach plays real mods *today* at the cost of shipping two engines. Recommendation: **keep §12's native-parity path**; add only (a) `pack.json` `engine` detection + a clear "wrong engine" notice (§27.5), and (b) V-Slice *chart* import (their Codename layer's `VSliceParser`/`PsychParser`/`FNFLegacyParser` trio in `source-codename/codename/funkin/backend/chart/` is a good reference for §12.4's parser item). Effort: S (notice) — the rest is a non-goal, add to §12.8.
- **[P3] Vendored-Flixel `FlxSound` null-guard + patch tool.** Their `dependencies/flixel-5.9.0-main/flixel/sound/FlxSound.hx` carries two SIGSEGV fixes (destroyed sound's `_transform` written via `volume`; `loadEmbedded(null)` skipping `cleanup(true)` so the next `loadHelper` derefs null — reachable from Lua `playSound('<missing>')`), applied by `tools/patch-flxsound-null-guard.ps1`. Phoenix patches Flixel differently (`source/source-haxelib-patches/flixel/sound/FlxSound.hx` exists, with `FLX_SOUND_FILTERS` support). Action: diff our patched `FlxSound` for the same two paths; if unguarded, port the guards (two small `if`s) + a `tests/` case that `playSound` on a missing file doesn't crash. Effort: S. **Do not adopt their whole vendored Flixel.**
- **[P3] Library diff worth knowing (don't port by default):** `spinehaxe` + `FlxSpine` import (commented-out spine support in `source/import.hx:15-21` — Phoenix: no Spine), `polymod`/`jsonpatch`/`jsonpath`/`thx.*` (Codename-layer deps), `flxsoundfilters` (we have `FLX_SOUND_FILTERS` in our Flixel patch — check parity, don't double-add), `FlxPartialSound` (streaming partial loads — relevant to our `SongAudioStreaming`, compare before duplicating), `luahscript` (Lua-AST parsing, used *only* for §27.3's preload scanner), `haxeui-core/-flixel` (Codename layer + the unused `main-view.xml`), `trandom` (native RNG for the Windows IV in `EncryptUtil`), `crypto`/`tjson`/`json2object` (we have `tjson` equivalents). Each needs its own justification; none is a free win.
- **[P3] Audio config: `ALSoftConfig` + `alsoft.txt`.** Ships an OpenAL-Soft config as `plugins/alsoft.ini/.conf` (`general/backend/device/ALSoftConfig.hx`, `Project.xml:83-86`) for consistent desktop audio. Phoenix relies on Lime defaults. Small, safe, test on Windows/Linux. Effort: S.
- **[P3] Online layer — design only, do not port code.** `server/nakama/{NakamaClient,NakamaAuth,NakamaAccount,NakamaStorage}.hx` (Nakama backend client, default `127.0.0.1:7350`/`defaultkey`), `server/online/LoginClient.hx`, `ServerConnectState`, `PassState`, `getServer.txt`, AES `EncryptUtil` (hard-coded key, §27.3), and `gameanalytics/` (GA bridge — the repo's `private/` keys are *not* included, correctly). Phoenix has no accounts/online anything. If online ever happens (leaderboards for §14's replay-verified scores is the only compelling use), it needs: our own server story, no hard-coded keys, no plaintext credentials in `FlxSave` (**their `PassState` stores user+password verbatim — explicitly do not copy**), and privacy review for analytics (§19 tie-in). Until then: non-goal. Effort: —.
- **[P3] Save robustness ideas:** their `ClientPrefs.recoverUnreadableSave` + `ensureSaveData` (repair a corrupted save blob instead of crashing) and the `performanceDefaultsVersion` migration (bump perf defaults without touching user settings). Phoenix §13 covers backups/migration generally — add these two as named techniques there. Effort: S.

### 27.9. Checked — already in Phoenix or deliberately not taken

- **Lua API size:** Phoenix 375 registered functions ≥ their 228; all Psych-standard names match. Python scripting (Hython, `psychlua/pystdlib/`) is Phoenix-only — D.C.E. has no Python at all. Don't let any §27.2 port regress the three-language parity (every new Lua function gets a Python + HScript twin, as our `callbacks/` + `pystdlib/` split already enforces).
- **Difficulties/content volume:** Phoenix's JS-Engine chart sets (`-erect/-expert/-insane/-jshard/-nightmare/-noob` + `events-erect.json`) dwarf their Easy/Normal/Hard-only set. Their `Difficulty.hx` (week-declared difficulty lists) ≈ our week `difficulties` handling — checked, no port.
- **Achievements backend:** same Psych list + score API on both sides (§27.2); only `self_deception` is new (§27.6).
- **Custom events/notetypes folders, `pack.json` + `runsGlobally`, mod `data/settings.json` parsing, hitsound types, `gameplaySettings` changers (`scrollspeed/songspeed/healthgain/…` incl. `opponentplay`), FPS counter, RAM graph, frame profiler, chart-editor undo** — all present in both (theirs independently implemented; ours equal or better). No action except the broken `ModSettingsSubState` (§27.2).
- **Do not port:** `PirateState` ban screen; `PassState` plaintext-credential admin gate; hard-coded AES key in `EncryptUtil`; the `private/` GameAnalytics keys (absent anyway); joke language pack as a default (ship it as a mod if at all); their vendored Flixel/OpenFL/Lime forks wholesale (`NovaFlare-Engine-haxelib/*`) — Phoenix pins its own forks in `hmm.json` and rebasing onto theirs would invalidate every existing patch in `source-haxelib-patches/`.
- **Phoenix-only, keep:** Python, Android-first platform layer (`source/android/platform/*`), MetaHorror/GDI script effects, Low-Memory profiles, mod sandbox (`ModSecurity`), deep links (`phoenix://`), rendered-note caps. D.C.E. has none of these; several §27 ports must be designed not to break them (noted inline).

### 27.10. If only five get done (suggested order)

1. **Global/module + state scripts (§27.2)** — unlocks menu-modding, the thing Psych-style engines can't do today.
2. **`KeyChange` event on top of §25.1 (§27.3)** — the signature gameplay feature; editor parity is already designed on their side.
3. **Replay record/playback + Freeplay browser (§27.3)** — feeds §14 determinism, §21.1 results, and any future leaderboard.
4. **Localisation core (§27.8)** — `Language.get` + font fallback; every other UI port gets cheaper after it.
5. **Per-mod settings fix (§27.2)** — smallest item here that repairs an existing broken button.
