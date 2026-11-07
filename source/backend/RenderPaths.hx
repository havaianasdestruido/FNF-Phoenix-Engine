package backend;

import haxe.io.Path;
#if sys
import sys.FileSystem;
#end
using StringTools;

/**
 * Folder helpers used by Rendering Mode (`Options -> Game Rendering`).
 *
 * Rendering used to rely on two assumptions that only hold on a developer's
 * machine: that `FileSystem.createDirectory()` creates a whole nested path in
 * one call, and that the working directory is always the game's own folder.
 * Neither is true on Windows (`CreateDirectory` only creates the last segment,
 * and shortcuts/launchers may start the game from anywhere), so the render
 * folder either never appeared or appeared outside the game folder. Both
 * failures were silent, which made Rendering Mode look completely broken.
 *
 * This module is deliberately free of Flixel/Lime imports (it only touches
 * `sys`), so it runs under the Haxe interpreter in
 * `tests/haxe/run-video-render.sh`.
 */
class RenderPaths
{
  /** Folder Rendering Mode writes to when the player did not change it. */
  public static inline var DEFAULT_RENDER_PATH:String = 'assets/gameRenders/';

  /** Separator used for building paths; Haxe accepts `/` on every platform. */
  public static inline var SEPARATOR:String = '/';

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

  /**
   * Turns `path` into a folder path: forward slashes, `.` segments collapsed,
   * trimmed and with exactly one trailing separator. `null` and blank input
   * become an empty string.
   *
   * Only `.` is collapsed; `..` is left alone, because resolving it depends on
   * the folder the path ends up being anchored to.
   */
  public static function normalizeDirectory(path:Null<String>):String
  {
    if (path == null) return '';

    var normalized:String = path.split('\\').join(SEPARATOR).trim();
    if (normalized.length == 0) return '';

    // Keep filesystem roots (`/`, `C:/`) intact while collapsing trailing ones.
    while (normalized.length > 1 && normalized.charAt(normalized.length - 1) == SEPARATOR)
      normalized = normalized.substr(0, normalized.length - 1);

    if (normalized == SEPARATOR) return SEPARATOR;

    // Leading separators are significant: `/home` and `//server/share` (UNC).
    var leading:Int = 0;
    while (leading < normalized.length && normalized.charAt(leading) == SEPARATOR) leading++;
    final prefix:String = normalized.substr(0, leading);

    final kept:Array<String> = [];
    for (part in normalized.substr(leading).split(SEPARATOR))
    {
      if (part == null || part.length == 0 || part == '.') continue;
      kept.push(part);
    }

    if (kept.length == 0) return prefix.length > 0 ? SEPARATOR : '';
    return prefix + kept.join(SEPARATOR) + SEPARATOR;
  }

  /** `directory` joined with `name`, using exactly one separator. */
  public static function joinPath(directory:Null<String>, name:Null<String>):String
  {
    if (name == null) name = '';
    if (directory == null || directory.length == 0) return name;

    final last:String = directory.charAt(directory.length - 1);
    return (last == '/' || last == '\\') ? directory + name : directory + SEPARATOR + name;
  }

  /**
   * Whether `path` is absolute: a POSIX root (`/home/x`), a Windows drive path
   * (`C:\x`, `C:/x`) or a UNC share (`\\server\share`).
   *
   * Drive-relative paths such as `C:folder` are *not* absolute on Windows, so
   * they get anchored like any other relative folder.
   */
  public static function isAbsolute(path:Null<String>):Bool
  {
    if (path == null || path.length == 0) return false;

    final first:String = path.charAt(0);
    if (first == '/' || first == '\\') return true;

    return path.length >= 3 && path.charAt(1) == ':' && (path.charAt(2) == '/' || path.charAt(2) == '\\');
  }

  /**
   * Folder that relative render paths are anchored to.
   *
   * On Windows it is the folder that holds the executable, which is what the
   * option promises ("a folder inside assets called gameRenders") and what
   * players expect when a shortcut starts the game with a different working
   * directory. Everywhere else the working directory is kept, matching how
   * `backend.Paths` looks for assets.
   */
  public static function baseDirectory():String
  {
    #if sys
    #if (android || ios)
    // Mobile builds keep their relative paths: their writable folders come from
    // `mobile.StorageUtil`, not from the working directory.
    return '';
    #elseif windows
    final programPath:String = Sys.programPath();
    if (programPath != null && programPath.length > 0)
    {
      final programDirectory:String = Path.directory(programPath);
      if (programDirectory != null && programDirectory.length > 0) return programDirectory;
    }
    #end
    return Sys.getCwd();
    #else
    return '';
    #end
  }

  /** Resolves `path` against `base` unless it is already absolute. */
  public static function resolveDirectory(path:Null<String>, base:Null<String>):String
  {
    if (path == null || path.length == 0) return normalizeDirectory(base);
    if (isAbsolute(path) || base == null || base.length == 0) return normalizeDirectory(path);
    return normalizeDirectory(joinPath(base, path));
  }

  /**
   * Creates `directory` and every missing parent, returning whether it exists
   * as a folder afterwards. Never throws: a read-only install location is a
   * warning, not a crash.
   *
   * `FileSystem.createDirectory()` maps to a non-recursive call
   * (`CreateDirectory` on Windows, `mkdir` on POSIX), hence the segment walk.
   */
  public static function ensureDirectory(directory:Null<String>):Bool
  {
    #if sys
    final normalized:String = normalizeDirectory(directory);
    if (normalized.length == 0) return false;
    if (FileSystem.exists(normalized)) return FileSystem.isDirectory(normalized);

    final path:String = normalized.substr(0, normalized.length - 1);

    var prefixLength:Int = 0;
    while (prefixLength < path.length && path.charAt(prefixLength) == SEPARATOR) prefixLength++;
    var current:String = path.substr(0, prefixLength);

    for (part in path.split(SEPARATOR))
    {
      if (part == null || part.length == 0) continue;

      if (current.length == 0)
        current = part;
      else if (current.charAt(current.length - 1) == SEPARATOR)
        current += part;
      else
        current += SEPARATOR + part;

      if (FileSystem.exists(current))
      {
        // A file sitting where the folder should be cannot be used.
        if (!FileSystem.isDirectory(current)) return false;
        continue;
      }

      try
      {
        FileSystem.createDirectory(current);
      }
      catch (e:Dynamic)
      {
        return false;
      }
    }

    return FileSystem.exists(normalized) && FileSystem.isDirectory(normalized);
    #else
    return false;
    #end
  }

  /**
   * Resolves the configured render folder against the game's own folder and
   * creates it when missing.
   *
   * @return the folder that was prepared, or `null` when it could not be
   *         created (read-only install location, a file with that name, ...).
   */
  public static function prepareRenderDirectory(configured:Null<String>):Null<String>
  {
    #if sys
    final wanted:String = (configured == null || configured.trim().length == 0) ? DEFAULT_RENDER_PATH : configured;
    final resolved:String = resolveDirectory(wanted, baseDirectory());
    return ensureDirectory(resolved) ? resolved : null;
    #else
    return null;
    #end
  }
}
