package openfl.utils;

import openfl.media.Sound;
import lime.media.AudioBuffer;

class Assets
{
  public static var paths:Map<String, String> = new Map<String, String>();
  public static var soundLoads:Int = 0;
  public static function getPath(id:String):String
  {
    if (id.indexOf('throw-path') != -1) throw 'not on disk';
    return paths.get(id);
  }
  public static function getSound(id:String):Sound
  {
    soundLoads++;
    return new Sound(new AudioBuffer(), id, 120000, false);
  }
}
