package openfl.media;

import lime.media.AudioBuffer;

class Sound
{
  public static var fileLoads:Int = 0;
  public var __buffer:AudioBuffer;
  public var length:Float;
  public var origin:String;
  public var streamed:Bool;

  public function new(buffer:AudioBuffer, origin:String, length:Float, streamed:Bool)
  {
    __buffer = buffer;
    this.origin = origin;
    this.length = length;
    this.streamed = streamed;
  }

  public static function fromAudioBuffer(buffer:AudioBuffer):Sound
  {
    final path:String = buffer.vorbis.path;
    if (path.indexOf('throw-sound') != -1) throw 'sound failed';
    if (path.indexOf('no-sound') != -1) return null;
    return new Sound(buffer, path, path.indexOf('empty') != -1 ? 0 : 120000, true);
  }

  public static function fromFile(path:String):Sound
  {
    fileLoads++;
    return new Sound(new AudioBuffer(), path, 120000, false);
  }
}
