package backend;

using StringTools;

/*
 * 4th-wall-breaking ("META_HORROR") system effects for horror mods.
 *
 * Ported with adaptation from two Apache-2.0 sources:
 *   - `CoolUtil.hx` META_HORROR section, psych-engine-modified-build
 *     https://github.com/notmagniill/psych-engine-modified-build (Apache License 2.0)
 *     Copyright the psych-engine-modified-build contributors
 *   - `CppAPI.hx` / `WindowsData.hx` / `Wallpaper.hx` / `Transparency.hx`, Mario Madness
 *     https://github.com/Dewott2501/Mario-Madness (Apache License 2.0)
 *     Copyright the Mario Madness contributors
 *
 * Port notes (see docs/META_HORROR.md for the full mapping):
 *   - The upstream `nircmd` helper binary is NOT used: system volume, mouse
 *     movement and key input are implemented natively through WASAPI and the
 *     Win32 input APIs, so no third-party executable has to ship with the game.
 *   - `obtainRAM` reuses the engine's `debug.system.SystemInfo` instead of
 *     adding a second native RAM query.
 *   - Window style effects remember the original extended style so they can be
 *     undone with `resetWindowEffects()` (the upstream Transparency class
 *     could never restore the window).
 *   - Everything is compile-time gated behind the `META_HORROR` define
 *     (opt-in, `-DMETA_HORROR`) and degrades to safe no-ops on unsupported
 *     platforms, so this file compiles on every supported target.
 *
 * These effects are deliberately intrusive (wallpaper swaps, taskbar/window
 * hiding, system volume/mouse/keyboard control). Mods that use them MUST warn
 * the player up front — see docs/META_HORROR.md.
 */
class MetaHorror
{
  /**
   * Process-name fragments treated as "recording/streaming software" by `isRecording`.
   * Matched as lowercase substrings against the host process list; extend freely.
   */
  public static var programList:Array<String> = [
    'obs64', 'obs32',
    'bdcam', // Bandicam
    'fraps',
    'xsplit',
    'hycam2',
    'twitchstudio'
  ];

  /**
   * Wallpaper-engine processes killed by `killWallpaperApps` so a wallpaper
   * swap is actually visible over live-wallpaper apps.
   */
  public static var wallpaperAppList:Array<String> = [
    'Lively.exe',
    'wallpaper32.exe',
    'wallpaper64.exe'
  ];

  /**
   * Desktop wallpaper captured before the first `setWallpaper` call on this
   * session; `restoreWallpaper` puts it back. `null` until then.
   */
  public static var oldWallpaper(default, null):Null<String> = null;

  static var hiddenWindowTitles:Array<String> = [];
  static var taskbarWasVisible:Bool = true;
  static var typeToken:Int = 0;

  /** Title the window had before `setWindowTitle`; `null` when unchanged. */
  static var originalWindowTitle:Null<String> = null;
  /** The `MusicBeatState` suffix/prefix values `setWindowTitle` replaced. */
  static var originalTitlePrefix:Null<String> = null;
  static var originalTitleSuffix:Null<String> = null;
  static var originalTitleSuffix2:Null<String> = null;
  /** `true` while `setAlwaysOnTop(true)` owns the window's topmost state. */
  static var alwaysOnTop:Bool = false;
  /** Save slot for the "the game remembers you" persistent values. */
  static var sessionSave:FlxSave = null;
  /** Keys `installExitCleanup` has already applied. */
  static var exitCleanupInstalled:Bool = false;

  /** Save-file key holding the launch counter. */
  static inline var LAUNCH_COUNT_KEY:String = 'launchCount';
  /** Save slot name; shares the engine's save folder but not its data. */
  static inline var PERSISTENT_SAVE_NAME:String = 'meta_horror';

  /**
   * True when recording/streaming software from `programList` seems to be
   * running. Intended for "streamer-safe" swaps, but horror mods also use it
   * to change behaviour when the player is live.
   *
   * Fails OPEN (returns `true`) when the process list cannot be read, so an
   * unknown error never leaks content to a live stream. Always `false`
   * without `META_HORROR`.
   */
  public static function isRecording():Bool
  {
    #if (META_HORROR && sys)
    var listCommand:String;
    var listArgs:Array<String>;
    #if windows
    listCommand = 'tasklist';
    listArgs = [];
    #elseif linux
    listCommand = 'ps';
    listArgs = ['-e', '-o', 'comm=']; // every process, command name only
    #elseif mac
    listCommand = 'ps';
    listArgs = ['-axo', 'comm='];
    #else
    return false;
    #end

    var readableList:String = '';
    try
    {
      #if (windows && cpp)
      // HiddenProcess spawns without a console window flashing over the game.
      var taskList = new utils.HiddenProcess(listCommand, listArgs);
      readableList = taskList.stdout.readAll().toString().toLowerCase();
      taskList.close();
      #else
      var taskList = new sys.io.Process(listCommand, listArgs);
      readableList = taskList.stdout.readAll().toString().toLowerCase();
      taskList.close();
      #end
    }
    catch (e:Dynamic)
    {
      // Process failed for some reason; assume the user may be streaming.
      return true;
    }

    for (program in programList)
    {
      if (readableList.contains(program))
        return true;
    }
    return false;
    #else
    return false;
    #end
  }

  /**
   * Forcefully closes the live-wallpaper apps in `wallpaperAppList` so a
   * `setWallpaper` swap is visible. Windows only; no-op elsewhere.
   */
  public static function killWallpaperApps():Void
  {
    #if (META_HORROR && windows && cpp)
    for (app in wallpaperAppList)
    {
      try
        new utils.HiddenProcess('taskkill', ['/f', '/im', app]).close()
      catch (e:Dynamic) {}
    }
    #else
    PlatformUtil.unsupportedMetaHorror('killWallpaperApps');
    #end
  }

  /**
   * Writes a copy of an image asset to the real filesystem ("leaking" art
   * out of the game). Accepts an absolute/relative file path or an embedded
   * asset path.
   *
   * @param imageFile    Asset path or on-disk path of the source image.
   * @param finalFileName File name without extension for the copy.
   * @param fileType     Extension to write (`png` recommended; PNG preserves alpha).
   * @param location     Target directory. Default: `<temp>/phoenix_horror`.
   * @return The written file path, or `null` on failure / unsupported target.
   */
  public static function duplicateImage(imageFile:String, finalFileName:String, ?fileType:String = 'png', ?location:String):Null<String>
  {
    #if (META_HORROR && sys)
    if (location == null)
    {
      location = CoolSystemStuff.getTempPath();
      if (location == null || location.length == 0)
        location = Sys.getCwd();
      location = haxe.io.Path.join([location, 'phoenix_horror']);
    }
    var outPath:String = haxe.io.Path.join([location, '$finalFileName.$fileType']);
    return dumpImageToFile(imageFile, outPath) ? outPath : null;
    #else
    PlatformUtil.unsupportedMetaHorror('duplicateImage');
    return null;
    #end
  }

