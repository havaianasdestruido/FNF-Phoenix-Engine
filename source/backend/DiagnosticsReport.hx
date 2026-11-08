package backend;

/*
 * Phoenix Engine diagnostics — the read-only support snapshot.
 *
 * One plain-text page answering "what is this player actually running?", for
 * the moment a bug report needs evidence: engine version and commit, target
 * and feature flags, CPU/GPU/driver, framerate and memory, save and log
 * locations, the mod list in load order, the settings that change feel or
 * performance, and the last few vlog lines. It is what `phoenix://diagnostics`
 * opens (see `backend.deeplink.DeepLinks`), so a support thread can ask for a
 * single tap plus a screenshot.
 *
 * The whole module is deliberately *inert*: it only reads. Nothing here writes
 * a file, changes a preference, switches a state or touches the save data, and
 * every section is guarded, because a diagnostics page that throws while a
 * player is already debugging is worse than one with a blank row. A failing
 * data source becomes `unavailable: …` instead of an exception.
 *
 * The text is built for a screenshot, not for a terminal: roughly one screen
 * of short `Label  value` rows, section titles in `[BRACKETS]` (the VCR font
 * has no box-drawing glyphs), and the numbers support asks for most often
 * first.
 */

import flixel.FlxG;
import debug.system.SystemInfo;
#if sys
import Sys;
import sys.FileSystem;
import sys.io.File;
#end

class DiagnosticsReport
{
  /** Values are padded to this many characters so the columns stay aligned. */
  static inline final LABEL:Int = 15;

  /** How many enabled mods are listed by name before the rest are collapsed. */
  static inline final MAX_MODS:Int = 10;

  /** How many trailing log lines are shown. */
  static inline final LOG_LINES:Int = 10;

  /** Only this much of the live log is read back for the tail. */
  static inline final LOG_TAIL_BYTES:Int = 32 * 1024;

  /**
   * The full snapshot as one plain-text block: header, sections, footer.
   *
   * @return the report, ready to render or to hand to the clipboard.
   */
  public static function build():String
    return lines().join('\n');

  /** The snapshot as one entry per line, which is how the screen renders it. */
  public static function lines():Array<String>
  {
    final out:Array<String> = [];
    out.push('Phoenix Engine diagnostics - read-only snapshot');
    out.push(Date.now().toString() + '   (opening this page changed nothing)');
    out.push('');

    section(out, 'BUILD', buildSection);
    section(out, 'HARDWARE', hardwareSection);
    section(out, 'RUNTIME', runtimeSection);
    section(out, 'FILES', filesSection);
    section(out, 'MODS', modsSection);
    section(out, 'SETTINGS', settingsSection);
    section(out, 'RECENT LOG', logSection);

    out.push('[FOOTER]');
    out.push(row('Screenshot', 'this page, or press copy, then attach it to your report'));
    out.push(row('Privacy', 'log lines arrive redacted; the paths above do not'));
    return out;
  }

  // -- Sections --------------------------------------------------------------

  /** Which build this is: version identity, commit, target and feature flags. */
  static function buildSection():Array<String>
  {
    final rows:Array<String> = [];
    rows.push(row('Phoenix', PhoenixVersion.display(PhoenixVersion.current)));
    rows.push(row('Upstream', 'JS Engine v' + states.MainMenuState.psychEngineJSVersion
      + ' / Psych v' + states.MainMenuState.psychEngineVersion));
    final commit:String = states.MainMenuState.gitCommit;
    rows.push(row('Commit', (commit == null || commit.length == 0)
      ? 'unknown (built without -Dcommit)' : commit));
    final kind:String = #if debug 'debug' #else 'release' #end;
    rows.push(row('Target', platformLabel() + ', ' + kind + ' build'));
    rows.push(row('Architecture', archText()));
    rows.push(row('Features', featureFlags()));
    #if sys
    final args:Array<String> = Sys.args();
    rows.push(row('Launch args', args.length == 0 ? 'none (icon launch)' : args.join(' ')));
    #end
    return rows;
  }

  /** The machine, from the same detection the crash log uses. */
  static function hardwareSection():Array<String>
  {
    final info = Native.getSystemInfo();
    final rows:Array<String> = [];
    rows.push(row('OS', trimPair(info.osName, info.osVersion)));
    rows.push(row('CPU', info.cpuModel));
    rows.push(row('CPU vendor', info.cpuVendor));
    rows.push(row('CPU cores', Std.string(SystemInfo.logicalCPUCount())));
    rows.push(row('Total RAM', byteText(SystemInfo.totalPhysicalMemory())));
    rows.push(row('GPU', info.gpuModel));
    rows.push(row('GPU vendor', info.gpuVendor));
    rows.push(row('GPU driver', info.gpuDriver));
    rows.push(row('Graphics', info.graphicsApi));
    rows.push(row('Audio', info.audioApi));
    return rows;
  }

