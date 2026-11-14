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
    PlayState.isPixelStage = false;
    PlayState.sectionsLoaded = 0;
    backend.Paths.missingSkinFiles.clear();
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
    testAudioPolicy();
    testCharacterMetadata();
    testBasicConversion();
    testLegacyNumericNoteType();
    testLegacyMissingAndBooleanNoteTypes();
    testStartingPointAndCharacterEvents();
    testOverlappingCharacterEvents();
    testUnsortedNotesAndDefaultSkin();
    testCharacterEventsWithNoteOffset();
    testPackagedExternalEvents();
    testMissingCharacterSkinAssets();
    testMultipliersAndJacks();
    testNoAnimationPropagation();
    testLargeChart();
    trace('ChartLoaderSpec passed');
  }

  static function testAudioPolicy():Void
  {
    for (streaming in [false, true])
    {
      backend.LowMemory.streaming = streaming;
      backend.Paths.audioCalls = [];
      backend.Paths.missingPlayer = true;
      PlayState.SONG = song([section([])]);
      PlayState.SONG.needsVoices = true;
      PlayStateChartLoader.generateSong(state());
      equal(backend.Paths.audioCalls.length, 4, 'player fallback, opponent, and instrumental requested');
      equal(backend.Paths.audioCalls[0].postfix, 'Player', 'specific player vocal tried first');
      equal(backend.Paths.audioCalls[1].postfix, null, 'generic vocal fallback tried');
      equal(backend.Paths.audioCalls[2].postfix, 'Opponent', 'opponent vocal requested');
      equal(backend.Paths.audioCalls[3].type, 'inst', 'instrumental requested');
      for (call in backend.Paths.audioCalls)
        equal(call.stream, streaming, 'profile policy reaches every stem and fallback');
    }
    backend.LowMemory.streaming = false;
    backend.Paths.missingPlayer = false;
  }

  static function testCharacterMetadata():Void
  {
    var current = state();
    current.boyfriend.vocalsFile = 'bf-custom';
    current.dad.vocalsFile = 'rival';
    current.bfNoteskin = null; // Built-in character JSON can omit this field.
    current.dadNoteskin = null;
    backend.Paths.audioCalls = [];
    backend.LowMemory.streaming = true;
    PlayState.SONG = song([section([note(0, 0, 0, ''), note(100, 4, 0, '')])]);
    PlayState.SONG.needsVoices = true;
    PlayStateChartLoader.generateSong(current);
    equal(backend.Paths.audioCalls[0].postfix, 'bf-custom', 'player character-specific vocal requested');
    equal(backend.Paths.audioCalls[1].postfix, 'rival', 'opponent character-specific vocal requested');
    equal(headAt(current, 0).noteskin, '', 'null player noteskin uses the default');
    equal(headAt(current, 100).noteskin, '', 'null opponent noteskin uses the default');
    backend.LowMemory.streaming = false;
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

  static function testLegacyMissingAndBooleanNoteTypes():Void
  {
    final current = state();
    PlayState.SONG = song([section([
      ([0, 0, 0] : Array<Dynamic>),
      note(100, 1, 0, false), note(200, 2, 0, true), note(300, 3, 0, 999)
    ])]);
    PlayState.SONG.specialAudioName = null;
    PlayState.SONG.specialEventsName = null;
    PlayStateChartLoader.generateSong(current);
    equal(headAt(current, 0).noteType, '', 'omitted note type defaults to normal');
    equal(headAt(current, 100).noteType, '', 'false legacy type defaults to normal');
    equal(headAt(current, 200).animSuffix, '-alt', 'true legacy type retains alt animation');
    equal(headAt(current, 300).noteType, '', 'invalid numeric type defaults to normal');
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

  static function testOverlappingCharacterEvents():Void
  {
    var current = state();
    var hero = new objects.Character.Boyfriend();
    hero.noteskin = 'hero-skin';
    current.boyfriendMap.set('hero', hero);
    var rival = new objects.Character();
    rival.noteskin = 'rival-skin';
    current.dadMap.set('rival', rival);
    PlayState.SONG = song([section([
      note(50, 0, 0, ''),
      note(300, 0, 0, ''),
      note(301, 4, 0, '')
    ])], [
      // Events may be supplied out of order by the chart and events file.
      event(200, 'Change Character', '1', 'rival'),
      event(100, 'Change Character', '0', 'hero')
    ]);
    PlayStateChartLoader.generateSong(current);
    equal(headAt(current, 50).noteskin, '', 'initial skin precedes both changes');
    equal(headAt(current, 300).noteskin, 'hero-skin', 'all prior changes apply before the next player note');
    equal(headAt(current, 301).noteskin, 'rival-skin', 'numeric opponent change is applied too');
    check(backend.Paths.noteSkinFramesMap.exists('noteskins/hero-skin'), 'character atlas warmed under the full noteskin path');
    equal(current.charChangeTimes.length, 0, 'all reached changes are consumed');
  }

  static function testUnsortedNotesAndDefaultSkin():Void
  {
    final current = state();
    current.bfNoteskin = 'original';
    current.dadNoteskin = 'initial-opponent';
    final hero = new objects.Character.Boyfriend();
    hero.noteskin = 'hero';
    final defaultBf = new objects.Character.Boyfriend();
    defaultBf.noteskin = null;
    final rival = new objects.Character();
    rival.noteskin = 'rival';
    final lastRival = new objects.Character();
    lastRival.noteskin = 'last-rival';
    current.boyfriendMap.set('hero', hero);
    current.boyfriendMap.set('bf', defaultBf);
    current.dadMap.set('rival', rival);
    current.dadMap.set('last-rival', lastRival);
    PlayState.SONG = song([section([
      note(300, 0, 0, ''), note(50, 0, 0, ''), note(100, 0, 0, ''), note(200, 0, 0, ''),
      note(350, 4, 0, ''), note(51, 4, 0, ''), note(250, 4, 0, '')
    ])], [
      event(200, 'Change Character', '0', 'bf'),
      event(100, 'Change Character', '0', 'hero'),
      event(250, 'Change Character', '1', 'rival'),
      event(250, 'Change Character', '1', 'last-rival')
    ]);
    PlayStateChartLoader.generateSong(current);
    equal(headAt(current, 50).noteskin, 'original', 'earlier out-of-order note uses initial player skin');
    equal(headAt(current, 100).noteskin, 'hero', 'event applies at its timestamp');
    equal(headAt(current, 200).noteskin, '', 'a null character skin returns to the default');
    equal(headAt(current, 300).noteskin, '', 'default persists after the return');
    equal(headAt(current, 51).noteskin, 'initial-opponent', 'earlier opponent note keeps its initial skin');
    equal(headAt(current, 250).noteskin, 'last-rival', 'last same-time event wins');
    equal(headAt(current, 350).noteskin, 'last-rival', 'last rival skin persists');
  }

  static function testCharacterEventsWithNoteOffset():Void
  {
    for (offset in [-200.0, 200.0])
    {
      final current = state();
      current.bfNoteskin = 'original';
      final hero = new objects.Character.Boyfriend();
      hero.noteskin = 'hero';
      current.boyfriendMap.set('hero', hero);
      backend.ClientPrefs.noteOffset = offset;
      PlayState.SONG = song([section([
        note(99, 0, 0, ''), note(100, 1, 0, ''), note(101, 2, 0, '')
      ])], [event(100, 'Change Character', '0', 'hero')]);
      PlayStateChartLoader.generateSong(current);
      equal(headAt(current, 99).noteskin, 'original', 'offset $offset: note before character event');
      equal(headAt(current, 100).noteskin, 'hero', 'offset $offset: event and note share the same timestamp');
      equal(headAt(current, 101).noteskin, 'hero', 'offset $offset: note after character event');
      equal(current.charChangeTimes.length, 0, 'offset $offset: reached character events are consumed');
    }
    backend.ClientPrefs.noteOffset = 0;
  }

  static function testMissingCharacterSkinAssets():Void
  {
    final current = state();
    PlayState.isPixelStage = true;
    current.bfNoteskin = 'regular-only';
    current.dadNoteskin = 'no-ends';
    backend.Paths.missingSkinFiles.set('images/pixelUI/noteskins/regular-only.png', true);
    backend.Paths.missingSkinFiles.set('images/pixelUI/noteskins/no-endsENDS.png', true);
    final pixelHero = new objects.Character.Boyfriend();
    pixelHero.noteskin = 'pixel-good';
    current.boyfriendMap.set('hero', pixelHero);
    PlayState.SONG = song([section([
      note(50, 0, 0, ''), note(60, 4, 0, ''), note(200, 0, 0, '')
    ])], [event(100, 'Change Character', '0', 'hero')]);
    PlayStateChartLoader.generateSong(current);
    equal(headAt(current, 50).noteskin, '', 'regular-only character skin falls back on pixel stages');
    equal(headAt(current, 60).noteskin, '', 'pixel skin without sustain sheet falls back');
    equal(headAt(current, 200).noteskin, 'pixel-good', 'complete pixel character skin remains available');
    equal(current.bfNoteskin, '', 'initial receptor skin uses the same pixel fallback');
    check(!backend.Paths.noteSkinFramesMap.exists('noteskins/pixel-good'), 'pixel sheets are not warmed as Sparrow atlases');

    final normal = state();
    normal.bfNoteskin = 'no-atlas';
    backend.Paths.missingSkinFiles.set('images/noteskins/no-atlas.xml', true);
    PlayState.SONG = song([section([note(0, 0, 0, '')])]);
    PlayStateChartLoader.generateSong(normal);
    equal(headAt(normal, 0).noteskin, '', 'normal character skin without its atlas descriptor falls back');
  }

  static function testPackagedExternalEvents():Void
  {
    // The asset id is a registered OpenFL path, not the short song/events key
    // and not necessarily a loose file on disk (e.g. Android packaged assets).
    final current = state();
    final hero = new objects.Character.Boyfriend();
    hero.noteskin = 'external-hero';
    current.boyfriendMap.set('hero', hero);
    final eventsPath = backend.Paths.json('test-song/events-normal');
    OpenFlAssets.existing.set(eventsPath, true);
    data.Song.lastLoaded = null;
    data.Song.fixture = song([], [event(100, 'Change Character', 'bf', 'hero')]);
    PlayState.SONG = song([section([note(100, 0, 0, '')])]);
    PlayStateChartLoader.generateSong(current);
    equal(data.Song.lastLoaded, 'test-song/events-normal', 'packaged external event chart loaded');
    equal(current.eventNotes.length, 1, 'external event enters gameplay timeline');
    equal(headAt(current, 100).noteskin, 'external-hero', 'external character event affects note skin');
    OpenFlAssets.existing.clear();
    data.Song.fixture = null;
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
