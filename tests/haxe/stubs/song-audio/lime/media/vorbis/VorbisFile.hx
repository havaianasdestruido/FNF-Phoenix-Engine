package lime.media.vorbis;

/** Fake native decoder: filenames select deterministic failure cases. */
class VorbisFile
{
  public static var opens:Int = 0;
  public static var clears:Int = 0;
  public var path:String;

  public function new(path:String) this.path = path;

  public static function fromFile(path:String):VorbisFile
  {
    opens++;
    if (path.indexOf('throw-open') != -1) throw 'open failed';
    if (path.indexOf('missing-decoder') != -1) return null;
    return new VorbisFile(path);
  }

  public function info():FakeVorbisInfo
  {
    if (path.indexOf('throw-info') != -1) throw 'info failed';
    if (path.indexOf('no-info') != -1) return null;
    return {
      channels: path.indexOf('bad-channels') != -1 ? 6 : (path.indexOf('mono') != -1 ? 1 : 2),
      rate: path.indexOf('bad-rate') != -1 ? 0 : 44100
    };
  }

  public function seekable():Bool
  {
    if (path.indexOf('throw-seekable') != -1) throw 'seekable failed';
    return path.indexOf('no-seek') == -1;
  }

  public function clear():Void clears++;
}

typedef FakeVorbisInfo = { var channels:Int; var rate:Int; }
