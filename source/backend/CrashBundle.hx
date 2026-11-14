package backend;

import backend.CrashBundleWriter.CrashBundleBuild;
import backend.CrashBundleWriter.CrashBundleFile;
import backend.CrashBundleWriter.CrashBundleWriteResult;
import haxe.io.Bytes;
import haxe.io.Path;
import mobile.files.MobileFilePicker;
import states.MainMenuState;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Collects the crash bundle and gets it into the player's hands (TODO.md §19
 * "Crash bundle export", pairs with §11 FILES).
 *
 * Alongside the plain crash log, every crash now also produces a `.zip`
 * containing everything a bug report needs:
 *
 *  - `crash.txt`            — the same text as `crash/FNF-Phoenix-Engine_*.log`;
 *  - `modsList.txt`         — the raw enabled/disabled mod list;
 *  - `modSecurity.txt`      — mods whose ModSecurity switch the player changed
 *    in the Mods menu, when there are any;
 *  - `mods/<folder>/pack.json` — one per installed mod;
 *  - `prefs.json`           — every preference, in the settings-backup format;
 *  - `screenshot.png`       — the frame the game crashed on (best effort);
 *  - `vlog.txt`             — the tail of the verbose log, when VLog is on;
 *  - `bundle.json`          — manifest: versions, target, mod list, file list.
 *
 * Where it lands:
 *
 *  - desktop: the `crash/` folder next to the executable, already reachable;
 *  - Android: the same `crash/` folder, which is exactly the SAF **"Crash
 *    Logs"** root of `PhoenixDocumentsProvider`, so the system Files app can
 *    copy it out. Because `Android/data` is still buried on Android 11+, the
 *    crash screen also offers an explicit **export** action that opens the
 *    Storage Access Framework "save as" picker (`MobileFilePicker.saveFile`),
 *    letting the player drop the bundle in Downloads or share it directly.
 *
 * Every step is best-effort and individually guarded: a missing screenshot or
 * an unreadable `pack.json` must never stop the bundle, and the bundle must
 * never stop the crash handler. The archive format, caps and retention live in
 * the Flixel-free {@link backend.CrashBundleWriter}.
 */
class CrashBundle
{
  /** Folder the bundle is written to (same as the crash log). */
  public static inline var DIRECTORY:String = 'crash';

  /** MIME type used by the Android document picker. */
  public static inline var MIME:String = 'application/zip';

  /** Cap for a single `pack.json` (a broken/huge one must not bloat the zip). */
  public static inline var MAX_PACK_BYTES:Int = 1024 * 1024;

  /** Cap for the crash text / modsList entries. */
  public static inline var MAX_TEXT_BYTES:Int = 2 * 1024 * 1024;

  /** Only the tail of the vlog is bundled, to keep the archive small. */
  public static inline var MAX_VLOG_BYTES:Int = 512 * 1024;

  /** Most mods whose `pack.json` is bundled. */
  public static inline var MAX_MODS:Int = 200;

  /** Path of the bundle written for the last crash ('' when none). */
  public static var lastBundlePath(default, null):String = '';

  /** File name of the last bundle ('' when none). */
  public static var lastBundleName(default, null):String = '';

  /** Bytes of the last bundle, kept for the crash screen's "save as" action. */
  public static var lastBundleBytes(default, null):Bytes = null;

  /** Why the last bundle could not be written ('' when it was). */
  public static var lastError(default, null):String = '';

  /** True while the export picker is open, so it cannot stack dialogs. */
  public static var busy(default, null):Bool = false;

  static var lastCrashText:String = '';
  static var lastLogPath:String = '';

  /**
   * Called by `CrashHandler` right after the crash log is written. Builds the
   * bundle, writes it next to the log and keeps the bytes around so the crash
   * screen can save it somewhere else. Never throws.
   *
   * @param crashText the full crash log contents (message + versions + hardware)
   * @param logPath   path of the `.log` that was just written
   */
  public static function onCrash(crashText:String, logPath:String):Void
  {
    lastCrashText = crashText == null ? '' : crashText;
    lastLogPath = logPath == null ? '' : logPath;
    lastBundlePath = '';
    lastBundleName = '';
    lastBundleBytes = null;
    lastError = '';

    #if sys
    try
    {
      var notes:Array<String> = [];
      var built:CrashBundleBuild = CrashBundleWriter.build(collect(lastCrashText, notes), manifestInfo(notes));
      lastBundleBytes = built.bytes;

      var result:CrashBundleWriteResult = CrashBundleWriter.writeBytes(DIRECTORY, built.bytes);
      if (result.ok)
      {
        lastBundlePath = result.path;
        lastBundleName = Path.withoutDirectory(result.path);
      }
      else
        lastError = result.error;
    }
    catch (e:Dynamic)
    {
      lastError = describeError(e);
    }
    #else
    lastError = 'Crash bundles need a filesystem (unavailable on this target).';
    #end
  }

