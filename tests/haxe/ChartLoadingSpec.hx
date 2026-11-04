import data.Song;

/** Dependency-free tests for the production JSON chart normalizer.
 *
 * Run with tests/haxe/run-chart-loading.sh. The runner copies source/data/Song.hx
 * into an isolated classpath so these assertions exercise the real loader code,
 * not a reimplementation.
 */
@:access(data.Song)
class ChartLoadingSpec
{
  static function equal<T>(actual:T, expected:T, label:String):Void
  {
    if (actual != expected) throw '$label: expected $expected, got $actual';
  }

  static function check(ok:Bool, label:String):Void
  {
    if (!ok) throw label;
  }

  static function main():Void
  {
    testParseWrappedChart();
    testParsePsychV1Chart();
    testParseBom();
    testLegacyEventExtraction();
    testLegacyEventExtractionLarge();
    testPsychV1Conversion();
    trace('ChartLoadingSpec passed');
  }

  static function testParseWrappedChart():Void
  {
    var parsed:Dynamic = Song.parseJSON('{"song":{"song":"wrapped","notes":[],"events":[]}}');
    equal(parsed.song, 'wrapped', 'wrapped chart song name');
    equal(Song.psychV1Chart, false, 'wrapped chart is not psych v1');
  }

  static function testParsePsychV1Chart():Void
  {
    var parsed:Dynamic = Song.parseJSON('{"format":"psych_v1","song":"legacy","notes":[],"events":null}');
    equal(parsed.song, 'legacy', 'psych v1 chart song name');
    equal(Song.psychV1Chart, true, 'psych v1 flag');
    equal(Reflect.hasField(parsed, 'format'), false, 'format field removed');
  }

  static function testParseBom():Void
  {
    var parsed:Dynamic = Song.parseJSON('\uFEFF{"song":{"song":"bom","notes":[],"events":[]}}');
    equal(parsed.song, 'bom', 'UTF-8 BOM is stripped before parsing');
  }

  static function testLegacyEventExtraction():Void
  {
    Song.psychV1Chart = false;
    var keepA:Array<Dynamic> = [0, 0, 0, ''];
    var keepB:Array<Dynamic> = [250, 3, 125, 'Alt Animation'];
    var keepC:Array<Dynamic> = [500, 4, 0, 'GF Sing'];
    var songJson:Dynamic = {
      notes: [
        {
          sectionNotes: [
            ([-10, -1, 'Hey!', '0', ''] : Array<Dynamic>),
            keepA,
            ([100, -2, 'Change Character', 'dad', 'dad-pixel'] : Array<Dynamic>),
            keepB,
            ([300, -1, 'Set Property', 'camZooming', 'true'] : Array<Dynamic>),
            keepC
          ]
        },
        {
          sectionNotes: [
            ([700, -3, 'Change Note Multiplier', '2', ''] : Array<Dynamic>),
            ([800, 1, 0, ''] : Array<Dynamic>)
          ]
        }
      ],
      events: null
    };

    Song.onLoadJson(songJson);

    equal(songJson.events.length, 4, 'legacy event count');
    equal(songJson.events[0][0], -10, 'first legacy event time');
    equal(songJson.events[0][1][0][0], 'Hey!', 'first legacy event name');
    equal(songJson.events[1][0], 100, 'second legacy event time');
    equal(songJson.events[1][1][0][1], 'dad', 'second legacy event value1');
    equal(songJson.events[2][0], 300, 'third legacy event time');
    equal(songJson.events[3][0], 700, 'fourth legacy event time');

    var first:Array<Dynamic> = songJson.notes[0].sectionNotes;
    equal(first.length, 3, 'first section keeps only playable notes');
    check(first[0] == keepA, 'first kept note identity preserved');
    check(first[1] == keepB, 'second kept note identity preserved');
    check(first[2] == keepC, 'third kept note identity preserved');

    var second:Array<Dynamic> = songJson.notes[1].sectionNotes;
    equal(second.length, 1, 'second section keeps only playable notes');
    equal(second[0][0], 800, 'second section kept note time');
  }

  static function testLegacyEventExtractionLarge():Void
  {
    Song.psychV1Chart = false;
    var notes:Array<Dynamic> = [];
    var expectedPlayable:Int = 0;
    var expectedEvents:Int = 0;
    for (i in 0...20000)
    {
      if (i % 3 == 0)
      {
        notes.push(([i, -1, 'Event $i', 'v1', 'v2'] : Array<Dynamic>));
        expectedEvents++;
      }
      else
      {
        notes.push(([i, i % 8, 0, ''] : Array<Dynamic>));
        expectedPlayable++;
      }
    }
    var songJson:Dynamic = {notes: [{sectionNotes: notes}], events: null};

    final start = haxe.Timer.stamp();
    Song.onLoadJson(songJson);
    final elapsedMs = (haxe.Timer.stamp() - start) * 1000;

    equal(songJson.events.length, expectedEvents, 'large legacy event count');
    equal(songJson.notes[0].sectionNotes.length, expectedPlayable, 'large legacy playable count');
    equal(songJson.events[0][0], 0, 'large legacy first event time');
    equal(songJson.events[expectedEvents - 1][0], 19998, 'large legacy last event time');
    equal(songJson.notes[0].sectionNotes[0][0], 1, 'large legacy first playable time');
    trace('Legacy event compaction (20000 notes): ${elapsedMs} ms');
  }

  static function testPsychV1Conversion():Void
  {
    Song.psychV1Chart = true;
    backend.Conductor.bpm = 120;
    var songJson:Dynamic = {
      notes: [
        {
          changeBPM: false,
          bpm: 120,
          sectionBeats: null,
          lengthInSteps: 16,
          mustHitSection: true,
          altAnim: false,
          sectionNotes: [
            ([0, 1, 250, 1] : Array<Dynamic>),
            ([100, 5, 0, 'Hurt Note'] : Array<Dynamic>)
          ]
        }
      ],
      events: []
    };

    Song.onLoadJson(songJson);

    var section:Dynamic = songJson.notes[0];
    equal(section.sectionBeats, 4, 'psych v1 missing sectionBeats fallback');
    equal(Reflect.hasField(section, 'lengthInSteps'), false, 'psych v1 lengthInSteps removed');
    equal(section.sectionNotes[0][1], 1, 'psych v1 player lane remap');
    equal(section.sectionNotes[0][2], 187.5, 'psych v1 sustain conversion');
    equal(section.sectionNotes[0][3], 'Alt Animation', 'psych v1 numeric note type');
    equal(section.sectionNotes[1][1], 5, 'psych v1 opponent lane remap');
    Song.psychV1Chart = false;
  }
}