  /**
   * Opens `path` with the OS default application (ShellExecute on Windows,
   * `xdg-open` on Linux, `open` on macOS).
   * @return `true` when the open request was dispatched.
   */
  public static function openFile(path:String):Bool
  {
    #if (META_HORROR && sys)
    if (!sys.FileSystem.exists(path))
    {
      trace('MetaHorror.openFile: "$path" does not exist');
      return false;
    }
    #if (windows && cpp)
    return openFileNative(path);
    #elseif linux
    return Sys.command('xdg-open', [path]) == 0;
    #elseif mac
    return Sys.command('open', [path]) == 0;
    #else
    return false;
    #end
    #else
    PlatformUtil.unsupportedMetaHorror('openFile');
    return false;
    #end
  }

  // ------------------------------------------------------------------
  // System audio (master output device)
  // ------------------------------------------------------------------

  /**
   * Sets the default audio output device's master volume.
   * @param percentage 0-100.
   * @return `true` on success; `false` on failure / unsupported target.
   */
  public static function setSysAudioVolume(percentage:Int):Bool
  {
    #if (META_HORROR && windows && cpp)
    return setMasterVolumeNative(clamp01(percentage / 100.0));
    #else
    PlatformUtil.unsupportedMetaHorror('setSysAudioVolume');
    return false;
    #end
  }

  /**
   * Mutes (or unmutes) the default audio output device.
   * @return `true` on success; `false` on failure / unsupported target.
   */
  public static function setSysAudioMute(mute:Bool):Bool
  {
    #if (META_HORROR && windows && cpp)
    return setMasterMuteNative(mute);
    #else
    PlatformUtil.unsupportedMetaHorror('setSysAudioMute');
    return false;
    #end
  }

  /**
   * @return Current master volume percentage (0-100), or `-1` when unavailable.
   */
  public static function getSysAudioVolume():Int
  {
    #if (META_HORROR && windows && cpp)
    return Math.round(getMasterVolumeNative() * 100);
    #else
    PlatformUtil.unsupportedMetaHorror('getSysAudioVolume');
    return -1;
    #end
  }

  /**
   * @return Master-mute state, or `false` when unavailable.
   */
  public static function getSysAudioMute():Bool
  {
    #if (META_HORROR && windows && cpp)
    return getMasterMuteNative();
    #else
    PlatformUtil.unsupportedMetaHorror('getSysAudioMute');
    return false;
    #end
  }

  // ------------------------------------------------------------------
  // Mouse & keyboard injection
  // ------------------------------------------------------------------

  /**
   * Moves the mouse cursor by `x`/`y` pixels relative to its current
   * position (matches the upstream `nircmd sendmouse move` behaviour).
   * Windows only.
   */
  public static function moveMousePos(x:Float, y:Float):Bool
  {
    #if (META_HORROR && windows && cpp)
    return moveMouseNative(Std.int(x), Std.int(y));
    #else
    PlatformUtil.unsupportedMetaHorror('moveMousePos');
    return false;
    #end
  }

  /**
   * Types `text` into whatever window has focus, `delay` seconds per
   * character (SendInput with Unicode scan codes, so any layout works).
   *
   * Special keys inside `text`: `\n` = Enter, `\t` = Tab, `\b` = Backspace.
   * A new call cancels a previous unfinished one. Windows only.
   */
  public static function typeText(text:String, delay:Float = 0.05):Void
  {
    #if (META_HORROR && windows && cpp)
		var token:Int = ++typeToken;
		var i:Int = 0;
		var typeNext:Void->Void = null;
		typeNext = function() {
			// A newer typeText call (or a cancelled script) supersedes this one.
			if (token != typeToken)
				return;
			if (i >= text.length)
				return;

			var code:Int = text.charCodeAt(i);
			i++;
			switch (code)
			{
				case 0x0A:
					sendVirtualKeyNative(0x0D); // \n = VK_RETURN
				case 0x09:
					sendVirtualKeyNative(0x09); // \t = VK_TAB
				case 0x08:
					sendVirtualKeyNative(0x08); // \b = VK_BACK
				default:
					sendUnicodeCharNative(code);
			}
			haxe.Timer.delay(typeNext, Std.int(Math.max(1, delay * 1000)));
		}
		typeNext();
    #else
    PlatformUtil.unsupportedMetaHorror('typeText');
    #end
  }

  // ------------------------------------------------------------------
  // Wallpaper
  // ------------------------------------------------------------------

  /**
   * Changes the desktop wallpaper. `path` is either an on-disk image path
   * (`absolute`) or an image name resolved like the upstream helper:
   * `mods/images/<name>.png` first, then any embedded asset (dumped to a
   * temp file automatically, since the OS needs a real file).
   *
   * The pre-change wallpaper is captured once per session for
   * `restoreWallpaper`. Windows only.
   *
   * @return `true` when the wallpaper changed.
   */
  public static function setWallpaper(path:String, ?absolute:Bool = false):Bool
  {
    #if (META_HORROR && windows && cpp)
    var file:String = resolveWallpaperFile(path, absolute);
    if (file == null)
    {
      trace('MetaHorror.setWallpaper: could not resolve "$path" to a file');
      return false;
    }
    if (oldWallpaper == null)
      oldWallpaper = getWallpaperNative();
    return setWallpaperNative(sys.FileSystem.absolutePath(file));
    #else
    PlatformUtil.unsupportedMetaHorror('setWallpaper');
    return false;
    #end
  }

  /**
   * Restores the wallpaper captured by the first `setWallpaper` call of
   * this session.
   * @return `true` when restored (also `true` when there was nothing to restore).
   */
  public static function restoreWallpaper():Bool
  {
    #if (META_HORROR && windows && cpp)
    if (oldWallpaper == null)
      return true;
    var restored:Bool = setWallpaperNative(oldWallpaper);
    oldWallpaper = null;
    return restored;
    #else
    PlatformUtil.unsupportedMetaHorror('restoreWallpaper');
    return false;
    #end
  }

  /**
   * Hides the Windows taskbar. Remember the result state and call
   * `restoreTaskbar` when the effect ends.
   * @return `true` when the taskbar is now hidden.
   */
  public static function hideTaskbar():Bool
  {
    #if (META_HORROR && windows && cpp)
    taskbarWasVisible = hideTaskbarNative();
    return !taskbarWasVisible;
    #else
    PlatformUtil.unsupportedMetaHorror('hideTaskbar');
    return false;
    #end
  }

  /**
   * Restores the taskbar to the visibility it had before `hideTaskbar`.
   */
  public static function restoreTaskbar():Void
  {
    #if (META_HORROR && windows && cpp)
    restoreTaskbarNative(taskbarWasVisible);
    taskbarWasVisible = true;
    #else
    PlatformUtil.unsupportedMetaHorror('restoreTaskbar');
    #end
  }

  // ------------------------------------------------------------------
  // Other windows on the desktop
  // ------------------------------------------------------------------

  /**
   * Hides every visible top-level window except the game (and the shell).
   * Titles of the hidden windows are kept for `restoreAllWindows`.
   * @return How many windows were hidden. Windows only.
   */
  public static function hideAllWindows():Int
  {
    #if (META_HORROR && windows && cpp)
    var ownTitle:String = '';
    #if lime
    if (lime.app.Application.current != null && lime.app.Application.current.window != null)
      ownTitle = lime.app.Application.current.window.title;
    #end
    hiddenWindowTitles = hideWindowsNative(ownTitle);
    return hiddenWindowTitles.length;
    #else
    PlatformUtil.unsupportedMetaHorror('hideAllWindows');
    return 0;
    #end
  }

