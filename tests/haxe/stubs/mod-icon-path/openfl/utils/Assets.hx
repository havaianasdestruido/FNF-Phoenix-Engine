package openfl.utils;
class Assets {
  public static var cache:Dynamic = { clear:function(k:String){}, };
  public static function exists(id:String, ?type:AssetType):Bool return false;
  public static function getBitmapData(id:String):openfl.display.BitmapData return null;
  public static function getText(id:String):String return null;
  public static function getSound(id:String):openfl.media.Sound return null;
  public static function getMusic(id:String):openfl.media.Sound return null;
  public static function list():Array<String> return [];
}
