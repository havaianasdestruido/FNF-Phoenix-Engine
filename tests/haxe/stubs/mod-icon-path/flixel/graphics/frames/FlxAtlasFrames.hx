package flixel.graphics.frames;
class FlxAtlasFrames extends FlxFramesCollection {
  public var parent:Dynamic;
  public function new(parent:Dynamic) { this.parent = parent; }
  public function addAtlas(atlas:FlxAtlasFrames, clearHash:Bool=false):Void {}
  public static function fromSparrow(img:Dynamic, xml:String):FlxAtlasFrames return null;
  public static function fromTexturePackerJson(img:Dynamic, json:String):FlxAtlasFrames return null;
  public static function fromSpriteSheetPacker(img:Dynamic, txt:String):FlxAtlasFrames return null;
}
