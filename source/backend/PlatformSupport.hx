package backend;

import backend.PlatformIcons;

using StringTools;

/**
 * Which settings, mods and engine features a build target actually supports.
 *
 * Options menus used to answer this ad hoc with `#if` blocks, and bundled mods
 * had no way to say "this only works on desktop" at all. This module gives both
 * one shared vocabulary:
 *
 * - **target tags** (`windows`, `mac`, `linux`, `android`, `ios`, `web`,
 *   `flash`, `air`);
 * - **family tags** (`desktop` = native Windows/macOS/Linux, `mobile`,
 *   `native`, `apple`, `sys`);
 * - **capability tags** (`window-alpha`, `window-color-key`,
 *   `window-click-through`, `window-resize`, `screen-resolution`,
 *   `desktop-notifications`, `deeplink`, `file-picker`, `filesystem`,
 *   `video-render`).
 *
 * Positive entries in a requirement list are **alternatives** (at least one has
 * to match), while entries starting with `!` are **exclusions** (none may
 * match). So `['desktop', 'android']` means "desktop or Android",
 * `['!mobile']` means "anything but phones/tablets", and
 * `['desktop', '!air']` means "a native desktop, not Adobe AIR". An empty or
 * `null` list means "everywhere", and so does the explicit `all` pseudo-tag
 * (aliases: `any`, `*`, `everywhere`). Mods that predate the field therefore
 * keep working untouched: an omitted `platforms` key behaves exactly like
 * `[]` or `["all"]`. Unknown positive tags never match, so
 * a typo hides the feature instead of silently showing it on platforms where
 * it cannot work.
 *
 * The module is deliberately free of Flixel/OpenFL/Lime imports (it only reads
 * compile-time defines and reuses the pure `backend.PlatformIcons` detector),
 * so the rules run under the Haxe interpreter in
 * `tests/haxe/PlatformSupportSpec.hx`.
 *
 * ### Where the rules are enforced
 *
 * - `options.Option` / `options.BaseOptionsMenu`: an option that does not apply
 *   to this build is never added to the list;
 * - `backend.ClientPrefs`: settings that belong to another platform are not
 *   loaded from or written to the save file;
 * - `backend.SettingsBackup`: those settings are also left out of `.json`
 *   backups (and ignored when one is imported);
 * - `backend.Mods`: a mod may declare `platforms` in its `pack.json` and is
 *   then skipped entirely where it does not apply.
 */
class PlatformSupport
{
  // Canonical target tags.
  public static inline var WINDOWS = 'windows';
  public static inline var MAC = 'mac';
  public static inline var LINUX = 'linux';
  public static inline var ANDROID = 'android';
  public static inline var IOS = 'ios';
  public static inline var WEB = 'web';
  public static inline var FLASH = 'flash';
  public static inline var AIR = 'air';

  // Family tags.
  /** Native Windows, macOS and Linux. Adobe AIR/Flash are *not* desktop here. */
  public static inline var DESKTOP = 'desktop';
  public static inline var MOBILE = 'mobile';
  /** Compiled to a native binary (`cpp`), i.e. every non-web/flash target. */
  public static inline var NATIVE = 'native';
  public static inline var APPLE = 'apple';
  /** Haxe's `sys` platform: file APIs and processes are available. */
  public static inline var SYS = 'sys';
  /** Pseudo-tag that matches every build (`all`, `any`, `*`, `everywhere`). */
  public static inline var ALL = 'all';

