package lime.media;

import lime.media.vorbis.VorbisFile;

class AudioBuffer
{
  public var vorbis:VorbisFile;
  public function new(?vorbis:VorbisFile) this.vorbis = vorbis;

  public static function fromVorbisFile(vorbis:VorbisFile):AudioBuffer
  {
    if (vorbis.path.indexOf('throw-buffer') != -1) throw 'buffer failed';
    if (vorbis.path.indexOf('no-buffer') != -1) return null;
    return new AudioBuffer(vorbis);
  }
}
