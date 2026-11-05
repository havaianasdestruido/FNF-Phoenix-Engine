package backend.deeplink;

import backend.ClientPrefs;
import backend.CoolUtil;
import flixel.FlxG;
import states.MainMenuState;
import states.LoadingState;
import options.OptionsState;

/** Native callbacks only queue requests; safe menu update hooks perform navigation. */
class DeepLinks
{
  /** Per-user registry key that owns the phoenix:// scheme on Windows. */
  static final WINDOWS_KEY = 'HKCU\\Software\\Classes\\phoenix';

  static var initialized:Bool = false;
  static var pending:Null<String>;
  static var pendingEx:Null<ParsedURI>;

  /**
   * Arms the platform callbacks that feed `receive`. This never registers
   * anything: a launch must not touch the user's registry unattended, so on
   * Windows the scheme is only claimed from Options -> Misc ("Toggle Deeplink")
   * through `applyRegistration`. Android and iOS advertise the scheme in the
   * manifest / Info.plist at build time and need no runtime step at all.
   */
  public static function init():Void
  {
    if (initialized) return;
    initialized = true;
    #if android
    android.platform.AndroidIntents.subscribeDeepLink(receive);
    #elseif ios
    // Lime's SDL UIKit delegate delivers both launch and later URLs as drop events.
    lime.app.Application.current.window.onDropFile.add(receive);
    #elseif (windows && sys)
    // A registered copy can still be launched by a link; read those arguments.
    for (argument in Sys.args()) receive(argument);
    // Protocol launches need not inherit the executable's working directory.
    if (pending != null || pendingEx != null) Sys.setCwd(haxe.io.Path.directory(Sys.programPath()));
    #end
  }

  public static function receive(uri:String):Void
  {
    var parsed = PhoenixURI.parseEx(uri);
    if (parsed == null) return;
    // Keep v1 string for backward compat in dispatch() simple path
    var legacy = PhoenixURI.parse(uri);
    pending = legacy;
    pendingEx = parsed;
    // Notify Lua/HScript listeners
    try
    {
      var asString:String = uri;
      FlxG.signals.postUpdate.addOnce(function() {
        // Expose to scripts via global event — does not navigate automatically
        // beyond the built-in dispatch() below.
      });
    }
    catch (e:Dynamic) {}
  }

  /** Subscribers for parsed URI data (Lua/HScript can listen via `onDeepLink`). */
  public static var onDeepLink:Null<ParsedURI->Void> = null;

  /** Called only from a fully initialized, idle Title or Main Menu. */
  public static function dispatch():Bool
  {
    if ((pending == null && pendingEx == null) || FlxG.state.subState != null) return false;
    var route = pending;
    var parsed = pendingEx;
    pending = null;
    pendingEx = null;
    OptionsState.onPlayState = false;
    states.substates.PauseSubState.inPause = false;

    // Prefer the structured v2 parser when available
    if (parsed != null)
    {
      return dispatchEx(parsed);
    }

    switch (route)
    {
      case "mods":
        #if MODS_ALLOWED
        FlxG.switchState(() -> new states.ModsMenuState());
        #else
        FlxG.switchState(MainMenuState.new);
        #end
      case "options", "misc":
        LoadingState.loadAndSwitchState(() -> new OptionsState(route == "misc"));
      case "story": FlxG.switchState(states.StoryMenuState.new);
      case "freeplay": FlxG.switchState(states.FreeplayState.new);
      case "credits": FlxG.switchState(states.CreditsState.new);
      default: FlxG.switchState(MainMenuState.new);
    }
    return true;
  }

  static function dispatchEx(parsed:ParsedURI):Bool
  {
    // Fire external listener first (Lua/HScript exposure)
    if (onDeepLink != null)
    {
      try
      {
        onDeepLink(parsed);
      }
      catch (e:Dynamic) {}
    }

    return switch (parsed.kind)
    {
      case Menu(route), Screen(route):
        switch (route)
        {
          case "mods":
            #if MODS_ALLOWED
            FlxG.switchState(() -> new states.ModsMenuState());
            #else
            FlxG.switchState(MainMenuState.new);
            #end
          case "options", "misc":
            LoadingState.loadAndSwitchState(() -> new OptionsState(route == "misc"));
          case "story": FlxG.switchState(states.StoryMenuState.new);
          case "freeplay": FlxG.switchState(states.FreeplayState.new);
          case "credits": FlxG.switchState(states.CreditsState.new);
          default: FlxG.switchState(MainMenuState.new);
        }
        true;
      case Song(name, diff):
        // Resolve song via normal chart loading — validates existence before switch
        var songLower = Paths.formatToSongPath(name);
        var diffIndex = 0;
        if (diff != null && diff.length > 0)
        {
          var target = diff.toLowerCase();
          for (i in 0...CoolUtil.difficulties.length)
            if (CoolUtil.difficulties[i].toLowerCase() == target) { diffIndex = i; break; }
        }
        var formatted = backend.Highscore.formatSong(songLower, diffIndex);
        var exists = false;
        #if sys
        exists = sys.FileSystem.exists(Paths.modsJson(songLower + '/' + formatted))
          || sys.FileSystem.exists(Paths.json(songLower + '/' + formatted))
          || openfl.utils.Assets.exists(Paths.modsJson(songLower + '/' + formatted))
          || openfl.utils.Assets.exists(Paths.json(songLower + '/' + formatted));
        #else
        exists = openfl.utils.Assets.exists(Paths.json(songLower + '/' + formatted));
        #end
        if (!exists)
        {
          CoolUtil.coolError('Song not found: $name' + (diff != null ? ' ($diff)' : ''), 'Deep Link');
          FlxG.switchState(MainMenuState.new);
        }
        else
        {
          backend.CoolUtil.currentDifficulty = CoolUtil.difficulties[diffIndex];
          play.PlayState.SONG = data.Song.loadFromJson(formatted, songLower);
          play.PlayState.storyDifficulty = diffIndex;
          play.PlayState.isStoryMode = false;
          play.PlayState.wasOriginallyFreeplay = true;
          LoadingState.loadAndSwitchState(play.PlayState.new);
        }
        true;
      case Mod(modId, song):
        #if MODS_ALLOWED
        backend.Mods.currentModDirectory = modId;
        #end
        if (song != null)
        {
          var songLower = Paths.formatToSongPath(song);
          var formatted = backend.Highscore.formatSong(songLower, 0);
          var exists = false;
          #if sys
          exists = sys.FileSystem.exists(Paths.modsJson(songLower + '/' + formatted))
            || sys.FileSystem.exists(Paths.json(songLower + '/' + formatted));
          #else
          exists = openfl.utils.Assets.exists(Paths.json(songLower + '/' + formatted));
          #end
          if (exists)
          {
            play.PlayState.SONG = data.Song.loadFromJson(formatted, songLower);
            play.PlayState.isStoryMode = false;
            LoadingState.loadAndSwitchState(play.PlayState.new);
          }
          else
          {
            FlxG.switchState(() -> new states.ModsMenuState());
          }
        }
        else
        {
          FlxG.switchState(() -> new states.ModsMenuState());
        }
        true;
      case Diagnostics:
        // The report page only reads: it writes no file, changes no preference,
        // starts no song and frees nothing, which is exactly why a stranger can
        // be asked to tap it. Built by backend.DiagnosticsReport.
        FlxG.switchState(() -> new states.DiagnosticsState());
        true;
      case Replay(id):
        CoolUtil.coolError('Replay playback not yet implemented (id: $id)', 'Deep Link');
        FlxG.switchState(MainMenuState.new);
        true;
    }
  }

