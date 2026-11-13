---
title: Mobile
sidebar_position: 8
description: Touch controls, storage and permissions, the first-run copy state, and the Android platform services.
---

# Mobile

Mobile support (Android + iOS) is isolated in `source/mobile/` and
`source/android/`, so desktop code paths stay untouched.

## First run — `mobile.CopyState`

Lime ships assets inside the APK, but mods, saves and editor output need a writable
location. On launch `Main` checks `mobile.CopyState.checkExistingFiles()`; if assets have
not been copied yet, `CopyState` becomes the initial state and copies them into app
storage with a progress screen. Files listed in `CopyState-Ignore.txt` are skipped.

After that, `Sys.setCwd(mobile.StorageUtil.getStorageDirectory())` makes every relative
path — including `mods/` — resolve inside storage.

## Storage & permissions

`mobile.StorageUtil`:

- `initStorageDirectory()` — called from `Main` before asset/mod access on Android,
- `getStorageDirectory()` — the writable app-specific root,
- helpers for creating directories and saving content.

`android.platform.AndroidStorage` wraps the Java side for SAF and `content://`
URIs. App-specific storage needs no runtime storage or media permission, and
“manage all files” access is not requested. The manifest removes broad
storage/media permissions even if a dependency declares them; the only runtime
permission prompt kept by the platform layer is the opt-in notification prompt.

:::note[Known issue]

A song with valid files can still show the "no JSON/voices/instrumental" dialog —
accepting it works fine.

:::

## Touch controls

| Module | Role |
|---|---|
| `mobile.MobileControls` | chooses and owns the active control scheme |
| `mobile.flixel.FlxVirtualPad` | directional + action pad for menus |
| `mobile.flixel.FlxHitbox` | the four-lane gameplay hitbox |
| `mobile.flixel.FlxButton` | touch-friendly button base |
| `mobile.MobileControlsSelectSubState` | layout picker |
| `mobile.options.MobileOptionsSubState` | mobile-only settings (listed in the options menu on android/ios only) |

Opacity and extra toggles come from `ClientPrefs.mobileCAlpha` and `mobileCEx`.
Menus add a virtual pad; `PlayState` adds the hitbox. Both route into the same
`backend.Controls` actions as keyboard input, so gameplay code never checks for touch.

## Guarded destructive actions

Deleting a mod/save/chart, leaving a song and resetting settings are easy to hit by
accident on a phone. `objects.TouchTarget` lays an invisible rectangle of at least
**88 × 88 game units** (~44 dp at 2×) over the existing art, centred on it and padded
by 12 units; the sprite itself is never resized or recoloured. The hit area follows
animated menu rows every frame, so it survives selection lerps and screen resizes.

`objects.HoldToConfirm` combines that hit area with the renderer-free
`backend.HoldToConfirmLogic` state machine. Input comes from the mouse, every active
touch and a `held` callback (keyboard, gamepad or virtual pad); releasing early,
dragging off the target, tapping elsewhere, losing focus or running out of time
cancels the gesture. A small runtime progress bar and hint give feedback without
shipping new art.

Two gestures are available, selected by **Options → Visuals and UI → Hold to
Confirm**:

| Mode | Gesture |
|---|---|
| On (default) | Keep the press down for **Hold Duration** seconds (0.3–2 s). |
| Off | Press once to arm, release, then press again within three seconds. |

Turning the option off never restores single-tap behaviour. The guard is one-shot:
`onConfirm` runs exactly once. It is wired into `objects.Prompt` (destructive OK/CANCEL
questions such as replacing a mod folder, clearing chart progress or importing a
settings backup), `ResetScoreSubState` ("Yes" wipes saved scores), the pause menu's
`Exit to ...` submenu, the guarded **Reset All Settings** row in every options list,
and SHIFT+RESET in the Gameplay Changers menu. Chart-editor buttons that delete
sections/sides/events or load a different event sheet use the same guard, and the editor's
"Ignore Progress Warnings" checkbox can no longer bypass it for destructive prompts.
CANCEL/Back/No stay single taps.

## File picking and app files

`mobile.files.MobileFilePicker` bridges to the platform picker, used by the editors for
loading and saving charts and characters on device.

On Android, `PhoenixDocumentsProvider` adds three roots to the system Files picker
when Lime's existing `SHARE_FILES` feature is enabled. Lime derives this from the
`SHARE_MOBILE_FILES` Haxe define, which `project.hxp` sets for mobile builds, so
normal Android builds retain the previous system-visible sharing behavior.

- **Crash Logs** — read-only access to crash reports written in `crash/`.
- **VLogs** — read-only access to the verbose session log `backend.VLog` writes
  to `vlog/log.txt` (RAM usage, per-frame timings, lag spikes, asset-cache
  events, Lua/Python/HScript traces) once it is enabled in
  **Options → Misc → "Enable VLog"**; it is off by default, so the folder only
  appears after the first enabled session.
- **Mods** — browse and manage the runtime `mods/` directory; the provider supports
  creating folders/files, reading and writing files, renaming files, and deleting files
  or subfolders.

All three roots use the same app-specific external-files directory as the game's
runtime working directory. Only these three folders are exposed. Android startup creates `mods/`
so the Mods root is a real, writable folder from the first launch; `crash/` appears
once `CrashHandler` writes a report; `vlog/` is created when the VLog option is
enabled (off by default). Browsing a root never creates its directory.
If `getExternalFilesDir(null)` returns no path, or Android reports its volume as
unavailable, no roots are returned. Mounted read-only storage remains browsable but
cannot be written; if storage later becomes unavailable, document operations fail.
Static traversal and symlink escapes are rejected, but Java path-based checks cannot
make the check/use pair atomic against an independent concurrent filesystem writer.

## The Android platform layer

Full detail lives in `docs/ANDROID_PLATFORM.md` and
[Platform layer](../architecture/platform-layer.md). In short:

```text
gameplay → android.platform.*  →  AndroidBridge (JNI)  →  quack.fnf.phoenix.android.*
```

| Service | What it provides |
|---|---|
| `AndroidPlatform` | boots everything from `Main` |
| `AndroidLifecycle` | pause/resume/focus events |
| `AndroidMedia` + `PhoenixMedia`/`PhoenixMediaService` | Media3 MediaSession metadata, lock-screen and Bluetooth controls, MediaSessionService-backed background visibility |
| `AndroidDisplay` | cutouts, insets, refresh rate, immersive mode |
| `AndroidStorage` | SAF pickers and `content://` URI reads/writes |
| `AndroidHardwareInput`, `AndroidGamepad`, `AndroidHaptics` | keys, controllers, vibration |
| `AndroidIntents`, `AndroidNotification` | intents (including `phoenix://` deep links) and notifications |
| `AndroidDiscord`, `AndroidSystem` | RPC and device info |

Off Android, every one of these modules compiles to an empty body, so calling them from
shared code is safe.

## Building for mobile

```bash
lime build android          # runs setup/android-copy-stl.sh via project.hxp
lime build ios -nosign      # local iOS build; not part of CI
```

The Android build **must** include `libc++_shared.so`; see
[Troubleshooting](../getting-started/troubleshooting.md#android-dlopen-failed-libc_sharedso-not-found).
CI (`.github/workflows/main.yml`) builds Android and verifies the APK's native
libraries. `mobile-release.yml` reuses that build to publish the APK. iOS builds
remain local-only.

## Window and orientation

`project.hxp` sets mobile windows to `0 × 0` (native resolution), `LANDSCAPE`, not
fullscreen, resizable on Android and fixed on iOS.
