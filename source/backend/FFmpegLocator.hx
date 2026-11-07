package backend;

import backend.RenderPaths;
#if sys
import sys.FileSystem;
#end
using StringTools;

/**
 * Locates the FFmpeg executable Rendering Mode streams video frames into.
 *
 * Rendering Mode used to accept exactly one location - `ffmpeg.exe` in the
 * working directory - and gave up with a `trace()` (invisible in a release
 * build) when it was not there. That is why Windows players who installed
 * FFmpeg through winget/scoop/choco (so it lives on `PATH`, which is where
 * `CreateProcess` finds it) could never render anything, and why the render
 * folder was never created either.
 *
 * The lookup order is:
 *
 * 1. `PHOENIX_FFMPEG`, then `FFMPEG`: either the executable itself or the
 *    folder that holds it;
 * 2. `ffmpeg/bin`, `ffmpeg` and `bin` inside the game's folder (an FFmpeg zip
 *    unpacked next to the game);
 * 3. the folder that holds the game executable (the "just drop it next to the
 *    .exe" workflow);
 * 4. the working directory;
 * 5. every `PATH` entry;
 * 6. well-known package-manager install folders.
 *
 * The module is free of Flixel/Lime imports, so the pure helpers are covered
 * by `tests/haxe/run-video-render.sh` under the Haxe interpreter.
 */
class FFmpegLocator
{
  /** Executable name on Windows. */
  public static inline var WINDOWS_EXECUTABLE:String = 'ffmpeg.exe';

  /** Executable name on macOS and Linux. */
  public static inline var POSIX_EXECUTABLE:String = 'ffmpeg';

  /** Environment variables checked first; they may name a file or a folder. */
  public static final OVERRIDE_VARIABLES:Array<String> = ['PHOENIX_FFMPEG', 'FFMPEG'];

  /** True when this build targets Windows. */
  public static var isWindows(get, never):Bool;

  static function get_isWindows():Bool
  {
    #if windows
    return true;
    #else
    return false;
    #end
  }

  /** Executable file name for `windows` (which need not be this build). */
  public static function executableName(windows:Bool):String
  {
    return windows ? WINDOWS_EXECUTABLE : POSIX_EXECUTABLE;
  }

  /** Separator between the entries of a `PATH`-like variable. */
  public static function pathSeparator(windows:Bool):String
  {
    return windows ? ';' : ':';
  }

  /**
   * Splits a `PATH`-like value into directories.
   *
   * Windows allows quoted entries (`"C:\Program Files\ffmpeg\bin"`), and a
   * trailing separator produces an empty entry which means "current folder" to
   * some shells - both are cleaned, because the working directory is probed
   * anyway. Duplicates keep their first position.
   */
  public static function splitPathValue(value:Null<String>, separator:String):Array<String>
  {
    final entries:Array<String> = [];
    if (value == null || separator == null || separator.length == 0) return entries;

    for (raw in value.split(separator))
    {
      final entry:String = cleanEntry(raw);
      if (entry.length == 0) continue;
      if (entries.indexOf(entry) < 0) entries.push(entry);
    }

    return entries;
  }

  static function cleanEntry(raw:Null<String>):String
  {
    if (raw == null) return '';

    var entry:String = raw.trim();
    if (entry.length >= 2 && entry.charAt(0) == '"' && entry.charAt(entry.length - 1) == '"')
      entry = entry.substring(1, entry.length - 1).trim();

    while (entry.length > 1 && (entry.charAt(entry.length - 1) == '/' || entry.charAt(entry.length - 1) == '\\'))
      entry = entry.substr(0, entry.length - 1);

    return entry;
  }

  /**
   * Folders inside the game folder that players commonly unpack FFmpeg into
   * (`.../ffmpeg/bin/ffmpeg.exe` from the official zip, or a bare `.../bin`).
   */
  public static function nearbyDirectories(programDirectory:Null<String>):Array<String>
  {
    final directories:Array<String> = [];

    final base:String = cleanEntry(programDirectory);
    if (base.length == 0) return directories;

    for (sub in ['ffmpeg/bin', 'ffmpeg', 'bin'])
      directories.push(RenderPaths.joinPath(base, sub));

    return directories;
  }

