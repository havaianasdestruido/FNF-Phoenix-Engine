# iOS Platform Layer

This document describes the Phoenix Engine iOS platform support — the
native extensions, Haxe API modules, and how the engine adapts to iOS
constraints. iOS support is **not yet feature-complete** (video decode and
full AVPlayer integration are still pending), but the core platform layer
compiles, boots, and passes CI.

Everything described here is **iOS-only**. On every other target the Haxe
modules compile to no-ops (empty bodies behind `#if ios`), so gameplay code
never needs `#if ios` guards for basic queries.

---

## Why iOS is different from Android

| Concern | Android | iOS |
|---|---|---|
| Window / fullscreen | SDL activity, immersive flags, cutout mode (`always`/`never`) | Single fullscreen `UIWindow`, safe-area insets (notch, home indicator) |
| Storage | `Context.getExternalFilesDir()` + SAF DocumentsProvider | App sandbox `documentsDirectory` (readable/writable without permissions) |
| Video | `hxvlc` not available — fallback skips | `hxvlc` not available — fallback skips (future: `AVPlayer` bridge) |
| Notifications | Media3 `MediaSession` + `POST_NOTIFICATIONS` | `UNUserNotificationCenter` (not yet wired) |
| Deep links | `phoenix://` intent filter in `AndroidManifest.xml` | `phoenix://` URL scheme in `Info.plist` + `onDropFile` drop event |
| Gamepad | `PhoenixInput` / Android `InputManager` | Core (`GameController.framework`) not yet bridged — uses Flixel defaults |
| Haxelibs | Desktop-only libs gated off (`hxdiscord_rpc`, `hxvlc`) | Same gating — iOS is `isMobile() && isCPP()` so `VIDEOS_ALLOWED` is true but `hxvlc` is absent, so `VideoSprite` falls back to skipping |

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Gameplay code (PlayState, editors, options...)          │
│   talks only to: ios.platform.* + MobileFilePicker      │
├─────────────────────────────────────────────────────────┤
│ Haxe API modules          source/ios/platform/*.hx      │
│   IOSDisplay / IOSStorage / IOSPlatform                 │
│   (no-ops off-iOS)                                      │
├─────────────────────────────────────────────────────────┤
│ Native bridge             source/ios/src/ (ObjC/Swift)  │
│   (future: AVPlayer, safe-area, document picker)        │
├─────────────────────────────────────────────────────────┤
│ Lime template             source/templates/ios/         │
│   Info.plist, launch storyboard, URL scheme             │
└─────────────────────────────────────────────────────────┘
```

The boot hook lives in `Main.hx`:

```haxe
#if ios
ios.platform.IOSPlatform.init();
#end
```

`IOSPlatform.init()` wires `IOSDisplay.init()`; further native listeners
(orientation, memory pressure) will be added when the ObjC src lands.

---

## Build integration (`project.hxp`)

The iOS pieces are injected only for the iOS target (`configureIOSRuntime()`):

* `templatePaths.push("source/templates")` — engine templates override Lime's:
  `source/templates/ios/template/Info.plist` registers the `phoenix://` URL
  scheme and sets `UIRequiresFullScreen` / `UISupportedInterfaceOrientations`
  to landscape.

* Native iOS-only haxelibs (`hxvlc`, `hxdiscord_rpc`, `hxluajit`) are gated
  to desktop builds (`isDesktop() && isCPP()`), so iOS never links them.
  `VIDEOS_ALLOWED` is still true on iOS (`isMobile() && isCPP()`), but the
  `#if (VIDEOS_ALLOWED && hxvlc)` guard in `objects.VideoSprite` falls back
  to the `NullVideoSpriteBackend` — the song keeps playing, the video is
  skipped, and `finishCallback` fires one frame later.

* `HSCRIPT_ALLOWED`, `LUA_ALLOWED`, `PYTHON_ALLOWED` remain enabled on iOS
  (`isMobile() && isCPP()`), so Lua/Python/HScript mods keep working.

* `isIOS()` / `isMobile()` checks in `project.hxp` already set
  `SHARE_MOBILE_FILES` and the mobile window defaults (0×0, non-resizable,
  landscape) for iOS.

---

## Haxe API modules (`source/ios/platform/`)

All modules are safe to reference from cross-platform code: every call is a
no-op outside `#if ios` unless noted.

| Module | Purpose | Highlights |
|---|---|---|
| `IOSPlatform` | One-shot boot | `init()` — wires display, storage, deep-link listeners |
| `IOSDisplay` | Screen info | `getSafeAreaInsets()` (notch/home-indicator), `getRefreshRate()`, `hasCutout()`, `setFullscreen()` (no-op — iOS is always fullscreen) |
| `IOSStorage` | Sandbox files | `getDocumentsDirectory()`, `isPickerAvailable()`, `getOSVersion()` |

Deep-link routing reuses the platform-independent `backend.deeplink.PhoenixURI`
contract:

```haxe
#if ios
lime.app.Application.current.window.onDropFile.add(DeepLinks.receive);
#end
```

Lime's SDL UIKit delegate delivers both launch and later `phoenix://` URLs
as drop events, so no separate `handleNewIntent` shim is needed.

---

## Video on iOS

`hxvlc` is a desktop-only haxelib (it links `libvlc`). The engine's
`objects.VideoSprite` has two branches:

```haxe
#if (VIDEOS_ALLOWED && hxvlc)
class VideoSprite extends FlxSpriteGroup { /* real hxvlc path */ }
#else
class VideoSprite extends FlxSpriteGroup { /* fallback — logs and skips */ }
#end
```

* **Desktop:** `VIDEOS_ALLOWED && hxvlc` → real decode, `FlxVideoSprite`.
* **Android / iOS / Web:** `VIDEOS_ALLOWED` may be true, but `hxvlc` is
  absent → fallback. The cutscene is skipped immediately (within one frame)
  and `finishCallback` / `onSkip` resolve so `inCutscene` does not lock
  gameplay. Logs read `Video backend unavailable on this platform`.

Future iOS work: a thin `AVPlayer` bridge (`source/ios/src/PhoenixVideo.m`)
that exposes `playVideo(path, canSkip)` to Haxe via hxcpp ObjC. The fallback
API surface is already stable so the bridge can be swapped in without
changing `PlayStateCutscenes.startVideo()` call sites.

---

## Display / safe area

iPhone X and later have a top notch or Dynamic Island and a bottom home
indicator. `IOSDisplay.getSafeAreaInsets()` returns `{left, top, right, bottom}`
in logical pixels (UIKit points). Non-iOS targets return all zeros.

```haxe
var insets = ios.platform.IOSDisplay.getSafeAreaInsets();
if (insets.top > 0) {
    // pad HUD / pause button away from notch
}
```

Until the native bridge ships, the Haxe implementation returns `0,0,0,0`
and `hasCutout()` is false — the game boots and CI passes, but notch
padding is not yet applied on device. The native signatures are already
frozen so the ObjC side can land without a Haxe API break:

```haxe
@:keep static function getSafeAreaInsets_native():SafeAreaInsets => null;
@:keep static function getRefreshRate_native():Float => 0;
```

---

## Storage

iOS apps live in a sandbox:

```haxe
final dir:String = #if android getAndroidStorageDirectory()
                  #elseif ios lime.system.System.documentsDirectory
                  #else Sys.getCwd() #end;
```

`IOSStorage.getDocumentsDirectory()` wraps the `lime.system.System`
extern directly. No extra entitlement is needed for the app's own files.
User-chosen imports/exports will use `UIDocumentPickerViewController`
when the ObjC bridge is available; until then `MobileFilePicker`'s
`lime.ui.FileDialog` path is used where Lime exposes it.

---

## Known follow-ups

* Wire `UIDevice.orientationDidChangeNotification` → `IOSDisplay.onChanged`.
* Bridge `GCController` for MFi gamepads (`IOSGamepad`).
* Implement `AVPlayer` video path so Week-7 cutscenes play on iOS.
* Request `UNUserNotificationCenter` permissions for opt-in event
  notifications (mirror `AndroidNotification` opt-in pattern).
* Test flight: fresh install, upgrade preserving `documents/`, background/
  resume during asset copy, notch vs non-notch devices.

Regression checks: iOS behavior is validated on device / TestFlight (fresh
install, upgrade preserving `documents/`, background/resume during asset copy,
notch vs non-notch devices); there is no host-side iOS test harness.
