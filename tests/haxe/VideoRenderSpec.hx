import backend.FFmpegLocator;
import backend.RenderPaths;
import sys.FileSystem;
import sys.io.File;
using StringTools;

/**
 * Contract for Rendering Mode's folder handling and FFmpeg lookup.
 *
 * Both bugs this guards against were Windows-only and silent: the render folder
 * was never created (nested `createDirectory` + a working directory that is not
 * always the game folder), and FFmpeg was only accepted next to the `.exe`
 * even though Windows finds it on `PATH`. The helpers live in Flixel-free
 * modules, so this spec runs under the Haxe interpreter.
 */
class VideoRenderSpec
{
  static var checks:Int = 0;

  static function check(ok:Bool, label:String):Void
  {
    checks++;
    if (!ok) throw label;
  }

  static function equals(actual:Dynamic, expected:Dynamic, label:String):Void
  {
    check(actual == expected, '$label (expected "$expected", got "$actual")');
  }

  static function main():Void
  {
    testNormalizeDirectory();
    testJoinPath();
    testIsAbsolute();
    testResolveDirectory();
    testEnsureDirectory();
    testPrepareRenderDirectory();
    testExecutableNames();
    testSplitPathValue();
    testWellKnownDirectories();
    testSearchDirectories();
    testLocateHonoursOverride();

    Sys.println('VideoRenderSpec: $checks checks passed.');
  }

  static function testNormalizeDirectory():Void
  {
    equals(RenderPaths.normalizeDirectory(null), '', 'null path');
    equals(RenderPaths.normalizeDirectory(''), '', 'empty path');
    equals(RenderPaths.normalizeDirectory('  '), '', 'blank path');
    equals(RenderPaths.normalizeDirectory('assets/gameRenders'), 'assets/gameRenders/', 'missing separator');
    equals(RenderPaths.normalizeDirectory('assets/gameRenders///'), 'assets/gameRenders/', 'redundant separators');
    // The old Windows default used backslashes; both spellings must normalise.
    equals(RenderPaths.normalizeDirectory('assets\\gameRenders\\'), 'assets/gameRenders/', 'backslash path');
    equals(RenderPaths.normalizeDirectory('/'), '/', 'POSIX root');
    equals(RenderPaths.normalizeDirectory('C:\\Games\\Phoenix\\'), 'C:/Games/Phoenix/', 'drive path');
    // The old folder picker could store `./` for "the game folder itself".
    equals(RenderPaths.normalizeDirectory('./'), '', 'dot path collapses');
    equals(RenderPaths.normalizeDirectory('assets/./gameRenders'), 'assets/gameRenders/', 'dot segment collapses');
    equals(RenderPaths.normalizeDirectory('..'), '../', 'parent segment is preserved');
    equals(RenderPaths.normalizeDirectory('\\\\server\\share\\renders'), '//server/share/renders/', 'UNC path keeps its prefix');
  }

  static function testJoinPath():Void
  {
    equals(RenderPaths.joinPath('assets/gameRenders', 'song'), 'assets/gameRenders/song', 'plain join');
    equals(RenderPaths.joinPath('assets/gameRenders/', 'song'), 'assets/gameRenders/song', 'join with separator');
    equals(RenderPaths.joinPath('assets\\gameRenders\\', 'song'), 'assets\\gameRenders\\song', 'join with backslash');
    equals(RenderPaths.joinPath('', 'song'), 'song', 'join without folder');
    equals(RenderPaths.joinPath(null, 'song'), 'song', 'join with null folder');
    equals(RenderPaths.joinPath('assets/gameRenders', ''), 'assets/gameRenders/', 'join with empty name');
  }

  static function testIsAbsolute():Void
  {
    check(RenderPaths.isAbsolute('/home/player/renders'), 'POSIX absolute path');
    check(RenderPaths.isAbsolute('C:/renders'), 'drive path with forward slash');
    check(RenderPaths.isAbsolute('C:\\renders'), 'drive path with backslash');
    check(RenderPaths.isAbsolute('\\\\server\\share'), 'UNC path');
    check(!RenderPaths.isAbsolute('assets/gameRenders'), 'relative path');
    check(!RenderPaths.isAbsolute('C:renders'), 'drive-relative path is not absolute');
    check(!RenderPaths.isAbsolute(''), 'empty path');
    check(!RenderPaths.isAbsolute(null), 'null path');
  }

