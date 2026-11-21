package backend;

/**
 * Which benchmark to run. The original Device Benchmark is `GAMEPLAY` — a
 * balanced 60 s chart that exercises the whole pipeline. The two new families
 * split the load so a bottleneck is easier to name:
 *
 * - `VISUAL` — high on-screen note density, chords and sustains on every
 *   8th, camera bops/zooms and splash spawning. Stresses the renderer,
 *   draw calls and VRAM bandwidth.
 * - `LOGIC` — jack bursts, trills and dense 16th runs on a tight lane.
 *   Stresses note spawning, sorting, hit-window math and the update loop.
 * - `SYNTHETIC` — pure-Haxe micro-benchmarks (JSON parse, sort, path ops,
 *   math, alloc/GC). No stage, no audio, no `PlayState`; finishes in ~2 s.
 * - `SUITE` — runs `SYNTHETIC` immediately and reports it, then invites the
 *   player to run `VISUAL` and `LOGIC` to complete a full device profile.
 *
 * `Benchmark.active` is true for *any* kind, so `RecoveryBoot.modsDisabled()`
 * still suppresses mod lookups for all of them.
 */
enum BenchmarkKind
{
  GAMEPLAY;
  VISUAL;
  LOGIC;
  SYNTHETIC;
  SUITE;
}
