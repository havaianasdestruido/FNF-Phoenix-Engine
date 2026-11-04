package backend;

import backend.DiagnosticsReport.DiagnosticsFacts;
import backend.Native.HardwareInfo;
import flixel.FlxG;
import lime.app.Application;
import lime.system.Clipboard;
import lime.system.Display;
import lime.ui.Window;
import openfl.Lib;

#if sys
import Sys;
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Collects the live facts behind `Options -> Misc -> "Copy Diagnostics"` and
 * puts the finished block on the system clipboard.
 *
 * The player-facing shape of the feature is one button: it builds the report,
 * copies it, writes a copy to `crash/diagnostics-<date>.txt` (the folder the
 * Android DocumentsProvider already exposes next to `crash/` and `vlog/`) and
 * shows the result in a read-only sub-state so the text can also be read on a
 * device without a usable clipboard.
 *
 * **Offline by design.** Nothing in this class opens a socket: the recent
 * update flow is deliberately repository-based (see `TODO.md` §0), so a
 * diagnostics report is never uploaded anywhere. The player decides where the
 * text goes.
 *
 * Formatting and redaction live in the Flixel-free `backend.DiagnosticsReport`;
 * everything here only measures, and every measurement degrades to `Unknown`
 * instead of throwing. Mods, prefs and paths are read through the same helpers
 * the rest of the engine uses (`Mods.parseList`, `SettingsBackup.preferenceFields`,
 * `CoolUtil.getSavePath`), so the report cannot drift from what the game shows.
 */
class Diagnostics
{
  /** File the report is also written to, under the exposed `crash/` folder. */
  public static inline var FILE_PREFIX:String = 'crash/diagnostics-';

  /** Trailing log lines a report keeps unless the caller asks otherwise. */
  public static inline var DEFAULT_LOG_LINES:Int = 60;

  /** True while a report is being copied, so the action cannot be stacked. */
  public static var busy(default, null):Bool = false;

  /** Report produced by the last successful copy (`null` until then). */
  public static var lastReport(default, null):String = null;

  /** Path of the file written by the last successful copy, if it was written. */
  public static var lastPath(default, null):String = null;

  /**
   * Whether the last `copyToClipboard()` actually reached a clipboard.
   *
   * The viewer reads this instead of parsing the summary text: "no clipboard
   * on this target" and "copied" produce different wording, and a substring
   * check on that wording is exactly the kind of thing that rots silently.
   */
  public static var lastClipboardOk(default, null):Bool = false;

  /**
   * Reason the last `copyToClipboard()` failed outright, or null.
   *
   * Kept separate from the returned message so the caller can decide whether
   * `lastReport` is fresh: on a failure it still holds the *previous* report,
   * and showing that would be worse than showing nothing.
   */
  public static var lastError(default, null):String = null;

  /** Memoised `Native.getSystemInfo()`; Native caches it too, this skips the try. */
  static var cachedHardware:HardwareInfo = null;

  /**
   * Builds the diagnostics block and puts it on the clipboard.
   *
   * @param logLines how many trailing log lines to attach
   * @return a short, player-facing summary; never null, never throws
   */
  public static function copyToClipboard(?logLines:Int = DEFAULT_LOG_LINES):String
  {
    if (busy) return 'A diagnostics report is already being copied.';
    busy = true;

    var message:String;
    lastError = null;
    lastClipboardOk = false;
    try
    {
      final report:String = build(logLines);
      lastReport = report;

      final copied:Bool = writeClipboard(report);
      lastClipboardOk = copied;
      lastPath = writeFile(report);

      final lines:Int = report.split('\n').length;
      final notes:Array<String> = ['Diagnostics copied to the clipboard (' + lines + ' lines).'];
      if (!copied)
        notes[0] = 'Diagnostics ready (' + lines + ' lines) — the clipboard is unavailable on this target.';
      if (lastPath != null) notes.push('Also saved to ' + lastPath + '.');
      notes.push('Paste it into your GitHub issue or support message.');
      message = notes.join('\n');
    }
    catch (e:Dynamic)
    {
      lastError = Std.string(e);
      message = 'Could not build the diagnostics report:\n' + lastError;
    }

    busy = false;
    return message;
  }