  /**
   * Re-shows the windows hidden by `hideAllWindows` (without stealing focus).
   * @return How many windows were restored. Windows only.
   */
  public static function restoreAllWindows():Int
  {
    #if (META_HORROR && windows && cpp)
    var restored:Int = restoreWindowsNative(hiddenWindowTitles);
    hiddenWindowTitles = [];
    return restored;
    #else
    PlatformUtil.unsupportedMetaHorror('restoreAllWindows');
    return 0;
    #end
  }

  // ------------------------------------------------------------------
  // Game-window tricks
  // ------------------------------------------------------------------

  /**
   * Removes the window icon AND the whole system menu (close/minimize/
   * maximize buttons) by stripping `WS_SYSMENU`, like the upstream
   * `removeWindowIcon`. Windows only.
   */
  public static function removeWindowIcon():Bool
  {
    #if (META_HORROR && windows && cpp)
    return removeWindowIconNative();
    #else
    PlatformUtil.unsupportedMetaHorror('removeWindowIcon');
    return false;
    #end
  }

  /**
   * Whole-window opacity, 0.0 (invisible) - 1.0 (opaque). Values are
   * clamped. Windows only.
   */
  public static function setWindowAlpha(alpha:Float):Bool
  {
    #if (META_HORROR && windows && cpp)
    return setWindowAlphaNative(clamp01(alpha));
    #else
    PlatformUtil.unsupportedMetaHorror('setWindowAlpha');
    return false;
    #end
  }

  /**
   * Color-key window transparency: every pixel of the game whose color
   * equals `color` (0xRRGGBB) becomes see-through to the desktop.
   * Windows only.
   */
  public static function setWindowColorKey(color:Int):Bool
  {
    #if (META_HORROR && windows && cpp)
    return setWindowColorKeyNative(color & 0xFFFFFF);
    #else
    PlatformUtil.unsupportedMetaHorror('setWindowColorKey');
    return false;
    #end
  }

  /**
   * Restores the game window's original extended style, undoing
   * `setWindowAlpha` / `setWindowColorKey` / layered effects.
   */
  public static function resetWindowEffects():Bool
  {
    #if (META_HORROR && windows && cpp)
    return resetWindowStylesNative();
    #else
    PlatformUtil.unsupportedMetaHorror('resetWindowEffects');
    return false;
    #end
  }

  // ------------------------------------------------------------------
  // The player ("who is on the other side of the screen")
  // ------------------------------------------------------------------

  /**
   * The OS account name of whoever is playing (`USERNAME` / `USER`).
   *
   * This is the classic "the character says your name" effect: a mod can put
   * the player's own Windows/Linux/macOS login name in a dialogue line. Only
   * the short account name is read - never a full name, home path or email.
   *
   * @return The account name, or `"player"` when it cannot be read.
   */
  public static function getDesktopUsername():String
  {
    #if META_HORROR
    var name:String = CoolSystemStuff.getUsername();
    if (name == null || StringTools.trim(name).length == 0)
      return 'player';
    return StringTools.trim(name);
    #else
    return 'player';
    #end
  }

  /**
   * Seconds since the machine booted, useful for "your PC has been on for
   * 14 hours"-style lines.
   *
   * Windows reads `GetTickCount64`; Linux reads `/proc/uptime`; macOS reads
   * `kern.boottime`. Other targets (and HTML5) report `0`.
   *
   * @return Uptime in whole seconds, or `0` when it cannot be read.
   */
  public static function getSystemUptime():Int
  {
    #if (META_HORROR && sys)
    #if (windows && cpp)
    var seconds:Float = getSystemUptimeNative();
    if (seconds > 0)
      return Std.int(seconds);
    #elseif linux
    try
    {
      var uptime:String = sys.io.File.getContent('/proc/uptime');
      var seconds:Float = Std.parseFloat(uptime.split(' ')[0]);
      if (!Math.isNaN(seconds) && seconds > 0)
        return Std.int(seconds);
    }
    catch (e:Dynamic) {}
    #elseif mac
    try
    {
      var boot:String = new sys.io.Process('sysctl', ['-n', 'kern.boottime']).stdout.readAll().toString();
      // "kern.boottime: { sec = 1712345678, usec = 0 } Sat Apr  6 ..."
      var match:EReg = ~/sec\s*=\s*(\d+)/;
      if (match.match(boot))
        return Std.int(Math.max(0, Date.now().getTime() / 1000 - Std.parseInt(match.matched(1))));
    }
    catch (e:Dynamic) {}
    #end
    return 0;
    #else
    return 0;
    #end
  }

  /**
   * The player's local clock hour (0-23), for "it is 3 AM, why are you still
   * playing?" lines. Never blocks; falls back to `0` on targets without a
   * real clock.
   */
  public static function getLocalHour():Int
  {
    #if META_HORROR
    return Date.now().getHours();
    #else
    return 0;
    #end
  }

  /**
   * The player's local time as `HH:MM` (24-hour clock).
   */
  public static function getLocalTimeString():String
  {
    #if META_HORROR
    var now:Date = Date.now();
    return twoDigits(now.getHours()) + ':' + twoDigits(now.getMinutes());
    #else
    return '00:00';
    #end
  }

  /**
   * `true` when the player's local hour is inside `[fromHour, toHour)`.
   *
   * The default `0`-`5` window is "late night"; the range may wrap past
   * midnight (`isLateNight(23, 4)`).
   *
   * @param fromHour Inclusive start hour (0-23).
   * @param toHour   Exclusive end hour (0-24); `0` is treated as `24`.
   */
  public static function isLateNight(fromHour:Int = 0, toHour:Int = 5):Bool
  {
    #if META_HORROR
    var hour:Int = getLocalHour();
    var from:Int = fromHour % 24;
    var to:Int = (toHour == 0 || toHour >= 24) ? 24 : toHour;
    if (from < 0)
      from += 24;
    if (from == to)
      return false;
    if (from < to)
      return hour >= from && hour < to;
    // Wraps midnight: 23 -> 4 means [23, 24) + [0, 4).
    return hour >= from || hour < to;
    #else
    return false;
    #end
  }

  // ------------------------------------------------------------------
  // Memory across sessions (the game remembering the player)
  // ------------------------------------------------------------------

  /**
   * How many times this engine install has been launched, including this one.
   *
   * Counted once per process and stored next to the normal save file, so a mod
   * can say "this is your 12th time here". Values survive restarts, mod
   * switches and crashes.
   */
  public static function getLaunchCount():Int
  {
    #if META_HORROR
    return Std.int(persistentNumber(LAUNCH_COUNT_KEY, 0));
    #else
    return 0;
    #end
  }

  /**
   * Reads a number a mod stored with `setPersistentValue`.
   * @return The stored value, or `defaultValue` when the key is unknown.
   */
  public static function getPersistentValue(key:String, ?defaultValue:Float = 0):Float
  {
    #if META_HORROR
    if (!validPersistentKey(key))
      return defaultValue;
    return persistentNumber(key, defaultValue);
    #else
    return defaultValue;
    #end
  }

