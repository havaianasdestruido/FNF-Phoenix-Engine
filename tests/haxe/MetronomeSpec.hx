import backend.ClientPrefs;
import backend.Conductor;
import backend.Metronome;
import backend.Paths;
import flixel.FlxG;
import play.PlayState;
import play.helpers.PlayStateMetronome;

/** Exercises the real metronome policy and shared voice with small audio stubs. */
class MetronomeSpec
{
  static function check(ok:Bool, label:String):Void
  {
    if (!ok) throw label;
  }

  static function equal<T>(actual:T, expected:T, label:String):Void
  {
    if (actual != expected) throw '$label: expected $expected, got $actual';
  }

  static function reset():PlayState
  {
    Metronome.stop();
    FlxG.sound.reset();
    Paths.lookups = 0;
    ClientPrefs.metronome = Metronome.OFF;
    PlayState.startOnTime = 0;
    Conductor.songPosition = 0;
    return new PlayState();
  }

  static function plays():Int
  {
    return FlxG.sound.lastSound == null ? 0 : FlxG.sound.lastSound.plays;
  }

  static function main():Void
  {
    equal(Metronome.MODES.join('/'), 'Off/Count-in/Always', 'mode labels');
    check(!Metronome.allowsTick(Metronome.OFF, true), 'Off is silent in the count-in');
    check(!Metronome.allowsTick(Metronome.OFF, false), 'Off is silent in the song');
    check(Metronome.allowsTick(Metronome.COUNT_IN, true), 'Count-in ticks during the lead-in');
    check(!Metronome.allowsTick(Metronome.COUNT_IN, false), 'Count-in stops at the song');
    check(Metronome.allowsTick(Metronome.ALWAYS, true), 'Always ticks during the lead-in');
    check(Metronome.allowsTick(Metronome.ALWAYS, false), 'Always ticks during the song');
    check(!Metronome.allowsTick('invalid', true), 'unknown saved values fail closed');

    var state = reset();
    Metronome.cache();
    equal(Paths.lookups, 1, 'cache decodes the shipped sample');
    equal(FlxG.sound.loads, 0, 'cache creates no voice');
    PlayStateMetronome.cache(state);
    equal(Paths.lookups, 1, 'Off does not preload the tick');
    ClientPrefs.metronome = Metronome.ALWAYS;
    PlayStateMetronome.cache(state);
    equal(Paths.lookups, 2, 'enabled mode preloads the tick');

    state = reset();
    state.startingSong = true;
    for (counter in 0...5)
      PlayStateMetronome.countdownTick(state, counter);
    PlayStateMetronome.beatHit(state);
    equal(plays(), 0, 'Off never ticks');

    state = reset();
    ClientPrefs.metronome = Metronome.COUNT_IN;
    state.startingSong = true;
    state.playbackRate = 1.5;
    for (counter in 0...5)
      PlayStateMetronome.countdownTick(state, counter);
    equal(plays(), 5, 'five count-in beats including START');
    equal(FlxG.sound.lastSound.pitch, 1.5, 'count-in follows playbackRate');
    check(FlxG.sound.lastSound.restarted, 'each beat restarts the sample');
    PlayStateMetronome.countdownTick(state, 4);
    equal(plays(), 5, 'duplicate countdown callbacks do not double-tick');
    state.startingSong = false;
    state.curBeat = 1;
    PlayStateMetronome.beatHit(state);
    equal(plays(), 5, 'Count-in is silent after START');

    state = reset();
    ClientPrefs.metronome = Metronome.ALWAYS;
    state.startingSong = true;
    for (counter in 0...5)
      PlayStateMetronome.countdownTick(state, counter);
    state.startingSong = false;
    PlayStateMetronome.beatHit(state);
    equal(plays(), 5, 'START is not repeated by the first song update');
    state.curBeat = 1;
    state.playbackRate = 0.75;
    PlayStateMetronome.beatHit(state);
    PlayStateMetronome.beatHit(state);
    equal(plays(), 6, 'one tick per song beat');
    equal(FlxG.sound.lastSound.pitch, 0.75, 'song ticks follow rate changes');
    equal(FlxG.sound.loads, 1, 'beats reuse one voice');
    FlxG.sound.lastSound.volume = 0.2;
    Metronome.play(1);
    equal(FlxG.sound.lastSound.volume, 1, 'idle voice refreshes its transform before playback');
    Metronome.stop();
    equal(FlxG.sound.lastSound.stops, 1, 'stop silences an active tick');
    FlxG.sound.lastSound.exists = false;
    Metronome.play(2);
    equal(FlxG.sound.loads, 2, 'a voice destroyed by a state change is rebuilt');

    state = reset();
    ClientPrefs.metronome = Metronome.ALWAYS;
    PlayState.startOnTime = 10000;
    Conductor.songPosition = 9650;
    PlayStateMetronome.seek(state);
    state.curBeat = 19;
    PlayStateMetronome.beatHit(state);
    equal(plays(), 0, 'no tick while startOnTime is pending');
    PlayState.startOnTime = 0;
    Conductor.songPosition = 9500;
    PlayStateMetronome.beatHit(state);
    Conductor.songPosition = 9999;
    PlayStateMetronome.beatHit(state);
    equal(plays(), 0, 'no catch-up ticks during the seek lead-in or stem rewind');
    Conductor.songPosition = 10000;
    state.curBeat = 20;
    PlayStateMetronome.beatHit(state);
    equal(plays(), 0, 'the crossed seek beat is absorbed');
    Conductor.songPosition = 10500;
    state.curBeat = 21;
    PlayStateMetronome.beatHit(state);
    equal(plays(), 1, 'normal ticks resume after the seek');

    state = reset();
    ClientPrefs.metronome = Metronome.ALWAYS;
    for (field in ['paused', 'endingSong', 'isDead', 'transitioning', 'inCutscene', 'ffmpegMode'])
    {
      Reflect.setField(state, field, true);
      PlayStateMetronome.beatHit(state);
      Reflect.setField(state, field, false);
    }
    state.finishTimer = {};
    PlayStateMetronome.beatHit(state);
    state.finishTimer = null;
    state.startedCountdown = false;
    PlayStateMetronome.beatHit(state);
    equal(plays(), 0, 'pause, ending, death, transitions, cutscenes and rendering stay silent');

    trace('MetronomeSpec passed');
  }
}
