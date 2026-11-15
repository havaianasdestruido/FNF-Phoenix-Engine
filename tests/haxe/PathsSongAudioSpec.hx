import backend.MemoryLedger;
import backend.Paths;
import lime.media.vorbis.VorbisFile;
import openfl.media.Sound;
import openfl.utils.Assets;
import sys.io.File;

/** Runs the production Paths audio methods inside a minimal asset test shell. */
class PathsSongAudioSpec
{
  static function main():Void
  {
    testModSongsAndIndependentStreams();
    testFormatsAndFailuresFallBack();
    testLibraryAndEmbeddedAssets();
    testDifficultyAndMissingAssets();
    trace('PathsSongAudioSpec passed');
  }

  static function testModSongsAndIndependentStreams():Void
  {
    Paths.reset();
    File.saveContent('song.ogg', 'OggS');
    Paths.modFiles.set('songs/test/Inst', 'song.ogg');
    final before:Int = VorbisFile.opens;
    final decoded:Sound = cast Paths.inst('test');
    check(decoded != null && !decoded.streamed, 'ordinary profiles decode as before');
    check(Paths.inst('test') == decoded, 'ordinary decoded sounds are shared');
    equal(Sound.fileLoads, 1, 'decoded mod sound is loaded once');
    equal(VorbisFile.opens, before, 'ordinary profiles never open a stream');

    final one:Sound = cast Paths.inst('test', '', true);
    final two:Sound = cast Paths.inst('test', '', true);
    #if (lime_vorbis && lime_openal && sys && !html5 && !flash)
    check(one != null && one.streamed && two != null && two.streamed, 'native Ogg stems stream');
    check(one != two, 'two players never share a stream/seek cursor');
    check(Paths.currentTrackedSounds.get('song.ogg') == decoded, 'streams do not replace a decoded cache entry');
    var streams:Int = 0;
    for (key => sound in Paths.currentTrackedSounds)
    {
      if (sound != null && sound.streamed)
      {
        streams++;
        check(Paths.local.exists(key), 'each stream is tracked for cleanup');
        equal(MemoryLedger.tracked.get(key), 'song.ogg', 'ledger retains the source path');
      }
    }
    equal(streams, 2, 'each stream has a unique cache key');
    equal(Sound.fileLoads, 1, 'streaming did not decode another copy');
    #else
    check(one == decoded && two == decoded, 'unsupported platforms reuse the decoded sound');
    #end
  }

  static function testFormatsAndFailuresFallBack():Void
  {
    Paths.reset();
    File.saveContent('song.mp3', 'fake');
    Paths.modFiles.set('songs/mp3/Inst', 'song.mp3');
    final opens:Int = VorbisFile.opens;
    final first:Sound = cast Paths.inst('mp3', '', true);
    final second:Sound = cast Paths.inst('mp3', '', true);
    check(first != null && !first.streamed && first == second, 'MP3 uses and reuses normal decoding');
    equal(Sound.fileLoads, 1, 'MP3 fallback does not decode twice');
    equal(VorbisFile.opens, opens, 'MP3 never reaches the Vorbis decoder');

    Paths.reset();
    File.saveContent('missing-decoder.ogg', 'OggS');
    Paths.modFiles.set('songs/fallback/Inst', 'missing-decoder.ogg');
    final fallback:Sound = cast Paths.inst('fallback', '', true);
    check(fallback != null && !fallback.streamed, 'failed Ogg stream falls back to decoding');
    equal(Sound.fileLoads, 1, 'failed stream decoded exactly once');
  }

  static function testLibraryAndEmbeddedAssets():Void
  {
    Paths.reset();
    final id:String = 'songs:assets/songs/library/Inst.ogg';
    Paths.libraryFiles.set('songs/library/Inst', id);
    Assets.paths.set(id, 'library.ogg');
    final sound:Sound = cast Paths.inst('library', '', true);
    #if (lime_vorbis && lime_openal && sys && !html5 && !flash)
    check(sound != null && sound.streamed, 'library Ogg with a disk path streams');
    equal(Assets.soundLoads, 0, 'streaming avoids the decoded library cache');
    #else
    check(sound != null && !sound.streamed, 'library sounds fall back without native streaming');
    #end

    Paths.reset();
    final embedded:String = 'songs:assets/songs/embedded/Inst.ogg';
    Paths.libraryFiles.set('songs/embedded/Inst', embedded);
    final fallback:Sound = cast Paths.inst('embedded', '', true);
    check(fallback != null && !fallback.streamed, 'embedded assets without a path decode normally');
    equal(Assets.soundLoads, 1, 'embedded fallback uses OpenFL');
    check(Paths.inst('embedded', '', true) == fallback, 'fallback can reuse the decoded cache');
    equal(Assets.soundLoads, 1, 'embedded fallback does not decode twice');

    Paths.reset();
    final throwing:String = 'songs:assets/songs/throw-path/Inst.ogg';
    Paths.libraryFiles.set('songs/throw-path/Inst', throwing);
    check(Paths.inst('throw-path', '', true) != null, 'unresolvable paths fall back instead of throwing');
    equal(Assets.soundLoads, 1, 'failed getPath falls back to OpenFL');
  }

  static function testDifficultyAndMissingAssets():Void
  {
    Paths.reset();
    File.saveContent('player-hard.ogg', 'OggS');
    Paths.modFiles.set('songs/test/Voices-Player-hard', 'player-hard.ogg');
    final voice:Sound = cast Paths.voices('test', 'hard', 'Player', true);
    check(voice != null && voice.origin == 'player-hard.ogg', 'difficulty and vocal postfix select the right asset');
    #if (lime_vorbis && lime_openal && sys && !html5 && !flash)
    check(voice.streamed, 'vocal stems receive the streaming option');
    #end
    equal(Paths.voices('absent', '', null, true), null, 'missing vocals still return null');
    equal(Paths.inst('absent', '', true), null, 'missing instrumentals still return null');
  }

  static function check(value:Bool, message:String):Void { if (!value) throw message; }
  static function equal(actual:Dynamic, expected:Dynamic, message:String):Void
  {
    if (actual != expected) throw message + ': expected ' + Std.string(expected) + ', got ' + Std.string(actual);
  }
}