  /**
   * Stores a number that survives game restarts (playthrough counters,
   * "how many times has the player seen this", ...).
   *
   * @return `true` when the value was written.
   */
  public static function setPersistentValue(key:String, value:Float):Bool
  {
    #if META_HORROR
    if (!validPersistentKey(key))
    {
      trace('MetaHorror.setPersistentValue: invalid key "$key"');
      return false;
    }
    var save:FlxSave = getSessionSave();
    if (save == null || save.data == null)
      return false;
    var values:Dynamic = save.data.metaHorrorValues;
    if (values == null)
    {
      values = {};
      save.data.metaHorrorValues = values;
    }
    Reflect.setField(values, key, value);
    save.flush();
    return true;
    #else
    return false;
    #end
  }

  /**
   * @return Whether `setPersistentValue` has ever stored `key`.
   */
  public static function hasPersistentValue(key:String):Bool
  {
    #if META_HORROR
    if (!validPersistentKey(key))
      return false;
    var save:FlxSave = getSessionSave();
    if (save == null || save.data == null)
      return false;
    var values:Dynamic = save.data.metaHorrorValues;
    return values != null && Reflect.hasField(values, key);
    #else
    return false;
    #end
  }

  /**
   * Adds `amount` to a persistent counter and returns the new total.
   *
   * Handy for "you have died 37 times" style callbacks without the mod having
   * to read-modify-write the value itself.
   */
  public static function addPersistentValue(key:String, ?amount:Float = 1):Float
  {
    #if META_HORROR
    var total:Float = getPersistentValue(key) + amount;
    return setPersistentValue(key, total) ? total : getPersistentValue(key);
    #else
    return 0;
    #end
  }

  /** Removes every value stored by `setPersistentValue`. */
  public static function clearPersistentValues():Bool
  {
    #if META_HORROR
    var save:FlxSave = getSessionSave();
    if (save == null || save.data == null)
      return false;
    save.data.metaHorrorValues = null;
    save.flush();
    return true;
    #else
    return false;
    #end
  }

  // ------------------------------------------------------------------
  // Clipboard
  // ------------------------------------------------------------------

  /**
   * The current OS clipboard text - the game reading what the player copied.
   *
   * @return The clipboard contents, or `""` when empty/unavailable.
   */
  public static function getClipboardText():String
  {
    #if META_HORROR
    try
    {
      var text:String = lime.system.Clipboard.text;
      return text == null ? '' : text;
    }
    catch (e:Dynamic)
    {
      return '';
    }
    #else
    return '';
    #end
  }

  /**
   * Puts `text` on the OS clipboard, so the player finds a message waiting
   * for them in whatever they paste into next.
   *
   * @return `true` when the clipboard was updated.
   */
  public static function setClipboardText(text:String):Bool
  {
    #if META_HORROR
    if (text == null)
      return false;
    try
    {
      lime.system.Clipboard.text = text;
      return true;
    }
    catch (e:Dynamic)
    {
      return false;
    }
    #else
    return false;
    #end
  }

  // ------------------------------------------------------------------
  // Window title & focus games
  // ------------------------------------------------------------------

  /**
   * Renames the game window ("Friday Night Funkin' - Phoenix Engine" becomes
   * "I CAN SEE YOU"). The original title is remembered for
   * `restoreWindowTitle`, and any title `MusicBeatState` applies afterwards
   * replaces this one, so call it again after a state change if the effect
   * must persist.
   *
   * @return `true` when the title changed.
   */
  public static function setWindowTitle(title:String):Bool
  {
    #if (META_HORROR && !flash)
    if (title == null)
      return false;
    var window:Dynamic = currentWindow();
    if (window == null)
      return false;
    if (originalWindowTitle == null)
    {
      originalWindowTitle = window.title;
      // Remember the parts MusicBeatState rebuilds the title from, so
      // restoreWindowTitle can put the exact same string back later.
      originalTitlePrefix = MusicBeatState.windowNamePrefix;
      originalTitleSuffix = MusicBeatState.windowNameSuffix;
      originalTitleSuffix2 = MusicBeatState.windowNameSuffix2;
    }
    window.title = title;
    return window.title == title;
    #else
    PlatformUtil.unsupportedMetaHorror('setWindowTitle');
    return false;
    #end
  }

  /**
   * Puts back the window title from before the first `setWindowTitle`.
   * @return `true` when a title was restored.
   */
  public static function restoreWindowTitle():Bool
  {
    #if (META_HORROR && !flash)
    if (originalWindowTitle == null)
      return true;
    var window:Dynamic = currentWindow();
    var restored:Bool = false;
    if (window != null)
    {
      window.title = originalWindowTitle;
      restored = window.title == originalWindowTitle;
    }
    if (originalTitlePrefix != null)
      MusicBeatState.windowNamePrefix = originalTitlePrefix;
    if (originalTitleSuffix != null)
      MusicBeatState.windowNameSuffix = originalTitleSuffix;
    if (originalTitleSuffix2 != null)
      MusicBeatState.windowNameSuffix2 = originalTitleSuffix2;
    originalWindowTitle = null;
    originalTitlePrefix = null;
    originalTitleSuffix = null;
    originalTitleSuffix2 = null;
    return restored;
    #else
    PlatformUtil.unsupportedMetaHorror('restoreWindowTitle');
    return false;
    #end
  }

  /**
   * Keeps the game window above every other window (`HWND_TOPMOST`), so the
   * player cannot hide it behind a browser. Windows only.
   *
   * @return `true` when the window is now (or already was) always on top.
   */
  public static function setAlwaysOnTop(enabled:Bool):Bool
  {
    #if (META_HORROR && windows && cpp)
    var applied:Bool = setAlwaysOnTopNative(enabled);
    if (applied)
      alwaysOnTop = enabled;
    return applied;
    #else
    PlatformUtil.unsupportedMetaHorror('setAlwaysOnTop');
    return false;
    #end
  }

  /**
   * @return Whether this session currently pins the window on top.
   */
  public static function isAlwaysOnTop():Bool
  {
    #if (META_HORROR && windows && cpp)
    return alwaysOnTop;
    #else
    return false;
    #end
  }

  /**
   * Flashes the game's taskbar button `times` times, the way a chat app
   * demands attention. The flash stops by itself; `stopTaskbarFlash` cancels
   * it early.
   *
   * @param times How many flashes (clamped to 1-10). Windows only.
   * @return `true` when the flash request reached the shell.
   */
  public static function flashTaskbar(?times:Int = 3):Bool
  {
    #if (META_HORROR && windows && cpp)
    var count:Int = Std.int(Math.max(1, Math.min(10, times)));
    return flashTaskbarNative(count);
    #else
    PlatformUtil.unsupportedMetaHorror('flashTaskbar');
    return false;
    #end
  }

  /** Stops a `flashTaskbar` request that is still running. Windows only. */
  public static function stopTaskbarFlash():Void
  {
    #if (META_HORROR && windows && cpp)
    stopTaskbarFlashNative();
    #else
    PlatformUtil.unsupportedMetaHorror('stopTaskbarFlash');
    #end
  }

  // ------------------------------------------------------------------
  // Looking at the desktop
  // ------------------------------------------------------------------

