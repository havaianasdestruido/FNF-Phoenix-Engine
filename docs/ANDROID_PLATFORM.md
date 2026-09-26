# Android Platform Layer

This document describes the Phoenix Engine Android platform integration:
the native Java extensions, the Haxe API modules that wrap them, and how
the engine is wired to both.

Everything described here is **Android-only**. On every other target the
Haxe modules compile to no-ops (empty bodies behind `#if android`), so
gameplay code never needs to know about the platform layer.

---

## Architecture

```
┌────────────────────────────────────────────────────────────┐
│ Gameplay code (PlayState, editors, options...)             │
│   talks only to: android.platform.* + MobileFilePicker     │
├────────────────────────────────────────────────────────────┤
│ Haxe API modules            source/android/platform/*.hx   │
│   AndroidMedia / AndroidSystem / AndroidDisplay / ...      │
│   (cached JNI method handles, signal fan-out, no-ops       │
│    off-Android)                                            │
├────────────────────────────────────────────────────────────┤
│ Bridge                  source/android/platform/           │
│   AndroidBridge.hx — JNI helpers + event dispatcher        │
├────────────────────────────────────────────────────────────┤
│ Java extensions            android/src/quack/fnf/phoenix/  │
│   PhoenixCore / PhoenixMedia / PhoenixMediaService /       │
│   PhoenixDisplay / PhoenixStorage / PhoenixInput           │
│   (registered via `config.set("android.extension", ...)`;  │
│    Lime's GameActivity instantiates + dispatches to them)  │
└────────────────────────────────────────────────────────────┘
```

- **Haxe → Java**: lazily cached `JNI.createStaticMethod` handles.
  Arrays cross the boundary as CSV strings; byte buffers via
  `haxe.io.Bytes.ofData`.
- **Java → Haxe**: extensions call `PhoenixCore.dispatch(event, arg)`
  which routes through a registered `HaxeObject` to
  `AndroidBridge.onAndroidEvent(event, arg)`. The bridge fans events out
  to the module signals (`lifecycle`, `media_*`, `focus`, `thermal`,
  `memory`, `gamepad_*`, `hwkey`, `display`, `deeplink`, `intent`,
  `permissions`, `recovery`).
- The boot hook lives in `Main.hx`:
  `android.platform.AndroidPlatform.init()` (Android only) initializes the
  bridge, lifecycle handling, gamepad tracking, thermal watching and display
  watching.

### Build integration (`project.hxp`)

The Android pieces are injected **only for the Android target**
(`configureAndroidRuntime()`):

- `javaPaths.push("android/src")` — Lime copies the Java extensions into
  the generated Gradle project's java source set.
- `templatePaths.push("templates")` — engine templates override Lime's:
  - `templates/android/MainActivity.java` — deep-link intents
    (`onNewIntent`) and hardware-key interception.
  - `templates/android/template/app/src/main/AndroidManifest.xml` —
    `phoenix://` intent filter, `PhoenixMediaService`
    (`foregroundServiceType="mediaPlayback"`), FileProvider,
    StorageProvider.
- `config.set("android.extension", [...])` — registers the five
  `Extension` subclasses (`PhoenixCore`, `PhoenixDisplay`,
  `PhoenixInput`, `PhoenixMedia`, `PhoenixStorage`) with Lime's
  GameActivity. `PhoenixMediaService` is an Android `Service`, declared
  in the manifest template instead.
- `config.set("android.permission", [...])` — Lime's defaults plus
  `POST_NOTIFICATIONS`, `FOREGROUND_SERVICE`,
  `FOREGROUND_SERVICE_MEDIA_PLAYBACK`.
- Signing: `PHOENIX_KEYSTORE`, `PHOENIX_KEYSTORE_PASSWORD`,
  `PHOENIX_KEYSTORE_ALIAS`, `PHOENIX_KEYSTORE_ALIAS_PASSWORD` env vars,
  falling back to a local `key.keystore` for development. No credentials
  are stored in source.
- Native desktop-only haxelibs (`hxdiscord_rpc`, `hxvlc`, `hxluajit`,
  `hxnativefiledialog`) are gated to desktop builds so Android never
  links them.

---

## Haxe API modules (`source/android/platform/`)

All modules are safe to reference from cross-platform code: every call is
a no-op outside `#if android` unless noted.

