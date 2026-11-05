package flixel.system.frontEnds;
class SoundFrontEnd {
  public var music:openfl.media.Sound;
  public function new() {}
  public function playMusic(s:openfl.media.Sound, volume:Float=1, loop:Bool=false):Void {}
  public function play(s:openfl.media.Sound, volume:Float=1):Void {}
}