  /** What the game is doing right now: viewport, framerate budget and memory. */
  static function runtimeSection():Array<String>
  {
    final rows:Array<String> = [];
    rows.push(row('Game size', Std.int(FlxG.width) + 'x' + Std.int(FlxG.height)
      + (FlxG.fullscreen ? ' fullscreen' : ' windowed')));
    if (FlxG.scaleMode != null && FlxG.scaleMode.scale != null)
      rows.push(row('Scale', classNameOf(FlxG.scaleMode) + ' at x' + roundText(FlxG.scaleMode.scale.x)));
    rows.push(row('Framerate', 'target ' + ClientPrefs.framerate
      + ' (update ' + FlxG.updateFramerate + ' / draw ' + FlxG.drawFramerate + ')'));
    rows.push(row('Uptime', durationText(FlxG.game.ticks / 1000.0)));
    rows.push(row('Heap', byteText(VLog.heapUsedBytes())));
    rows.push(row('Process RSS', byteText(readRss(false))));
    rows.push(row('Peak RSS', byteText(readRss(true))));
    rows.push(row('State', classNameOf(FlxG.state)));
    rows.push(row('Measured FPS', 'see the on-screen counter, or the log lines below'));
    return rows;
  }

  /** Where the files a support thread asks for live. */
  static function filesSection():Array<String>
  {
    final rows:Array<String> = [];
    #if sys
    rows.push(row('Working dir', Sys.getCwd()));
    #end
    rows.push(row('Save data', CoolUtil.getSavePath()));
    rows.push(row('Session log', (VLog.isActive() ? 'active' : 'inactive') + ' at ' + VLog.FILE));
    rows.push(row('Crash logs', 'crash/ next to the game'));
    #if (sys && MODS_ALLOWED)
    var listState:String = 'unreadable';
    try
    {
      listState = FileSystem.exists('modsList.txt') ? 'found' : 'missing';
    }
    catch (e:Dynamic) {}
    rows.push(row('Mods folder', 'mods/ with modsList.txt ' + listState));
    #end
    #if (windows && sys)
    rows.push(row('phoenix://', ClientPrefs.deeplinkEnabled
      ? 'registered to this copy' : 'not registered (Options -> Misc)'));
    #end
    return rows;
  }

  /** The mod list in load order, since "it works without mods" needs proof. */
  static function modsSection():Array<String>
  {
    final rows:Array<String> = [];
    final list:ModsList = Mods.parseList();
    rows.push(row('Enabled', list.enabled.length + ' of ' + list.all.length));
    final shown:Int = Std.int(Math.min(list.enabled.length, MAX_MODS));
    for (i in 0...shown)
      rows.push('     ' + (i + 1) + '. ' + list.enabled[i]);
    if (list.enabled.length > shown)
      rows.push('     +' + (list.enabled.length - shown) + ' more (the mods menu lists them all)');
    if (list.enabled.length == 0)
      rows.push('     no mods are enabled');
    if (list.disabled.length > 0)
      rows.push(row('Disabled', list.disabled.join(', ')));
    if (Mods.invalidMods != null && Mods.invalidMods.length > 0)
      rows.push(row('Rejected', Mods.invalidMods.join(', ') + ' (folder missing or unsafe)'));
    if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
      rows.push(row('Active mod', Mods.currentModDirectory));
    return rows;
  }

