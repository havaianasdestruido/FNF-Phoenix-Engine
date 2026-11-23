package backend;

import backend.BenchmarkKind;

/**
 * The fixed charts behind the Device Benchmark suite (Options -> Optimization).
 *
 * The original benchmark is a *test run*: a stage and a chart that never
 * change, so two runs on the same device are comparable and a submitted score
 * means the same thing on every report. Mods are not loaded for any of them
 * (see `backend.Benchmark`), which is why every chart lives in code instead
 * of in `assets/data/` — nothing in `mods/` can shadow or extend it, and
 * content-stripped builds still get it.
 *
 * Suite:
 *  - `phoenix-benchmark`         — the balanced 60 s original (120 BPM, 30
 *    bars, ~500 notes, verse + chords + jacks + finale).
 *  - `phoenix-benchmark-visual`  — visual stress: same 60 s, ~900 notes, a
 *    chord on every 8th, long sustains on every downbeat, constant both-sides
 *    and a splash-heavy finale to stress the renderer/draw calls.
 *  - `phoenix-benchmark-logic`   — logic stress: same 60 s, ~800 notes, jack
 *    bursts, alternating trills and 16th runs to stress spawning, sorting and
 *    the update loop.
 *
 * All three share `SONG_LENGTH_MS` and `WATCHDOG_MS` so they reuse the bundled
 * `assets/songs/phoenix-benchmark/Inst.ogg` (60 s, 44.1 kHz, 120 BPM). The
 * BPM field in the JSON is kept truthful so the editor and Conductor math
 * stay honest; only the note pattern changes.
 *
 * The generator is deterministic: a seeded LCG drives every lane choice, so
 * each chart is bit-identical on every device and every run. Do not
 * \"improve\" the randomness by accident — `tests/haxe/run-benchmark.sh` pins
 * the shape.
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

  /** Note count sanity window for the balanced original; also printed by the generator log. */
  public static inline final MIN_NOTES:Int = 300;
  public static inline final MAX_NOTES:Int = 640;

  // ---- Visual / Logic stress identifiers -----------------------------------

  public static inline final VISUAL_SONG_NAME:String = 'phoenix-benchmark-visual';
  public static inline final LOGIC_SONG_NAME:String = 'phoenix-benchmark-logic';
  public static inline final SYNTHETIC_SONG_NAME:String = 'phoenix-benchmark-synthetic';

  public static inline final VISUAL_MIN_NOTES:Int = 700;
  public static inline final VISUAL_MAX_NOTES:Int = 1200;
  public static inline final LOGIC_MIN_NOTES:Int = 650;
  public static inline final LOGIC_MAX_NOTES:Int = 1150;

  /**
   * Builds the benchmark song as a plain object with the exact shape of
   * `data.Song.SwagSong` (every field `PlayState` reads is present), plus the
   * optional fields `Song.onLoadJson` normally fills in. Typed as `Dynamic`
   * so this module stays import-free; `backend.Benchmark.chart()` casts it.
   *
   * This is the original balanced chart (Gameplay / `BenchmarkKind.GAMEPLAY`);
   * `buildVisual()`, `buildLogic()` and `buildKind()` are the suite variants.
   */
  public static function build():Dynamic
    return buildGameplay();

  /** The original balanced chart — see `build()`. */
  public static function buildGameplay():Dynamic
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

    return makeSong(SONG_NAME, 'Device Benchmark', sections);
  }

  /**
   * Visual stress chart: same 60 s, but every 8th carries chords + sustains
   * on the downbeats, both sides always, and a dense splash-heavy finale.
   * Reuses the 60 s `Inst.ogg` so no new audio asset is needed.
   */
  public static function buildVisual():Dynamic
  {
    final seed:Array<Int> = [SEED ^ 0x5A5A5A5A];
    final sections:Array<Dynamic> = [];

    for (sectionIndex in 0...SECTION_COUNT)
    {
      final notes:Array<Array<Dynamic>> = [];
      final sectionStart:Float = sectionIndex * SECTION_MS;
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
        // Finale: 4-note chords every 8th, both sides, long holds on the bar.
        for (eighth in 0...6)
        {
          final step:Float = eighth * 2;
          final sus:Float = eighth == 0 ? 6 : 0;
          for (lane in 0...4)
          {
            addNote(step, lane, sus);
            addNote(step, 4 + lane, sus);
          }
        }
        // 16th chord run into the final hit.
        var lastPlayer:Int = -1;
        var lastOpponent:Int = -1;
        for (sixteenth in 0...8)
        {
          final step:Float = 12.0 + sixteenth * 0.5;
          lastPlayer = pickLane(lastPlayer);
          addNote(step, lastPlayer);
          lastOpponent = pickLane(lastOpponent);
          addNote(step, 4 + lastOpponent);
          // Double every other 16th for render spikes.
          if (sixteenth % 2 == 0)
          {
            addNote(step, (lastPlayer + 2) % 4);
            addNote(step, 4 + (lastOpponent + 2) % 4);
          }
        }
        // Final slam: 8-way chord on the last step.
        for (lane in [0, 1, 2, 3])
        {
          addNote(15.0, lane, 0);
          addNote(15.0, 4 + lane, 0);
        }
      }
      else
      {
        final pattern:Int = sectionIndex % 4;
        if (pattern == 0)
        {
          // Sustains + chords: every downbeat is a chord + hold, every offbeat a single.
          var lastPlayer:Int = -1;
          var lastOpponent:Int = -1;
          for (eighth in 0...8)
          {
            final step:Float = eighth * 2;
            final isDownbeat:Bool = eighth % 2 == 0;
            lastPlayer = pickLane(lastPlayer);
            lastOpponent = pickLane(lastOpponent);
            // Base notes, both sides, always.
            addNote(step, lastPlayer, isDownbeat ? 4 : 0);
            addNote(step, 4 + lastOpponent, isDownbeat ? 4 : 0);
            if (isDownbeat)
            {
              addNote(step, (lastPlayer + 2) % 4, 0);
              addNote(step, 4 + (lastOpponent + 2) % 4, 0);
            }
          }
        }
        else if (pattern == 1)
        {
          // Full-stage 8ths: both sides, 16 notes per section before extras.
          var lastPlayer:Int = -1;
          var lastOpponent:Int = -1;
          for (eighth in 0...8)
          {
            final step:Float = eighth * 2;
            lastPlayer = pickLane(lastPlayer);
            addNote(step, lastPlayer);
            lastOpponent = pickLane(lastOpponent);
            addNote(step, 4 + lastOpponent);
          }
          // Extra chord layer on the backbeats.
          for (eighth in [2, 6])
          {
            final step:Float = eighth * 2;
            addNote(step, nextRand(seed) % 4);
            addNote(step, 4 + nextRand(seed) % 4);
          }
        }
        else if (pattern == 2)
        {
          // Rolling 16ths: visual smear, many sprites on screen at once.
          var lastPlayer:Int = -1;
          var lastOpponent:Int = -1;
          for (sixteenth in 0...24)
          {
            final step:Float = sixteenth * 0.5;
            if (step >= 15.5) break;
            lastPlayer = pickLane(lastPlayer);
            addNote(step, lastPlayer, sixteenth % 8 == 0 ? 2 : 0);
            lastOpponent = pickLane(lastOpponent);
            addNote(step, 4 + lastOpponent, sixteenth % 8 == 0 ? 2 : 0);
          }
        }
        else
        {
          // Chord ladder: 2-note chords climbing, then a hold.
          for (eighth in 0...8)
          {
            final step:Float = eighth * 2;
            final base:Int = (eighth * 2) % 4;
            addNote(step, base, eighth == 0 ? 5 : 0);
            addNote(step, (base + 1) % 4, 0);
            addNote(step, 4 + base, eighth == 0 ? 5 : 0);
            addNote(step, 4 + ((base + 1) % 4), 0);
          }
        }
      }

      sections.push({
        sectionNotes: notes,
        sectionBeats: SECTION_BEATS,
        typeOfSection: 0,
        mustHitSection: sectionIndex % 2 == 1,
        gfSection: false,
        bpm: SONG_BPM,
        changeBPM: false,
        altAnim: false,
        crossFade: sectionIndex % 3 == 0,
        lengthInSteps: STEPS_PER_SECTION
      });
    }

    return makeSong(VISUAL_SONG_NAME, 'Visual Benchmark', sections);
  }

  /**
   * Logic stress chart: same 60 s, jack bursts, trills and 16th runs that
   * hammer the note spawner, sorter and update loop without piling as many
   * simultaneous sprites as the visual chart.
   */
  public static function buildLogic():Dynamic
  {
    final seed:Array<Int> = [SEED ^ 0xA55AA55A];
    final sections:Array<Dynamic> = [];

    for (sectionIndex in 0...SECTION_COUNT)
    {
      final notes:Array<Array<Dynamic>> = [];
      final sectionStart:Float = sectionIndex * SECTION_MS;
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
        // Jack finale: same lane repeated, then a trill into a quad chord.
        final playerJack:Int = nextRand(seed) % 4;
        final opponentJack:Int = 4 + nextRand(seed) % 4;
        for (eighth in 0...4)
        {
          final step:Float = eighth * 2;
          addNote(step, playerJack);
          addNote(step, opponentJack);
        }
        // Trill: alternate two lanes as fast as possible.
        final pA:Int = nextRand(seed) % 4;
        final pB:Int = (pA + 1) % 4;
        final oA:Int = 4 + nextRand(seed) % 4;
        final oB:Int = 4 + ((oA - 4 + 1) % 4);
        for (sixteenth in 0...12)
        {
          final step:Float = 8.0 + sixteenth * 0.5;
          addNote(step, sixteenth % 2 == 0 ? pA : pB);
          addNote(step, sixteenth % 2 == 0 ? oA : oB);
        }
        // Resolve on a quad chord.
        for (lane in [0, 1, 2, 3])
        {
          addNote(15.0, lane);
          addNote(15.0, 4 + lane);
        }
      }
      else
      {
        final pattern:Int = sectionIndex % 5;
        if (pattern == 0)
        {
          // Pure jacks: one lane per side for the whole section.
          final playerJack:Int = nextRand(seed) % 4;
          final opponentJack:Int = 4 + nextRand(seed) % 4;
          for (eighth in 0...8)
          {
            final step:Float = eighth * 2;
            addNote(step, playerJack);
            addNote(step, opponentJack);
          }
          // Add a sustain anchor in the middle so hold logic is exercised.
          addNote(6.0, 4 + (opponentJack - 4 + 2) % 4, 4);
        }
        else if (pattern == 1)
        {
          // Trill section: alternate two lanes every 8th.
          final pA:Int = nextRand(seed) % 4;
          final pB:Int = (pA + 2) % 4;
          final oA:Int = 4 + nextRand(seed) % 4;
          final oB:Int = 4 + ((oA - 4 + 2) % 4);
          for (eighth in 0...8)
          {
            final step:Float = eighth * 2;
            addNote(step, eighth % 2 == 0 ? pA : pB);
            addNote(step, eighth % 2 == 0 ? oA : oB);
          }
        }
        else if (pattern == 2)
        {
          // 16th burst: 8ths then a 16th run across the barline.
          var lastPlayer:Int = -1;
          var lastOpponent:Int = -1;
          for (eighth in 0...5)
          {
            final step:Float = eighth * 2;
            lastPlayer = pickLane(lastPlayer);
            addNote(step, lastPlayer);
            lastOpponent = pickLane(lastOpponent);
            addNote(step, 4 + lastOpponent);
          }
          for (sixteenth in 0...10)
          {
            final step:Float = 10.0 + sixteenth * 0.5;
            lastPlayer = pickLane(lastPlayer);
            addNote(step, lastPlayer);
            lastOpponent = pickLane(lastOpponent);
            addNote(step, 4 + lastOpponent);
          }
        }
        else if (pattern == 3)
        {
          // Staggered jacks: opponent jacks, player runs.
          final opponentJack:Int = 4 + nextRand(seed) % 4;
          var lastPlayer:Int = -1;
          for (eighth in 0...8)
          {
            final step:Float = eighth * 2;
            lastPlayer = pickLane(lastPlayer);
            addNote(step, lastPlayer);
            addNote(step, opponentJack);
          }
        }
        else
        {
          // Dense 16ths, single side then both.
          var lastPlayer:Int = -1;
          var lastOpponent:Int = -1;
          for (sixteenth in 0...16)
          {
            final step:Float = sixteenth * 1.0;
            if (step >= 15.0) break;
            lastPlayer = pickLane(lastPlayer);
            addNote(step, lastPlayer);
            if (sixteenth >= 4)
            {
              lastOpponent = pickLane(lastOpponent);
              addNote(step, 4 + lastOpponent);
            }
          }
        }
      }

      sections.push({
        sectionNotes: notes,
        sectionBeats: SECTION_BEATS,
        typeOfSection: 0,
        mustHitSection: sectionIndex % 2 == 1,
        gfSection: false,
        bpm: SONG_BPM,
        changeBPM: false,
        altAnim: false,
        crossFade: false,
        lengthInSteps: STEPS_PER_SECTION
      });
    }

    return makeSong(LOGIC_SONG_NAME, 'Logic Benchmark', sections);
  }

  /**
   * Dispatch by `BenchmarkKind`. `GAMEPLAY` and `null` (legacy callers)
   * return the original balanced chart; `VISUAL`/`LOGIC` return the stress
   * variants. `SYNTHETIC`/`SUITE` have no PlayState chart — `null` is
   * returned so `Benchmark.chartKind()` can branch without building one.
   */
  public static function buildKind(kind:Null<BenchmarkKind>):Dynamic
  {
    if (kind == null) return buildGameplay();
    return switch (kind)
    {
      case GAMEPLAY: buildGameplay();
      case VISUAL: buildVisual();
      case LOGIC: buildLogic();
      case SYNTHETIC | SUITE: null;
    };
  }

  // ---- Shared song envelope ------------------------------------------------

  static function makeSong(songName:String, windowName:String, sections:Array<Dynamic>):Dynamic
  {
    return {
      song: songName,
      notes: sections,
      events: [],
      bpm: SONG_BPM,
      needsVoices: false,
      speed: 2,
      stage: 'stage',
      player1: 'bf',
      player2: 'dad',
      gfVersion: 'gf',
      arrowSkin: '',
      splashSkin: 'noteSplashes',
      songCredit: '',
      songCreditBarPath: '',
      songCreditIcon: '',
      event7: '',
      event7Value: '',
      windowName: windowName,
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
