package backend;

import sys.FileSystem;
import sys.io.File;

/**
 * Disk-backed stand-in for the asset reader, with an in-memory override map
 * for content that must not touch disk. `getPathCount` tracks how often the
 * game actually went to the reader, which is what proves the parse cache
 * works.
 */
class Paths
{
  public static var files:Map<String, String> = new Map();
  public static var getPathCount:Int = 0;

  public static function reset():Void
  {
    files = new Map();
    getPathCount = 0;
  }

  /** Register synthetic content without touching the filesystem. */
  public static function setText(path:String, content:String):Void
  {
    files.set(path, content);
  }

  public static function getTextFromFile(path:String):String
  {
    getPathCount++;
    if (files.exists(path)) return files.get(path);
    try
    {
      if (FileSystem.exists(path)) return File.getContent(path);
    }
    catch (_:Dynamic) {}
    return null;
  }
}
