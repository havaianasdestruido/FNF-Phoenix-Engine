import data.Section.SwagSection;
import data.Song.SwagSong;
import objects.Note.PreloadedChartNote;
import play.PlayState;
import play.helpers.PlayStateChartLoader;

/** Dependency-free tests for the production gameplay chart loader.
 *
 * Run with tests/haxe/run-chart-loader.sh. The runner copies
 * source/play/helpers/PlayStateChartLoader.hx into an isolated classpath with
 * renderer-free stubs, so note/event conversion is exercised without OpenFL.
 */
class ChartLoaderSpec
{
  static function equal<T>(actual:T, expected:T, label:String):Void
  {
    if (actual != expected) throw '$label: expected $expected, got $actual';
  }

  static function near(actual:Float, expected:Float, label:String):Void
  {
    if (Math.abs(actual - expected) > 0.0001) throw '$label: expected $expected, got $actual';
  }

  static function check(ok:Bool, label:String):Void
  {
    if (!ok) throw label;
  }

  static function note(time:Float, lane:Int, sustain:Float, type:Dynamic):Array<Dynamic>
  {
    return [time, lane, sustain, type];
  }

  static function event(time:Float, name:String, value1:String, value2:String):Array<Dynamic>
  {
    return [time, [[name, value1, value2]]];
  }

  static function section(notes:Array<Dynamic>, ?mustHit:Bool = true, ?alt:Bool = false, ?gf:Bool = false, ?changeBPM:Bool = false,
      ?bpm:Float = 120):SwagSection
  {
    return {
      sectionNotes: notes,
      sectionBeats: 4,
      mustHitSection: mustHit,
      gfSection: gf,
      bpm: bpm,
      changeBPM: changeBPM,
      altAnim: alt
    };
  }

  static function song(sections:Array<SwagSection>, ?events:Array<Dynamic>):SwagSong
  {
    return {
      song: 'test-song',
      notes: sections,
      events: events == null ? [] : events,
      bpm: 120,
      needsVoices: false,
      speed: 1,
      specialAudioName: '',
      specialEventsName: '',
      windowName: ''
    };
  }

  static function state():PlayState
  {
    PlayState.opponentChart = false;
    PlayState.bothSides = false;
    PlayState.sectionsLoaded = 0;
    return new PlayState();
  }

  static function headAt(state:PlayState, time:Float):PreloadedChartNote
  {
    for (note in state.unspawnNotes)
      if (!note.isSustainNote && Math.abs(note.strumTime - time) < 0.0001) return note;
    throw 'missing head note at $time';
  }

  static function main():Void
  {
    testBasicConversion();
    testLegacyNumericNoteType();
    testStartingPointAndCharacterEvents();
    testMultipliersAndJacks();
    testNoAnimationPropagation();
    testLargeChart();
    trace('ChartLoaderSpec passed');
  }

  static function testBasicConversion():Void
  {
    var state = state();
    PlayState.SONG = song([
      section([
        note(0, 0, 0, ''),
        note(100, 1, 250, 'Alt Animation'),
        note(200, 4, 0, 'Hurt Note'),
        note(300, 5, 0, 'GF Sing'),
        note(400, 6, 0, 'No Animation')
      ])
    ]);

    PlayStateChartLoader.generateSong(state);

    equal(state.unspawnNotes.length, 8, 'head + sustain note count');
    equal(state.totalNotes, 2, 'player note total');
    equal(state.opponentNoteTotal, 3, 'opponent note total');
    equal(state.generatedMusic, true, 'generatedMusic flag');
    equal(state.notesLoadedRN, 0, 'loading counter reset');

    var altHead = headAt(state, 100);
    equal(altHead.noteType, 'Alt Animation', 'alt note type');
    equal(altHead.animSuffix, '-alt', 'alt animation suffix');
    equal(altHead.sustainLength, 250, 'sustain length preserved');

    var hurtHead = headAt(state, 200);
    equal(hurtHead.missHealth, 0.3, 'hurt note miss health');
    equal(hurtHead.hitCausesMiss, true, 'hurt note causes miss');

    var sustainCount:Int = 0;
    for (note in state.unspawnNotes)
      if (note.isSustainNote) sustainCount++;
    equal(sustainCount, 3, 'sustain segment count');
  }

