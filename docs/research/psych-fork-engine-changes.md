# Engine-change audit: 18 FNF/Psych repositories

**Date:** 2026-11-03
**Scope:** the 18 repositories listed in the request (17 Haxe codebases + 1 untouched vanilla FNF fork)
**Method:** static analysis of the actual Git trees — no README-only claims (README claims are quoted separately and marked as such)
**Prepared for:** FNF Phoenix Engine (this repo) — see [§8](#8-what-phoenix-could-actually-borrow) for the porting notes

---

## 0. TL;DR

1. **Five repositories are real engine work; the rest are mod builds or cosmetic forks.** By measured code delta: **NovaFlare** (~308k lines touched, 1,309 Haxe files, three whole codebases merged), **Kathy** (~100k), **Plus Engine** (~100k), **Frozen** (~78k), then a long tail. Mint, Psike, DM-kun and the mobile port sit in the middle: smaller deltas, but architecturally meaningful.
2. **The single biggest engine change in the set is NovaFlare's tree merge** — a Psych-lineage tree (`source/`, 112k lines) plus a full copy of **FNF V-Slice** (`source-originFunkin/`, 131k lines) plus a copy of **Codename Engine** (`source-codename/`, 64k lines), with converters between the three mod formats. Nothing else in the set comes close in surface area.
3. **The pattern that actually spread across forks is not rendering or gameplay — it is scripting.** Lua API surface roughly doubles (236 → 458 registrations in Plus Engine), HScript is replaced/ported to *iris* variants, and two forks push the scripting *model* furthest — scriptable states/substates plus global scripts (Mint) and multi-version Lua compatibility routing (Kathy) — while a third adds the only script-security layer in the set (Plus Engine's `ModSecurity`).
4. **Editors became the main battleground.** Kathy ships *three complete chart editors* (1.0.4, 0.7.3, 0.6.3) behind a router; Frozen adds a `moonchart`-based chart converter (`.sm/.ssc/.osu/.osz/.qua/.qp/.mid`); Mint rewrote large parts of the 1.0.4 chart editor; NovaFlare merged V-Slice's and Codename's editors alongside Psych's.
5. **Only one fork touched the runtime below Flixel** — NovaFlare (documented hxcpp/GC replacement, render-thread separation). **Psike** and **custompsych** went one layer down instead, patching Flixel/OpenFL/Lime internals from inside the game source (asset caching, streaming audio, camera batch API).
6. **Only one fork added a real gameplay-fairness feature: Frozen's replay system** (frame-accurate input recording + judgment re-simulation), enabled by a full Freeplay/Options rewrite.
7. **The 2021 "mod" repos that started this whole ecosystem are historically interesting but contain almost no engine work** — with one exception: `PsychEngine-AprilFools` is effectively the **0.5.3b preview** (Blammed-lights event, colour-cycling menus, and a Lua sandbox hardening pass), and `FNF-VsCytrus` is 0.3.2 plus 171 changed lines.

---

## 1. How this was measured

| Step | What was done |
| --- | --- |
| Checkout | Every repo cloned with `git clone --filter=blob:none --sparse --depth 1`, then sparse-checked out every directory containing `.hx` (assets excluded — the NovaFlare/Plus/Custom-Psych repos are 0.8–2.7 GB in full). |
| Baselines | `ShadowMario/FNF-PsychEngine` tags `0.1.1 … 1.0.4` fetched the same way; `FunkinCrew/Funkin` `v0.2.7.1` as the vanilla reference. |
| Lineage detection | For each repo, the share of baseline `.hx` files whose **whitespace-normalized** content is byte-identical. Best-scoring tag = the fork's base. This is immune to re-indentation and line-ending changes. |
| "New" code | `.hx` files present in the fork but not in the base, with their line counts. |
| "Churn" | For files that exist in both: non-whitespace line inserts + deletes from a line-level diff. Reformatting contributes ~0. |
| Similarity matrix | Per canonical module (PlayState, Character, FunkinLua, ChartingState, FreeplayState, OptionsState, Conductor), `difflib` ratio between base and fork file. |
| Limits | (a) Tags are the only baselines — forks that tracked Psych's un-tagged `main` will look more divergent than they are; (b) generated/vendored code counts as new code (flagged where relevant: NovaFlare's V-Slice/CNE trees, `moonchart`); (c) asset work, build scripts, `Project.xml` flags and most of `mods/` are not measured; (d) README claims are labelled as such. |

Raw numbers: [`engine-change-stats.csv`](engine-change-stats.csv) (this directory). Reproduce with the commands in [§9](#9-reproducing-the-numbers).

---

## 2. Inventory and lineage

| Repo | Stars | Last push | State | Actual base (measured) | Verdict |
| --- | ---: | --- | --- | --- | --- |
| `ShadowMario/Funkin` | 1 | 2021-02-25 | active fork | FunkinCrew `v0.2.7.1`, **unmodified** | reference, not a mod |
| `ShadowMario/fnf-vsdaddico` | 2 | 2021-07-09 | archived | Psych **0.3** (24% verbatim) | mod build, heavily stripped |
| `ShadowMario/FNF-VsPsychic` | 10 | 2021-08-02 | archived | Psych **0.3.1** (33%) | mod build (Mind Games) |
| `ShadowMario/FNF-VsCytrus` | 2 | 2021-09-03 | archived | Psych **0.3.2** (89%) | content mod only |
| `ShadowMario/PsychEngine-AprilFools` | 14 | 2022-04-02 | archived | Psych **0.5.2h → 0.5.3b preview** (93%) | engine preview build |
| `ShadowMario/NewVeryCoolPsychic` | 23 | 2022-06-16 | archived | Psych **0.5/0.5.1** (61%) | mod build (Mind Games week) |
| `Raltyro/FNF-PsikeEngine` | 17 | 2024-02-20 | active | Psych **0.6.3** (48%) | real fork (performance) |
| `TheBeepSheepTeam/FNF-PsychEngineLTS` | 3 | 2025-01-09 | active | Psych **1.0** (68%) | maintenance fork |
| `DM-kun/FNF-PsychEngine` | 7 | 2025-09-05 | active | Psych **1.0.4** lineage (15%) | real fork + mod content |
| `Castan0va/VS-Sunky` | 1 | 2026-10-11 | active | Psych **1.0.4** (94%) | content mod on a fork |
| `nennneko5787/FNF-PsychEngine` | 2 | 2024-11-23 | active | Psych **1.0** (90%) | near-stock fork |
| `BrenninhoTools/FNF-PsychEngine-Mobile` | 4 | 2026-10-27 | active | Psych **1.0.4** (72%) | real fork (platform port) |
| `inky03/PsychEngineMint` | 17 | 2026-08-17 | active | Psych **1.0.4** (30%) | real fork (scripting/editor) |
| `Rudyrue/custom-psych` | 9 | 2026-03-24 | active | **not Psych** — Funkin 0.2.x-style rewrite (2–15%) | independent framework |
| `TieGao/FNF-FrozenEngine` | 6 | 2026-11-02 | active | Psych **1.0.4** lineage (38%) | real fork (replay/interop) |
| `NovaFlare-Engine-Concentration/FNF-NovaFlare-Engine` | 89 | 2026-10-31 | active | Psych 0.7.3 lineage + **V-Slice 0.8.7** + **Codename 1.1.0-rc3** | real fork, multi-engine |
| `LeninAsto/FNF-PlusEngine` | 91 | 2026-11-03 | active | Psych **1.0.4** lineage (25%) | real fork (modcharts/UI/i18n) |
| `kittycathy332/FNF-KathyEngine` | 11 | 2026-11-02 | active | Psych **1.0.4** lineage (35%) | real fork (editors/compat) |

`%` = share of the baseline's files that survive unmodified; low values mean heavy divergence from that tag, not necessarily from Psych.

---

## 3. Engine-change weight (measured)

| # | Repo | Haxe files | Haxe LOC | New files | New LOC | Modified files | Churn (lines) | Impact (new+churn) |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | NovaFlare | 1,309 | 308,296 | 1,303 | 305,737¹ | 6 | 2,634 | **308,371** |
| 2 | Kathy | 305 | 145,140 | 147 | 62,941 | 103 | 37,200 | **100,141** |
| 3 | Plus Engine | 434 | 131,442 | 291 | 61,818 | 104 | 37,693 | **99,511** |
| 4 | Frozen | 334 | 123,229 | 186 | 58,325 | 88 | 19,819 | **78,144** |
| 5 | Psike | 125 | 49,655 | 21 | 8,271 | 54 | 16,290 | 24,561 |
| 6 | custom-psych | 118 | 20,784 | 116 | 20,620 | 2 | 350 | 20,970² |
| 7 | Mint | 169 | 55,790 | 16 | 1,570 | 105 | 17,009 | 18,579 |
| 8 | DM-kun | 154 | 51,493 | 22 | 5,800 | 109 | 7,606 | 13,406 |
| 9 | vsdaddico | 52 | 11,590 | 8 | 1,081 | 29 | 5,694 | 6,775 |
| 10 | Mobile port | 183 | 58,253 | 25 | 4,406 | 45 | 1,258 | 5,664 |
| 11 | VsPsychic | 59 | 15,952 | 2 | 198 | 36 | 4,895 | 5,093 |
| 12 | LTS | 160 | 52,784 | 5 | 523 | 50 | 2,888 | 3,411 |
| 13 | NewVeryCoolPsychic | 84 | 30,448 | 1 | 58 | 31 | 2,043 | 2,101 |
| 14 | VS-Sunky | 161 | 53,382 | 3 | 476 | 9 | 957 | 1,433 |
| 15 | AprilFools | 97 | 34,742 | 0 | 0 | 6 | 252 | 252 |
| 16 | neko | 156 | 51,859 | 1 | 28 | 15 | 144 | 172 |
| 17 | vscytrus | 63 | 19,254 | 0 | 0 | 6 | 171 | 171 |
| — | Funkin (ref) | 49 | ~7k | 0 | 0 | 0 | 0 | 0 |

¹ Includes ~195k lines that are vendored FNF V-Slice / Codename Engine trees, not written by NovaFlare. NovaFlare's *own* lineage tree is `source/` = 356 files / 112,412 lines.
² A rewrite rather than a diff: the whole tree is new, and it is not Psych's tree.

Totals for the 17 Haxe repos: **1.21M lines of Haxe**, of which **532k lines are new relative to their bases** and **157k lines were rewritten in place**.

---

## 4. Where the changes land (subsystem similarity vs. base, %)

Lower = more rewritten. `–` = module does not exist under that name. Each fork is compared to its own nearest release tag (Psike→0.6.3, LTS/neko→1.0, the 2021 builds→0.3.x); NovaFlare (a 0.7.3 lineage) and custom-psych use 1.0.4 as a common yardstick.

| Repo | PlayState | Character | Lua API | Chart editor | Freeplay | Options | Conductor |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| vscytrus | 99 | 100 | 100 | 100 | 97 | 100 | 100 |
| AprilFools | 99 | 100 | 99 | 100 | 95 | 100 | 100 |
| neko | 99 | 100 | 99 | 100 | 100 | 100 | 100 |
| Sunky | 99 | 100 | 100 | 100 | 82 | 98 | 100 |
| Mobile port | 99 | 100 | 100 | 99 | 90 | 81 | 100 |
| NewVeryCoolPsychic | 96 | 100 | 96 | 90 | 96 | 98 | 100 |
| LTS | 96 | 100 | 93 | 95 | 99 | 100 | 100 |
| DM-kun | 75 | 81 | 93 | 98 | 98 | 92 | 72 |
| Plus Engine | 71 | 63 | 56 | 70 | **18** | **19** | 53 |
| Mint | 69 | 74 | **18** | 81 | 96 | 64 | 28 |
| Frozen | 68 | 94 | 98 | 90 | **13** | **8** | 100 |
| Psike | 58 | 65 | **34** | 97 | 94 | 88 | 40 |
| vsdaddico | 59 | 52 | – | 69 | 72 | **17** | 93 |
| VsPsychic | 70 | **37** | – | 75 | 85 | 97 | 100 |
| Kathy | **44** | 81 | 92 | 58 | **23** | **14** | 39 |
| NovaFlare (own tree) | **48** | 78 | **41** | – | – | – | 72 |
| custom-psych | 2 | 8 | – | – | – | – | 1 |

Three clear clusters:

* **Surgical forks** (Mobile, Sunky, LTS, neko, AprilFools): only touch what their feature needs.
* **Feature forks** (Mint, Frozen, Psike, DM-kun): leave `Conductor`/`Character` alone, rewrite *either* the menus *or* the scripting layer.
* **Re-architecture** (Kathy, Plus, NovaFlare, custom-psych): nothing below 50%, and the menu stack and PlayState are effectively new code.

---

## 5. Deep dives

### 5.1 NovaFlare Engine — three engines in one tree (the biggest change in the set)

**Measured:** 1,309 `.hx` files / 308k lines; 1,303 new files. Own tree `source/` = 356 files / 112k lines. `source-originFunkin/` = 554 files / 131k lines (FNF **V-Slice**). `source-codename/` = 394 files / 64k lines (**Codename Engine**). Overall 0% byte-identical to any Psych tag because the whole tree was re-formatted and moved (`source/games/PlayState.hx`, `source/general/backend/*`).

Biggest actual engine changes:

1. **Multi-modding-format runtime.** Three full mod file layouts live side by side, and there are dedicated converters between them: `developer/editors/ChartConverterState.hx`, `CharacterConverterState.hx`, `StageConverterState.hx`, plus a vendored `moonchart`. README (v1.2.1) claims mod support for *"Psych mod 0.7.3 to 1.0.4, V-Slice 0.8.7, CodeName 1.1.0-rc3"*.
2. **Runtime/GC replacement work.** The repo documents a from-scratch hxcpp replacement (own object ABI, precise descriptors, region + TLAB allocation, SATB barriers, concurrent marking/relocation, weak/ephemeron/pinned handles) in 12 `docs/HXCPP_*`/`ZGC_*` files. The `hxcpp/` tree itself is **not** in the repo, so this is design/status documentation, not verifiable source — treat as a claim. What *is* in-source: `general/thread/`, `general/gc/`, `Main.hx` changes (+496/−38) and a native crash handler (`general/backend/NativeCrashHandler.hx`, 1,659 lines).
3. **Online services.** A Nakama client (`source/server/nakama/{NakamaClient,NakamaAuth,NakamaAccount,NakamaStorage}.hx`) plus `states/serverConnectState/ServerConnectState.hx` — account/auth/storage backend, unique among all 18 repos.
4. **Scripting upgrade.** `scripts/lua/FunkinLua.hx` (2,245 lines, ~41% similar to Psych's), `scripts/hscript/`, `scriptClasses/`, `scripts/init/`. README: HScript replaced by *hscript-iris-improved* with `class`/`package` support.
5. **Mobile shader translation.** `general/shaders/MobileShaderConverter.hx` (3,338 lines) with a documented GLSL→GLSL-ES conversion plan — a level of mobile graphics work nobody else in the set attempted.
6. **Developer tooling as a product:** chart editor 3,946 lines, stage editor 2,526, character editor 1,485, note-splash editor 1,143, `GraphMonitor` (1,222), plus a modchart module (`source/modchart/`).
7. **Telemetry:** in-tree `general/gameanalytics/`, with a `private/` directory (not public) holding the API keys.

**Caveats worth repeating:** the project's own README warns that release 1.2.2 was *withdrawn* for being "overly customized, relied too much on AI modifications"; source comments and docs are largely Chinese; the tree is pre-reformatted, which makes upstream merges impossible.

---

### 5.2 Kathy Engine — an editor catalog + a scripting compatibility router

**Measured:** 305 files / 145k lines; 147 new files / 63k new lines; 37k lines churn. PlayState 44%, Freeplay 23%, Options 14% similarity.

1. **Three complete chart editors, selectable at runtime.** `states/editors/vanilla104/ChartingState.hx` (5,711 lines), `states/editors/old/OldChartingState073.hx` (3,485), `states/editors/old/OldChartingState063.hx` (3,289), dispatched by `ChartingRouter.hx`. Same pattern for the in-editor playtest (`vanilla104/content/EditorPlayState.hx`).
2. **Three scripting runtimes.** Psych Lua (380 API registrations), HScript/iris, and a **Leather Engine Lua port**: `psychlua/leather/LeatherLuaScript.hx` (2,173 lines) re-implements Leather's globals (`songLower`, `keyCount`, `scrollspeed`, `curStep`, …) and `dofile` semantics in a separate Lua state.
3. **Lua compatibility layer.** `psychlua/LuaCompatRouter.hx`, `LegacyClassAlias.hx`, `LegacyScriptFunctions.hx`, `DeprecatedFunctions.hx` — one mod script can target Kathy, Psych 1.0.4, 0.7.3 or 0.6.3 APIs.
4. **Static mod-compatibility scanner.** `psychlua/compat/ModCompatScanner.hx` (704 lines) + `CompatData.hx` (839) + `CompatProbe.hx`: strips comments/strings from a mod's `.lua`/`.hx`, extracts global calls and hook definitions, and diffs them against a generated database of which names exist in which engine version; surfaced through `options/ModCompatCheckerSubState.hx`. This is the only automated "will this mod work here?" tool in the set.
5. **Spine skeletal-animation support:** `spine/flixel/SkeletonSprite.hx`, `spineflixel/`, `SpineFunctions.hx` (782 lines of Lua bindings), `SpineViewerState.hx` (2,007).
6. **Patched Flixel internals:** `flixel/FlxSprite.hx` (1,716 lines) and `flixel/group/FlxGroup.hx` (970) are engine-source overrides, not subclasses.
7. **Freeplay/story authoring:** categories + editor (`FreeplayCategory.hx`, `FreeplayCategoryEditor.hx` 1,790, `FreeplayTabBar.hx`), `StoryEditorState.hx` (1,113), `StoryPlayerState.hx` (784), `HoldCoverEditorState.hx`, `ResultsScreen.hx`, `RatingCounter.hx`, `KeyViewer` (943).
8. **Mobile + self-describing UI:** `mobile/` (touch buttons, hitboxes, control selection), `PseudoTitleBar.hx` (1,537), plus four dedicated settings states for FPS counter, info display, debug display and extra gameplay options.

**Caveat:** the README calls it *"FOR PERSONAL USE, UNSTABLE — just a personal modified version of Psych Engine Mobile"*; 147 new files with 0 removed makes it a superset of 1.0.4, not a cleanup.

---

### 5.3 Plus Engine — modchart engine, Material 3 UI, real i18n, mod security

**Measured:** 434 files / 131k lines; 291 new / 61.8k new lines; 37.7k churn. Lua API **458** registrations vs 236 in 1.0.4 (+94%).

1. **A complete NotITG/SM-style modchart engine** under `source/modchart/` (README: *"modcharts like NotITG"*):
   * core: `Manager` (882), `PlayField`, `PlayfieldState`, `Config`, `ArrowData`, `PercentArray`, `RotationOrder`, `TransformMode`;
   * modifier system: ~60 shipped modifiers (`Drunk`, `Tipsy`, `Tornado`, `Bounce`, `Confusion`, `Reverse`, `ZigZag`, `Stealth`, `CenterRotate`, `Transform`, `ModSpline`, `PathModifier`, Mid-Fight-Masses/FALSE-PARADISE sets…) with a macro-generated registry (`backend/macros/ModifiersMacro.hx`) and `ModifierGroup`;
   * 3D math: `Quaternion`, `Vector3`, `View3D`;
   * event timeline: `SetEvent`/`EaseEvent`/`RepeaterEvent`/`CallbackEvent`/`AddEvent`;
   * scripted modifiers in Lua and HScript (`LuaModifier`, `ScriptedModifier`);
   * **standalone adapter** (`backend/standalone/adapters/psych/Psych.hx`, `ModchartEditorPreviewContext.hx`) so the engine can run outside a Psych PlayState — the only decoupled architecture in the set.
2. **Material Design 3 UI kit:** `backend/ui/md3/` — `MaterialButton`, `MaterialBox`, `MaterialChip`, `MaterialCheckbox`, `MaterialTextField`, `MaterialLoadingIndicator`, `MaterialProgressIndicator`, `MaterialWavyProgressIndicator`, `MD3Theme`/`MD3Metrics`/`MD3ShapeTools`, `NetworkCheckToast`, plus `options/ThemeAccentColorSubState.hx`.
3. **True localisation layer:** 12 language classes under `backend/languages/` (EnUS, EsLA, EsES, PtBR, FrFR, DeDE, ItIT, NlNL, IdID, JpJP, ZhCN, ZhHK) with `LanguageSubState` (+509 lines) — no other fork in the set has more than the Psych default.
4. **Mod security:** `backend/ModSecurity.hx` (767 lines) + `substates/ModSecuritySubstate.hx` (505) — regex pattern tables for Lua and HScript with high/medium severity, per-file/per-line findings.
5. **Platform/native layer:** `mobile/backend/StorageUtil.hx` (898, JNI), `mobile/objects/TouchButton.hx`, `slushithings/windows/WindowsAPI.hx` + `WindowsCPP.hx` (1,940 lines of Windows-native calls).
6. **Rendering compat + usability:** `shaders/ShaderCompatibility.hx` (701), `debug/FPSCounter.hx` (+971/−30), `debug/TraceDisplay.hx` (676), `backend/MemoryManager.hx` (458), `objects/KeyViewer.hx` (692), `states/ResultsState.hx` (897-line post-song results screen), `psychlua/backend/ScriptedNativeFactory.hx` (671), `backend/Cache.hx`, `AssetLoader`.
7. **Deliberate legacy compatibility:** `states/FreeplayState_Psych.hx` (773) keeps the old freeplay around; README claims hxcodec video compatibility for 0.6.3/0.7.3-era mods.

---

### 5.4 Frozen Engine — replay/ghost system and chart interop

**Measured:** 334 files / 123k lines; 186 new / 58.3k new lines. Freeplay 13%, Options 8% similarity, while `Conductor`/`MusicBeatState` are untouched.

1. **Replay system.** `backend/Replay.hx` (1,037 lines): per-frame `FrameSave{time, pressKey, releaseKey, noteJudgments}`, metadata header, "high fidelity" mode that pre-records judgments. `states/freeplay/LoadReplaySubState.hx` (1,483) for browsing/loading; `objects/HitErrorBar.hx` (660) for judging replay accuracy.
2. **Chart format interop.** `states/editors/content/ChartConvertCore.hx` (784) on top of vendored **moonchart**: import `.sm/.ssc/.osu/.osz/.qua/.qp/.mid/.mc`, export `.sm/.ssc/.osu/.qua`. Its header documents the two real bugs it fixes vs. moonchart's FNF adapter (8-lane modulo wrapping of >7K charts, and `offsetHolds` eating one `stepCrochet`). Plus `ChartSourceSelectSubstate.hx` (1,385), `ChartImportDialog.hx` (572), `ChartMinimap.hx` (1,120).
3. **Win8 "Charm"-style settings replacement:** `options/Win8CharmSettings.hx` (1,302), `backend/ui/Win8DropDown.hx` (518), `options/objects/win10/OptionPreviewLayer.hx`, and a whole parallel option framework (`options/keoptions/KEOptionsMenu.hx` 1,414, `KEOption.hx` 961, `KEKeyBindMenu.hx` 796, `KEConfirmMenu.hx` 598, `KESubMenu.hx`).
4. **Freeplay rework:** `FreeplayCard.hx`, `ToolBar.hx` (821), `SearchSubState.hx` (630), `ModFolderSubstate.hx` (1,018), `OldFreeplayState.hx` (697) retained as fallback.
5. **Diagnostics:** `backend/BlueScreenCrashHandler.hx` (695), `backend/DiffRating.hx`, `objects/KeyboardViewer.hx` (521) + `KeyBoardDisplay.hx` (583), `backend/SongInfoParser.hx`, `backend/CustomChartData.hx` (814), `backend/CreditsData.hx` (847).
6. **Velocity:** this is the *most actively pushed* fork in the set (2026-11-02) and the README is explicit that it is AI-assisted — which shows in the doc-heavy, feature-broad but shallow-in-places code.

---

### 5.5 Mint — making the engine itself scriptable

**Measured:** 169 files / 55.8k lines but only **16 new files / 1.6k new lines** and **17k lines of in-place churn** — the smallest surface with the largest behavioural change. Lua API file similarity is **18%**.

1. **Scripted states.** `backend/ScriptedState.hx` (91) / `backend/ScriptedSubState.hx` (524) let `.hx` scripts take over states; `psychlua/CustomState.hx` + `CustomSubstate.hx` expose `openCustomState`, `switchState`, `openSubstate` to Lua. `onSelectItem`/`onAccept`/`onMusicPlayer` hooks for MainMenu/Freeplay/Options (per `docs/CHANGELOG.md`).
2. **Global scripts.** `psychlua/GlobalScriptHandler.hx` (141): `onCreate`/`onDestroy`/`onUpdate`, plus `onRegisterLuaAPI` — user scripts can **register new Lua functions** (`FunkinLua.registerFunction`).
3. **Script-level debugging:** `debug/Log.hx`, `debug/ScriptTraceDisplay.hx` (155), macro helpers (`backend/macro/{Scripting,Init,Flixel}.hx`) that mirror Codename's `DefinesMacro`.
4. **Chart editor overhaul** (`ChartingState` +1,407/−730 and `content/MetaNote.hx` +451): vortex mode, event icons/tooltips/selection, alt-drag resizing, textured sustains, "toys", waveform for all tracks, live noteskin.
5. **Gameplay internals:** re-sorted note input and a reworked note loop so doubles/triples hit on their frame (per changelog); `Conductor.hx` +314/−54.
6. **Web/desktop niceties:** `backend/JSFileSystem.hx`, F5 state reload (Shift = reload global scripts).

---

### 5.6 Psike Engine — fork that patches the platform, not the game

**Measured:** 125 files / 49.7k lines; 21 new files; 16.3k churn against **0.6.3**. `MusicBeatState` 18%, `Conductor` 40%, Lua file 34%.

1. **Overrides of Flixel/OpenFL/Lime inside the repo:** `openfl/display/Shader.hx` (1,094), `openfl/utils/Assets.hx` (941), `lime/_internal/backend/native/NativeApplication.hx` (918), `flixel/text/FlxText.hx` (1,200), `flixel/util/FlxSave.hx` (672), `flixel/system/FlxSound.hx` (+318/−66 streaming), `lime/media/AudioBuffer.hx`, `openfl/media/SoundChannel.hx`, `lime/.../HTML5AudioSource.hx` and `FlashAudioSource.hx`.
2. **Asset/GPU cache management:** `Paths.hx` with `excludeAsset`/`assetExcluded`, `decacheGraphic` (disposes `__texture`, `bitmapData`, image data), `decacheSound`, `clearUnusedMemory`/`clearStoredMemory`, and explicit `Gc` control (`gc`, `compress`, `_gc`) — the "hardware caching + GC handling" the README advertises.
3. **Lua layer rewritten as a static callback table:** `Lua_helper.init_callbacks` / `link_static_callbacks` / `set_static_callback` — 208 registrations, one closure table per engine rather than per script (`FunkinLua.hx` 1,966/−2,348).
4. **Audio backend fixes:** `NativeAudioSource` 263/−450, `SoundChannel`, `AudioBuffer`; README claims "streaming music".
5. **QoL:** `RatingSpr.hx`, `options/AdvancedSubstate.hx` (157), rewritten Title (266/−492) and Credits (+471), update checker `update/Update.hx` borrowed from Codename, `WindowUtil.hx`.

---

### 5.7 DM-kun / Mind Games — the cutscene framework

**Measured:** 154 files / 51.5k lines; 22 new / 5.8k new lines, 7.6k churn. Package reorg: `psychlua/*` → `scripting/*` (17 files moved), which is why "new" file counts look inflated.

1. **Cutscene engine:** `cutscenes/CutsceneHandler.hx` — timeline of `CutsceneEvent{time, func}` with `onStart`/`finishCallback`/`skipCallback`/`overallFinish`, hold-to-skip pie indicator, pause support; `DialogueCutscene.hx` (456) with per-line portrait/expression/boxState/speed/sound; `substates/CutscenePauseSubstate.hx`.
2. **Audio visualiser object:** `objects/ABotSpeaker.hx` (162) using `funkin.vis.dsp.SpectralAnalyzer` with 7 viz ranges.
3. **Scripting split into modules:** `scripting/{FunkinLua 1798, HScript 599, LuaUtils 517, ReflectionFunctions 324, ShaderFunctions 284, ExtraFunctions 251, TextFunctions 202, DeprecatedFunctions 161, CustomSubstate, CustomState, CallbackHandler}` — a cleaner factoring than Psych 1.0.4's monolithic `psychlua`.
4. **Small systems:** `objects/Countdown.hx`, `backend/CustomSoundTray.hx`, `states/InitState.hx`, `shaders/ShaderHelper.hx`.

---

### 5.8 Psych Engine Mobile (Brenninho) — the surgical platform port

**Measured:** 25 new files / 4.4k lines and only **1.3k churn against 1.0.4** — `PlayState` is 99% identical. This is how to port without forking the game.

1. **Input:** `mobile/TouchInput.hx` (618, multi-touch with `TouchPoint{id,x,y,startX,startY}`), `VirtualPad.hx`, `TouchButton.hx`, `Hitbox.hx`, `TouchCursor.hx`, `MobileButton.hx`.
2. **UI:** `options/MobileControlsState.hx` (556) for drag-and-drop control layout, `MobileSettingsSubState.hx`, `ScreenStyle.hx`, `WideScaleMode.hx`/`WideScreen.hx`, `EditorPad.hx` (299, chart-editor touch pad).
3. **Platform APIs:** `mobile/MobileAPI.hx` (339) — Android via `lime.system.JNI`, iOS via C++ externs (`psych_ios_keep_screen_on`, `psych_ios_battery_level`, `psych_ios_is_charging`, `psych_ios_vibrate`); `StorageUtil.hx` (431), `NativeCrash.hx`, `NativeImport.hx`, `MobileFileReference.hx`, `CopyState.hx` (388, SAF file copy), `DataFolder.hx`, `VSliceImport.hx`/`StageImageImport.hx`.
4. **Scripting bridge:** `psychlua/MobileFunctions.hx` (85 lines) exposing mobile functions to Lua.

---

### 5.9 custom-psych — a rewrite, not a fork

**Measured:** 118 files / 20.8k lines in `src/funkin/**` (Funkin 0.2.x layout); **2–15% similarity** to Psych's PlayState/Conductor/Character/Note. Despite being a GitHub fork of Psych, it does not share Psych's structure.

1. **Gameplay architecture:** `funkin/objects/PlayField.hx` (386) + `Strumline`/`Receptor` + `funkin/huds/DefaultHUD.hx` (325) — multi-playfield, multi-player-instrument design (`playerID`, per-playfield `botplay`, `scrollSpeed`, dynamic `noteHit`/`miss`/`ghostTap` callbacks). Explicitly aimed at VSRG-style gameplay (README).
2. **Flixel internals fork:** `flixel/FlxCamera.hx` (2,235 — batch APIs `startQuadBatch`/`startTrianglesBatch`/`drawTriangles`, `bindScrollPos`), `FlxGame.hx` (895), `FlxState.hx`, `FlxSound.hx` (785), `flixel/system/debug/interaction/Interaction.hx` (577), `lime/_internal/.../NativeAudioSource.hx` (498), `lime/media/AudioSource.hx`.
3. **Own UI toolkit:** `funkin/backend/ui/{PsychUIInputText, PsychUIBox, PsychUIRadioGroup, PsychUIDropDownMenu, PsychUINumericStepper, PsychUISlider}`.
4. **Own content pipeline:** shaders (`RainShader` 511, `ColorSwap`, `RGBPalette`, `WiggleEffect`), `funkin/backend/{Conductor, Paths, Song, Scores, Awards, DiscordClient}`, `substates/{ModSettingsSubState, GameplayModifiersMenu, PauseMenu}`, `states/CalibrateOffsetState`.

---

### 5.10 Psych Engine LTS — the conservative branch

**Measured:** 5 new files, 2.9k churn on Psych **1.0**. `HScript` 64% similar (iris bump), `Main` 78%.

* `debug/Argument.hx` (183) — command-line argument handling (state/level/difficulty/song shortcuts).
* `backend/FunkinSoundTray.hx` (158) — vanilla-style volume tray; `backend/ALSoftConfig.hx` (28) — points OpenAL Soft at a custom config; `psychlua/CustomFlxColor.hx` (108); `states/InitState.hx` (47).
* Lua: `loadSong(name, difficultyNum, difficultyArray)` (custom difficulty lists), `removeVar`, undefined-var guard changes.
* `objects/NoteSplash.hx` (+237/−134): `skin` → `texture` rename, `copyX/copyY`, `inEditor`, per-notedata splash map.
* Verdict: no architecture change; it is the "keep 1.0.x alive" branch, and the only fork here whose diff you could apply as a patch series.

---

### 5.11 The 2021 mod builds (vsdaddico, VsPsychic, VsCytrus, NewVeryCoolPsychic) and AprilFools

These predate the current fork culture: they are *game builds* with a mod inside. Diffed against their true bases:

* **`FNF-VsCytrus`** — Psych **0.3.2** + **171 lines**: PlayState +61 (song-specific events), week/story data, `CharacterEditorState` +10. Content mod. (`Friday Night Fitness` joke mod.)
* **`FNF-VsPsychic`** — Psych **0.3.1**, 4.9k churn: `Character.hx` +368/−160 (custom characters and animation handling), PlayState +976/−1061 (per-song events/cutscenes), `DialogueBoxPsych` rework, flat `ChartingState` +181/−590, `OptionsState` rewritten. Mind Games content drove engine edits, but nothing generalisable was added.
* **`fnf-vsdaddico`** — Psych **0.3**, 5.7k churn: the *subtractive* build — achievements, dialogue boxes, credits, story menu, week data, animated-atlas support and the mods menu were deleted; `OptionsState` replaced (−950/+9); `PlayState` +293/−1880 (engine features stripped out); new `PreferencesSubstate`, `ControlsSubstate`, `NotesSubstate`, `StoryModeSelectSubState`, `AnimationDebug`, `InputItem`. Worth reading only as an example of how much of Psych is optional.
* **`NewVeryCoolPsychic`** — Psych **0.5/0.5.1**, 2.1k churn: the Mind Games full-week build. Real editor work for its era — `ChartingState` +372 (event editing), `EditorPlayState` +206, `FunkinLua` +122, `CharacterEditorState` +120, `StrumNote` +76; `ModsMenuState` deleted (single-mod build); `TheEndState` added. This is the build that fed improvements back into Psych 0.5.x.
* **`PsychEngine-AprilFools`** — effectively **Psych 0.5.3b**: 0 new files, 252 churn lines in 6 files. Adds the **`Blammed Lights Special` event** + colour-cycling `blammedLightsColors` used by Title/MainMenu/StoryMenu/Freeplay, **hardens the Lua sandbox** (`CLENSE` strips `os.execute`, `os.exit`, disables `os`/`io`), makes Lua error alerts Windows-only, removes `Preloader.hx`. Small but genuinely engine-level (security + event system).
* **`ShadowMario/Funkin`** — untouched fork of FunkinCrew `v0.2.7.1` (49 files, 0 changes). It exists as the vanilla reference these builds were diffed against.

---

## 6. Cross-cutting: what the ecosystem is actually converging on

**a) Scripting is the product.** Lua API registrations: 236 (Psych 1.0.4) → 458 (Plus), 382 (Kathy), 271 (Mobile), 242 (DM-kun), 208 (Psike, restructured). New dimensions added:
* global scripts + scriptable states + user-registered API (Mint),
* multi-version API routing and a Leather Engine runtime (Kathy),
* static callback tables (Psike),
* script security scanning (Plus `ModSecurity` + `ModSecuritySubstate`, AprilFools `CLENSE`) — the only malware/exploit mitigation in the set outside of Psych's own `ModSecurity`.

**b) Editors are the differentiator.** Chart-editor similarity: everyone but Psike/LTS/DM-kun rewrote it. Kathy ships three; Frozen adds cross-game import/export; Mint modernises 1.0.4's; NovaFlare merges three editors. Story/week/stage/character/note-splash/hold-cover/Spine viewers also became first-class states in Kathy and NovaFlare.

**c) Menu stack rewrites are cheaper than gameplay rewrites.** Freeplay similarity: 8–23% in Frozen/Kathy/Plus vs. 68% in PlayState. Every serious fork rebuilds Freeplay (search, categories, cards, toolbars) and Options (Material 3, Win8 Charm, KE framework, page-based), while `Conductor`/`Character`/`Song` stay mostly untouched.

