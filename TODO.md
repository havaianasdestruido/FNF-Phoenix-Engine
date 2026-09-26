# Phoenix Engine — TODO / Roadmap (large feature & cleanup backlog)

Generated from full repo audit. Priority: `[P0]` critical/blocker, `[P1]` high, `[P2]` medium, `[P3]` nice-to-have. Sections grouped by system. Bold = biggest payoff.

---

## 1. BUILD / TOOLCHAIN (all targets green)

- **[P0] HashLink target blocked.** `lime.hdll` missing locally, HL wasn't verifiable, HL agent dead-ended. Install a compatible HashLink (`lime.hdll` + `lime-hdiowrap`), fix any compile errors, re-enable the `hl` CI job in `.github/workflows/main.yml`.
- **[P0] CI Android build.** Local Android can't be validated: NDK **28.1.13356709** fails on `aarch64-linux-android-strip` (NDK 28 ships only `llvm-strip.exe`; wrapper copy was made but build still fails) and NDK 28 libc++ has a `__posix_l_fallback.h` redefinition bug. CI uses NDK **r27c** (no such bug) but emulator/toolchain mismatch must be resolved or documented. Options:
  - Install NDK r27c locally (matches CI) to reproduce `#if mobile` errors faithfully.
  - Or fix the NDK 28 header conflict (locale redefinition) instead of pinning old NDK.
  - Re-run android build to green, then commit + push.
- **[P1] Android source fixes uncommitted.**
  - `source/mobile/CopyState.hx:101`: `new ThreadPool(4, 0)` — note these two fixes were applied but only the import commit `1a8a48d4` was pushed; verify the ThreadPool + PlatformUtilNative fixes are committed.
  - `source/utils/PlatformUtilNative.hx`: missing `#include <sys/utsname.h>` on `#elseif android` branch of `getArchNative`. Fixed in worktree but uncommitted.
- **[P1] macOS/Linux `sendFakeMsgBox` are TODO** (`source/backend/PlatformUtil.hx:10-11`, `source/utils/PlatformUtilNative.hx:86`). Add native `osascript`/`zenity`/`kdialog`-based implementations so crash dialogs work on all desktops; remove the `trace('not available')` stubs.
- **[P1] Hardcoded Android keystore credentials in project.hxp** (`key.keystore`, user/pass `javascriptengine`). Exfiltrate to env vars / CI secrets — shipping build creds in source is a security smell.
- **[P2] Refactor relic `REFACTOR:` comments** — dozens across `source/editors/`, `source/headers/`, `options/`. They document relocations but say nothing actionable. Fold into proper file headers or delete.
- **[P3] Remove dead Flash/Air code paths** — `officialBuild` feature flag never applied (`project.hxp`), unused `renderAll`/`ULTRA_OPTIMIZED` experiments, `WindowColorMode` flash stubs (trace-only).

## 2. GAMEPLAY / PSYCH SYNC (P3 imports)

- **[P2] Add missing `import`s/defines for full Psych parity** — audit found non-compiling-on-clean-machine deps (`backend.MusicBeatState` in `CopyState`, `ChartingUIWaveform` AIR gating). Grep revealed: `WeekData.hx`, `MusicPlayer.hx`, `PsychLua` all fine, but verify `#if desktop` vs `#if (desktop && !air)` at the 5 leftover audit sites (see §9).
- **[P1] Double-chart / charting BPM** `ChartingState.hx:574` TODO "expand more & port the 1.0 system" and `:617` TODO "make BPM changes work properly" — BPM-change-aware step/section math is a real gameplay-integrity gap vs Psych.
- **[P3] Missing funkin.vis cross-target** — `SpectralAnalyzer` patched; check hacking shaders (`Glitch`, `Chromatic`, `Malmo`?) compile on flash/air (`#if desktop` guard audit, §9).

## 3. MOBILE / PLATFORM

- **[P1] Mobile file picker incomplete** — `source/mobile/files/MobileFilePicker.hx` has a generic `StorageFilePicker` only wired to a few spots; chart-import, character-import from file picker are gated `#if desktop`. Verify on-device.
- **[P2] Virtual pad consistency** — touch notes fire on `FlxG.keys` via `FlxVirtualPad`, but charting/editor states also need pad support; check `CopyState`, `ChartingState` for `#if mobile` gaps.
- **[P3] iOS** — likely needs `#if ios` nuances (video/hxvlc below).
- LOW importance menu to set in-game keybinds to fire on hardware triggers (e.g.: on VOL_UP/VOL_DOWN)

## 4. VIDEO / AUDIO

