import backend.Conductor;
import data.Section.SwagSection;
import data.Song.SwagSong;
import editors.charting.ChartingTiming;

/** BPM-aware chart section conversion tests. Run with tests/haxe/run-charting-timing.sh. */
class ChartingTimingSpec
{
  static function equal<T>(actual:T, expected:T, label:String):Void
  {
    if (actual != expected) throw '$label: expected $expected, got $actual';
  }

  static function near(actual:Float, expected:Float, label:String):Void
  {
    if (Math.abs(actual - expected) > 0.0001) throw '$label: expected $expected, got $actual';
  }

  static function main():Void
  {
    // Four chart sections with two tempo changes and a non-four-beat ending:
    // 120 BPM (2s), 240 BPM (1s + 1s), then 60 BPM (3s).
    var sections:Array<SwagSection> = [
      {sectionBeats: 4, changeBPM: false, bpm: 120},
      {sectionBeats: 4, changeBPM: true, bpm: 240},
      {sectionBeats: 4, changeBPM: false, bpm: 240},
      {sectionBeats: 3, changeBPM: true, bpm: 60}
    ];
    var song:SwagSong = {bpm: 120, notes: sections};
    Conductor.mapBPMChanges(song);
    var bpmChanges:Array<Dynamic> = cast Conductor.bpmChangeMap;

    equal(bpmChanges.length, 2, 'number of tempo-change map entries');
    equal(bpmChanges[0].stepTime, 16, 'first BPM change step');
    near(bpmChanges[0].songTime, 2000, 'first BPM change time');
    equal(bpmChanges[1].stepTime, 48, 'second BPM change step');
    near(bpmChanges[1].songTime, 4000, 'second BPM change time');

    for (boundary in [
      {section: 0, step: 0, time: 0.0},
      {section: 1, step: 16, time: 2000.0},
      {section: 2, step: 32, time: 3000.0},
      {section: 3, step: 48, time: 4000.0},
      {section: 4, step: 60, time: 7000.0}
    ])
    {
      equal(ChartingTiming.sectionStartStep(cast sections, boundary.section), boundary.step, 'section ${boundary.section} start step');
      near(ChartingTiming.sectionStartTime(cast sections, bpmChanges, 120, boundary.section), boundary.time, 'section ${boundary.section} start time');
    }

    near(ChartingTiming.sectionDuration(cast sections, bpmChanges, 120, 0), 2000, 'base-BPM section duration');
    near(ChartingTiming.sectionDuration(cast sections, bpmChanges, 120, 1), 1000, 'first changed-BPM section duration');
    near(ChartingTiming.sectionDuration(cast sections, bpmChanges, 120, 3), 3000, 'non-four-beat section duration');
    near(ChartingTiming.stepAtTime(bpmChanges, 120, 2500), 24, 'time to step after first BPM change');
    near(ChartingTiming.timeAtStep(bpmChanges, 120, 24), 2500, 'step to time after first BPM change');
    near(ChartingTiming.stepAtTime(bpmChanges, 120, 2010, 20), 15.84, 'note-offset step calculation at a BPM boundary');

    for (position in [
      {time: -1.0, section: 0},
      {time: 0.0, section: 0},
      {time: 1999.9, section: 0},
      {time: 2000.0, section: 1},
      {time: 2999.9, section: 1},
      {time: 3000.0, section: 2},
      {time: 3999.9, section: 2},
      {time: 4000.0, section: 3},
      {time: 6999.9, section: 3},
      {time: 7000.0, section: 3},
      {time: 9000.0, section: 3}
    ])
    {
      equal(ChartingTiming.sectionIndexAtTime(cast sections, bpmChanges, 120, position.time), position.section, 'time ${position.time} section');
    }

    for (position in [
      {step: 0.0, section: 0},
      {step: 15.99, section: 0},
      {step: 16.0, section: 1},
      {step: 31.99, section: 1},
      {step: 32.0, section: 2},
      {step: 48.0, section: 3},
      {step: 60.0, section: 3}
    ])
    {
      equal(ChartingTiming.sectionIndexAtStep(cast sections, position.step), position.section, 'step ${position.step} section');
    }

    // A BPM change on section zero overrides the chart-base tempo at step zero.
    var firstSectionBpm:Array<SwagSection> = [
      {sectionBeats: 4, changeBPM: true, bpm: 90},
      {sectionBeats: 3, changeBPM: false, bpm: 120}
    ];
    Conductor.mapBPMChanges({bpm: 120, notes: firstSectionBpm});
    var firstSectionChangesBpm:Array<Dynamic> = cast Conductor.bpmChangeMap;
    near(ChartingTiming.stepCrochetAtSection(cast firstSectionBpm, firstSectionChangesBpm, 120, 0), 166.6666666667, 'section-zero BPM override');

    // Missing/invalid section lengths keep the editor's four-beat fallback.
    equal(ChartingTiming.sectionStepCount({sectionBeats: null}), 16, 'missing section length');
    equal(ChartingTiming.sectionStepCount({sectionBeats: 0}), 16, 'zero section length');

    trace('ChartingTimingSpec passed');
  }
}