**d) Mobile is expected, not exotic.** Three repos ship Android/iOS layers (Mobile, Kathy, Plus), Frozen has a separate mobile repo, NovaFlare does GLSL-ES conversion. The reusable patterns: JNI + iOS C externs for OS services, virtual pad/hitbox widgets, `StorageUtil`, SAF/copy import states, touch support in the chart editor.

**e) Performance work splits into two schools.**
* *Rewrite the runtime* (NovaFlare): hxcpp/GC replacement (documented), render-thread separation, native crash handler.
* *Patch the platform from inside the game* (Psike, custom-psych): override `openfl/`, `lime/`, `flixel/` classes in `source/`, add texture-cache eviction, streaming audio, camera batch APIs.
The second school is much more common (and portable), the first is unproven and largely undocumented outside its own repo.

**f) Mod compatibility is becoming an explicit subsystem.** Rather than "our fork breaks your mod": Kathy's scanner + version router, NovaFlare's V-Slice/CNE loaders + converters, Plus's `FreeplayState_Psych` fallback and hxcodec legacy compat, Frozen's chart importers. This is the clearest trend of 2025–2026.

**g) Where nobody innovated:** `Conductor`, timing/input latency, multiplayer gameplay (only NovaFlare's Nakama backend hints at online), accessibility, and automated testing. No repo in the set ships tests for engine behaviour.

---

## 7. Ranked: the biggest engine changes, by architectural impact

1. **NovaFlare — three engines in one binary** (Psych + V-Slice + Codename) with converters and a Nakama online backend. ~308k lines including vendored trees; own tree 112k lines, PlayState 48% similarity.
2. **Plus Engine — a NotITG-class modchart VM** (~60 modifiers, 3D math, event timeline, Lua/HScript modifiers, standalone adapter) **+ Material 3 UI kit + 12-language i18n + mod security scanner**. 291 new files, 61.8k new lines, Lua API doubled.
3. **Kathy — editor catalog and scripting compatibility router**: three chart editors behind a router, three script runtimes (incl. a Leather Lua port), a static mod-API compatibility scanner, and Spine support. 147 new files, 62.9k new lines.
4. **Frozen — replay/ghost recording + cross-game chart interop** (moonchart: SM/SSC/osu/qua/MIDI), behind a full Freeplay/Options rewrite. 186 new files, 58.3k new lines.
5. **Mint — scriptable engine**: scripted states/substates, global scripts, user-registered Lua API, and a modernised chart editor. Only 1.6k new lines but 17k rewritten; Lua layer 18% similarity.
6. **Psike — platform-level performance fork**: Flixel/OpenFL/Lime overrides, GPU/asset cache eviction, streaming audio, static Lua callback table. 16.3k churn on a 0.6.3 base.
7. **DM-kun — cutscene framework** (`CutsceneHandler` timeline + dialogue cutscenes + visualiser object) and a clean `scripting/` package split.
8. **Psych Engine Mobile — the minimal viable port**: 25 files, 1.3k churn, full touch/control/SAF/JNI/iOS platform layer with PlayState untouched.
9. **custom-psych — a Funkin-style rewrite** with multi-playfield architecture and forked Flixel camera/sound internals (not a Psych fork in practice).
10. **AprilFools (0.5.3b preview)** — the only pre-2023 build with an engine-level security change (Lua sandbox hardening) plus the Blammed-lights event system.
11. **LTS** — maintenance-scale fixes worth cherry-picking (CLI args, difficulty arrays in `loadSong`, NoteSplash refactor).
12. Everything else (`neko`, `VS-Sunky`, `vscytrus`, `VsPsychic`, `NewVeryCoolPsychic`, `vsdaddico`, `Funkin`) is content or historical.

---

## 8. What Phoenix could actually borrow

Checked against this repo's tree (`source/`, 323 `.hx` files) rather than assumed:

| Change in the set | Where it lives there | Phoenix today | Notes |
| --- | --- | --- | --- |
| NotITG-style modchart VM | Plus `source/modchart/**` | no modchart module (only `ModchartSprite` helpers) | Highest-value port. The `backend/standalone/IAdapter` split means it can be grafted without rewriting PlayState. |
| Mod-script security scanning | Plus `backend/ModSecurity.hx` | **already present** (`backend/ModSecurity.hx`, `backend/ScriptSecurityScanner.hx`) | Compare pattern tables; Plus's per-line/severity model is worth diffing. |
| Scriptable states + global scripts | Mint `backend/ScriptedState(.SubState)`, `psychlua/GlobalScriptHandler` | `psychlua/StateScripts.hx` exists, no global-script handler | Medium effort, big for mod authors. |
| Replay / ghost recording | Frozen `backend/Replay.hx` + `LoadReplaySubState` | absent | Independent of UI; only needs the note-hit path. |
| Chart format interop | Frozen `ChartConvertCore` + vendored `moonchart` | absent | Vendoring moonchart adds a dependency; licensing/dep weight to check. |
| Multi-version Lua routing | Kathy `LuaCompatRouter`/`LegacyClassAlias` | absent | Cheap to add as aliases; Kathy's `CompatData` is a generated table you would have to rebuild. |
| Multi-language layer | Plus `backend/languages/*` (12) | absent | Additive; also unlocks localised option menus. |
| Platform port pattern | Mobile `mobile/**` (JNI + iOS externs + SAF import) | `source/mobile/`, `source/android/` exist | Diff approaches; the `MobileAPI`/`StorageUtil` split is cleaner than a monolith. |
| Editor tri-version routing | Kathy `ChartingRouter` + `states/editors/{vanilla104,old}` | single `editors/ChartingState.hx` | Only worth it if you must open pre-1.0 charts in-place. |
| Cutscene timeline | DM-kun `cutscenes/CutsceneHandler` | `play/CutsceneHandler.hx` exists | Compare skip/pause semantics before porting anything. |
| Pixel-exact Flixel overrides | Psike / custom-psych | `source/source-haxelib-patches` (different mechanism) | Prefer the existing patch mechanism over copying class files. |

**Do not copy wholesale:** NovaFlare's vendored V-Slice/CNE trees (three diverging copies of the same game objects), custom-psych's forked `flixel/`/`lime/` classes (unmergeable), or Kathy's 147-new-files/no-removals superset structure.

---

## 9. Reproducing the numbers

```bash
# baseline tags (blobless, one commit each)
git init base-psych && cd base-psych
git remote add origin https://github.com/ShadowMario/FNF-PsychEngine
for t in 0.3 0.3.1 0.3.2 0.4.2 0.5 0.5.2h 0.6.3 0.7.3 1.0 1.0.4; do
  git fetch --filter=blob:none --depth 1 origin refs/tags/$t:refs/tags/$t
  git worktree add ../base-$t $t
done

# a fork, sources only
git clone --filter=blob:none --sparse --depth 1 --branch main \
  https://github.com/LeninAsto/FNF-PlusEngine repos/plusengine
cd repos/plusengine && git sparse-checkout set --no-cone /source/

# lineage + delta
python3 - <<'PY'   # whitespace-normalized md5 per .hx file, compare to each base
...
PY
```

The analysis scripts used (`analyze.py`, `deep.py`, `detail.py`, `simtable.py`, `final_stats.py`), the per-file add/remove/modify index (`detail.json`, `added_report.txt`) and the raw size data (`trees.json`) are kept out of the repo; the consolidated numbers are in [`engine-change-stats.csv`](engine-change-stats.csv).

---

## 10. Caveats

* Baselines are **release tags**. Forks tracking Psych's un-tagged `main` (Plus, Kathy, Frozen, Mint, DM-kun) will show lower "same content" percentages than their true ancestry; treat the base column as *nearest release*, not exact fork point.
* **Vendored code inflates NovaFlare** (≈195k of its 306k "new" lines are V-Slice/Codename trees). Its own-lineage tree is 112k lines — still the second-largest tree in the set, and the largest with a single PlayState.
* **Churn counts formatting-neutralised lines only**, but comment/documentation edits do count. Forks whose authors reformat (NovaFlare) or rewrite comments (Frozen, Plus) look busier than they may be.
* **Claims vs. code:** NovaFlare's hxcpp/ZGC work is documentation-only in this repo; Frozen's and Mobile's READMEs state AI assistance; Kathy's README states personal-use/unstable. Those are quoted as claims, not verified.
* Assets, `Project.xml` flags, build tooling, `mods/` content and CI are out of scope — several of these repos carry tens of thousands of asset files that dwarf their code.
