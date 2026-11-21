package backend;

/**
 * The fixed chart behind the Device Benchmark (Options -> Optimization).
 *
 * The benchmark is a *test run*: a stage and a chart that never change, so two
 * runs on the same device are comparable and a submitted score means the same
 * thing on every report. Mods are not loaded for it (see `backend.Benchmark`),
 * which is why the chart lives in code instead of in `assets/data/` — nothing
 * in `mods/` can shadow or extend it, and content-stripped builds still get it.
 *
 * Timing: 120 BPM, 4/4, 30 sections of 16 steps. A step is 125 ms, a section
 * is 2000 ms and the song is exactly 60 000 ms long, matching the bundled
 * `assets/songs/phoenix-benchmark/Inst.ogg`.
 *
 * The generator is deterministic: a seeded LCG drives every lane choice, so
 * the chart is bit-identical on every device and every run. Do not "improve"
 * the randomness by accident — `tests/haxe/run-benchmark.sh` pins the shape.
 *
 * This module deliberately has no imports: it is compiled standalone by the
 * spec runner, so keep it free of Flixel, OpenFL and game types.
 */
class BenchmarkChart
{
  public static inline final SONG_NAME:String = 'phoenix-benchmark';
  public static inline final SONG_BPM:Float = 120.0;
  public static inline final SECTION_COUNT:Int = 30;
  public static inline final SECTION_BEATS:Float = 4.0;
  public static inline final STEPS_PER_SECTION:Int = 16;
  public static inline final STEP_MS:Float = (60.0 / SONG_BPM / 4.0) * 1000.0; // 125 ms
  public static inline final SECTION_MS:Float = STEPS_PER_SECTION * STEP_MS; // 2000 ms
  /** Wall clock of the song itself; the whole benchmark run is this plus the countdown. */
  public static inline final SONG_LENGTH_MS:Float = SECTION_COUNT * SECTION_MS; // 60000 ms
  /** Force-end the run if the instrumental never completes (e.g. stripped builds with no audio). */
  public static inline final WATCHDOG_MS:Float = SONG_LENGTH_MS + 6000.0;

  static inline final SEED:Int = 0x0BADC0DE;

  /** Note count sanity window used by the spec; also printed by the generator log. */
  public static inline final MIN_NOTES:Int = 300;
  public static inline final MAX_NOTES:Int = 640;