  static function testResolveDirectory():Void
  {
    equals(RenderPaths.resolveDirectory('assets/gameRenders/', 'C:/Games/Phoenix'), 'C:/Games/Phoenix/assets/gameRenders/',
      'relative path is anchored to the game folder');
    equals(RenderPaths.resolveDirectory('C:/Renders/', 'C:/Games/Phoenix'), 'C:/Renders/', 'absolute path is kept');
    equals(RenderPaths.resolveDirectory('', 'C:/Games/Phoenix'), 'C:/Games/Phoenix/', 'empty path falls back to the base');
    equals(RenderPaths.resolveDirectory('renders', ''), 'renders/', 'empty base keeps the path relative');
  }

  static function testEnsureDirectory():Void
  {
    final root:String = 'build/video-render-spec';
    if (FileSystem.exists(root)) deleteTree(root);
    FileSystem.createDirectory(root);

    final nested:String = '$root/one/two/three';
    check(RenderPaths.ensureDirectory(nested), 'nested folder chain must be created');
    check(FileSystem.exists(nested) && FileSystem.isDirectory(nested), 'nested folder must exist');
    check(RenderPaths.ensureDirectory('$nested/'), 'already existing folder reports success');
    check(RenderPaths.ensureDirectory(nested), 'creating twice is harmless');

    File.saveContent('$root/blocker', 'not a folder');
    check(!RenderPaths.ensureDirectory('$root/blocker/inside'), 'a file in the way is a failure, not a crash');
    check(!RenderPaths.ensureDirectory(''), 'empty path cannot be created');
    check(!RenderPaths.ensureDirectory(null), 'null path cannot be created');

    deleteTree(root);
  }

  static function testPrepareRenderDirectory():Void
  {
    final root:String = 'build/video-render-spec-prepare';
    if (FileSystem.exists(root)) deleteTree(root);
    FileSystem.createDirectory(root);

    final absolute:String = FileSystem.fullPath(root) + '/nested/renders';
    final prepared:String = RenderPaths.prepareRenderDirectory(absolute);
    check(prepared != null, 'absolute render folder should be prepared');
    equals(prepared, RenderPaths.normalizeDirectory(absolute), 'prepared folder keeps the configured path');
    check(FileSystem.exists(prepared), 'prepared folder must exist on disk');

    deleteTree(root);
  }

  static function testExecutableNames():Void
  {
    equals(FFmpegLocator.executableName(true), 'ffmpeg.exe', 'Windows executable name');
    equals(FFmpegLocator.executableName(false), 'ffmpeg', 'POSIX executable name');
    equals(FFmpegLocator.pathSeparator(true), ';', 'Windows PATH separator');
    equals(FFmpegLocator.pathSeparator(false), ':', 'POSIX PATH separator');
    equals(FFmpegLocator.OVERRIDE_VARIABLES[0], 'PHOENIX_FFMPEG', 'PHOENIX_FFMPEG is checked first');
  }

  static function testSplitPathValue():Void
  {
    final windowsEntries:Array<String> = FFmpegLocator.splitPathValue('C:\\ffmpeg\\bin;D:\\tools\\bin;', ';');
    equals(windowsEntries.length, 2, 'trailing separator is not an entry');
    equals(windowsEntries[0], 'C:\\ffmpeg\\bin', 'first Windows PATH entry');
    equals(windowsEntries[1], 'D:\\tools\\bin', 'second Windows PATH entry');

    final quoted:Array<String> = FFmpegLocator.splitPathValue('"C:\\Program Files\\ffmpeg\\bin";"D:\\x"', ';');
    equals(quoted[0], 'C:\\Program Files\\ffmpeg\\bin', 'quoted PATH entries are unquoted');

    final posix:Array<String> = FFmpegLocator.splitPathValue('/usr/local/bin:/usr/bin', ':');
    equals(posix.length, 2, 'POSIX PATH entries');
    equals(posix[1], '/usr/bin', 'POSIX second entry');

    final duplicates:Array<String> = FFmpegLocator.splitPathValue('/a:/a:/b', ':');
    equals(duplicates.length, 2, 'duplicate entries are dropped');

    equals(FFmpegLocator.splitPathValue(null, ':').length, 0, 'missing PATH value');
    equals(FFmpegLocator.splitPathValue('', ':').length, 0, 'empty PATH value');
    equals(FFmpegLocator.splitPathValue('/a', '').length, 0, 'missing separator');
  }