  /**
   * Titles of the other visible windows on the desktop, so a mod can react to
   * what the player has open ("you left Discord open while playing?").
   *
   * Only window *titles* are read - never their contents. The game's own
   * window and the shell are excluded, and the list is sorted for stable
   * output.
   *
   * @return The titles, or `[]` on unsupported targets. Windows only.
   */
  public static function getOpenWindowTitles():Array<String>
  {
    #if (META_HORROR && windows && cpp)
    var ownTitle:String = '';
    var window:Dynamic = currentWindow();
    if (window != null)
      ownTitle = window.title;
    var titles:Array<String> = listWindowsNative(ownTitle);
    titles.sort(function(a:String, b:String):Int return Reflect.compare(a, b));
    return titles;
    #else
    PlatformUtil.unsupportedMetaHorror('getOpenWindowTitles');
    return [];
    #end
  }

  /**
   * Takes a PNG screenshot of the *whole desktop* (every monitor's current
   * desktop, including other applications) and writes it to disk, so the mod
   * can `openFile` it or leak it somewhere.
   *
   * This is the single most invasive effect in this class: it captures the
   * player's screen. `captureDesktop()` returns `null` (and writes nothing)
   * whenever the platform cannot do it.
   *
   * @param fileName File name without extension. Default: `desktop`.
   * @param location Target directory. Default: `<temp>/phoenix_horror`.
   * @return The written file path, or `null` on failure. Windows only.
   */
  public static function captureDesktop(?fileName:String = 'desktop', ?location:String):Null<String>
  {
    #if (META_HORROR && windows && cpp)
    if (location == null || location.length == 0)
    {
      location = CoolSystemStuff.getTempPath();
      if (location == null || location.length == 0)
        location = Sys.getCwd();
      location = haxe.io.Path.join([location, 'phoenix_horror']);
    }
    var name:String = (fileName == null || fileName.length == 0) ? 'desktop' : fileName;
    var outPath:String = haxe.io.Path.join([location, '$name.png']);

    // The capture itself is native and writes a 24-bit BMP: pixel buffers
    // never cross the hxcpp boundary, so there is no per-byte marshalling and
    // no multi-hundred-megabyte Haxe array for a 4K desktop. OpenFL then
    // decodes that BMP and re-encodes it as PNG.
    var rawPath:String = haxe.io.Path.join([location, '.meta_horror_capture.bmp']);
    if (!captureDesktopToBmpNative(rawPath))
    {
      trace('MetaHorror.captureDesktop: the desktop could not be captured');
      return null;
    }

    var bitmap:openfl.display.BitmapData = null;
    try
    {
      bitmap = openfl.display.BitmapData.fromFile(rawPath);
      if (bitmap == null)
      {
        trace('MetaHorror.captureDesktop: the capture could not be decoded');
        return null;
      }

      var png:openfl.utils.ByteArray = bitmap.encode(bitmap.rect, new openfl.display.PNGEncoderOptions(true));
      if (png == null)
        return null;

      var directory:String = haxe.io.Path.directory(outPath);
      if (!sys.FileSystem.exists(directory))
        sys.FileSystem.createDirectory(directory);
      png.position = 0;
      sys.io.File.saveBytes(outPath, png);
      return outPath;
    }
    catch (e:Dynamic)
    {
      trace('MetaHorror.captureDesktop: failed to write "$outPath" - $e');
      return null;
    }
    finally
    {
      if (bitmap != null)
        bitmap.dispose();
      // The intermediate BMP is an implementation detail, never a deliverable.
      try
        sys.FileSystem.deleteFile(rawPath)
      catch (e:Dynamic) {}
    }
    #else
    PlatformUtil.unsupportedMetaHorror('captureDesktop');
    return null;
    #end
  }

  // ------------------------------------------------------------------
  // Undo everything
  // ------------------------------------------------------------------

  /**
   * Undoes every effect this class can apply: the wallpaper, the taskbar, the
   * hidden windows, window style/alpha/color-key, always-on-top, the window
   * title and a running taskbar flash.
   *
   * A mod should call this from `onSongEnd`, `onGameOver` and `onDestroy`.
   * The engine also calls it automatically when the application exits, so a
   * crash or alt-F4 never leaves the player's desktop modified (see
   * `installExitCleanup`).
   */
  public static function restoreAll():Void
  {
    #if META_HORROR
    typeToken++; // cancel any unfinished typeText

    // Portable: the window title is a Lime property on every desktop target.
    restoreWindowTitle();

    #if windows
    // Windows-only effects, grouped so a Linux/macOS build does not print six
    // "not supported on this platform" traces every time the game exits.
    restoreWallpaper();
    restoreTaskbar();
    restoreAllWindows();
    resetWindowEffects();
    stopTaskbarFlash();
    if (alwaysOnTop)
      setAlwaysOnTop(false);
    #end
    #else
    PlatformUtil.unsupportedMetaHorror('restoreAll');
    #end
  }

  /**
   * Hooks `restoreAll` into the application exit signal and counts this
   * launch. Idempotent: the engine calls it once at startup, and calling it
   * again is harmless.
   */
  public static function installExitCleanup():Void
  {
    #if (META_HORROR && !flash)
    if (exitCleanupInstalled)
      return;
    exitCleanupInstalled = true;

    // Remember this launch for getLaunchCount(). Reading + writing once at
    // startup is cheap and keeps the counter correct even if the game crashes
    // before the player finishes a song.
    var save:FlxSave = getSessionSave();
    if (save != null && save.data != null)
    {
      var launches:Float = persistentNumber(LAUNCH_COUNT_KEY, 0) + 1;
      var values:Dynamic = save.data.metaHorrorValues;
      if (values == null)
      {
        values = {};
        save.data.metaHorrorValues = values;
      }
      Reflect.setField(values, LAUNCH_COUNT_KEY, launches);
      save.flush();
    }

    if (lime.app.Application.current != null && lime.app.Application.current.onExit != null)
      lime.app.Application.current.onExit.add(function(_:Int) restoreAll());
    #end
  }

  // ------------------------------------------------------------------
  // System info
  // ------------------------------------------------------------------

  /**
   * Physically installed system RAM in megabytes (upstream `obtainRAM`),
   * served by the engine's `debug.system.SystemInfo` query.
   * @return RAM in MB, or 0 when unavailable.
   */
  public static function getSystemRAM():Int
  {
    #if META_HORROR
    return Std.int(debug.system.SystemInfo.totalPhysicalMemory() / 1024 / 1024);
    #else
    return 0;
    #end
  }

  // ------------------------------------------------------------------
  // Internals
  // ------------------------------------------------------------------

  inline static function clamp01(value:Float):Float
    return Math.max(0.0, Math.min(1.0, value));

  /** Two-digit zero padding for `HH:MM` strings. */
  inline static function twoDigits(value:Int):String
    return (value < 10 ? '0' : '') + value;

  /**
   * The live Lime window, or `null` on targets without one. Typed `Dynamic`
   * because `lime.ui.Window` has no Flash implementation.
   */
  static function currentWindow():Dynamic
  {
    #if flash
    return null;
    #else
    var app:lime.app.Application = lime.app.Application.current;
    return app == null ? null : app.window;
    #end
  }

  /**
   * Persistent-value keys become object fields in the save file, so they are
   * restricted to `[A-Za-z0-9_]` (and a leading `_` is refused, since those
   * names are reserved for engine internals).
   */
  static function validPersistentKey(key:String):Bool
  {
    if (key == null)
      return false;
    var trimmed:String = StringTools.trim(key);
    if (trimmed.length == 0 || trimmed.length > 64 || StringTools.startsWith(trimmed, '_'))
      return false;
    for (i in 0...trimmed.length)
    {
      var code:Int = trimmed.charCodeAt(i);
      var isDigit:Bool = code >= 0x30 && code <= 0x39;
      var isUpper:Bool = code >= 0x41 && code <= 0x5A;
      var isLower:Bool = code >= 0x61 && code <= 0x7A;
      if (!isDigit && !isUpper && !isLower && code != 0x5F)
        return false;
    }
    return true;
  }