  /**
   * Builds the benchmark song as a plain object with the exact shape of
   * `data.Song.SwagSong` (every field `PlayState` reads is present), plus the
   * optional fields `Song.onLoadJson` normally fills in. Typed as `Dynamic`
   * so this module stays import-free; `backend.Benchmark.chart()` casts it.
   */
  public static function build():Dynamic
  {
    final seed:Array<Int> = [SEED];
    final sections:Array<Dynamic> = [];
    var noteCount:Int = 0;

    for (sectionIndex in 0...SECTION_COUNT)
    {
      final notes:Array<Array<Dynamic>> = [];
      final sectionStart:Float = sectionIndex * SECTION_MS;
      final phase:Int = sectionIndex % 8;
      final isFinale:Bool = sectionIndex == SECTION_COUNT - 1;

      function stepTime(step:Float):Float
        return sectionStart + step * STEP_MS;

      function addNote(step:Float, lane:Int, susSteps:Float = 0):Void
      {
        notes.push([stepTime(step), lane, susSteps * STEP_MS]);
      }

      function pickLane(lastLane:Int):Int
      {
        var lane:Int = nextRand(seed) % 4;
        if (lane == lastLane)
          lane = (lane + 1 + nextRand(seed) % 2) % 4;
        return lane;
      }

      if (isFinale)
      {
        // Verse 8ths for the first half, 16ths for the second, then a
        // full-stage chord to bow out.
        var lastPlayer:Int = -1;
        var lastOpponent:Int = -1;
        for (eighth in 0...4)
        {
          final step:Float = eighth * 2;
          lastPlayer = pickLane(lastPlayer);
          addNote(step, lastPlayer);
          lastOpponent = pickLane(lastOpponent);
          addNote(step, 4 + lastOpponent);
        }
        for (sixteenth in 0...16)
        {
          final step:Float = 8.0 + sixteenth * 0.5;
          if (step >= 15.0) break; // the chord takes over the last step
          lastPlayer = pickLane(lastPlayer);
          addNote(step, lastPlayer);
          lastOpponent = pickLane(lastOpponent);
          addNote(step, 4 + lastOpponent);
        }
        // Quad chord on the last step, both sides, simultaneous.
        for (lane in [0, 1, 2, 3])
        {
          addNote(15.0, lane);
          addNote(15.0, 4 + lane);
        }
      }
      else if (phase == 0 || phase == 1)
      {
        // Alternating verse sides: player, then opponent.
        final playerSide:Bool = phase == 0;
        var lastLane:Int = -1;
        for (eighth in 0...8)
        {
          final step:Float = eighth * 2;
          lastLane = pickLane(lastLane);
          final lane:Int = playerSide ? lastLane : 4 + lastLane;
          final sus:Float = (sectionIndex % 4 == 0 && eighth == 0) ? 4 : 0;
          addNote(step, lane, sus);
        }
      }
      else if (phase == 2)
      {
        // Opponent verse with a held note in the middle.
        var lastLane:Int = -1;
        for (eighth in 0...8)
        {
          final step:Float = eighth * 2;
          lastLane = pickLane(lastLane);
          final sus:Float = eighth == 4 ? 6 : 0;
          addNote(step, 4 + lastLane, sus);
        }
      }
      else if (phase == 3)
      {
        // Both sides straight 8ths.
        var lastPlayer:Int = -1;
        var lastOpponent:Int = -1;
        for (eighth in 0...8)
        {
          final step:Float = eighth * 2;
          lastPlayer = pickLane(lastPlayer);
          addNote(step, lastPlayer, sectionIndex % 4 == 3 && eighth == 0 ? 4 : 0);
          lastOpponent = pickLane(lastOpponent);
          addNote(step, 4 + lastOpponent);
        }
      }
      else if (phase == 4)
      {
        // Both sides plus two-note chords on the downbeats of steps 0 and 8.
        var lastPlayer:Int = -1;
        var lastOpponent:Int = -1;
        for (eighth in 0...8)
        {
          final step:Float = eighth * 2;
          lastPlayer = pickLane(lastPlayer);
          addNote(step, lastPlayer);
          lastOpponent = pickLane(lastOpponent);
          addNote(step, 4 + lastOpponent);
          if (step == 0 || step == 8)
          {
            addNote(step, (lastPlayer + 2) % 4);
            addNote(step, 4 + (lastOpponent + 2) % 4);
          }
        }
      }
      else if (phase == 5)
      {
        // Jacks: each side repeats one lane, a classic low-end stressor.
        final playerJack:Int = nextRand(seed) % 4;
        final opponentJack:Int = 4 + nextRand(seed) % 4;
        for (eighth in 0...8)
        {
          final step:Float = eighth * 2;
          addNote(step, playerJack);
          addNote(step, opponentJack);
        }
      }
      else // phase == 6 (and any residue): 8ths resolving into a 16th run
      {
        var lastPlayer:Int = -1;
        var lastOpponent:Int = -1;
        for (eighth in 0...6)
        {
          final step:Float = eighth * 2;
          lastPlayer = pickLane(lastPlayer);
          addNote(step, lastPlayer);
          lastOpponent = pickLane(lastOpponent);
          addNote(step, 4 + lastOpponent);
        }
        // 16th burst across the barline, both sides.
        for (sixteenth in 0...8)
        {
          final step:Float = 12.0 + sixteenth * 0.5;
          lastPlayer = pickLane(lastPlayer);
          addNote(step, lastPlayer);
          lastOpponent = pickLane(lastOpponent);
          addNote(step, 4 + lastOpponent);
        }
      }

      noteCount += notes.length;
      sections.push({
        sectionNotes: notes,
        sectionBeats: SECTION_BEATS,
        typeOfSection: 0,
        mustHitSection: phase % 2 == 1,
        gfSection: false,
        bpm: SONG_BPM,
        changeBPM: false,
        altAnim: false,
        crossFade: false,
        lengthInSteps: STEPS_PER_SECTION
      });
    }

    return {
      song: SONG_NAME,
      notes: sections,
      events: [],
      bpm: SONG_BPM,
      needsVoices: false,
      speed: 2,
      stage: 'stage',
      player1: 'bf',
      player2: 'dad',
      gfVersion: 'gf',
      // Song.onLoadJson normally fills these in; the benchmark bypasses the
      // JSON loader, so they are provided here to keep every reader happy.
      arrowSkin: '',
      splashSkin: 'noteSplashes',
      songCredit: '',
      songCreditBarPath: '',
      songCreditIcon: '',
      event7: '',
      event7Value: '',
      windowName: 'Device Benchmark',
      specialAudioName: '',
      specialEventsName: '',
      disableNoteRGB: false,
      gameOverChar: '',
      gameOverSound: '',
      gameOverLoop: '',
      gameOverEnd: ''
    };
  }

  /** Numerical Recipes LCG; the same constants the C runtimes use. */
  static function nextRand(state:Array<Int>):Int
  {
    state[0] = state[0] * 1664525 + 1013904223;
    final value:Int = state[0] >>> 1; // drop the sign bit
    return value;
  }
}
