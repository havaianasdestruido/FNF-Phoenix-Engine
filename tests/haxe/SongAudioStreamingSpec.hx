import backend.SongAudioStreaming;
import lime.media.vorbis.VorbisFile;

/** Tests best-effort stream construction without native audio libraries. */
class SongAudioStreamingSpec
{
  static function main():Void
  {
    #if (lime_vorbis && lime_openal && sys && !html5 && !flash)
    equal(SongAudioStreaming.open(null), null, 'null path falls back');
    equal(SongAudioStreaming.open('track.mp3'), null, 'MP3 is never passed to Vorbis');
    equal(VorbisFile.opens, 0, 'unsupported inputs do not open a decoder');

    final stereo = SongAudioStreaming.open('stereo.OGG');
    check(stereo != null && stereo.streamed, 'a valid stereo Ogg streams');
    final mono = SongAudioStreaming.open('mono.ogg');
    check(mono != null && mono.streamed, 'a valid mono Ogg streams');
    check(SongAudioStreaming.open('stereo.OGG') != stereo, 'each player gets its own decoder');

    rejected('missing-decoder.ogg', false);
    rejected('throw-open.ogg', false);
    for (path in ['no-info.ogg', 'bad-channels.ogg', 'bad-rate.ogg', 'throw-info.ogg',
      'no-seek.ogg', 'throw-seekable.ogg', 'no-buffer.ogg', 'throw-buffer.ogg',
      'no-sound.ogg', 'throw-sound.ogg', 'empty.ogg'])
      rejected(path, true);
    #else
    equal(SongAudioStreaming.open('track.ogg'), null, 'unsupported platforms fall back');
    equal(VorbisFile.opens, 0, 'unsupported platforms never open Vorbis');
    #end
    trace('SongAudioStreamingSpec passed');
  }

  #if (lime_vorbis && lime_openal && sys && !html5 && !flash)
  static function rejected(path:String, shouldClear:Bool):Void
  {
    final clears:Int = VorbisFile.clears;
    equal(SongAudioStreaming.open(path), null, '$path falls back');
    equal(VorbisFile.clears, clears + (shouldClear ? 1 : 0), '$path releases an opened decoder');
  }
  #end

  static function check(value:Bool, message:String):Void { if (!value) throw message; }
  static function equal(actual:Dynamic, expected:Dynamic, message:String):Void
  {
    if (actual != expected) throw message + ': expected ' + Std.string(expected) + ', got ' + Std.string(actual);
  }
}
