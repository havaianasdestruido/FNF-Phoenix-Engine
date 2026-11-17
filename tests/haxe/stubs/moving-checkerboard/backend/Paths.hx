package backend;

import flixel.graphics.FlxGraphic;

/**
 * Asset surface the checkerboard uses: one tile per installed `checker*` key,
 * plus a folder listing that may advertise variants this fake build does not
 * ship (so the fallback path can be exercised).
 */
class Paths
{
  /** Tiles this fake build ships; anything else is a missing asset. */
  public static var installed:Array<String> = ['checker', 'checker_fatty', 'checker_folk', 'checker_logo', 'checker_lol'];

  /** Names `readDirectory()` reports, like a real images folder would. */
  public static var preloadImages:Array<String> = [
    'checker.png', 'checker_fatty.png', 'checker_sandbox.png', 'menuDesat.png'
  ];

  /** Folders `readDirectory()` answers for; anything else throws, like sys does. */
  public static var imageFolders:Array<String> = ['assets/preload/images'];

  /** Tile keys handed out, in order, so a spec can see a reload happen. */
  public static var loaded:Array<String> = [];

  public static function image(name:String, ?library:String):FlxGraphic
  {
    if (installed.indexOf(name) < 0) return null;
    loaded.push(name);
    return new FlxGraphic(name);
  }

  public static inline function getPreloadPath(file:String = ''):String
    return 'assets/$file';

  /** `inline`, like the real `backend.Paths.readDirectory` it stands in for. */
  public static inline function readDirectory(path:String):Array<String>
  {
    if (imageFolders.indexOf(path) < 0) throw 'no such folder: $path';
    return preloadImages;
  }

  /** Restores the defaults every spec starts from. */
  public static function reset():Void
  {
    installed = ['checker', 'checker_fatty', 'checker_folk', 'checker_logo', 'checker_lol'];
    preloadImages = ['checker.png', 'checker_fatty.png', 'checker_sandbox.png', 'menuDesat.png'];
    imageFolders = ['assets/preload/images'];
    loaded = [];
  }
}