  // Capability tags.
  /** Whole-window opacity (Lime `Window.opacity`). */
  public static inline var WINDOW_ALPHA = 'window-alpha';
  /** Color-key transparency (`SetLayeredWindowAttributes`). Windows only. */
  public static inline var WINDOW_COLOR_KEY = 'window-color-key';
  /** Click-through windows (`WS_EX_TRANSPARENT`). Windows only. */
  public static inline var WINDOW_CLICK_THROUGH = 'window-click-through';
  /** Programmatic window resizing (resolution picker). */
  public static inline var WINDOW_RESIZE = 'window-resize';
  /** Resolution picker that changes the native window. */
  public static inline var SCREEN_RESOLUTION = 'screen-resolution';
  /** OS notification area / notification center. */
  public static inline var DESKTOP_NOTIFICATIONS = 'desktop-notifications';
  /** `phoenix://` links can be registered or received. */
  public static inline var DEEPLINK = 'deeplink';
  /** `mobile.files.MobileFilePicker` can actually open a dialog. */
  public static inline var FILE_PICKER = 'file-picker';
  /** The target can read/write the filesystem (`sys`). */
  public static inline var FILESYSTEM = 'filesystem';
  /** Options -> Game Rendering (FFmpeg or screenshot-frame capture). */
  public static inline var VIDEO_RENDER = 'video-render';

  /** Every tag this module knows how to match. */
  static final KNOWN_TAGS:Array<String> = [
    WINDOWS, MAC, LINUX, ANDROID, IOS, WEB, FLASH, AIR,
    DESKTOP, MOBILE, NATIVE, APPLE, SYS, ALL,
    WINDOW_ALPHA, WINDOW_COLOR_KEY, WINDOW_CLICK_THROUGH, WINDOW_RESIZE,
    SCREEN_RESOLUTION, DESKTOP_NOTIFICATIONS, DEEPLINK, FILE_PICKER,
    FILESYSTEM, VIDEO_RENDER
  ];

  /** Alias -> canonical tag. Keys are already lower case and trimmed. */
  static final ALIASES:Map<String, String> = [
    'win' => WINDOWS,
    'win32' => WINDOWS,
    'win64' => WINDOWS,
    'windows' => WINDOWS,
    'macos' => MAC,
    'osx' => MAC,
    'darwin' => MAC,
    'gnu-linux' => LINUX,
    'html' => WEB,
    'html5' => WEB,
    'js' => WEB,
    'javascript' => WEB,
    'web' => WEB,
    'iphone' => IOS,
    'ipad' => IOS,
    'phone' => MOBILE,
    'tablet' => MOBILE,
    'cpp' => NATIVE,
    'adobe-air' => AIR,
    'adobeair' => AIR,
    'swf' => FLASH,
    'all' => ALL,
    'any' => ALL,
    '*' => ALL,
    'everywhere' => ALL
  ];

  /**
   * `ClientPrefs` fields that only make sense on some targets.
   *
   * The options menu, the save file and the `.json` backup all consult this
   * table, so the field can exist on every build (mods and scripts may read it)
   * while never being shown, saved or exported where it does nothing.
   */
  static final PREFERENCE_PLATFORMS:Map<String, Array<String>> = [
    'respectCutout' => [ANDROID],
    'androidNotifications' => [ANDROID],
    'screensaver' => [MOBILE],
    'mobileCAlpha' => [MOBILE],
    'mobileCEx' => [MOBILE],
    'mobileCPlayStateVpad' => [MOBILE],
    'mobileCExTaunt' => [MOBILE],
    'hitboxType' => [MOBILE],
    'hitboxPos' => [MOBILE],
    'deeplinkEnabled' => [DEEPLINK],
    'autosaveCharts' => [FILESYSTEM],
    'autosaveTime' => [FILESYSTEM],
    'ffmpegMode' => [VIDEO_RENDER],
    'targetFPS' => [VIDEO_RENDER],
    'unlockFPS' => [VIDEO_RENDER],
    'renderBitrate' => [VIDEO_RENDER],
    'vidEncoder' => [VIDEO_RENDER],
    'oldFFmpegMode' => [VIDEO_RENDER],
    'lossless' => [VIDEO_RENDER],
    'quality' => [VIDEO_RENDER],
    'renderGCRate' => [VIDEO_RENDER],
    'renderPath' => [VIDEO_RENDER],
    'showRemainingTime' => [VIDEO_RENDER]
  ];

