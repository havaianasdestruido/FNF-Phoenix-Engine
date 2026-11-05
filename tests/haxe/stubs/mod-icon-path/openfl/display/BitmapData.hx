package openfl.display;
class BitmapData {
  public var width:Int; public var height:Int; public var image:Dynamic; public var readable:Bool;
  public var __texture:Dynamic;
  public function new(w:Int,h:Int) { width=w; height=h; }
  // Simulate decoding: a real file "loads", a missing one returns null.
  public static function fromFile(path:String):BitmapData return sys.FileSystem.exists(path) ? new BitmapData(150,150) : null;
  public function lock():Void {} public function getTexture(ctx:Dynamic):Dynamic return null;
  public function getSurface():Dynamic return null; public function disposeImage():Void {}
}