  /**
   * The preferences that change performance or feel. Deliberately not a dump
   * of `ClientPrefs`: a screenshot has room for what support would otherwise
   * have to ask about, and everything else already lives in the settings
   * export (`backend.SettingsBackup`).
   */
  static function settingsSection():Array<String>
  {
    final rows:Array<String> = [];
    rows.push(row('Resolution', ClientPrefs.resolution + (ClientPrefs.widescreen ? ' + widescreen' : '')));
    rows.push(row('Framerate', '' + ClientPrefs.framerate));
    rows.push(row('Quality', (ClientPrefs.lowQuality ? 'low' : 'full')
      + ' quality, AA ' + (ClientPrefs.globalAntialiasing ? 'on' : 'off')
      + ', shaders ' + (ClientPrefs.shaders ? 'on' : 'off')
      + ', ' + (ClientPrefs.cacheOnGPU ? 'textures on GPU' : 'textures in RAM')));
    rows.push(row('Optimization', 'GC ' + (ClientPrefs.enableGC ? 'allowed' : 'blocked')
      + ', spawn lead ' + roundText(ClientPrefs.noteSpawnTime)
      + ', splashes ' + (ClientPrefs.noteSplashes ? '' + ClientPrefs.maxSplashLimit : 'off')));
    rows.push(row('Scroll', (ClientPrefs.downScroll ? 'down' : 'up')
      + ', ' + (ClientPrefs.middleScroll ? 'middle' : 'sides')
      + ', ghost tap ' + (ClientPrefs.ghostTapping ? 'on' : 'off')));
    rows.push(row('Note lane', ClientPrefs.distantNotes ? 'distant (perspective, forced middlescroll)' : 'flat'));
    rows.push(row('Notes', ClientPrefs.noteSkin + ' / ' + ClientPrefs.splashType));
    rows.push(row('Debug aids', 'vlog ' + onOff(ClientPrefs.vlogEnabled)
      + ', frame profiler ' + onOff(ClientPrefs.frameProfiler)
      + ', extra info ' + onOff(ClientPrefs.debugInfo)
      + ', RAM graph ' + onOff(ClientPrefs.showRamGraph)));
    rows.push(row('Online', 'update checks ' + onOff(ClientPrefs.checkForUpdates)
      + ', discord ' + onOff(ClientPrefs.discordRPC)
      + ', deeplink ' + onOff(ClientPrefs.deeplinkEnabled)));
    rows.push(row('Anti-cheat', onOff(ClientPrefs.antiCheatEnable) + ' (scores are trusted when off)'));
    return rows;
  }

  /** The tail of the live log, when there is one to read. */
  static function logSection():Array<String>
  {
    if (!VLog.isActive())
      return [VLog.enabled
        ? '  the log could not be opened (storage unwritable?)'
        : '  VLog is off: Options -> Misc -> Enable VLog, reproduce the issue, then reopen this page'];

    var tail:String = '';
    var cutHead:Bool = false;
    #if sys
    // vlog/log.txt is capped at 10 MiB by rotation, which is a lot more than a
    // screenshot needs: read only the last rows, and skip the file when it is
    // bigger than the size LogUtils is willing to copy a log to anywhere. The
    // lines themselves need no scrubbing here: VLog redacts before every disk
    // write and on export, so this page shows a log the player could paste.
    // Everything this file prints directly (paths, save dir) is not redacted,
    // which is what the footer says.
    try
    {
      if (FileSystem.exists(VLog.FILE) && FileSystem.stat(VLog.FILE).size <= LogUtils.MAX_LOG_FILE_BYTES)
      {
        final bytes = File.getBytes(VLog.FILE);
        if (bytes.length > LOG_TAIL_BYTES)
        {
          tail = bytes.getString(bytes.length - LOG_TAIL_BYTES, LOG_TAIL_BYTES);
          cutHead = true; // the first line of a mid-file read is cut in half
        }
        else if (bytes.length > 0)
          tail = bytes.toString();
      }
    }
    catch (e:Dynamic)
      tail = '';
    #end

    // Whatever has not reached the disk yet (at most ~250 ms) still belongs here.
    var kept:Array<String> = [];
    for (line in (tail + '\n' + VLog.exportText()).split('\n'))
    {
      final clean:String = StringTools.trim(line);
      if (clean.length > 0) kept.push(clean);
    }
    if (cutHead && kept.length > 1) kept.shift();
    if (kept.length > LOG_LINES) kept = kept.slice(kept.length - LOG_LINES);

    if (kept.length == 0)
      return ['  nothing logged yet'];

    final rows:Array<String> = [];
    for (line in kept)
      rows.push('  ' + line);
    return rows;
  }

  // -- Helpers ---------------------------------------------------------------

  /** Appends one `[TITLE]` block, turning a throwing data source into a row. */
  static function section(out:Array<String>, title:String, gather:Void->Array<String>):Void
  {
    out.push('[' + title + ']');
    final rows:Array<String> = try gather() catch (e:Dynamic) ['  unavailable: ' + Std.string(e)];
    if (rows == null || rows.length == 0)
      out.push('  nothing to report');
    else
      for (row in rows)
        out.push(row);
    out.push('');
  }

  /** One aligned `Label  value` row. */
  static inline function row(label:String, value:String):String
    return '  ' + StringTools.rpad(label, ' ', LABEL) + (value == null || value.length == 0 ? 'n/a' : value);

  static inline function onOff(value:Bool):String
    return value ? 'on' : 'off';

