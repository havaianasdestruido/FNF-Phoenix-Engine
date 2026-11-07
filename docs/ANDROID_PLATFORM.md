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
│ Java services               source/android/src/                 │
│   quack/fnf/phoenix/android/*.java                              │
│   PhoenixCore / PhoenixMedia / PhoenixMediaService /             │
│   PhoenixDisplay / PhoenixStorage / PhoenixInput /               │
│   PhoenixDocumentsProvider                                 │
│   (extensions use `android.extension`; DocumentsProvider   │
│    is registered directly in the manifest)                │
└────────────────────────────────────────────────────────────┘
```

- **Haxe → Java**: lazily cached `JNI.createStaticMethod` handles.
  Arrays cross the boundary as CSV strings; byte buffers via
  `haxe.io.Bytes.ofData`.
- **Java → Haxe**: extensions call `PhoenixCore.dispatch(event, arg)`
  which routes through a registered `HaxeObject` to
  `AndroidBridge.onAndroidEvent(event, arg)`. The bridge fans events out
  to the module signals (`lifecycle`, `media_*`, `focus`, `memory`,
  `gamepad_*`, `hwkey`, `display`, `deeplink`, `intent`, `permissions`,
  `recovery`).
- The boot hook lives in `Main.hx`:
  `android.platform.AndroidPlatform.init()` (Android only) initializes the
  bridge, lifecycle handling, gamepad tracking and display watching from
  Flixel's one-shot `postGameStart` signal. This is after the first state and
  timer manager are ready, not during `Main`'s constructor before stage attachment.

### Build integration (`project.hxp`)

The Android pieces are injected **only for the Android target**
(`configureAndroidRuntime()`):

- `javaPaths.push("source/android/src")` — Lime copies the Java extensions into
  the generated Gradle project's java source set.
- `dependencies.push(new Dependency("phoenix-media3", "source/android/media3"))`
  adds a tiny local Android library module. Its pinned
  `androidx.media3:media3-session:1.6.1` dependency reaches the app without
  replacing Lime's entire `app/build.gradle` template.
- `templatePaths.push("source/templates")` — engine templates override Lime's:
  - `source/templates/android/MainActivity.java` — deep-link intents
    (`onNewIntent`) and hardware-key interception.
  - `source/templates/android/template/app/src/main/AndroidManifest.xml` —
    `phoenix://` intent filter, the exported Media3 `PhoenixMediaService`
    (`foregroundServiceType="mediaPlayback"` plus the
    `androidx.media3.session.MediaSessionService` discovery action),
    FileProvider, and the `PhoenixDocumentsProvider` SAF provider. Its
    registration remains behind Lime's `SHARE_FILES` template condition
    (derived from `SHARE_MOBILE_FILES`).
- `config.push("android.extension", extension, true)` — registers the five
  `Extension` subclasses (`PhoenixCore`, `PhoenixDisplay`,
  `PhoenixInput`, `PhoenixMedia`, `PhoenixStorage`) with Lime's
  GameActivity. `PhoenixMediaService` is an Android `Service` and
  `PhoenixDocumentsProvider` is a framework `DocumentsProvider`; both
  are declared directly in the manifest template.
- `config.push("android.permission", permission, true)` — an explicit minimal
  list for networking, vibration, wake locks, `POST_NOTIFICATIONS`,
  `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_MEDIA_PLAYBACK`. Broad storage
  and media-library permissions are intentionally omitted; app-owned files
  and SAF imports do not require them. The manifest template also carries
  `tools:node="remove"` entries for those broad permissions in both
  `uses-permission` and `uses-permission-sdk-23` form, so a dependency manifest
  cannot reintroduce image/audio/storage prompts into the merged APK.
- `android:requestLegacyExternalStorage` and
  `android:preserveLegacyExternalStorage` are explicitly `false`. Phoenix does
  not opt back into legacy shared storage on Android 10, including upgrades
  from an older install that had legacy storage enabled.
- Signing: `PHOENIX_KEYSTORE`, `PHOENIX_KEYSTORE_PASSWORD`,
  `PHOENIX_KEYSTORE_ALIAS`, `PHOENIX_KEYSTORE_ALIAS_PASSWORD` env vars,
  falling back to a local `key.keystore` for development. No credentials
  are stored in source.
- Native desktop-only haxelibs (`hxdiscord_rpc`, `hxvlc`, `hxluajit`,
  `hxnativefiledialog`) are gated to desktop builds so Android never
  links them.

### Android SDK and Java compatibility

The Android SDK values are pinned in `project.hxp` and match the defaults from
the exact Lime revision pinned in `hmm.json` (`lime-8.1.2`, commit
`45816ca456764761cbea8d3cc57701a592f892f1`):

| Setting | Effective value | Source |
| --- | ---: | --- |
| Minimum Android API | 21 | `project.hxp`; matches Lime's default |
| Target Android API | 36 | `project.hxp`; matches Lime's default |
| Compile SDK | 36 | Lime passes the target SDK through as `ANDROID_BUILD_SDK_VERSION` |
| Android Build Tools | 36.0.0 | `project.hxp`; installed by Android CI |
| Android NDK | 27.0.12077973 (r27) | Installed and selected by both Android workflows |
| Android Gradle Plugin / Gradle | 8.9.2 / 8.11.1 | Lime's Android template defaults |
| Java build JDK | 17 | Android CI toolchain |

The generated Gradle template does not set Java `sourceCompatibility` or
`targetCompatibility`; the provider uses Java language constructs supported by
the Android toolchain. `DocumentsProvider`/`DocumentsContract` are available
before the app's API-21 floor. Rename support, root `IS_CHILD`, and grant
revocation are API-21 behaviors and are guarded where applicable; the per-path
external-storage state check also uses an API-21 method and fails closed below
the floor. The CI build installs
API 36 and Build Tools 36.0.0 to match Lime's generated project.

### Startup and storage permissions

`Main` calls `StorageUtil.initStorageDirectory()` before checking or copying
assets. This validates/creates the app-specific directory and changes the
working directory inside one error boundary. On Android it also creates the
`mods/` directory that the `PhoenixDocumentsProvider` Mods root exposes, so the
system Files picker always backs that root with a writable folder; a failure
there is logged and does not abort startup. If storage is unavailable, the
engine shows a storage error and stops rather than continuing in the wrong
directory. Existing mods and player data are not deleted or migrated.

On the supported API-21+ devices, `Context.getExternalFilesDir(null)` requires
**no runtime storage or media permissions**. Startup must not request them,
poll an asynchronous permission request, or show the old “expect a crash”
notice. User-selected imports/exports use SAF grants instead. “Manage all
files” access is not required and is not requested; the only runtime permission
prompt kept by the platform layer is the opt-in notification permission.

Regression checks: `bash tests/haxe/run-android-permission-policy.sh` exercises
the real HXP allowlist, serialization, legacy-storage flags and manifest
removals. The Android build then runs
`tools/check_android_documents_manifest.py` against Gradle's merged manifest to
catch permissions contributed by dependencies.

`Main` is constructed before it is attached to the OpenFL stage. Installing
`PhoenixScaleMode` immediately invokes `FlxGame.onResize`, so `resizeGame`
applies the viewport but defers state/debugger callbacks while `_state` is
null. `FlxGame.create()` reapplies the resize after creating the first state.
Without this guard, startup can crash after dismissing the old notice and
fail again without a notice on relaunch.

Device checks need a rebuilt APK: test a fresh install, force-stop/relaunch, an
upgrade preserving existing mods/saves, and background/resume during initial
asset copying. With “manage all files” access both denied and granted, confirm
that no image/audio/storage permission prompt appears; only the opt-in
notification prompt is expected.

### System-visible app directories (`PhoenixDocumentsProvider`)

Lime's Android template only registers its generic `StorageProvider` when
`SHARE_FILES` is true; Lime derives that value from the
`SHARE_MOBILE_FILES` Haxe define. Phoenix keeps the same condition around its
replacement provider. `project.hxp` sets `SHARE_MOBILE_FILES` for mobile builds,
so normal Android builds continue to expose the SAF provider; builds without
the define omit it rather than silently enabling a new exported component.

The provider roots resolve from the same `Context.getExternalFilesDir(null)`
directory that `mobile.StorageUtil.getStorageDirectory()` returns. `Main` sets
that directory as the working directory, where `Paths.mods()` resolves to
`mods/`, `CrashHandler` writes reports under `crash/` and `backend.VLog`
writes the verbose session log to `vlog/log.txt` when it is enabled in
Options → Misc:

| SAF root | Relative directory | Access |
| --- | --- | --- |
| **Mods** | `mods/` | Read/write; create folders/files, rename files, delete files/subfolders |
| **Crash Logs** | `crash/` | Read-only; copying reports out of the game |
| **VLogs** | `vlog/` | Read-only; copying the verbose `log.txt` out of the game |

Only these three roots are exposed. `mobile.StorageUtil.initStorageDirectory()`
creates `mods/` during Android startup, so the Mods root backs onto a real,
writable directory from the first launch; if that creation fails startup still
continues, because the engine treats a missing mods directory as "no mods
installed". `crash/` is created by `CrashHandler` when it writes a report, and
`vlog/` is created by `backend.VLog` once the player enables
**Options → Misc → "Enable VLog"** (the vlog is off by default), so the VLogs
root backs onto a real directory from the first enabled session. Browsing a
root never creates its directory, and a root whose directory is missing simply lists no
children. If `getExternalFilesDir(null)` returns no directory, or Android
reports its volume as unavailable, no roots are returned.
Mounted read-only storage remains browsable but cannot be written. If storage
becomes unavailable later, document operations fail with
`FileNotFoundException`. Static traversal and symlink escapes are rejected,
and each path is revalidated near filesystem operations. The Android
`java.io.File` API does not make the check/use pair atomic, so this is not a
defense against a concurrent
filesystem writer with independent access to the same directories. The
provider is protected by `MANAGE_DOCUMENTS` and is intended for Android's
system DocumentsUI through SAF grants.

---

## Haxe API modules (`source/android/platform/`)

All modules are safe to reference from cross-platform code: every call is
a no-op outside `#if android` unless noted.

| Module | Purpose | Highlights |
| --- | --- | --- |
| `AndroidPlatform` | One-shot boot | `init(autoPauseAudio, watchDisplay)` |
| `AndroidBridge` | JNI plumbing | Event dispatch, `ensureRegistered()` |
| `AndroidLifecycle` | Activity lifecycle | `onCreate/onResume/onPause/onStop/onDestroy` signals, optional auto-pause of `FlxG.sound.music` |
| `AndroidMedia` | Media3 MediaSession/audio focus | `updateNowPlaying(title, artist, ?durationMs, ?album, ?artworkPath)`, `setPlaybackState(state, positionMs, speed)`, MediaSessionService start/stop, `requestAudioFocus()`/`abandonAudioFocus()`, `getAudioInfo()`, signals `onPlay/onPause/onStop/onNext/onPrevious/onSeek/onAudioFocusChanged` |
| `AndroidSystem` | Device state | `onLowMemory`/`onTrimMemory`, `getBatteryInfo()`, `acquireWakeLock()`/`releaseWakeLock()`, `setRecoveryState(blob)`/`consumeRecoveryState()` |
| `AndroidDisplay` | Screen info | `getInfo()` (size, DPI, orientation, refresh), `getCutoutInsets()`, `getRefreshRate()`, `setImmersive()`, `setCutoutMode()`, `setPreferredRefreshRate()`, `onChanged` |
| `AndroidGamepad` | Controllers | `getDevices()`/`getDevice(id)` with Xbox/PlayStation/Switch/HID identification, `onConnected`/`onDisconnected`, rumble via `vibrate(deviceId, ms)` |
| `AndroidHardwareInput` | Physical keys | Volume-key interception (`enableVolumeKeys()`/`disableVolumeKeys()`), `onKey(keyCode, down)` signal |
| `AndroidHaptics` | Vibration | `vibrate(ms)`, `vibratePattern(pattern, repeat)`, `cancel()` |
| `AndroidIntents` | System intents | `openUrl`, `openSettings`, `openFile`, `shareFile`, `shareText`, `viewContentUri`, `onDeepLink` signal (`phoenix://...`) — subscribe via `subscribeDeepLink(cb)` so a buffered cold-start link is confirmed delivered |
| `AndroidNotification` | Notifications | `notify(id, title, text)`, `notifyEvent(id, title, text)` (opt-in), `cancel(id)`, `requestPermission()` (API 33+) |
| `AndroidStorage` | SAF / content URIs | `openDocument`, `createDocument`, `openDocumentTree`, `readUriBytes/Text`, `writeUriBytes/Text`, `importUri`, `exportFileToUri`, `persistUriPermission`, `extensionToMime` |
| `AndroidDiscord` | Presence stand-in | No-op on Android: keeps `DiscordClient` platform-agnostic without ever touching the media session, which is owned by `PlayStateAndroidMedia` (Discord RPC is desktop-only) |


### JNI Bridge Contract

There are 56 `JNI.createStaticMethod` sites in `source/android/platform/` (plus external SDL bindings).
Each binds a Java method by string name *and* signature. A Java rename or
signature edit still compiles and fails only at runtime as a silent no-op.

*   Validate: `python3 tools/check_android_bridge.py --check` (also run in CI).
*   Regenerate this table: `python3 tools/check_android_bridge.py > docs/table.md` (Phoenix rows only).

| Haxe Module | Java Class | Method | Signature | Status |
|---|---|---|---|---|
| `AndroidSystem.hx` | `PhoenixCore` | `acquireWakeLock` | `()V` | OK |
| `AndroidBridge.hx` | `PhoenixCore` | `clearPendingDeepLink` | `()V` | OK |
| `AndroidSystem.hx` | `PhoenixCore` | `getBatteryInfo` | `()Ljava/lang/String;` | OK |
| `AndroidSystem.hx` | `PhoenixCore` | `getDeviceInfo` | `()Ljava/lang/String;` | OK |
| `StorageUtil.hx` | `PhoenixCore` | `getExternalFilesDir` | `()Ljava/lang/String;` | OK |
| `AndroidBridge.hx` | `PhoenixCore` | `getPendingDeepLink` | `()Ljava/lang/String;` | OK |
| `AndroidSystem.hx` | `PhoenixCore` | `getRecoveryState` | `()Ljava/lang/String;` | OK |
| `AndroidSystem.hx` | `PhoenixCore` | `getSDKInt` | `()I` | OK |
| `AndroidBridge.hx` | `PhoenixCore` | `registerCallback` | `(Lorg/haxe/lime/HaxeObject;)V` | OK |
| `AndroidSystem.hx` | `PhoenixCore` | `releaseWakeLock` | `()V` | OK |
| `AndroidNotification.hx` | `PhoenixCore` | `requestNotificationPermission` | `()V` | OK |
| `AndroidSystem.hx` | `PhoenixCore` | `setRecoveryState` | `(Ljava/lang/String;)V` | OK |
| `AndroidDisplay.hx` | `PhoenixDisplay` | `getCutoutInsets` | `()Ljava/lang/String;` | OK |
| `AndroidDisplay.hx` | `PhoenixDisplay` | `getDisplayInfo` | `()Ljava/lang/String;` | OK |
| `AndroidDisplay.hx` | `PhoenixDisplay` | `registerDisplayListener` | `()V` | OK |
| `AndroidDisplay.hx` | `PhoenixDisplay` | `setCutoutMode` | `(Ljava/lang/String;)V` | OK |
| `AndroidDisplay.hx` | `PhoenixDisplay` | `setImmersive` | `(Ljava/lang/String;)V` | OK |
| `AndroidDisplay.hx` | `PhoenixDisplay` | `setPreferredRefreshRate` | `(F)V` | OK |
| `AndroidHaptics.hx` | `PhoenixInput` | `cancelVibration` | `()V` | OK |
| `AndroidGamepad.hx` | `PhoenixInput` | `getDeviceInfo` | `(I)Ljava/lang/String;` | OK |
| `AndroidGamepad.hx` | `PhoenixInput` | `getGamepads` | `()Ljava/lang/String;` | OK |
| `AndroidHaptics.hx` | `PhoenixInput` | `hasVibrator` | `()Z` | OK |
| `AndroidGamepad.hx` | `PhoenixInput` | `registerGamepadListener` | `()V` | OK |
| `AndroidHardwareInput.hx` | `PhoenixInput` | `setVolumeKeysIntercepted` | `(Z)V` | OK |
| `AndroidHaptics.hx` | `PhoenixInput` | `vibrate` | `(J)V` | OK |
| `AndroidGamepad.hx` | `PhoenixInput` | `vibrateGamepad` | `(IJ)Z` | OK |
| `AndroidHaptics.hx` | `PhoenixInput` | `vibratePattern` | `(Ljava/lang/String;I)V` | OK |
| `AndroidMedia.hx` | `PhoenixMedia` | `abandonAudioFocus` | `()V` | OK |
| `AndroidNotification.hx` | `PhoenixMedia` | `cancelNotification` | `(I)V` | OK |
| `AndroidMedia.hx` | `PhoenixMedia` | `createSession` | `()V` | OK |
| `AndroidMedia.hx` | `PhoenixMedia` | `getAudioInfo` | `()Ljava/lang/String;` | OK |
| `AndroidMedia.hx` | `PhoenixMedia` | `notifyMedia` | `(Ljava/lang/String;Ljava/lang/String;Z)V` | OK |
| `AndroidNotification.hx` | `PhoenixMedia` | `notifySimple` | `(ILjava/lang/String;Ljava/lang/String;)V` | OK |
| `AndroidMedia.hx` | `PhoenixMedia` | `releaseSession` | `()V` | OK |
| `AndroidMedia.hx` | `PhoenixMedia` | `requestAudioFocus` | `()I` | OK |
| `AndroidMedia.hx` | `PhoenixMedia` | `setActive` | `(Z)V` | OK |
| `AndroidMedia.hx` | `PhoenixMedia` | `setMetadata` | `(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;JLjava/lang/String;)V` | OK |
| `AndroidMedia.hx` | `PhoenixMedia` | `setPlaybackState` | `(IJF)V` | OK |
| `AndroidMedia.hx` | `PhoenixMedia` | `startForegroundService` | `(Ljava/lang/String;Ljava/lang/String;Z)V` | OK |
| `AndroidMedia.hx` | `PhoenixMedia` | `stopForegroundService` | `()V` | OK |
| `AndroidStorage.hx` | `PhoenixStorage` | `copyUriToFile` | `(Ljava/lang/String;Ljava/lang/String;)Z` | OK |
| `AndroidStorage.hx` | `PhoenixStorage` | `createDocument` | `(Ljava/lang/String;Ljava/lang/String;)V` | OK |
| `AndroidStorage.hx` | `PhoenixStorage` | `getDisplayName` | `(Ljava/lang/String;)Ljava/lang/String;` | OK |
| `AndroidStorage.hx` | `PhoenixStorage` | `getUriSize` | `(Ljava/lang/String;)J` | OK |
| `AndroidStorage.hx` | `PhoenixStorage` | `openDocument` | `(Ljava/lang/String;Ljava/lang/String;)V` | OK |
| `AndroidStorage.hx` | `PhoenixStorage` | `openDocumentTree` | `()V` | OK |
| `AndroidIntents.hx` | `PhoenixStorage` | `openFile` | `(Ljava/lang/String;)V` | OK |
| `AndroidIntents.hx` | `PhoenixStorage` | `openSettings` | `(Ljava/lang/String;)V` | OK |
| `AndroidIntents.hx` | `PhoenixStorage` | `openUrl` | `(Ljava/lang/String;)V` | OK |
| `AndroidStorage.hx` | `PhoenixStorage` | `persistUriPermission` | `(Ljava/lang/String;Z)V` | OK |
| `AndroidStorage.hx` | `PhoenixStorage` | `readUriBytes` | `(Ljava/lang/String;)[B` | OK |
| `AndroidBridge.hx` | `PhoenixStorage` | `registerStorageCallback` | `(Lorg/haxe/lime/HaxeObject;)V` | OK |
| `AndroidIntents.hx` | `PhoenixStorage` | `shareFile` | `(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V` | OK |
| `AndroidIntents.hx` | `PhoenixStorage` | `shareText` | `(Ljava/lang/String;Ljava/lang/String;)V` | OK |
| `AndroidIntents.hx` | `PhoenixStorage` | `viewContentUri` | `(Ljava/lang/String;Ljava/lang/String;)V` | OK |
| `AndroidStorage.hx` | `PhoenixStorage` | `writeUriBytes` | `(Ljava/lang/String;[B)Z` | OK |

External SDL bindings (`org/libsdl/app/SDLActivity`) are provided by the
Lime fork and not listed here.

Common Android SDK classes (`android.Permissions`, `android.Settings`,
`android.content.Context`, `android.os.Build`, `android.os.Environment`)
are provided by the Lime fork itself — the engine uses those externs
directly instead of shipping its own copies, which would shadow Lime's
and break `lime.system.System` on Android.

### Notifications

The Media3 MediaStyle notification (owned by `AndroidMedia`) is the only
always-on notification. Simple status notifications go through
`AndroidNotification` and are strictly opt-in: `notifyEvent(...)` no-ops
unless `ClientPrefs.androidNotifications` is enabled (Options -> Mobile
Options -> "Event Notifications", which also requests POST_NOTIFICATIONS on
Android 13+ when toggled on — never unattended at startup). Wired events:

- **Chart backup saved** — `editors.charting.ChartingSaveLoad.saveLevel`
  autosave path, posted with the fixed `ID_CHART_BACKUP`.
- **Crash log saved** — `backend.CrashHandler` after writing `crash/*.log`,
  posted with the fixed `ID_CRASH_LOG` (wrapped so it can never interfere
  with crash handling).

Both use fixed ids and the native side sets `setOnlyAlertOnce(true)`, so
repeated events (e.g. the 4-minute chart autosave) update the existing
notification instead of re-alerting or stacking. "Update available" is
deliberately not wired: the in-app auto-updater is still a non-goal (§12.6).

### Gameplay integration (`play.helpers.PlayStateAndroidMedia`)

`PlayState.create()` starts and `PlayState.destroy()` stops the Android
media integration:

- The current song is published to Media3's `MediaSession` (title, chart
  creator, engine album, optional creator artwork and duration at create;
  state, pitch and position refresh once per second). Local artwork paths can
  point at a mod file, a Lime Android asset, or a `content://` URI. A bounded
  background worker reads and bounds-validates small artwork before returning
  only the current metadata generation to the main looper; an unreadable,
  oversized, corrupt, or stale image simply leaves playback running without
  artwork. Public `http(s)` artwork URIs can be published directly.
- `PhoenixMediaService` extends Media3's `MediaSessionService`. The bridge
  requests it only after Haxe has mirrored actual ready playback, never while a
  selected song is merely paused/buffering. Media3 then keeps its MediaStyle
  foreground notification synchronized with the mirrored player and owns its
  foreground promotion/demotion (including its post-playback timeout), while
  advertising the session to lock-screen controls, Bluetooth, Android Auto and
  compatible media browsers.
- Audio focus is requested on start and abandoned on stop; focus **loss
  pauses the game**, **duck** lowers music volume, **gain** restores it.
- The screen is kept on for the duration of gameplay via
  `FLAG_KEEP_SCREEN_ON` on the activity window.
- A recovery blob (`{type:"song", song, difficulty, difficulties, mod}`) is persisted while
  playing and cleared on a clean exit, so a process kill mid-song can be
  recovered (see below).

Media buttons: **play** resumes from the pause menu, **pause/stop** open
it. Physical **next** and **previous** media-button events are forwarded as
`AndroidMedia` signals for mods or custom song queues. `seek` is also exposed
as a signal (`AndroidMedia.onSeek`) rather than applied automatically, because
seeking mid-song would desync the chart.

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
**Import Char** button in `CharacterEditorState`), character export and the
mods menu's **IMPORT .ZIP** action. Desktop keeps the traditional
`FileReference` download flow.

### Installing a mod from a `.zip` (`mobile.files.ModZipInstaller`)

The mods menu (`ModsMenuState`) offers **IMPORT .ZIP** - in the button strip
next to the mod-order buttons, and as the primary button on the "no mods
installed" screen (where it is also bound to accept/A). It opens the same
cross-platform picker filtered to `application/zip`, reads the archive bytes,
and hands them to `mobile.files.ModZipInstaller`, then enables the new folder
with `Mods.registerInstalledMod()` and reloads the menu on it. On Android this
is the only practical install path without a file manager.

`backend.ModPathPolicy` owns the rules every entry must pass before anything is
written: no absolute paths (`/…`, `C:…`, `//server`), no `..` segments, no
NUL/control or Windows-illegal characters, no Windows device names, and bounded
length/depth. `ModZipInstaller` then:

- parses the zip **central directory** and trusts it over local headers (a
  local name that disagrees rejects the archive) so entry names and sizes are
  known before decompression;
- rejects encrypted entries, symbolic links and compression methods other than
  stored/deflate, and caps archive size, per-entry size, total expanded size and
  entry count (zip-bomb limits);
- finds the mod root (`pack.json` at the root, or inside a single top-level
  folder, ignoring macOS `__MACOSX`/`._*` metadata) and derives a safe folder
  name from it (or from the picked file name);
- extracts into a hidden `mods/.phoenix-import-*` staging folder, validates
  `pack.json` there, and only then swaps it into `mods/<folder>/`. A rejected or
  interrupted import leaves no partial mod behind, and staging folders are never
  listed as mods;
- refuses to overwrite an installed folder unless the caller asks to replace it;
  the menu asks with a `Prompt` before doing so.

Regression checks: `tests/haxe/run-mod-zip.sh` (interpreter spec for the path
policy, central-directory parser and extractor).

### System-visible app directories (`PhoenixDocumentsProvider`)

When Lime's `SHARE_FILES` condition is enabled (the normal Android project
build sets `SHARE_MOBILE_FILES`), the manifest registers
`quack.fnf.phoenix.android.PhoenixDocumentsProvider` under
`<application-id>.documentsprovider`, protected by
`android.permission.MANAGE_DOCUMENTS`. It replaces Lime's generic provider and
exposes only these roots from `Context.getExternalFilesDir(null)`:

| SAF root | Backing path | Access |
| --- | --- | --- |
| **Crash Logs** | `crash/` | Read-only, for copying reports out of the game |
| **VLogs** | `vlog/` | Read-only, for copying the verbose `log.txt` out of the game |
| **Mods** | `mods/` | Read/write; create folders/files, rename files, and delete files or subfolders |

Document IDs are opaque, root-scoped path IDs. Decoded traversal, unsafe names,
and static symlink escapes are rejected; stale or unavailable storage fails
closed. `java.io.File` checks cannot atomically prevent a race with an
independent concurrent filesystem writer. The system Files picker uses the
provider through SAF grants without exposing saves or other app-private roots.

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
- Hardware triggers (volume keys) can be bound to the four note lanes from
  Options -> Controls -> HARDWARE (Android only, unbound by default). They
  are stored in the regular keybind map as `hw_note_<lane>` entries, encoded
  with `backend.HardwareKeys`. Volume keys are only captured during gameplay
  (not paused) and while a HARDWARE row is being rebound; taunt and other
  actions are not bindable to hardware triggers yet.
- Media `seek` is intentionally not applied mid-song.
- Low-latency audio relies on Lime/SDL's Android backend (AAudio/OpenSL);
  no custom backend is provided.