- **[P1] hxvlc video gated desktop-only** — `VideoSprite`/`hxvlc` only on desktop (`isDesktop` gate). On AIR/Flash (no hxvlc) and mobile, videos silently fail or trace-error. Add graceful fallback (display splash/static instead of crashing) or Psych's flash-`VideoSprite` fallback.
- **[P3] Flash MP3 24/48kHz embed warnings** — 3 warnings, harmless, but notes in `BUILDING.md` claim "zero warnings" post-fix; reconcile.
- **[P3] Offsync long-session** — `MusicBeatState`/`Conductor` saved to same-tick; watch for drift on `sustain` notes w/ `playbackRate != 1`.

## 5. DEBUG / LOGGING

- **[P1] `trace()` spam in production hot paths** (Flash/AIR): `source/backend/Paths.hx:61` (`trace(defaultSkin)`), `:563/:866` `trace('oh no its returning null NOOOO')` inside asset fallback — this is on EVERY lookup. Wrap in `#if MAIN_DEBUG` or a `quiet` flag; these belong in debug builds only.
- **[P1] `BuildingEffect.addAlpha` traces every call** (`source/shaders/BuildingEffect.hx:14` `trace(shader.alphaShit.value[0])`) — 60fps spam on tank level.
- **[P3] Leftover stray traces** — `MusicPlayer.hx:100` `trace('Time: ...')` on K key; `WeekEditorState`/`DialogueEditor` `trace("file saved")`.
- **[P3] `DiscordClient.hx:55-56` cast-dep on success** — `request[0].username` may be null on AIR (no hxdiscord_rpc); guard.

## 6. SECURITY

- **[P0] Path traversal** — `WeekData`, `Mods`, `SSPlugin` read user JSON; `Paths.modsJson` splices `songName` into paths. `CoolUtil` mod asset walker uses `FileSystem` unguarded non-sys target? Audit brings up `#if (!target)` correctness. Ensure mod names are sanitized (`..`/absolute) before `FileSystem.exists`.
- **[P1] CrashHandler ref** — `did` handler writes logs into `logs/` w/ `Date.now()` filename; on Android no `sys` — verify guard.
- **[P3] No signature/webhook secrets** — `ChartingSaveLoad`/`WeekData` parse `JSON` without try/catch around `File.getContent` (some are).

## 7. MODDING / SCRIPTS

- **[P1] hscript/Lua mod API parity** — `PsychLua` (`FunkinLua`, `HScript`) methods work, but `#if HSCRIPT_ALLOWED`/`LUA_ALLOWED` only set on `desktop !web !flash !air` (project.hxp:418). No scripting on AIR/Flash — document as intended or shim.
- **[P3] Python (`hython`) not wired everywhere** — check callbacks exposed.

## 8. PERFORMANCE / MEMORY

- **[P3] Alloc-per-frame** in `PlayState` hot loops (notes, sustains, `chartingEvents`) — no pooling for `FlxSprite` note graphics; Psych pooled. Watch HTML5 GC on web.
- **[P3] `FlxG.watch` in FPSCounter** — verify only debug.
- **[P3] `cast` / `Reflect.field` in per-frame paths** — `ChartChartingUI`/`Conductor` use `Reflect.field(ClientPrefs, ...)` in window accessors; cache static before loop.

## 9. GUARD AUDIT — REMAINING `#if desktop` ELIGIBLE FOR `!air`

Audited; these 5 sites were flagged but NOT changed (only 3 charting sites converted). Decide: convert or document why not.

| Site | Why flagged |
|---|---|
| `source/utils/CoolUtil.hx` ~116 (resW/resH/resetResScale) | Flash-only-safe desktop funcs |
| `source/play/PlayState.hx` ~465 | promote `#if desktop` music? flags |
| `source/options/OptionsState.hx`:26 / `GraphicsSettingsSubState.hx` 73,134 | resolution list on AIR |
| `FunkinGame.hx` 8-21 (fullscreen/window flags) | AIR window APIs differ |

## 10. CI / REPO HYGIENE

- **[P1] .github CI android emulator `CopyState`** — same 2 fixes; confirm CI picks them via `1a8a48d4`+.
- **[P2] NDK pin** — commit `.github` to use **r27c** explicitly (matches verified toolchain) so CI != local.
- **[P3] BUILDING.md "0 warnings" vs 3 MP3 warnings** — fix text.

---

## TOP 5 (do these first)
1. Commit + push the two uncommitted Android fixes (`CopyState.hx` ThreadPool, `PlatformUtilNative.hx` utsname) — they ARE the Android CI fix.
2. Resolve NDK version (install r27c or fix the NDK28 libc++ redefinition) so Android builds locally → green.
3. HashLink target: install working `lime.hdll`, build, re-enable CI `hl` job.
4. Kill `Paths.hx`/`BuildingEffect.hx` production trace spam.
5. Path-traversal + keystore-secret hardening (security).
