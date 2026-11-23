package backend;

/** Minimal stand-in: lowercases and hyphenates, like the real formatToSongPath. */
class Paths
{
  public static function formatToSongPath(path:String):String
  {
    if (path == null) return '';
    return path.split(' ').join('-').toLowerCase();
  }
}
