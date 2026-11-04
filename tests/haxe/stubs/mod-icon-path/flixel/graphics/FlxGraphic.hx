package flixel.graphics;
class FlxGraphic {
  public var key:String; public var persist:Bool; public var destroyOnNoUse:Bool;
  public var bitmap:openfl.display.BitmapData; public var width:Int; public var height:Int;
  public function new() {}
  public static function fromBitmapData(data:openfl.display.BitmapData, unique:Bool=false, ?key:String):FlxGraphic {
    var g = new FlxGraphic(); g.key = key; g.bitmap = data; return g;
  }
}