  /**
   * Folders FFmpeg commonly ends up in once installed, for platforms where
   * package managers install outside `PATH` (or before the shell that started
   * the game picked the new `PATH` up).
   *
   * @param env environment lookup, so tests can fake a machine.
   */
  public static function wellKnownDirectories(windows:Bool, env:String->Null<String>):Array<String>
  {
    final directories:Array<String> = [];

    if (!windows)
    {
      directories.push('/usr/local/bin');
      directories.push('/usr/bin');
      directories.push('/opt/homebrew/bin');
      directories.push('/snap/bin');
      return directories;
    }

    if (env == null) return directories;

    addUnder(directories, env('ProgramFiles'), 'ffmpeg/bin');
    addUnder(directories, env('ProgramW6432'), 'ffmpeg/bin');
    addUnder(directories, env('ProgramFiles(x86)'), 'ffmpeg/bin');
    addUnder(directories, env('LOCALAPPDATA'), 'Microsoft/WinGet/Links');
    addUnder(directories, env('USERPROFILE'), 'scoop/shims');
    directories.push('C:/ffmpeg/bin');
    directories.push('C:/ProgramData/chocolatey/bin');

    return directories;
  }

  static function addUnder(directories:Array<String>, parent:Null<String>, child:String):Void
  {
    if (parent == null || parent.trim().length == 0) return;
    directories.push(RenderPaths.joinPath(cleanEntry(parent), child));
  }

  /**
   * Ordered list of folders to probe, without duplicates (case-insensitive on
   * Windows, where `C:\FFmpeg` and `c:\ffmpeg` are the same folder).
   */
  public static function searchDirectories(windows:Bool, programDirectory:Null<String>, workingDirectory:Null<String>,
      pathValue:Null<String>, wellKnown:Array<String>):Array<String>
  {
    final directories:Array<String> = [];
    addDirectory(directories, programDirectory, windows);
    addDirectory(directories, workingDirectory, windows);
    for (entry in splitPathValue(pathValue, pathSeparator(windows))) addDirectory(directories, entry, windows);
    if (wellKnown != null)
      for (entry in wellKnown) addDirectory(directories, entry, windows);

    return directories;
  }

  static function addDirectory(directories:Array<String>, directory:Null<String>, windows:Bool):Void
  {
    final entry:String = cleanEntry(directory);
    if (entry.length == 0) return;

    for (existing in directories)
    {
      if (existing == entry) return;
      // Windows compares paths case-insensitively (`C:\FFmpeg` == `c:\ffmpeg`).
      if (windows && existing.toLowerCase() == entry.toLowerCase()) return;
    }

    directories.push(entry);
  }

  /**
   * Full path of the FFmpeg executable, or `null` when it cannot be found.
   *
   * The returned path is safe to hand to `sys.io.Process`: Haxe quotes the
   * command itself on Windows, so paths with spaces (`C:\Program Files\...`)
   * work without extra quoting here.
   */
  public static function locate():Null<String>
  {
    #if sys
    final windows:Bool = isWindows;
    final name:String = executableName(windows);

    // 1. Explicit override: a variable pointing at the executable or its folder.
    for (variable in OVERRIDE_VARIABLES)
    {
      final overridePath:String = cleanEntry(Sys.getEnv(variable));
      if (overridePath.length == 0) continue;

      if (isFile(overridePath)) return overridePath;

      final inside:String = RenderPaths.joinPath(overridePath, name);
      if (isFile(inside)) return inside;
    }

    // 2. Folders inside the game folder, then the game folder itself, the
    //    working directory, PATH and the known install folders.
    final programDir:Null<String> = programDirectory();
    final directories:Array<String> = nearbyDirectories(programDir)
      .concat(searchDirectories(windows, programDir, Sys.getCwd(), Sys.getEnv('PATH'), wellKnownDirectories(windows, Sys.getEnv)));

    for (directory in directories)
    {
      final candidate:String = RenderPaths.joinPath(directory, name);
      if (isFile(candidate)) return candidate;
    }

    // 3. The OS could still resolve a bare name through its own search rules,
    //    but reporting "not found" is honest: this is what the caller warns on.
    return null;
    #else
    return null;
    #end
  }

  /** Folder that holds the running executable, or `null` when unknown. */
  public static function programDirectory():Null<String>
  {
    #if sys
    final programPath:String = Sys.programPath();
    if (programPath == null || programPath.length == 0) return null;

    final directory:String = haxe.io.Path.directory(programPath);
    return (directory == null || directory.length == 0) ? null : directory;
    #else
    return null;
    #end
  }

  #if sys
  static function isFile(path:Null<String>):Bool
  {
    if (path == null || path.length == 0) return false;

    try
    {
      return FileSystem.exists(path) && !FileSystem.isDirectory(path);
    }
    catch (e:Dynamic)
    {
      return false;
    }
  }
  #end
}