  static function trimPair(left:String, right:String):String
  {
    final a:String = (left == null) ? '' : StringTools.trim(left);
    final b:String = (right == null) ? '' : StringTools.trim(right);
    if (a.length == 0) return b;
    if (b.length == 0) return a;
    return '$a $b';
  }

  /**
   * Byte counts go through the vlog formatter, so this page agrees with the
   * log. The queries answer 0 or -1 when the target cannot know (RSS on web,
   * host RAM off C++), which would read like "0B" - so they read honestly.
   */
  static inline function byteText(bytes:Float):String
    return (bytes > 0.0) ? VLog.formatBytes(bytes) : 'not reported here';

  static inline function roundText(value:Float):String
    return Std.string(Math.round(value * 100) / 100);

  /** `Type.getClassName` with the package stripped; the class name is the useful half. */
  static function classNameOf(object:Dynamic):String
  {
    try
    {
      final cls:Class<Dynamic> = Type.getClass(object);
      if (cls == null) return 'unknown';
      final name:String = Type.getClassName(cls);
      final dot:Int = name.lastIndexOf('.');
      return dot == -1 ? name : name.substr(dot + 1);
    }
    catch (e:Dynamic) {}
    return 'unknown';
  }

  /** Seconds as `1h 02m`, `12m 30s` or `41s`. */
  static function durationText(seconds:Float):String
  {
    if (!(seconds > 0.0)) return 'n/a';
    final total:Int = Math.round(seconds);
    final hours:Int = Std.int(total / 3600);
    final minutes:Int = Std.int((total % 3600) / 60);
    final secs:Int = total % 60;
    if (hours > 0) return hours + 'h ' + pad2(minutes) + 'm';
    if (minutes > 0) return minutes + 'm ' + pad2(secs) + 's';
    return secs + 's';
  }

  static inline function pad2(value:Int):String
    return value < 10 ? '0' + value : Std.string(value);

  /** Process resident memory, and its session peak when asked for. */
  static function readRss(peak:Bool):Float
  {
    try
    {
      final rss:Float = peak ? debug.mem.GetTotalMemory.getPeakRSS() : debug.mem.GetTotalMemory.getCurrentRSS();
      return rss;
    }
    catch (e:Dynamic) {}
    return -1.0;
  }

  /** Human readable build target, mirroring the labels the vlog header writes. */
  static function platformLabel():String
  {
    #if windows
    return 'windows';
    #elseif mac
    return 'macos';
    #elseif linux
    return 'linux';
    #elseif android
    return 'android';
    #elseif ios
    return 'ios';
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
    return 'unknown target';
    #end
  }

  /** Compile-time feature flags, so a mod incompatibility can be spotted from the list. */
  static function featureFlags():String
  {
    final flags:Array<String> = [];
    addFlag(flags, 'MODS', #if MODS_ALLOWED true #else false #end);
    addFlag(flags, 'LUA', #if LUA_ALLOWED true #else false #end);
    addFlag(flags, 'PYTHON', #if PYTHON_ALLOWED true #else false #end);
    addFlag(flags, 'HSCRIPT', #if HSCRIPT_ALLOWED true #else false #end);
    addFlag(flags, 'VIDEOS', #if VIDEOS_ALLOWED true #else false #end);
    addFlag(flags, 'ACHIEVEMENTS', #if ACHIEVEMENTS_ALLOWED true #else false #end);
    addFlag(flags, 'DISCORD', #if DISCORD_ALLOWED true #else false #end);
    addFlag(flags, 'SHADERS', #if SHADERS_ALLOWED true #else false #end);
    addFlag(flags, 'GAMEMODE', #if GAMEMODE_ALLOWED true #else false #end);
    addFlag(flags, 'CRASH-HANDLER', #if CRASH_HANDLER true #else false #end);
    addFlag(flags, 'META-HORROR', #if META_HORROR true #else false #end);
    addFlag(flags, 'ULTRA-OPTIMIZED', #if ULTRA_OPTIMIZED true #else false #end);
    addFlag(flags, 'COMMIT-STAMPED', #if commit true #else false #end);
    return flags.length == 0 ? 'none' : flags.join(' ');
  }

  static inline function addFlag(flags:Array<String>, name:String, enabled:Bool):Void
  {
    if (enabled) flags.push(name);
  }

  /** CPU family, where the native bridge can answer; the arch decides 32-bit limits. */
  static function archText():String
  {
    #if cpp
    try
    {
      final arch:String = utils.PlatformUtil.getArch();
      if (arch != null && arch.length > 0) return arch;
    }
    catch (e:Dynamic) {}
    #end
    return 'not reported here';
  }
}