  /**
   * Applies the "Toggle Deeplink" preference, called from the Misc menu after
   * the preference has already been flipped. Checking registers this executable
   * as the phoenix:// handler, unchecking deletes the handler. A registration
   * that could not be made is reported and the preference is rolled back, so
   * the checkbox never claims more than the system actually does.
   */
  public static function applyRegistration():Void
  {
    #if (windows && sys)
    if (ClientPrefs.deeplinkEnabled && !registerWindowsProtocol())
    {
      ClientPrefs.deeplinkEnabled = false;
      CoolUtil.coolError('phoenix:// could not be registered for this copy of the game.\n'
        + 'Another installation may already own the scheme, or uri\\Register-PhoenixURI.ps1\n'
        + 'is missing next to the executable. Register it manually from the game folder.',
        'Phoenix URI');
    }
    else if (!ClientPrefs.deeplinkEnabled)
      unregisterWindowsProtocol();
    // The handler lives outside the save file, so never let the two drift apart.
    ClientPrefs.saveSettings();
    #end
  }

  #if (windows && sys)
  /**
   * Points phoenix:// at this executable using the script that ships beside it.
   * The script checks the registry itself and refuses to overwrite another
   * copy's handler, so that case is reported instead of silently overwritten.
   * @return whether the scheme now resolves to this executable.
   */
  static function registerWindowsProtocol():Bool
  {
    var exe = Sys.programPath();
    var expected = protocolCommand(exe);
    var current = windowsProtocolCommand();
    if (sameCommand(current, expected)) return true; // already ours, nothing to write
    if (current != null) return false; // another installation owns the scheme

    var script = haxe.io.Path.directory(exe) + '\\uri\\Register-PhoenixURI.ps1';
    if (!sys.FileSystem.exists(script)) return false;
    // Quoted by hand because an install folder may contain spaces; the
    // executable is passed explicitly so a renamed build registers itself.
    Sys.command('powershell -NoProfile -ExecutionPolicy Bypass -File "' + script + '" -Executable "' + exe + '"');
    return sameCommand(windowsProtocolCommand(), expected);
  }

  /** Opting out deletes the key outright, even when a moved or deleted copy of
      the game left a stale entry behind; re-register from whichever copy you
      keep. `setup/uri/Unregister-PhoenixURI.ps1` stays available for a check
      first removal. */
  static function unregisterWindowsProtocol():Void
  {
    Sys.command('reg', ['delete', WINDOWS_KEY, '/f']);
  }

  /** The value the shell needs in `shell\\open\\command`: quoted exe, quoted URI. */
  static inline function protocolCommand(exe:String):String
    return '\"' + exe + '\" \"%1\"';

  /**
   * Windows paths are case-insensitive, the script re-resolves the path it is
   * given, and targets like HashLink report the program path with forward
   * slashes - so the recorded command is compared after normalising both.
   */
  static function sameCommand(registered:Null<String>, expected:String):Bool
    return registered != null && normalizePath(registered) == normalizePath(expected);

  static inline function normalizePath(path:String):String
    return path.toLowerCase().replace('/', '\\');

  /** Reads back the open command registered for phoenix://, or null when absent. */
  static function windowsProtocolCommand():Null<String>
  {
    try
    {
      var process = new sys.io.Process('reg', ['query', WINDOWS_KEY + '\\shell\\open\\command', '/ve']);
      var output = process.stdout.readAll().toString();
      var status = process.exitCode();
      try process.close() catch (e:Dynamic) {}
      if (status != 0) return null;
      for (line in output.split('\n'))
      {
        var at = line.indexOf('REG_SZ');
        if (at >= 0) return line.substr(at + 6).trim();
      }
    }
    catch (e:Dynamic) {}
    return null;
  }
  #end
}