  static var cachedTags:Array<String> = null;

  /** The platform this build runs on, as the watermark badge reports it. */
  public static function current():PlatformKind
  {
    return PlatformIcons.detect();
  }

  /** Human readable name of the running target ("Windows", "Web", ...). */
  public static function currentLabel():String
  {
    return PlatformIcons.label(current());
  }

  /**
   * Every tag that describes the running build.
   *
   * Target *and* family/capability tags are included, so a Windows build
   * matches `windows`, `desktop`, `native`, `sys`, `window-color-key`, ...
   */
  public static function currentTags():Array<String>
  {
    if (cachedTags == null) cachedTags = collectTags();
    return cachedTags;
  }

  /**
   * Whether the running build satisfies a requirement list.
   *
   * @param requirements positive tags are alternatives (at least one has to
   *                     match); `!tag` entries are exclusions (none may
   *                     match). `null` / empty means "everywhere".
   */
  public static function supports(?requirements:Array<String>):Bool
  {
    if (requirements == null || requirements.length == 0) return true;

    final tags:Array<String> = currentTags();
    var hasPositive:Bool = false;
    var matchedPositive:Bool = false;

    for (requirement in requirements)
    {
      if (requirement == null) continue;
      final text:String = requirement.trim().toLowerCase();
      if (text.length == 0) continue;

      final negated:Bool = text.charAt(0) == '!';
      final tag:String = canonicalTag(negated ? text.substr(1) : text);
      final present:Bool = tag == ALL || tags.indexOf(tag) >= 0;

      if (negated)
      {
        // An excluded tag must not be present (`!all` can never be satisfied).
        if (present) return false;
      }
      else
      {
        hasPositive = true;
        if (present) matchedPositive = true;
      }
    }

    // With positives listed, at least one of them has to match. A list made
    // only of exclusions (`!mobile`) is satisfied when none of them matched.
    return !hasPositive || matchedPositive;
  }

  /** Convenience overload for a single requirement. */
  public static function supportsOne(tag:String):Bool
  {
    return supports(tag == null ? null : [tag]);
  }

  /**
   * Reads a `platforms` value from JSON (`pack.json`) or code.
   *
   * Accepts an array of strings, a single string (split on commas and
   * whitespace) or `null`. Anything else is ignored, which means "everywhere".
   */
  public static function requirementsFrom(value:Dynamic):Array<String>
  {
    if (value == null) return null;

    if (Std.isOfType(value, String))
    {
      final raw:String = value;
      final parts:Array<String> = [];
      for (piece in raw.split(','))
        for (word in piece.split(' '))
          if (StringTools.trim(word).length > 0) parts.push(StringTools.trim(word));
      return parts.length == 0 ? null : parts;
    }

    if (Std.isOfType(value, Array))
    {
      final values:Array<Dynamic> = value;
      final parts:Array<String> = [];
      for (entry in values)
        if (entry != null)
        {
          final text:String = Std.string(entry).trim();
          if (text.length > 0) parts.push(text);
        }
      return parts.length == 0 ? null : parts;
    }

    return null;
  }

  /** Requirements for a `ClientPrefs` field, or `null` when it works everywhere. */
  public static function requirementsForPreference(field:String):Array<String>
  {
    if (field == null) return null;
    return PREFERENCE_PLATFORMS.get(field);
  }

  /** True when a `ClientPrefs` field applies to this build. */
  public static function supportsPreference(field:String):Bool
  {
    return supports(requirementsForPreference(field));
  }

  /** Requirements declared by a mod's parsed `pack.json`, if any. */
  public static function requirementsForPack(pack:Dynamic):Array<String>
  {
    if (pack == null) return null;
    return requirementsFrom(Reflect.field(pack, 'platforms'));
  }

