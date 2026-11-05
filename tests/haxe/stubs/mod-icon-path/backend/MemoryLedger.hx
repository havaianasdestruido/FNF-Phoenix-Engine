package backend;
class MemoryLedger {
  public static function trackImage(key:String, path:String, bitmap:Dynamic, gpu:Bool):Void {}
  public static function trackSound(key:String, path:String, sound:Dynamic):Void {}
  public static function untrackAsset(key:String):Void {}
}
