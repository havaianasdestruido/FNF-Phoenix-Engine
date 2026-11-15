package backend;
class LowMemory
{
  public static var streaming:Bool = false;
  public static function policy():Dynamic return {streamSongAudio: streaming};
}