  /** True when `tag` (after alias resolution, `!` allowed) is a known tag. */
  public static function isKnownTag(tag:String):Bool
  {
    if (tag == null) return false;
    final text:String = tag.trim().toLowerCase();
    if (text.length == 0) return false;
    final name:String = text.charAt(0) == '!' ? text.substr(1) : text;
    return KNOWN_TAGS.indexOf(canonicalTag(name)) >= 0;
  }

  /**
   * Canonical form of a (single, non-negated) tag: lower case, alias resolved.
   * Unknown tags are returned as-is so `supports()` can reject them.
   */
  public static function canonicalTag(tag:String):String
  {
    if (tag == null) return '';
    final text:String = tag.trim().toLowerCase();
    final alias:String = ALIASES.get(text);
    return alias != null ? alias : text;
  }

  /** Comma separated tag list for logs and the diagnostics report. */
  public static function describeCurrent():String
  {
    return currentTags().join(', ');
  }

  static function collectTags():Array<String>
  {
    final tags:Array<String> = [];

    // Target + family tags. The ladder is ordered like PlatformIcons.detect():
    // AIR also defines `flash`, mobile CPP builds also define `sys`, so the most
    // specific target has to win.
    #if android
    addTags(tags, [ANDROID, MOBILE, NATIVE, 'cpp', SYS, FILESYSTEM, DEEPLINK, VIDEO_RENDER]);
    #elseif ios
    addTags(tags, [IOS, MOBILE, NATIVE, 'cpp', SYS, APPLE, FILESYSTEM]);
    #elseif html5
    addTags(tags, [WEB, 'html5']);
    #elseif air
    addTags(tags, [AIR, FLASH]);
    #elseif flash
    addTags(tags, [FLASH]);
    #elseif windows
    addTags(tags, [
      WINDOWS, DESKTOP, NATIVE, 'cpp', SYS, FILESYSTEM, VIDEO_RENDER,
      WINDOW_ALPHA, WINDOW_COLOR_KEY, WINDOW_CLICK_THROUGH, WINDOW_RESIZE,
      SCREEN_RESOLUTION, DESKTOP_NOTIFICATIONS, DEEPLINK, FILE_PICKER
    ]);
    #elseif mac
    addTags(tags, [
      MAC, DESKTOP, NATIVE, 'cpp', SYS, APPLE, FILESYSTEM, VIDEO_RENDER,
      WINDOW_ALPHA, WINDOW_RESIZE, SCREEN_RESOLUTION, DESKTOP_NOTIFICATIONS,
      FILE_PICKER
    ]);
    #elseif linux
    addTags(tags, [
      LINUX, DESKTOP, NATIVE, 'cpp', SYS, FILESYSTEM, VIDEO_RENDER,
      WINDOW_ALPHA, WINDOW_RESIZE, SCREEN_RESOLUTION, DESKTOP_NOTIFICATIONS,
      FILE_PICKER
    ]);
    #elseif sys
    // Neko/HashLink and other host builds: sys APIs exist even without a
    // target define. When the host itself is a desktop OS, keep the desktop
    // family so the same rules also describe `haxe --interp` runs.
    final host:String = Std.string(PlatformIcons.detect());
    addTags(tags, [NATIVE, SYS, FILESYSTEM, FILE_PICKER, host]);
    if (host == WINDOWS || host == MAC || host == LINUX) addTags(tags, [DESKTOP, WINDOW_RESIZE, SCREEN_RESOLUTION]);
    #else
    addTags(tags, [Std.string(PlatformIcons.detect())]);
    #end

    // Android reaches the SAF picker through JNI instead of `sys`, and its
    // deeplink scheme is registered by the build rather than at runtime.
    #if android
    addTags(tags, [FILE_PICKER]);
    #end

    return tags;
  }

  static function addTags(target:Array<String>, values:Array<String>):Void
  {
    for (value in values)
      if (value != null && value.length > 0 && target.indexOf(value) < 0) target.push(value);
  }
}
