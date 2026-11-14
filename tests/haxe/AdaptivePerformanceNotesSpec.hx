import backend.ClientPrefs;
import debug.PoolStats;
import objects.Note;
import objects.NoteSplash;
import play.PlayState;
import play.helpers.PlayStateNoteHelpers;
import play.objects.SustainSplash;

/** Calls the production splash helpers for both sides and the public direct paths. */
class AdaptivePerformanceNotesSpec
{
  static function check(value:Bool, label:String):Void
  {
    if (!value) throw label;
  }

  static function equal<T>(actual:T, expected:T, label:String):Void
  {
    if (actual != expected) throw '$label: expected $expected, got $actual';
  }

  static function main():Void
  {
    final state = new PlayState();
    final note = new Note();
    ClientPrefs.noteSplashes = true;

    PlayStateNoteHelpers.spawnNoteSplashOnNote(state, false, note);
    PlayStateNoteHelpers.spawnNoteSplashOnNote(state, true, note);
    PlayStateNoteHelpers.spawnHoldSplashOnNote(state, note, false);
    PlayStateNoteHelpers.spawnHoldSplashOnNote(state, note, true);
    equal(NoteSplash.setups, 2, 'player and opponent splashes work normally');
    equal(SustainSplash.setups, 2, 'player and opponent sustain splashes work normally');
    equal(state.splashesPerFrame[0], 1, 'opponent splash counted normally');
    equal(state.splashesPerFrame[1], 1, 'player splash counted normally');
    equal(state.splashesPerFrame[2], 1, 'opponent hold counted normally');
    equal(state.splashesPerFrame[3], 1, 'player hold counted normally');

    final count:Int = PoolStats.spawns;
    final oldHold:SustainSplash = note.noteHoldSplash;
    state.adaptiveSplashesDisabled = true;
    PlayStateNoteHelpers.spawnNoteSplashOnNote(state, false, note);
    PlayStateNoteHelpers.spawnNoteSplashOnNote(state, true, note);
    PlayStateNoteHelpers.spawnHoldSplashOnNote(state, note, false);
    PlayStateNoteHelpers.spawnHoldSplashOnNote(state, note, true);
    PlayStateNoteHelpers.spawnNoteSplash(state, 10, 20, 0, note);
    PlayStateNoteHelpers.spawnHoldSplash(state, note);
    equal(PoolStats.spawns, count, 'no new splash allocations through any path');
    equal(NoteSplash.setups, 2, 'no tap splash is set up after suppression');
    equal(SustainSplash.setups, 2, 'no hold splash is set up after suppression');
    equal(state.splashesPerFrame[0], 1, 'suppressed opponent hit does not consume splash quota');
    equal(state.splashesPerFrame[1], 1, 'suppressed player hit does not consume splash quota');
    equal(note.noteHoldSplash, oldHold, 'suppression does not replace the hold association');
    check(ClientPrefs.noteSplashes && note.alive && note.strumTime == 1000,
      'suppression changes neither the preference nor gameplay note data');

    // Preserve the existing direct-spawn behavior when adaptive performance
    // is off, even if a mod manually asks for a splash with the preference off.
    state.adaptiveSplashesDisabled = false;
    ClientPrefs.noteSplashes = false;
    PlayStateNoteHelpers.spawnNoteSplashOnNote(state, false, note);
    equal(NoteSplash.setups, 2, 'normal preference is still honoured');
    PlayStateNoteHelpers.spawnNoteSplash(state, 10, 20, 0, note);
    equal(NoteSplash.setups, 3, 'direct mod spawn retains its original behavior');
    Sys.println('AdaptivePerformanceNotesSpec: PASS');
  }
}