  /**
   * Builds the report text without copying it (used by the viewer sub-state
   * and by tests). Callers are expected to have run `Main`/`InitState`, but
   * every accessor below survives being called earlier.
   *
   * @param logLines how many trailing log lines to attach, 0 for none
   */
  public static function build(?logLines:Int = DEFAULT_LOG_LINES):String
  {
    return DiagnosticsReport.build(collect(logLines));
  }

  /** Everything the formatter needs, measured with fail-safe accessors. */
  public static function collect(?logLines:Int = DEFAULT_LOG_LINES):DiagnosticsFacts
  {
    final info:HardwareInfo = hardware();
    final log:String = safe(VLog.recentText, '');
    final wanted:Int = (logLines == null) ? DEFAULT_LOG_LINES : logLines;
    final tailLines:Array<String> = DiagnosticsReport.tail(log, wanted);

    return {
      generatedAt: Date.now().toString(),
      engineVersion: engineVersion(),
      jseVersion: jseVersion(),
      psychVersion: psychVersion(),
      commit: safe(() -> states.MainMenuState.gitCommit, 'Unknown'),
      target: target(),
      haxeVersion: haxeVersion(),
      frameworkVersion: definedVersion('openfl'),
      runtimeLibVersion: definedVersion('lime'),
      gameFrameworkVersion: definedVersion('flixel'),
      osName: info.osName,
      osVersion: info.osVersion,
      cpuModel: info.cpuModel,
      cpuVendor: info.cpuVendor,
      cpuCores: cpuCores(),
      ramTotal: ramTotal(),
      ramUsed: ramUsed(),
      gpuModel: info.gpuModel,
      gpuVendor: info.gpuVendor,
      gpuDriver: info.gpuDriver,
      graphicsApi: info.graphicsApi,
      renderer: rendererInfo(),
      audioApi: info.audioApi,
      heapUsed: memory(VLog.heapUsedBytes),
      processRss: memory(debug.mem.GetTotalMemory.getCurrentRSS),
      display: display(),
      framerate: framerate(),
      modCount: modCount(),
      state: stateName(),
      vlogState: vlogState(),
      installPath: installPath(),
      savePath: savePath(),
      mods: mods(),
      nonDefaultPrefs: nonDefaultPrefs(),
      logSource: logSource(log, tailLines.length, wanted),
      homeDirectory: homeDirectory(),
      // The formatter applies the count again so a caller cannot paste more
      // than it asked for.
      logLines: tailLines
    };
  }

  // -- Clipboard / file -------------------------------------------------------

  /** Puts `text` on the system clipboard; false when this target has none. */
  public static function writeClipboard(text:String):Bool
  {
    #if android
    // Lime's Android backend does not bridge the clipboard JNI that this fork
    // already ships, so ask the SDL activity directly.
    try
    {
      android.PsychJNI.clipboardSetText(text);
      return true;
    }
    catch (_:Dynamic) {}
    #end

    try
    {
      Clipboard.text = text;
      return true;
    }
    catch (_:Dynamic)
      return false;
  }

  /**
   * Writes the report next to the crash logs and returns the path, or `null`
   * when the target has no writable filesystem (web/flash).
   *
   * The stamp is spelled exactly like `CrashHandler`'s (`_` for the space,
   * `'` between the time fields) so the two kinds of file sort together in
   * `crash/`, which is the folder the player opens from the Files app.
   */
  public static function writeFile(text:String):String
  {
    #if sys
    try
    {
      if (!FileSystem.exists('crash/')) FileSystem.createDirectory('crash/');
      var stamp:String = Date.now().toString();
      stamp = stamp.replace(' ', '_');
      stamp = stamp.replace(':', "'");
      final path:String = FILE_PREFIX + stamp + '.txt';
      File.saveContent(path, text);
      return path;
    }
    catch (_:Dynamic) {}
    #end
    return null;
  }

