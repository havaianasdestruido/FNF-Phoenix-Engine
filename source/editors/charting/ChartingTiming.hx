package editors.charting;

/**
 * Chart section conversions that work with Psych-style BPM maps.
 *
 * Sections are measured in steps (four steps per beat), while the conductor
 * map converts those steps to milliseconds. Keeping the two conversions here
 * makes chart navigation and the editor grid use the same boundaries as
 * playback.
 */
class ChartingTiming
{
  /** Returns the number of steps in a section, using the chart's 4-beat default. */
  public static function sectionStepCount(section:Dynamic):Int
  {
    if (section == null) return 16;

    var beats:Float = positiveNumber(Reflect.field(section, 'sectionBeats'), 4);
    return Math.round(beats * 4);
  }

  /** Returns the cumulative step at the beginning of a section. */
  public static function sectionStartStep(sections:Array<Dynamic>, sectionIndex:Int):Int
  {
    if (sections == null || sections.length == 0 || sectionIndex <= 0) return 0;

    var endIndex:Int = sectionIndex > sections.length ? sections.length : sectionIndex;
    var totalSteps:Int = 0;
    for (i in 0...endIndex)
      totalSteps += sectionStepCount(sections[i]);

    return totalSteps;
  }

  /** Finds the section containing a step. Times beyond the chart use its last section. */
  public static function sectionIndexAtStep(sections:Array<Dynamic>, step:Float):Int
  {
    if (sections == null || sections.length == 0 || Math.isNaN(step) || step <= 0) return 0;

    var sectionStart:Int = 0;
    for (i in 0...sections.length)
    {
      var sectionEnd:Int = sectionStart + sectionStepCount(sections[i]);
      if (step < sectionEnd || i == sections.length - 1) return i;
      sectionStart = sectionEnd;
    }

    return sections.length - 1;
  }

  /** Converts a step position to milliseconds using the active BPM-map entry. */
  public static function timeAtStep(bpmChanges:Array<Dynamic>, baseBpm:Float, step:Float):Float
  {
    var baseStepCrochet:Float = 15000 / positiveNumber(baseBpm, 100);
    var lastStepTime:Float = 0;
    var lastSongTime:Float = 0;
    var lastStepCrochet:Float = baseStepCrochet;

    if (bpmChanges != null)
    {
      for (change in bpmChanges)
      {
        if (change != null && number(Reflect.field(change, 'stepTime'), 0) <= step)
        {
          lastStepTime = number(Reflect.field(change, 'stepTime'), 0);
          lastSongTime = number(Reflect.field(change, 'songTime'), 0);
          lastStepCrochet = stepCrochet(change, baseStepCrochet);
        }
      }
    }

    return lastSongTime + (step - lastStepTime) * lastStepCrochet;
  }

  /** Converts milliseconds to steps using the active BPM-map entry. */
  public static function stepAtTime(bpmChanges:Array<Dynamic>, baseBpm:Float, time:Float, offset:Float = 0):Float
  {
    var baseStepCrochet:Float = 15000 / positiveNumber(baseBpm, 100);
    var lastStepTime:Float = 0;
    var lastSongTime:Float = 0;
    var lastStepCrochet:Float = baseStepCrochet;

    if (bpmChanges != null)
    {
      for (change in bpmChanges)
      {
        if (change != null && number(Reflect.field(change, 'songTime'), 0) <= time)
        {
          lastStepTime = number(Reflect.field(change, 'stepTime'), 0);
          lastSongTime = number(Reflect.field(change, 'songTime'), 0);
          lastStepCrochet = stepCrochet(change, baseStepCrochet);
        }
      }
    }

    return lastStepTime + (time - offset - lastSongTime) / lastStepCrochet;
  }

  /** Returns the start time of a section (or the chart end when sectionIndex == length). */
  public static function sectionStartTime(sections:Array<Dynamic>, bpmChanges:Array<Dynamic>, baseBpm:Float, sectionIndex:Int):Float
  {
    return timeAtStep(bpmChanges, baseBpm, sectionStartStep(sections, sectionIndex));
  }

  /** Returns the section containing a playback time, clamped to the available chart. */
  public static function sectionIndexAtTime(sections:Array<Dynamic>, bpmChanges:Array<Dynamic>, baseBpm:Float, time:Float):Int
  {
    return sectionIndexAtStep(sections, stepAtTime(bpmChanges, baseBpm, time));
  }

  /** Returns the duration of a section in milliseconds, including its own BPM change. */
  public static function sectionDuration(sections:Array<Dynamic>, bpmChanges:Array<Dynamic>, baseBpm:Float, sectionIndex:Int):Float
  {
    if (sections == null || sectionIndex < 0 || sectionIndex >= sections.length) return 0;

    return sectionStartTime(sections, bpmChanges, baseBpm, sectionIndex + 1)
      - sectionStartTime(sections, bpmChanges, baseBpm, sectionIndex);
  }

  /** Returns the step duration active at the beginning of a section. */
  public static function stepCrochetAtSection(sections:Array<Dynamic>, bpmChanges:Array<Dynamic>, baseBpm:Float, sectionIndex:Int):Float
  {
    var step:Float = sectionStartStep(sections, sectionIndex);
    var baseStepCrochet:Float = 15000 / positiveNumber(baseBpm, 100);
    var result:Float = baseStepCrochet;

    if (bpmChanges != null)
    {
      for (change in bpmChanges)
      {
        if (change != null && number(Reflect.field(change, 'stepTime'), 0) <= step)
          result = stepCrochet(change, baseStepCrochet);
      }
    }

    return result;
  }

  static function stepCrochet(change:Dynamic, fallback:Float):Float
  {
    var mappedStepCrochet:Float = positiveNumber(Reflect.field(change, 'stepCrochet'), 0);
    if (mappedStepCrochet > 0) return mappedStepCrochet;

    var bpm:Float = positiveNumber(Reflect.field(change, 'bpm'), 15000 / fallback);
    return 15000 / bpm;
  }

  static function positiveNumber(value:Dynamic, fallback:Float):Float
  {
    var parsed:Float = number(value, fallback);
    return parsed > 0 ? parsed : fallback;
  }

  static function number(value:Dynamic, fallback:Float):Float
  {
    if (value == null) return fallback;

    var parsed:Float = Std.parseFloat(Std.string(value));
    return Math.isNaN(parsed) ? fallback : parsed;
  }
}