  /**
   * Opens a "save as" dialog (desktop) or the SAF picker (Android) for the last
   * crash bundle, so the player can put it somewhere they can actually reach.
   *
   * @param onResult message to show the player; `null` means they canceled.
   */
  public static function exportLastBundle(?onResult:String->Void):Void
  {
    if (busy)
      return;

    // The auto-write may have failed (read-only folder, disk full); rebuilding
    // from the stashed crash text still lets the player export manually.
    if (lastBundleBytes == null)
    {
      #if sys
      try
      {
        var notes:Array<String> = [];
        lastBundleBytes = CrashBundleWriter.build(collect(lastCrashText, notes), manifestInfo(notes)).bytes;
      }
      catch (e:Dynamic)
      {
        lastError = describeError(e);
      }
      #end
    }

    if (lastBundleBytes == null)
    {
      if (onResult != null)
        onResult('No crash bundle is available on this platform.');
      return;
    }

    busy = true;
    var name:String = lastBundleName.length > 0 ? lastBundleName : CrashBundleWriter.fileName();
    var answered:Bool = false;
    final started:Bool = MobileFilePicker.saveFile(lastBundleBytes, name, MIME, 'Save the crash bundle (.zip)', function(path:String):Void
    {
      answered = true;
      busy = false;
      if (onResult == null)
        return;
      if (path == null || StringTools.trim(path).length == 0)
      {
        onResult(null); // canceled
        return;
      }
      onResult('Crash bundle saved to:\n' + path);
    });

    if (!started)
    {
      busy = false;
      if (!answered && onResult != null)
        onResult('This platform has no "save as" dialog,\nso the bundle cannot be exported.');
    }
  }

  /**
   * Gathers every bundle entry. Each piece is independently guarded and a
   * failure is recorded in `notes` (which ends up in the manifest) instead of
   * aborting the collection.
   */
  public static function collect(crashText:String, notes:Array<String>):Array<CrashBundleFile>
  {
    var files:Array<CrashBundleFile> = [];

    // 1. The crash text itself.
    files.push({name: 'crash.txt', data: cappedText(crashText, MAX_TEXT_BYTES, notes, 'crash.txt')});

    #if sys
    // 2. The raw mod list (read directly; Mods.parseList() would rewrite it).
    try
    {
      if (FileSystem.exists('modsList.txt') && !FileSystem.isDirectory('modsList.txt'))
        files.push({name: 'modsList.txt', data: cappedText(File.getContent('modsList.txt'), MAX_TEXT_BYTES, notes, 'modsList.txt')});
      else
        notes.push('modsList.txt: not present (no mods installed yet).');
    }
    catch (e:Dynamic)
    {
      notes.push('modsList.txt unavailable: ' + describeError(e));
    }

    // 2b. The player's per-mod ModSecurity choices (Mods menu -> Mod Info). The
    //     file only exists once a choice was made; a mod it lists with "|0" ran
    //     unsandboxed, whatever its pack.json says.
    try
    {
      var choices:String = ModSecurity.PLAYER_OVERRIDES_FILE;
      if (FileSystem.exists(choices) && !FileSystem.isDirectory(choices))
        files.push({name: choices, data: cappedText(File.getContent(choices), MAX_TEXT_BYTES, notes, choices)});
    }
    catch (e:Dynamic)
    {
      notes.push(ModSecurity.PLAYER_OVERRIDES_FILE + ' unavailable: ' + describeError(e));
    }

    // 3. One pack.json per installed mod.
    try
    {
      var folders:Array<String> = Mods.getModDirectories();
      var count:Int = 0;
      for (folder in folders)
      {
        if (count >= MAX_MODS)
        {
          notes.push('Only the first $MAX_MODS mods were bundled (${folders.length} installed).');
          break;
        }
        var packPath:String = 'mods/' + folder + '/pack.json';
        try
        {
          if (FileSystem.exists(packPath) && !FileSystem.isDirectory(packPath))
          {
            files.push({name: 'mods/' + folder + '/pack.json', data: cappedText(File.getContent(packPath), MAX_PACK_BYTES, notes, packPath)});
            count++;
          }
        }
        catch (e:Dynamic)
        {
          notes.push('$packPath unavailable: ' + describeError(e));
        }
      }
    }
    catch (e:Dynamic)
    {
      notes.push('mod folders unavailable: ' + describeError(e));
    }
    #end

    // 4. Preferences, in the same format as the settings backup.
    try
    {
      files.push({name: 'prefs.json', data: Bytes.ofString(SettingsBackupCodec.encode(SettingsBackup.collect()))});
    }
    catch (e:Dynamic)
    {
      notes.push('prefs.json unavailable: ' + describeError(e));
    }

    // 5. The frame the game crashed on.
    try
    {
      var shot:Null<CrashBundleFile> = captureScreenshot();
      if (shot != null)
        files.push(shot);
      else
        notes.push('screenshot unavailable on this target.');
    }
    catch (e:Dynamic)
    {
      notes.push('screenshot failed: ' + describeError(e));
    }

    // 6. The verbose log tail, only when the player enabled VLog.
    try
    {
      if (VLog.enabled)
      {
        var text:String = VLog.exportText();
        if (text != null && text.length > 0)
        {
          if (text.length > MAX_VLOG_BYTES)
            text = '[vlog tail: last $MAX_VLOG_BYTES characters]\n' + text.substr(text.length - MAX_VLOG_BYTES);
          files.push({name: 'vlog.txt', data: Bytes.ofString(text)});
        }
      }
    }
    catch (e:Dynamic)
    {
      notes.push('vlog.txt unavailable: ' + describeError(e));
    }

    return files;
  }