  // -- Individual facts -------------------------------------------------------

  /** Cached `backend.Native` hardware report; never throws. */
  static function hardware():HardwareInfo
  {
    if (cachedHardware != null) return cachedHardware;
    try
    {
      final info:HardwareInfo = Native.getSystemInfo();
      if (info != null)
      {
        cachedHardware = info;
        return info;
      }
    }
    catch (_:Dynamic) {}

    cachedHardware = {
      gpuVendor: Native.UNKNOWN,
      gpuModel: Native.UNKNOWN,
      gpuDriver: Native.UNKNOWN,
      cpuVendor: Native.UNKNOWN,
      cpuModel: Native.UNKNOWN,
      osName: Native.UNKNOWN,
      osVersion: Native.UNKNOWN,
      graphicsApi: Native.UNKNOWN,
      audioApi: Native.UNKNOWN
    };
    return cachedHardware;
  }

  /** Logical CPU count from the native layer, or `Unknown` off the C++ targets. */
  static function cpuCores():String
  {
    final cores:Int = safe(debug.system.SystemInfo.logicalCPUCount, 0);
    return cores <= 0 ? Native.UNKNOWN : cores + ' logical';
  }

  /** Host RAM: the total from `SystemInfo`, the current RSS as "used". */
  static function ramTotal():String
  {
    final total:Float = safe(debug.system.SystemInfo.totalPhysicalMemory, 0.0);
    return total <= 0 ? 'Unknown' : VLog.formatBytes(total);
  }

  /** Process RSS, which is the honest "used" number a weak device cares about. */
  static function ramUsed():String
  {
    final rss:Float = safe(debug.mem.GetTotalMemory.getCurrentRSS, 0.0);
    if (rss <= 0) return 'Unknown';
    return VLog.formatBytes(rss) + ' resident';
  }

  /**
   * The raw `GL_VENDOR` / `GL_VERSION` strings, next to the parsed GPU model:
   * a bug can be one specific driver build that the parsed version alone does
   * not pin down.
   */
  static function rendererInfo():String
  {
    final vendor:String = safe(Native.getOpenGLRenderer, '');
    // Native reports "Unable to detect" when there is no live GL context yet.
    if (vendor.length == 0 || vendor == 'Unable to detect') return Native.UNKNOWN;
    final version:String = safe(Native.getOpenGLVersion, '');
    if (version.length == 0 || version == 'Unable to detect') return vendor;
    return vendor + ' | ' + version;
  }

  /**
   * The window size and whether it is running fullscreen.
   *
   * "Fullscreen" means the window fills its display's current mode; that is
   * also the closest a diagnostics report needs to get to the device's real
   * resolution, which matters for the low-end devices this engine targets.
   */
  static function display():String
  {
    try
    {
      final window:Window = Lib.application == null ? null : Lib.application.window;
      final width:Int = window == null ? Std.int(FlxG.width) : window.width;
      final height:Int = window == null ? Std.int(FlxG.height) : window.height;
      final state:String = (window != null && window.display != null && window.display.currentMode != null
        && window.display.currentMode.width == width) ? 'fullscreen' : 'windowed';
      return width + 'x' + height + ' ' + state;
    }
    catch (_:Dynamic)
      return Std.int(FlxG.width) + 'x' + Std.int(FlxG.height);
  }

  /** The framerate the game actually runs at, not just the preference. */
  static function framerate():String
  {
    final draw:Int = Std.int(FlxG.drawFramerate);
    final update:Int = Std.int(FlxG.updateFramerate);
    if (draw <= 0 && update <= 0) return 'uncapped';
    return draw == update ? draw + ' fps' : draw + ' draw / ' + update + ' update fps';
  }

