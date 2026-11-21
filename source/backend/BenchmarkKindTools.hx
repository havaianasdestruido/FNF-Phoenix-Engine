package backend;

/**
 * Static helpers for `BenchmarkKind` — display names, descriptions and
 * stable ids used in logs, exports and the results screen.
 */
class BenchmarkKindTools
{
  public static function id(kind:BenchmarkKind):String
    return switch (kind)
    {
      case GAMEPLAY: 'phoenix-benchmark';
      case VISUAL: 'phoenix-benchmark-visual';
      case LOGIC: 'phoenix-benchmark-logic';
      case SYNTHETIC: 'phoenix-benchmark-synthetic';
      case SUITE: 'phoenix-benchmark-suite';
    };

  public static function displayName(kind:BenchmarkKind):String
    return switch (kind)
    {
      case GAMEPLAY: 'Gameplay Benchmark';
      case VISUAL: 'Visual Stress';
      case LOGIC: 'Logic Stress';
      case SYNTHETIC: 'Synthetic (CPU)';
      case SUITE: 'Full Suite';
    };

  public static function shortLabel(kind:BenchmarkKind):String
    return switch (kind)
    {
      case GAMEPLAY: 'GAMEPLAY';
      case VISUAL: 'VISUAL';
      case LOGIC: 'LOGIC';
      case SYNTHETIC: 'SYNTHETIC';
      case SUITE: 'SUITE';
    };

  public static function description(kind:BenchmarkKind):String
    return switch (kind)
    {
      case GAMEPLAY:
        'Balanced 60 s chart · stage + HUD + notes · FPS/1% low/worst';
      case VISUAL:
        'Visual stress · chords + sustains + splashes · render/draw-call bound';
      case LOGIC:
        'Logic stress · jacks + trills + 16th bursts · update/sort bound';
      case SYNTHETIC:
        'Synthetic · JSON/sort/path/math/alloc · no audio, ~2 s, CPU score';
      case SUITE:
        'Full suite · synthetic now, visual+logic charts next · combined report';
    };

  public static function windowTitle(kind:BenchmarkKind):String
    return switch (kind)
    {
      case GAMEPLAY: 'Device Benchmark';
      case VISUAL: 'Visual Benchmark';
      case LOGIC: 'Logic Benchmark';
      case SYNTHETIC: 'Synthetic Benchmark';
      case SUITE: 'Benchmark Suite';
    };

  public static function runHint(kind:BenchmarkKind):String
    return switch (kind)
    {
      case GAMEPLAY: 'A fixed ~60 s chart will play by itself.';
      case VISUAL: 'A visual-heavy ~60 s chart will play by itself.';
      case LOGIC: 'A logic-heavy ~60 s chart will play by itself.';
      case SYNTHETIC: 'A ~2 s CPU test will run right now (no song).';
      case SUITE: 'Synthetic now, then visual/logic charts to complete the profile.';
    };

  public static function isGameplayKind(kind:BenchmarkKind):Bool
    return switch (kind)
    {
      case GAMEPLAY | VISUAL | LOGIC: true;
      case SYNTHETIC | SUITE: false;
    };

  public static function allGameplayKinds():Array<BenchmarkKind>
    return [GAMEPLAY, VISUAL, LOGIC];

  public static function allKinds():Array<BenchmarkKind>
    return [GAMEPLAY, VISUAL, LOGIC, SYNTHETIC, SUITE];
}
