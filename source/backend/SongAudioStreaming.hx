package backend;

import openfl.media.Sound;
#if (lime_vorbis && lime_openal && sys && !html5 && !flash)
import lime.media.AudioBuffer;
import lime.media.vorbis.VorbisFile;
#end

/**
 * Best-effort native Vorbis streaming for the Experimental Extreme profile.
 * A stream owns its decoder and must not be shared between sound channels.
 * Unsupported targets, non-Ogg files, inaccessible assets and invalid streams
 * return null so Paths can fall back to its normal decoded-sound loader.
 */
class SongAudioStreaming
{
  public static function open(file:String):Sound
  {
    #if (lime_vorbis && lime_openal && sys && !html5 && !flash)
    if (file == null || !StringTools.endsWith(file.toLowerCase(), '.ogg')) return null;

    var vorbis:VorbisFile = null;
    try
    {
      vorbis = VorbisFile.fromFile(file);
      if (vorbis == null) return null;
      final info = vorbis.info();
      // Lime's OpenAL stream path supports only mono/stereo, and gameplay
      // needs seeking for pause/resume and vocal resync. Fall back otherwise.
      if (info == null || info.channels < 1 || info.channels > 2 || info.rate <= 0 || !vorbis.seekable())
      {
        vorbis.clear();
        return null;
      }
      final buffer:AudioBuffer = AudioBuffer.fromVorbisFile(vorbis);
      if (buffer == null)
      {
        vorbis.clear();
        return null;
      }
      final sound:Sound = Sound.fromAudioBuffer(buffer);
      if (sound == null || sound.length <= 0)
      {
        vorbis.clear();
        return null;
      }
      return sound;
    }
    catch (_:Dynamic)
    {
      if (vorbis != null)
      {
        try vorbis.clear() catch (_:Dynamic) {}
      }
    }
    #end
    return null;
  }
}