  /**
   * `2 enabled / 3 installed` for `modsList.txt`.
   *
   * `all` is not reported separately: `Mods.parseList()` fills `all` from the
   * same file, and the disabled ones are already listed by `mods()`.
   */
  static function modCount():String
  {
    final list:ModsList = safe(() -> Mods.parseList(), {enabled: [], disabled: [], all: []});
    final known:Int = list.all == null ? 0 : list.all.length;
    final enabled:Int = list.enabled == null ? 0 : list.enabled.length;
    if (known == 0) return 'none installed';
    return enabled + ' enabled / ' + known + ' installed';
  }

  /**
   * The enabled mods in load order (the order `modsList.txt` is read in), then
   * the installed-but-disabled ones. Only folder names are reported: they are
   * what `mods/<folder>/` is, and intentionally the most a report needs.
   */
  static function mods():Array<String>
  {
    final list:ModsList = safe(() -> Mods.parseList(), {enabled: [], disabled: [], all: []});
    final out:Array<String> = [];
    if (list.enabled != null)
      for (name in list.enabled) out.push(name + ' (enabled)');
    if (list.disabled != null)
      for (name in list.disabled) out.push(name + ' (disabled)');
    return out;
  }

  /**
   * Preferences whose current value differs from the engine default.
   *
   * Field names come from `SettingsBackup.preferenceFields()`, so a preference
   * added to `ClientPrefs` is picked up without touching this class; the
   * default values come from `DEFAULTS` below. Arrays and maps (keybinds, note
   * colours, gameplay modifiers) are skipped here — the modifiers are listed
   * separately with a `gameplay.` prefix, and the tables are exported by the
   * settings backup instead of being dumped into a support ticket.
   */
  static function nonDefaultPrefs():Array<String>
  {
    final fields:Array<String> = safe(SettingsBackup.preferenceFields, []);
    final current:Array<Dynamic> = [];
    final defaults:Array<Dynamic> = [];
    final names:Array<String> = [];
    for (field in fields)
    {
      final value:Dynamic = Reflect.field(ClientPrefs, field);
      // Arrays and maps are exported by the settings backup, not diffed here.
      if (Std.isOfType(value, Array) || Std.isOfType(value, haxe.ds.StringMap)
        || Std.isOfType(value, haxe.ds.IntMap)) continue;
      names.push(field);
      current.push(value);
      defaults.push(defaultFor(field));
    }
    // Gameplay modifiers (pause menu) are preferences too.
    for (name in ClientPrefs.gameplaySettings.keys())
    {
      names.push('gameplay.' + name);
      current.push(ClientPrefs.gameplaySettings.get(name));
      defaults.push(gameplayDefault(name));
    }
    final diff:Array<String> = DiagnosticsReport.diffPrefs(names, current, defaults);
    diff.sort(Reflect.compare);
    return diff;
  }

  /**
   * The default of a `ClientPrefs` field.
   *
   * `ClientPrefs.loadPrefs()` overwrites each field with the saved value, so
   * the field initialisers are not readable any more by the time a report is
   * built. The defaults therefore come from a table generated from the
   * initialisers themselves (kept honest by `tests/test_diagnostics.py`).
   */
  static function defaultFor(field:String):Dynamic
  {
    final value:Dynamic = Reflect.field(DEFAULTS, field);
    return value;
  }

  /** Default of one pause-menu gameplay modifier. */
  static function gameplayDefault(name:String):Dynamic
  {
    final value:Dynamic = Reflect.field(GAMEPLAY_DEFAULTS, name);
    return value;
  }

  /** The current user's home directory, or null when the target has none. */
  static function homeDirectory():String
  {
    #if sys
    try
    {
      final home:String = Sys.getEnv('HOME');
      if (home != null && home.length > 1) return home;
      final profile:String = Sys.getEnv('USERPROFILE');
      if (profile != null && profile.length > 1) return profile;
    }
    catch (_:Dynamic) {}
    #end
    return null;
  }