  static function testWellKnownDirectories():Void
  {
    final env:Map<String, String> = [
      'ProgramFiles' => 'C:/Program Files',
      'LOCALAPPDATA' => 'C:/Users/player/AppData/Local',
      'USERPROFILE' => 'C:/Users/player'
    ];
    final windowsDirs:Array<String> = FFmpegLocator.wellKnownDirectories(true, name -> env.get(name));

    check(windowsDirs.indexOf('C:/Program Files/ffmpeg/bin') >= 0, 'Program Files ffmpeg folder');
    check(windowsDirs.indexOf('C:/Users/player/AppData/Local/Microsoft/WinGet/Links') >= 0, 'winget links folder');
    check(windowsDirs.indexOf('C:/Users/player/scoop/shims') >= 0, 'scoop shims folder');
    check(windowsDirs.indexOf('C:/ProgramData/chocolatey/bin') >= 0, 'chocolatey folder');

    final posixDirs:Array<String> = FFmpegLocator.wellKnownDirectories(false, name -> null);
    check(posixDirs.indexOf('/usr/local/bin') >= 0, 'POSIX ffmpeg folder');
  }

  static function testSearchDirectories():Void
  {
    final directories:Array<String> = FFmpegLocator.searchDirectories(true, 'C:/Games/Phoenix', 'C:/Games/Phoenix',
      'C:/Windows;C:\\FFmpeg\\bin', ['c:/ffmpeg/bin', 'C:/ProgramData/chocolatey/bin']);

    equals(directories[0], 'C:/Games/Phoenix', 'the game folder is probed first (where players drop ffmpeg.exe)');
    equals(directories.filter(dir -> dir.toLowerCase() == 'c:/games/phoenix').length, 1,
      'the working directory is not probed twice');
    equals(directories[1], 'C:/Windows', 'PATH entries come after the game folder');
    // Windows paths are case-insensitive: `C:\FFmpeg\bin` and `c:/ffmpeg/bin` are one folder.
    equals(directories.filter(dir -> dir.toLowerCase() == 'c:/ffmpeg/bin').length, 1,
      'case-insensitive duplicates are dropped on Windows');
    equals(directories[directories.length - 1], 'C:/ProgramData/chocolatey/bin', 'known install folders come last');

    final posix:Array<String> = FFmpegLocator.searchDirectories(false, '/opt/game', null, '/usr/bin:/usr/local/bin', null);
    equals(posix[0], '/opt/game', 'POSIX game folder first');
    equals(posix.length, 3, 'POSIX directory list');

    // An FFmpeg zip unpacked inside the game folder usually nests it in ffmpeg/bin.
    final nearby:Array<String> = FFmpegLocator.nearbyDirectories('C:/Games/Phoenix/');
    equals(nearby[0], 'C:/Games/Phoenix/ffmpeg/bin', 'unpacked ffmpeg/bin inside the game folder');
    check(nearby.indexOf('C:/Games/Phoenix/ffmpeg') >= 0, 'unpacked ffmpeg folder inside the game folder');
    equals(FFmpegLocator.nearbyDirectories(null).length, 0, 'no game folder, no nearby folders');
  }

  static function testLocateHonoursOverride():Void
  {
    final root:String = 'build/video-render-spec-ffmpeg';
    if (FileSystem.exists(root)) deleteTree(root);
    FileSystem.createDirectory(root);

    final executable:String = root + '/' + FFmpegLocator.executableName(RenderPaths.isWindows);
    File.saveContent(executable, '');
    final expected:String = FileSystem.fullPath(executable);

    Sys.putEnv('PHOENIX_FFMPEG', FileSystem.fullPath(root));
    final viaFolder:Null<String> = FFmpegLocator.locate();
    check(viaFolder != null, 'PHOENIX_FFMPEG pointing at a folder must resolve');
    equals(FileSystem.fullPath(viaFolder), expected, 'folder override resolves to the executable inside it');

    Sys.putEnv('PHOENIX_FFMPEG', expected);
    final viaFile:Null<String> = FFmpegLocator.locate();
    check(viaFile != null, 'PHOENIX_FFMPEG pointing at the executable must resolve');
    equals(FileSystem.fullPath(viaFile), expected, 'file override resolves to that executable');

    Sys.putEnv('PHOENIX_FFMPEG', '');
    deleteTree(root);
  }

  static function deleteTree(path:String):Void
  {
    if (!FileSystem.exists(path)) return;

    if (FileSystem.isDirectory(path))
    {
      for (name in FileSystem.readDirectory(path)) deleteTree('$path/$name');
      FileSystem.deleteDirectory(path);
    }
    else
    {
      FileSystem.deleteFile(path);
    }
  }
}