  /**
   * The persistent save slot, opened on first use.
   *
   * It is a separate `FlxSave` (still in the engine's save folder) so a mod
   * writing a counter can never corrupt `FlxG.save` or the controls file.
   * Returns `null` when the save system is unavailable.
   */
  static function getSessionSave():Null<FlxSave>
  {
    #if META_HORROR
    if (sessionSave != null)
      return sessionSave;
    try
    {
      var save:FlxSave = new FlxSave();
      save.bind(PERSISTENT_SAVE_NAME, CoolUtil.getSavePath());
      sessionSave = save;
      return save;
    }
    catch (e:Dynamic)
    {
      trace('MetaHorror: persistent values unavailable - $e');
      return null;
    }
    #else
    return null;
    #end
  }

  /** Reads one persisted number without creating the key. */
  static function persistentNumber(key:String, defaultValue:Float):Float
  {
    #if META_HORROR
    var save:FlxSave = getSessionSave();
    if (save == null || save.data == null)
      return defaultValue;
    var values:Dynamic = save.data.metaHorrorValues;
    if (values == null || !Reflect.hasField(values, key))
      return defaultValue;
    var value:Dynamic = Reflect.field(values, key);
    if (value == null)
      return defaultValue;
    if (Std.isOfType(value, Int) || Std.isOfType(value, Float))
      return value;
    var parsed:Float = Std.parseFloat(Std.string(value));
    return Math.isNaN(parsed) ? defaultValue : parsed;
    #else
    return defaultValue;
    #end
  }

  #if (META_HORROR && sys)
	/**
	 * Copies `imageFile` (a real file) or dumps an embedded asset (re-encoded
	 * as PNG with alpha) to `outPath`. Creates directories as needed.
	 */
	static function dumpImageToFile(imageFile:String, outPath:String):Bool
	{
		try
		{
			var directory:String = haxe.io.Path.directory(outPath);
			if (!sys.FileSystem.exists(directory))
				sys.FileSystem.createDirectory(directory);

			// Real file on disk: plain copy keeps the original format.
			if (sys.FileSystem.exists(imageFile))
			{
				sys.io.File.copy(imageFile, outPath);
				return true;
			}

			// Embedded asset: decode synchronously, re-encode as PNG.
			if (openfl.utils.Assets.exists(imageFile))
			{
				var bitmap:openfl.display.BitmapData = openfl.utils.Assets.getBitmapData(imageFile);
				if (bitmap == null)
					return false;
				var bytes:openfl.utils.ByteArray = bitmap.encode(bitmap.rect, new openfl.display.PNGEncoderOptions(true));
				if (bytes == null)
					return false;
				sys.io.File.saveBytes(outPath, bytes);
				return true;
			}

			trace('MetaHorror: image "$imageFile" not found');
			return false;
		}
		catch (e:Dynamic)
		{
			trace('MetaHorror: failed to dump "$imageFile" - $e');
			return false;
		}
	}

  /**
   * Turns a `setWallpaper` argument into a real file on disk: absolute
   * paths pass through, mod images (`mods/images/<name>.png`) resolve
   * directly, and embedded assets are dumped to a temp file first.
   */
  static function resolveWallpaperFile(path:String, absolute:Bool):Null<String>
  {
    if (absolute)
      return sys.FileSystem.exists(path) ? path : null;

    #if MODS_ALLOWED
    var modPath:String = Paths.modsImages(path);
    if (sys.FileSystem.exists(modPath))
      return modPath;
    #end

    var assetPath:String = Paths.imagePath(path);
    if (openfl.utils.Assets.exists(assetPath))
      return duplicateImage(assetPath, 'phoenix_wallpaper', 'png');
    return null;
  }
  #end