| Module | Purpose | Highlights |
| --- | --- | --- |
| `AndroidPlatform` | One-shot boot | `init(autoPauseAudio, watchThermal, watchDisplay)` |
| `AndroidBridge` | JNI plumbing | Event dispatch, `ensureRegistered()` |
| `AndroidLifecycle` | Activity lifecycle | `onCreate/onResume/onPause/onStop/onDestroy` signals, optional auto-pause of `FlxG.sound.music` |
| `AndroidMedia` | MediaSession/audio focus | `updateNowPlaying(title, artist, ?durationMs)`, `setPlaybackState(state, positionMs, speed)`, `updateNotification`, foreground service start/stop, `requestAudioFocus()`/`abandonAudioFocus()`, `getAudioInfo()`, signals `onPlay/onPause/onStop/onNext/onPrevious/onSeek/onAudioFocusChanged` |
| `AndroidSystem` | Device state | `getThermalStatus()`/`watchThermalStatus()`/`onThermalStatus`, `onLowMemory`/`onTrimMemory`, `getBatteryInfo()`, `acquireWakeLock()`/`releaseWakeLock()`, `setRecoveryState(blob)`/`consumeRecoveryState()` |
| `AndroidDisplay` | Screen info | `getInfo()` (size, DPI, orientation, refresh), `getCutoutInsets()`, `getRefreshRate()`, `setImmersive()`, `setCutoutMode()`, `setPreferredRefreshRate()`, `onChanged` |
| `AndroidGamepad` | Controllers | `getDevices()`/`getDevice(id)` with Xbox/PlayStation/Switch/HID identification, `onConnected`/`onDisconnected`, rumble via `vibrate(deviceId, ms)` |
| `AndroidHardwareInput` | Physical keys | Volume-key interception (`enableVolumeKeys()`/`disableVolumeKeys()`), `onKey(keyCode, down)` signal |
| `AndroidHaptics` | Vibration | `vibrate(ms)`, `vibratePattern(pattern, repeat)`, `cancel()` |
| `AndroidIntents` | System intents | `openUrl`, `openSettings`, `openFile`, `shareFile`, `shareText`, `viewContentUri`, `onDeepLink` signal (`phoenix://...`) |
| `AndroidNotification` | Notifications | `notify(id, title, text)`, `cancel(id)`, `requestPermission()` (API 33+) |
| `AndroidStorage` | SAF / content URIs | `openDocument`, `createDocument`, `openDocumentTree`, `readUriBytes/Text`, `writeUriBytes/Text`, `importUri`, `exportFileToUri`, `persistUriPermission`, `extensionToMime` |
| `AndroidDiscord` | Presence stand-in | Publishes the engine's Discord presence strings to the media session (Discord RPC is desktop-only) |

Compatibility bindings for common Android classes live under
`source/android/` (`Permissions`, `Settings`, `content.Context`,
`os.Build`, `os.Environment`).

### Gameplay integration (`play.helpers.PlayStateAndroidMedia`)

`PlayState.create()` starts and `PlayState.destroy()` stops the Android
media integration:

- The current song is published to the MediaSession
  (title/duration at create; state + position refreshed once per second).
- Audio focus is requested on start and abandoned on stop; focus **loss
  pauses the game**, **duck** lowers music volume, **gain** restores it.
- The screen wake lock is held for the duration of gameplay.
- A MediaStyle notification is kept in sync via `PhoenixMediaService`.
- A recovery blob (`{type:"song", song, difficulty}`) is persisted while
  playing and cleared on a clean exit, so a process kill mid-song can be
  recovered (see below).

Media buttons: **play** resumes from the pause menu, **pause/stop** open
it. `seek` is exposed as a signal (`AndroidMedia.onSeek`) rather than
applied automatically, because seeking mid-song would desync the chart.

### Process-death recovery

`PlayStateAndroidMedia.start()` writes the recovery blob via
`AndroidSystem.setRecoveryState()`. `TitleState.checkRecoveryState()`
(Android only) consumes it on boot: if it describes a song whose chart
still exists, the player gets a prompt to jump straight back into it.
A clean exit clears the blob, so the prompt never appears after quitting
normally.

---

## Files & user data (`mobile.files.MobileFilePicker`)

`source/mobile/files/MobileFilePicker.hx` is the cross-platform facade:

- **Android**: Android SAF via `AndroidStorage`
  (`ACTION_OPEN_DOCUMENT` / `ACTION_CREATE_DOCUMENT` /
  `ACTION_OPEN_DOCUMENT_TREE`), full byte transfer through the Java
  layer. `PickedFile` carries `name`, `uri`, `path` and `data`.
- **Desktop/sys**: `lime.ui.FileDialog` open/save dialogs.

API: `openFile(onResult, ?extensions, ?title)`,
`saveFile(data, suggestedName, ?mime, ?title, ?onDone)`, `saveText`,
`openFolder(onResult, ?title)`.

Wired into: chart import (`ChartingSaveLoad.promptBackup`), chart &
event export (`saveLevel`/`saveEvents`), character import (the
**Import Char** button in `CharacterEditorState`) and character export.
Desktop keeps the traditional `FileReference` download flow.

---

## Editor virtual pads

All editor states now create touch pads (`#if mobile`) with action
buttons mirroring their keyboard shortcuts:

- `ChartingState` — `BOTH_FULL` pad + `CHART_EDITOR` layout; dpad up/down
  next/previous section, A = playtest (Enter), B = exit (Backspace,
  with unsaved-changes prompt), X = play/pause audio (Space),
  Y = test song (Esc).
- `CharacterEditorState` — `BOTH_FULL` + `CHARACTER_EDITOR`.
- `DialogueCharacterEditorState`, `MenuCharacterEditorState`,
  `NoteSplashDebugState` — pads with their matching layouts.

---

## Known follow-ups

- `phoenix://` deep links reach Haxe (`AndroidIntents.onDeepLink`) but
  per-screen routing UI is not implemented yet (roadmap P3).
- In-game keybind menu for hardware triggers (volume keys) is deferred
  per the roadmap; `AndroidHardwareInput` is the intended backend.
- Media `seek` is intentionally not applied mid-song.
- Low-latency audio relies on Lime/SDL's Android backend (AAudio/OpenSL);
  no custom backend is provided.