  /** Name of the current state class, for the `[runtime]` section. */
  static function stateName():String
  {
    try
    {
      if (FlxG.state != null) return Type.getClassName(Type.getClass(FlxG.state));
    }
    catch (_:Dynamic) {}
    return 'Unknown';
  }

  /** Whether the vlog is writing, and where. */
  static function vlogState():String
  {
    if (!VLog.enabled) return 'off (Options -> Misc)';
    return VLog.isRecording() ? 'recording (' + VLog.filePath() + ')' : 'enabled, session not started';
  }

  /**
   * The working directory: on desktop the install folder, on Android the app's
   * external-files folder (`StorageUtil` chdir's there), which is exactly where
   * `mods/`, `crash/` and `vlog/` live on every target.
   */
  static function installPath():String
  {
    #if sys
    try
    {
      final cwd:String = Sys.getCwd();
      if (cwd != null && StringTools.trim(cwd).length > 0) return cwd;
    }
    catch (_:Dynamic) {}
    #end
    return 'Unknown';
  }

  /**
   * Where `funkin.sol` and `controls_v2.sol` live: the Flixel save folder plus
   * the game's own identifier, straight from `CoolUtil.getSavePath()` so the
   * report matches the folder the player can actually open.
   */
  static function savePath():String
  {
    final folder:String = safe(CoolUtil.getSavePath, 'Unknown');
    if (folder == 'Unknown') return folder;
    // The file names are FlixelSave's: the "funkin" default plus the
    // controls save (see ClientPrefs.loadPrefs / saveSettings).
    return folder + ' (funkin.sol, controls_v2.sol)';
  }

  /** Human label for the report's `[log]` header. */
  /**
   * The `[log]` heading: where the tail came from and how many lines it kept.
   *
   * @param log     the full log text the tail was sliced from
   * @param kept    number of lines `DiagnosticsReport.tail()` actually kept
   * @param wanted  number of lines the caller asked for
   */
  static function logSource(log:String, kept:Int, wanted:Int):String
  {
    if (log == null || StringTools.trim(log).length == 0) return 'no log available';
    if (wanted <= 0) return 'excluded';
    // "last 60 of 60 lines" when the session is shorter than the request,
    // so a three-line log does not claim to have kept sixty.
    final count:String = (kept < wanted) ? (kept + ' of ' + wanted + ' lines') : (kept + ' lines');
    if (VLog.enabled) return 'last ' + count + ' of ' + VLog.filePath();
    return 'last ' + count + ' of the session buffer';
  }

  // -- Versions ---------------------------------------------------------------

  /**
   * Version of a library or of the compiler, baked in at compile time.
   *
   * `Context.definedValue('flixel')` and friends hold the haxelib versions the
   * build actually resolved, which is what a support ticket needs; the macro
   * runs in the game's compilation context, so it is not visible to the
   * interpreter tests (which only exercise the Flixel-free formatter).
   */
  static macro function definedVersion(name:String):haxe.macro.Expr.ExprOf<String>
  {
    #if display
    return macro $v{'Unknown'};
    #else
    final version:String = haxe.macro.Context.definedValue(name);
    return macro $v{version == null || version.length == 0 ? 'Unknown' : version};
    #end
  }

  /**
   * The compiler version, exactly as `Context.definedValue` spells it
   * (`haxe_ver` is "4.307" for 4.3.7, i.e. without the second dot), prefixed
   * so it reads as a version instead of a build number.
   */
  static function haxeVersion():String
    return 'Haxe ' + definedVersion('haxe_ver');

  /**
   * The engine version: `VERSION` from `project.hxp`, which `configureApp()`
   * bakes in as the `ENGINE_VERSION` haxedef and also writes to the app
   * metadata that `backend.PhoenixVersion` reads back (see #54). The haxedef
   * is preferred so `VERSION` in the report is literally the build file's
   * value even on a target without application metadata.
   */
  static function engineVersion():String
  {
    final fromBuild:String = definedVersion('ENGINE_VERSION');
    final value:String = (fromBuild == 'Unknown') ? PhoenixVersion.current : fromBuild;
    return PhoenixVersion.display(value);
  }