  // ------------------------------------------------------------------
  // Windows native implementation (Win32 / WASAPI)
  // ------------------------------------------------------------------
  #if (windows && cpp)
  @:buildXml('
<target id="haxe">
    <lib name="ole32.lib" if="windows" />
    <lib name="user32.lib" if="windows" />
    <lib name="shell32.lib" if="windows" />
</target>
')
  @:headerCode('
#include <Windows.h>
#include <shellapi.h>
#include "phoenix_window.h"
#include <mmdeviceapi.h>
#include <endpointvolume.h>
#include <cstdio>
#include <cstring>
#include <iostream>
#include <string>
#include <vector>
#undef TRUE
#undef FALSE
#undef NO_ERROR

// --- MetaHorror native helpers (file scope: statics with internal linkage) ---

// WASAPI GUIDs, defined here so no import library is needed.
static const CLSID metaClsidMMDeviceEnumerator = {0xBCDE0395, 0xE52F, 0x467C, {0x8E, 0x3D, 0xC4, 0x57, 0x92, 0x91, 0x69, 0x2E}};
static const IID metaIidIMMDeviceEnumerator = {0xA95664D2, 0x9614, 0x4F35, {0xA7, 0x46, 0xDE, 0x8D, 0xB6, 0x36, 0x17, 0xE6}};
static const IID metaIidIAudioEndpointVolume = {0x5CDF2C82, 0x841E, 0x4546, {0x97, 0x22, 0x0C, 0xF7, 0x40, 0x78, 0x22, 0x9A}};

static std::string metaOwnWindowTitle;

// Grabs the default output endpoint. COM is initialized process-wide and
// intentionally left initialized (other engine systems use it too).
static bool metaAudioEndpoint(IMMDeviceEnumerator **enumerator, IMMDevice **device, IAudioEndpointVolume **endpoint)
{
  CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
  *enumerator = NULL;
  *device = NULL;
  *endpoint = NULL;
  if (FAILED(CoCreateInstance(metaClsidMMDeviceEnumerator, NULL, CLSCTX_ALL, metaIidIMMDeviceEnumerator, (void **)enumerator)))
    return false;
  if (FAILED((*enumerator)->GetDefaultAudioEndpoint(eRender, eMultimedia, device)))
    return false;
  if (FAILED((*device)->Activate(metaIidIAudioEndpointVolume, CLSCTX_ALL, NULL, (void **)endpoint)))
    return false;
  return true;
}

// EnumWindows callback: hide every visible titled window except the game
// itself and the shell, remembering titles for restoration.
static BOOL CALLBACK metaEnumHideProc(HWND hwnd, LPARAM lparam)
{
  std::vector<std::string> *hidden = reinterpret_cast<std::vector<std::string> *>(lparam);
  char titleBuffer[512] = {0};
  int ret = GetWindowTextA(hwnd, titleBuffer, 512);
  if (IsWindowVisible(hwnd) && ret > 0 && std::string(titleBuffer) != metaOwnWindowTitle
    && std::string(titleBuffer) != "Program Manager" && std::string(titleBuffer) != "Setup")
  {
    ShowWindow(hwnd, SW_HIDE);
    hidden->push_back(std::string(titleBuffer));
  }
  return TRUE;
}

// EnumWindows callback: collect the titles of the other visible top-level
// windows. Read-only: nothing is hidden, moved or activated.
static BOOL CALLBACK metaEnumListProc(HWND hwnd, LPARAM lparam)
{
  std::vector<std::string> *titles = reinterpret_cast<std::vector<std::string> *>(lparam);
  char titleBuffer[512] = {0};
  int ret = GetWindowTextA(hwnd, titleBuffer, 512);
  if (IsWindowVisible(hwnd) && ret > 0 && std::string(titleBuffer) != metaOwnWindowTitle
    && std::string(titleBuffer) != "Program Manager" && std::string(titleBuffer) != "Setup")
    titles->push_back(std::string(titleBuffer));
  return TRUE;
}
')

  @:functionCode('
    float scalar = (float)volume;
    IMMDeviceEnumerator *enumerator = NULL;
    IMMDevice *device = NULL;
    IAudioEndpointVolume *endpoint = NULL;
    if (!metaAudioEndpoint(&enumerator, &device, &endpoint))
      return false;
    bool ok = SUCCEEDED(endpoint->SetMasterVolumeLevelScalar(scalar, NULL));
    if (endpoint != NULL) endpoint->Release();
    if (device != NULL) device->Release();
    if (enumerator != NULL) enumerator->Release();
    return ok;
  ')
  static function setMasterVolumeNative(volume:Float):Bool
    return false;

  @:functionCode('
    IMMDeviceEnumerator *enumerator = NULL;
    IMMDevice *device = NULL;
    IAudioEndpointVolume *endpoint = NULL;
    if (!metaAudioEndpoint(&enumerator, &device, &endpoint))
      return false;
    bool ok = SUCCEEDED(endpoint->SetMute(mute ? 1 : 0, NULL));
    if (endpoint != NULL) endpoint->Release();
    if (device != NULL) device->Release();
    if (enumerator != NULL) enumerator->Release();
    return ok;
  ')
  static function setMasterMuteNative(mute:Bool):Bool
    return false;

  @:functionCode('
    IMMDeviceEnumerator *enumerator = NULL;
    IMMDevice *device = NULL;
    IAudioEndpointVolume *endpoint = NULL;
    if (!metaAudioEndpoint(&enumerator, &device, &endpoint))
      return -1.0;
    float level = -1.0;
    endpoint->GetMasterVolumeLevelScalar(&level);
    if (endpoint != NULL) endpoint->Release();
    if (device != NULL) device->Release();
    if (enumerator != NULL) enumerator->Release();
    return (Float)level;
  ')
  static function getMasterVolumeNative():Float
    return -1.0;

  @:functionCode('
    IMMDeviceEnumerator *enumerator = NULL;
    IMMDevice *device = NULL;
    IAudioEndpointVolume *endpoint = NULL;
    if (!metaAudioEndpoint(&enumerator, &device, &endpoint))
      return false;
    BOOL muted = FALSE;
    endpoint->GetMute(&muted);
    if (endpoint != NULL) endpoint->Release();
    if (device != NULL) device->Release();
    if (enumerator != NULL) enumerator->Release();
    return muted != 0;
  ')
  static function getMasterMuteNative():Bool
    return false;

  @:functionCode('
    POINT point;
    if (!GetCursorPos(&point))
      return false;
    return SetCursorPos(point.x + dx, point.y + dy) != 0;
  ')
  static function moveMouseNative(dx:Int, dy:Int):Bool
    return false;

  @:functionCode('
    INPUT input;
    memset(&input, 0, sizeof(INPUT));
    input.type = INPUT_KEYBOARD;
    input.ki.wVk = vk;
    input.ki.dwFlags = up ? KEYEVENTF_KEYUP : 0;
    return SendInput(1, &input, sizeof(INPUT)) == 1;
  ')
  static function sendVirtualKeyNative(vk:Int, up:Bool = false):Bool
    return false;

  @:functionCode('
    INPUT inputs[2];
    memset(inputs, 0, sizeof(inputs));
    inputs[0].type = INPUT_KEYBOARD;
    inputs[0].ki.dwFlags = KEYEVENTF_UNICODE;
    inputs[0].ki.wScan = (WORD)charCode;
    inputs[1].type = INPUT_KEYBOARD;
    inputs[1].ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;
    inputs[1].ki.wScan = (WORD)charCode;
    return SendInput(2, inputs, sizeof(INPUT)) == 2;
  ')
  static function sendUnicodeCharNative(charCode:Int):Bool
    return false;

  @:functionCode('
    HWND window = phoenixWindowFind();
    if (window == NULL)
      return false;
    // SW_SHOWNORMAL (1) is the success threshold; values <= 32 mean failure.
    HINSTANCE result = ShellExecuteW(window, L"open", path.wchar_str(), NULL, NULL, SW_SHOWNORMAL);
    return reinterpret_cast<INT_PTR>(result) > 32;
  ')
  static function openFileNative(path:String):Bool
    return false;

  @:functionCode('
    ULONGLONG milliseconds = GetTickCount64();
    return (Float)((double)milliseconds / 1000.0);
  ')
  static function getSystemUptimeNative():Float
    return 0.0;

  @:functionCode('
    HWND window = phoenixWindowFind();
    if (window == NULL)
      return false;
    // Keep the current position/size/visibility; only change the Z order.
    return SetWindowPos(window, top ? HWND_TOPMOST : HWND_NOTOPMOST, 0, 0, 0, 0,
      SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_NOOWNERZORDER) != 0;
  ')
  static function setAlwaysOnTopNative(top:Bool):Bool
    return false;

  @:functionCode('
    HWND window = phoenixWindowFind();
    if (window == NULL)
      return false;
    FLASHWINFO info;
    memset(&info, 0, sizeof(info));
    info.cbSize = sizeof(FLASHWINFO);
    info.hwnd = window;
    info.dwFlags = FLASHW_TRAY;
    info.uCount = (UINT)(count > 0 ? count : 1);
    info.dwTimeout = 0;
    return FlashWindowEx(&info) != 0;
  ')
  static function flashTaskbarNative(count:Int):Bool
    return false;

  @:functionCode('
    HWND window = phoenixWindowFind();
    if (window == NULL)
      return false;
    FLASHWINFO info;
    memset(&info, 0, sizeof(info));
    info.cbSize = sizeof(FLASHWINFO);
    info.hwnd = window;
    info.dwFlags = FLASHW_STOP;
    FlashWindowEx(&info);
    return true;
  ')
  static function stopTaskbarFlashNative():Bool
    return false;

  @:functionCode('
    std::vector<std::string> titles;
    metaOwnWindowTitle = ownTitle.c_str();
    EnumWindows(metaEnumListProc, reinterpret_cast<LPARAM>(&titles));
    metaOwnWindowTitle.clear();

    Array_obj<String> *out = new Array_obj<String>(titles.size(), titles.size());
    for (size_t i = 0; i < titles.size(); i++)
      out->Item(i) = String(titles[i].c_str());
    return out;
  ')
  static function listWindowsNative(ownTitle:String):Array<String>
    return [];


  @:functionCode('
    const int left = GetSystemMetrics(SM_XVIRTUALSCREEN);
    const int top = GetSystemMetrics(SM_YVIRTUALSCREEN);
    const int width = GetSystemMetrics(SM_CXVIRTUALSCREEN);
    const int height = GetSystemMetrics(SM_CYVIRTUALSCREEN);
    if (width <= 0 || height <= 0)
      return false;

    HDC screen = GetDC(NULL);
    if (screen == NULL)
      return false;

    // A bottom-up 32bpp DIB section: GDI writes the rows in exactly the order
    // a 24-bit BMP stores them, so the pixels can be copied out verbatim.
    BITMAPINFO info;
    memset(&info, 0, sizeof(info));
    info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    info.bmiHeader.biWidth = width;
    info.bmiHeader.biHeight = height;
    info.bmiHeader.biPlanes = 1;
    info.bmiHeader.biBitCount = 32;
    info.bmiHeader.biCompression = BI_RGB;

    void *bits = NULL;
    HBITMAP dib = CreateDIBSection(screen, &info, DIB_RGB_COLORS, &bits, NULL, 0);
    HDC memory = CreateCompatibleDC(screen);
    if (dib == NULL || memory == NULL || bits == NULL)
    {
      if (memory != NULL) DeleteDC(memory);
      if (dib != NULL) DeleteObject(dib);
      ReleaseDC(NULL, screen);
      return false;
    }

    HGDIOBJ previous = SelectObject(memory, dib);
    // SRCCOPY | CAPTUREBLT also grabs layered windows (tooltips, overlays).
    const BOOL copied = BitBlt(memory, 0, 0, width, height, screen, left, top, SRCCOPY | CAPTUREBLT);
    SelectObject(memory, previous);
    DeleteDC(memory);
    ReleaseDC(NULL, screen);

    if (!copied)
    {
      DeleteObject(dib);
      return false;
    }

    // 24-bit BI_RGB BMP: BMP rows are padded to a 4-byte boundary.
    const int rowBytes = width * 3;
    const int padding = (4 - (rowBytes % 4)) % 4;

    FILE *file = _wfopen(path.wchar_str(), L"wb");
    if (file == NULL)
    {
      DeleteObject(dib);
      return false;
    }

    BITMAPFILEHEADER header;
    memset(&header, 0, sizeof(header));
    header.bfType = 0x4D42; // "BM"
    header.bfOffBits = (DWORD)(sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER));
    header.bfSize = (DWORD)(header.bfOffBits + (DWORD)(rowBytes + padding) * (DWORD)height);

    BITMAPINFOHEADER pixelInfo;
    memset(&pixelInfo, 0, sizeof(pixelInfo));
    pixelInfo.biSize = sizeof(BITMAPINFOHEADER);
    pixelInfo.biWidth = width;
    pixelInfo.biHeight = height;
    pixelInfo.biPlanes = 1;
    pixelInfo.biBitCount = 24;
    pixelInfo.biCompression = BI_RGB;
    pixelInfo.biSizeImage = (DWORD)(rowBytes + padding) * (DWORD)height;

    bool ok = fwrite(&header, sizeof(header), 1, file) == 1
      && fwrite(&pixelInfo, sizeof(pixelInfo), 1, file) == 1;

    const unsigned char *source = (const unsigned char *)bits;
    const unsigned char pad[3] = {0, 0, 0};
    std::vector<unsigned char> row;
    if (ok)
      row.resize((size_t)rowBytes);

    for (int y = 0; ok && y < height; y++)
    {
      const unsigned char *pixel = source + (size_t)y * (size_t)width * 4;
      for (int x = 0; x < width; x++)
      {
        // DIB pixels are BGRA; BMP stores BGR, so alpha is dropped (a screen
        // capture has no meaningful alpha and 0 would read as transparent).
        row[(size_t)x * 3] = pixel[(size_t)x * 4];
        row[(size_t)x * 3 + 1] = pixel[(size_t)x * 4 + 1];
        row[(size_t)x * 3 + 2] = pixel[(size_t)x * 4 + 2];
      }
      ok = fwrite(&row[0], 1, (size_t)rowBytes, file) == (size_t)rowBytes;
      if (ok && padding > 0)
        ok = fwrite(pad, 1, (size_t)padding, file) == (size_t)padding;
    }

    fclose(file);
    DeleteObject(dib);
    return ok;
  ')
  static function captureDesktopToBmpNative(path:String):Bool
    return false;

  @:functionCode('
    wchar_t *wallpath = const_cast<wchar_t *>(path.wchar_str());
    return SystemParametersInfoW(SPI_SETDESKWALLPAPER, 0, reinterpret_cast<void *>(wallpath), SPIF_UPDATEINIFILE | SPIF_SENDCHANGE) != 0;
  ')
  static function setWallpaperNative(path:String):Bool
    return false;

  @:functionCode('
    WCHAR buffer[1024] = {0};
    if (!SystemParametersInfoW(SPI_GETDESKWALLPAPER, 1024, buffer, 0))
      return String();
    return String(buffer);
  ')
  static function getWallpaperNative():String
    return null;

  @:functionCode('
    HWND taskbar = FindWindowW(L"Shell_TrayWnd", NULL);
    if (taskbar == NULL)
      return true; // pretend it was visible so restore is a harmless no-op
    BOOL wasVisible = IsWindowVisible(taskbar);
    ShowWindow(taskbar, SW_HIDE);
    return wasVisible != 0;
  ')
  static function hideTaskbarNative():Bool
    return false;

  @:functionCode('
    if (!wasVisible)
      return;
    HWND taskbar = FindWindowW(L"Shell_TrayWnd", NULL);
    if (taskbar == NULL)
      return;
    ShowWindow(taskbar, SW_SHOWNOACTIVATE);
  ')
  static function restoreTaskbarNative(wasVisible:Bool):Void {}

  @:functionCode('
    std::vector<std::string> hidden;
    metaOwnWindowTitle = ownTitle.c_str();
    EnumWindows(metaEnumHideProc, reinterpret_cast<LPARAM>(&hidden));
    metaOwnWindowTitle.clear();

    Array_obj<String> *out = new Array_obj<String>(hidden.size(), hidden.size());
    for (size_t i = 0; i < hidden.size(); i++)
      out->Item(i) = String(hidden[i].c_str());
    return out;
  ')
  static function hideWindowsNative(ownTitle:String):Array<String>
    return [];

  @:functionCode('
    int restored = 0;
    for (int i = 0; i < prevHidden->length; i++)
    {
      HWND hwnd = FindWindowA(NULL, prevHidden[i].c_str());
      if (hwnd != NULL && ShowWindow(hwnd, SW_SHOWNA))
        restored++;
    }
    return restored;
  ')
  static function restoreWindowsNative(prevHidden:Array<String>):Int
    return 0;

  @:functionCode('
    HWND window = phoenixWindowFind();
    if (window == NULL)
      return false;
    SetWindowLongPtrW(window, GWL_STYLE, GetWindowLongPtrW(window, GWL_STYLE) & ~WS_SYSMENU);
    SetWindowPos(window, NULL, 0, 0, 0, 0, SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOOWNERZORDER);
    return true;
  ')
  static function removeWindowIconNative():Bool
    return false;

  static function setWindowAlphaNative(alpha:Float):Bool
    return Windows.__setWindowTransparencyAlpha(alpha);

  static function setWindowColorKeyNative(color:Int):Bool
    return Windows.__setWindowTransparencyColor(color);

  static function resetWindowStylesNative():Bool
    return Windows.resetWindowTransparency();
  #end
}