  /**
   * Captures the current window contents as a PNG (falling back to JPEG when a
   * huge PNG would exceed the entry cap). Returns null when the target cannot
   * read pixels.
   */
  static function captureScreenshot():Null<CrashBundleFile>
  {
    #if sys
    if (FlxG.stage == null || FlxG.stage.window == null)
      return null;
    var image:lime.graphics.Image = FlxG.stage.window.readPixels();
    if (image == null)
      return null;

    var png:Bytes = image.encode(PNG);
    if (png != null && png.length > 0 && png.length <= CrashBundleWriter.MAX_ENTRY_BYTES)
      return {name: 'screenshot.png', data: png};

    // A 4K lossless PNG can be enormous; JPEG keeps the bundle shareable.
    var jpeg:Bytes = image.encode(JPEG, 85);
    if (jpeg != null && jpeg.length > 0 && jpeg.length <= CrashBundleWriter.MAX_ENTRY_BYTES)
      return {name: 'screenshot.jpg', data: jpeg};
    #end
    return null;
  }

  /** Manifest fields describing the build and the mod setup. */
  static function manifestInfo(notes:Array<String>):Dynamic
  {
    var info:Dynamic = {
      engine: 'Phoenix Engine ' + PhoenixVersion.current,
      jseVersion: MainMenuState.psychEngineJSVersion,
      psychVersion: MainMenuState.psychEngineVersion,
      commit: MainMenuState.gitCommit,
      target: targetLabel(),
      createdAt: Date.now().toString(),
      crashLog: lastLogPath,
      currentMod: Mods.currentModDirectory,
      mods: modsListSummary(),
      notes: notes
    };
    return info;
  }

  /**
   * Enabled/disabled mods parsed straight from `modsList.txt`. Deliberately not
   * `Mods.parseList()`, which can rewrite the file as a side effect — a crash
   * handler must not mutate the player's setup.
   */
  static function modsListSummary():Dynamic
  {
    var enabled:Array<String> = [];
    var disabled:Array<String> = [];
    #if sys
    try
    {
      if (FileSystem.exists('modsList.txt'))
      {
        for (line in File.getContent('modsList.txt').split('\n'))
        {
          var trimmed:String = StringTools.trim(line);
          if (trimmed.length == 0)
            continue;
          var parts:Array<String> = trimmed.split('|');
          if (parts.length > 1 && parts[1] == '1')
            enabled.push(parts[0]);
          else
            disabled.push(parts[0]);
        }
      }
    }
    catch (e:Dynamic) {}
    #end
    return {enabled: enabled, disabled: disabled};
  }

  /** Caps a text entry, keeping the head and noting the truncation. */
  static function cappedText(text:String, limit:Int, notes:Array<String>, label:String):Bytes
  {
    var value:String = text == null ? '' : text;
    if (value.length > limit)
    {
      notes.push('$label truncated to $limit characters (was ${value.length}).');
      value = value.substr(0, limit) + '\n[truncated by crash bundle]';
    }
    return Bytes.ofString(value);
  }

  static function targetLabel():String
  {
    #if android
    return 'android';
    #elseif ios
    return 'ios';
    #elseif windows
    return 'windows';
    #elseif mac
    return 'macos';
    #elseif linux
    return 'linux';
    #elseif hl
    return 'hashlink';
    #elseif neko
    return 'neko';
    #elseif web
    return 'html5';
    #elseif air
    return 'air';
    #elseif flash
    return 'flash';
    #else
    return 'unknown';
    #end
  }

  static function describeError(e:Dynamic):String
  {
    if (e == null)
      return 'Unknown error.';
    if (Std.isOfType(e, String))
      return cast e;
    var message:Dynamic = Reflect.field(e, 'message');
    if (message != null && Std.isOfType(message, String))
      return cast message;
    return Std.string(e);
  }
}