  /** Upstream compatibility marker, same value `MainMenuState` prints. */
  static function jseVersion():String
  {
    return safe(() -> states.MainMenuState.psychEngineJSVersion, 'Unknown');
  }

  /** Psych version the scripting/format code is based on; see `VLog`. */
  static function psychVersion():String
    return '0.6.3';

  /** Platform + build kind, matching the `[BOOT] target` line of the vlog. */
  static function target():String
  {
    final platform:String = #if windows 'windows'
      #elseif mac 'macos'
      #elseif linux 'linux'
      #elseif android 'android'
      #elseif ios 'ios'
      #elseif hl 'hashlink'
      #elseif neko 'neko'
      #elseif web 'html5'
      #elseif air 'air'
      #elseif flash 'flash'
      #else 'unknown' #end;
    final runtime:String = #if cpp 'hxcpp'
      #elseif hl 'hashlink'
      #elseif neko 'neko'
      #elseif js 'js'
      #elseif flash 'flash'
      #else 'unknown' #end;
    final build:String = #if debug 'debug build' #else 'release build' #end;
    return platform + ' (' + runtime + ') ' + build;
  }

  // -- Helpers ----------------------------------------------------------------

  /**
   * Runs an accessor and coerces its result, falling back to `def` when it
   * throws or returns null. Every fact in the report is read through this so
   * a target without native queries (or a state that is not up yet) reports
   * `Unknown`/`none` instead of taking the copy action down.
   */
  static function safe<T>(read:Void->Dynamic, def:T):T
  {
    try
    {
      final value:Dynamic = read();
      return value == null ? def : (value : T);
    }
    catch (_:Dynamic)
      return def;
  }

  /**
   * Formats a byte figure with `VLog.formatBytes` (the same "90.6MB" spelling
   * the FPS overlay and the vlog use), or `Unknown` when it is not available.
   */
  static function memory(read:Void->Float):String
  {
    final value:Float = safe(read, -1.0);
    return value <= 0 ? 'Unknown' : VLog.formatBytes(value);
  }

  // -- Defaults ---------------------------------------------------------------

