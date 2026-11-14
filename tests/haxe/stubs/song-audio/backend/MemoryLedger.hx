package backend;

import openfl.media.Sound;

class MemoryLedger
{
  public static var tracked:Map<String, String> = new Map<String, String>();
  public static function trackSound(key:String, source:String, sound:Sound):Void tracked.set(key, source);
}
