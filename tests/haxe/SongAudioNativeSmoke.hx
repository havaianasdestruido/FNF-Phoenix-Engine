import backend.SongAudioStreaming;
import flixel.sound.FlxSound;
import lime.media.openal.ALC;
import openfl.media.Sound;

/**
 * Optional Linux/Neko smoke test with real Lime/OpenFL and the engine's
 * FlxSound patch. Run via run-song-audio-native-smoke.sh with the pinned
 * libraries and a native Lime ndll installed. OpenAL's null driver advances
 * real channels without requiring a desktop or speakers.
 *
 * This is not a full game/device test: it checks independent streaming,
 * seek/pause/resume, pitch, and native decoder finalization.
 */
class SongAudioNativeSmoke
{
  static var done:Bool = false;
  static var first:FlxSound;
  static var second:FlxSound;
  static var firstSound:Sound;
  static var secondSound:Sound;

  static function check(ok:Bool, message:String):Void
  {
    if (!ok) throw 'SongAudioNativeSmoke: ' + message;
  }

  static function fdCount():Int return sys.FileSystem.readDirectory('/proc/self/fd').length;

  static function main():Void
  {
    final device = ALC.openDevice();
    check(device != null, 'OpenAL device unavailable');
    final context = ALC.createContext(device);
    check(context != null && ALC.makeContextCurrent(context), 'OpenAL context unavailable');
    final beforeOpen:Int = fdCount();

    firstSound = SongAudioStreaming.open(Sys.args()[0]);
    secondSound = SongAudioStreaming.open(Sys.args()[0]);
    check(firstSound != null && secondSound != null && firstSound != secondSound, 'independent decoders open');
    check(firstSound.length > 31000, 'fixture is long enough for the seek test');
    check(fdCount() >= beforeOpen + 2, 'each decoder owns an open file');

    first = new FlxSound().loadEmbedded(firstSound);
    second = new FlxSound().loadEmbedded(secondSound);
    first.play(false, 2500);
    second.play(false, 10000);
    check(first.playing && second.playing, 'both channels play');
    first.pitch = 1.25;
    check(Math.abs(@:privateAccess first._channel.__audioSource.pitch - 1.25) < 0.01,
      'pitch reaches the native audio source');

    haxe.Timer.delay(function()
    {
      first.update(1.2);
      second.update(1.2);
      check(first.time > 3300 && first.time < 5500, 'first channel advances at the changed pitch');
      check(second.time > 10700 && second.time < 13000, 'second channel advances independently');
      first.pause();
      final paused:Float = first.time;
      first.play(); // resume via FlxSound
      second.time = 30000; // seek the other channel

      haxe.Timer.delay(function()
      {
        first.update(0.4);
        second.update(0.4);
        check(first.time > paused + 100, 'paused channel resumes at its previous time');
        check(second.time > 30000 && second.time < 32000, 'forward seek advances');
        first.stop();
        second.stop();
        first.destroy();
        second.destroy();
        first = second = null;
        firstSound.close();
        secondSound.close();
        firstSound = secondSound = null;

        // Let the preceding callback return so no local references keep the
        // AudioBuffers alive. Lime's native CFFI finalizer closes Vorbis files.
        haxe.Timer.delay(function()
        {
          neko.vm.Gc.run(true);
          neko.vm.Gc.run(true);
          check(fdCount() <= beforeOpen, 'GC releases both stopped decoders and their file handles');
          ALC.makeContextCurrent(null);
          ALC.destroyContext(context);
          ALC.closeDevice(device);
          done = true;
          trace('SongAudioNativeSmoke passed');
        }, 200);
      }, 400);
    }, 1200);

    // A real Lime Application normally drives its replacement haxe.Timer.
    // This headless harness supplies those ticks on the same thread instead.
    final started:Float = Sys.time();
    while (!done && Sys.time() - started < 8)
    {
      for (timer in @:privateAccess haxe.Timer.sRunningTimers.copy())
        if (timer != null) @:privateAccess timer.__check(lime.system.System.getTimer());
      Sys.sleep(0.01);
    }
    check(done, 'timed out waiting for playback checks');
  }
}