  /**
   * Expected value of every `ClientPrefs` preference on a fresh install.
   *
   * Mirrors the field initialisers in `source/backend/ClientPrefs.hx`;
   * `tests/test_diagnostics.py` fails when the two disagree, so a new
   * preference cannot silently be reported as "changed by the player".
   * Fields that are not preferences (keybinds, colour tables, maps, the
   * gameplay modifiers below) are deliberately absent.
   */
  static final DEFAULTS:Dynamic =
  {
    controllerMode: false,
    downScroll: false,
    middleScroll: false,
    opponentStrums: true,
    ghostTapping: true,
    autoPause: true,
    complexAccuracy: false,
    noMarvJudge: false,
    noReset: false,
    antiCheatEnable: false,
    ezSpam: false,
    spaceVPose: true,
    ghostTapAnim: true,
    hitsoundVolume: 0,
    hitsoundType: 'osu!mania',
    overrideInstrumentalVolume: false,
    instrumentalVolumeOverride: 1,
    overrideVocalsVolume: false,
    vocalsVolumeOverride: 1,
    voiidTrollMode: false,
    trollMaxSpeed: 'Medium',
    missSoundEnabled: false,
    crossFadeLimit: 4,
    boyfriendCrossFadeLimit: 1,
    crossFadeMode: 'Mid-Fight Masses',
    noteSkin: 'Default',
    splashType: 'Default',
    noteSplashes: true,
    oppNoteSplashes: true,
    showNPS: true,
    showComboInfo: true,
    maxSplashLimit: 16,
    oppNoteAlpha: 0.65,
    hideHud: false,
    tauntOnGo: true,
    oldSusStyle: false,
    showRendered: false,
    botWatermark: true,
    missRating: false,
    noteColorStyle: 'Normal',
    enableColorShader: true,
    rateNameStuff: 'Quotes',
    timeBarType: 'Time Left',
    scoreStyle: 'Psych Engine',
    timeBarStyle: 'Vanilla',
    healthBarStyle: 'Vanilla',
    watermarkStyle: 'Vanilla',
    platformWatermark: true,
    botTxtStyle: 'Vanilla',
    strumLitStyle: 'Full Anim',
    bfIconStyle: 'Default',
    ratingType: 'Default',
    simplePopups: false,
    iconBounceType: 'New Psych',
    smoothHealth: true,
    smoothHPBug: false,
    flashing: true,
    camZooms: true,
    showNotes: true,
    scoreZoom: true,
    healthBarAlpha: 1,
    showFPS: true,
    botTxtFade: true,
    pauseMusic: 'Tea Time',
    daMenuMusic: 'Default',
    checkForUpdates: true,
    showRamUsage: true,
    showRamGraph: false,
    showMaxRamUsage: true,
    debugInfo: false,
    frameProfiler: false,
    tipTexts: true,
    discordRPC: true,
    peOGCrash: false,
    respectCutout: true,
    mobileCAlpha: #if mobile 0.6 #else 0 #end,
    mobileCEx: false,
    mobileCPlayStateVpad: false,
    mobileCExTaunt: true,
    screensaver: false,
    hitboxType: "Gradient",
    hitboxPos: true,
    androidNotifications: false,
    widescreen: false,
    lowQuality: false,
    globalAntialiasing: true,
    shaders: true,
    cacheOnGPU: false,
    dynamicSpawnTime: false,
    noteSpawnTime: 1,
    resolution: '1280x720',
    framerate: 60,
    charsAndBG: true,
    enableGC: true,
    opponentLightStrum: true,
    botLightStrum: true,
    playerLightStrum: true,
    ratingPopups: true,
    comboPopups: true,
    showMS: false,
    noSpawnFunc: false,
    noHitFuncs: false,
    noSkipFuncs: false,
    lessBotLag: false,
    maxNotes: 0,
    noGunsRNG: false,
    rainbowFPS: false,
    noRenderGC: false,
    cursing: true,
    violence: true,
    noPausing: false,
    ffmpegMode: false,
    targetFPS: 60,
    unlockFPS: false,
    renderBitrate: 5.0,
    vidEncoder: 'libx264',
    oldFFmpegMode: false,
    lossless: false,
    quality: 50,
    renderGCRate: 5.0,
    showRemainingTime: false,
    renderPath: 'assets/gameRenders/',
    enablePreReleaseUpdates: false,
    JSEngineRecharts: false,
    alwaysTriggerCutscene: false,
    disableSplash: false,
    disableAprilFools: false,
    rainbowTime: 5.0,
    autosaveCharts: true,
    autosaveTime: 240,
    deeplinkEnabled: false,
    vlogEnabled: false,
    ratingOffset: 0,
    perfectWindow: 15.0,
    sickWindow: 45.0,
    goodWindow: 90.0,
    badWindow: 135.0,
    safeFrames: 10.0,
    noteOffset: 0
  };

  /** Expected value of every pause-menu gameplay modifier. */
  static final GAMEPLAY_DEFAULTS:Dynamic =
  {
    scrollspeed: 1.0,
    scrolltype: 'multiplicative',
    songspeed: 1.0,
    healthgain: 1.0,
    healthloss: 1.0,
    instakill: false,
    practice: false,
    botplay: false,
    randommode: false,
    opponentplay: false,
    bothSides: false,
    opponentdrain: false,
    drainlevel: 1,
    flip: false,
    stairmode: false,
    wavemode: false,
    onekey: false,
    jacks: 0,
    randomspeed: false,
    randomspeedmin: 0.5,
    randomspeedmax: 2,
    thetrollingever: false
  };
}
