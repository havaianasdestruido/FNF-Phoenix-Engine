package flixel.system.frontEnds;
class BitmapFrontEnd {
  public var _cache:Map<String, flixel.graphics.FlxGraphic> = [];
  public function new() {}
  public function get(key:String):flixel.graphics.FlxGraphic return _cache.get(key);
  public function remove(g:flixel.graphics.FlxGraphic):Void {}
  public function add(data:Dynamic, unique:Bool=false, ?key:String):flixel.graphics.FlxGraphic return null;
}