  static function testLegacyNumericNoteType():Void
  {
    var state = state();
    PlayState.SONG = song([
      section([
        note(0, 0, 0, 1),
        note(100, 1, 0, 4)
      ])
    ]);

    PlayStateChartLoader.generateSong(state);

    equal(headAt(state, 0).noteType, 'Alt Animation', 'numeric legacy note type normalized');
    equal(headAt(state, 0).animSuffix, '', 'numeric legacy note does not imply alt suffix');
    equal(headAt(state, 100).noteType, 'Hurt Note', 'numeric hurt note type normalized');
    check(state.noteTypeMap.exists('Alt Animation'), 'note type map records normalized type');
  }

  static function testStartingPointAndCharacterEvents():Void
  {
    var state = state();
    var pixelDad = new objects.Character();
    pixelDad.noteskin = 'pixel';
    state.dadMap.set('dad-pixel', pixelDad);
    PlayState.SONG = song([
      section([
        note(0, 0, 0, ''),
        note(1600, 1, 0, ''),
        note(2000, 4, 0, '')
      ])
    ], [
      event(500, 'Hey!', '0', ''),
      event(2000, 'Change Character', 'dad', 'dad-pixel')
    ]);

    state.missCounter.miss();
    state.missCounter.miss();
    state.missCombo = 2;
    PlayStateChartLoader.generateSong(state, 1000);

    equal(state.missCounter.count, 0, 'skipped successful notes reset the miss streak');
    equal(state.missCombo, 0, 'skipped successful notes reset legacy miss combo');
    equal(state.unspawnNotes.length, 2, 'notes before the restart cutoff are not spawned');
    equal(state.totalNotesPlayed, 1, 'skipped player note counted as played');
    equal(state.eventNotes.length, 1, 'events before the restart cutoff are skipped');
    equal(state.charChangeTimes.length, 0, 'consumed character events removed');
    equal(headAt(state, 1600).noteskin, '', 'noteskin before character change');
    equal(headAt(state, 2000).noteskin, 'pixel', 'noteskin after character change');
  }

  static function testMultipliersAndJacks():Void
  {
    var state = state();
    state.jackingtime = 1;
    PlayState.SONG = song([
      section([
        note(0, 0, 0, ''),
        note(100, 1, 0, ''),
        note(200, 2, 0, '')
      ])
    ], [
      event(0, 'Change Note Multiplier', '2', ''),
      event(100, 'Change Note Multiplier', '3', '')
    ]);

    PlayStateChartLoader.generateSong(state);

    equal(state.unspawnNotes.length, 6, 'jack notes added');
    equal(state.multiChangeEvents[0].length, 0, 'consumed multiplier events removed');
    near(headAt(state, 0).noteDensity, 2, 'first multiplier applied');
    near(headAt(state, 100).noteDensity, 3, 'second multiplier applied');
    near(headAt(state, 200).noteDensity, 3, 'multiplier persists');
  }

  static function testNoAnimationPropagation():Void
  {
    var state = state();
    state.jackingtime = 1;
    PlayState.SONG = song([
      section([
        note(0, 0, 250, 'No Animation')
      ])
    ]);

    PlayStateChartLoader.generateSong(state);

    equal(headAt(state, 0).noAnimation, true, 'head disables hit animation');
    equal(headAt(state, 0).noMissAnimation, true, 'head disables miss animation');
    equal(headAt(state, 125).noAnimation, true, 'jack disables hit animation');
    equal(headAt(state, 125).noMissAnimation, true, 'jack disables miss animation');

    var sustainCount:Int = 0;
    for (chartNote in state.unspawnNotes)
    {
      if (!chartNote.isSustainNote) continue;
      sustainCount++;
      equal(chartNote.noAnimation, true, 'sustain disables hit animation');
      equal(chartNote.noMissAnimation, true, 'sustain disables miss animation');
    }
    equal(sustainCount, 3, 'all sustain segments keep no-animation flags');
  }

  static function testLargeChart():Void
  {
    var state = state();
    var notes:Array<Dynamic> = [];
    for (i in 0...5000)
      notes.push(note(i * 10, i % 8, 250, i % 5 == 0 ? 'Hurt Note' : ''));
    PlayState.SONG = song([section(notes)]);

    final start = haxe.Timer.stamp();
    PlayStateChartLoader.generateSong(state);
    final elapsedMs = (haxe.Timer.stamp() - start) * 1000;

    equal(state.unspawnNotes.length, 20000, 'large chart note count');
    equal(state.eventNotes.length, 0, 'large chart has no events');
    trace('Gameplay chart conversion (5000 notes + sustains): ${elapsedMs} ms');
  }
}
