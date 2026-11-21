# Benchmarks — Phoenix Engine

The **Benchmark Suite** (Options → Optimization → **Benchmarks**) is a set of
deterministic, mod-free test runs that describe what a device can actually
do under a real chart, plus a synthetic CPU probe that finishes in ~2 s.

| Kind | What it measures | How long | Song | Notes |
| --- | --- | --- | --- | --- |
| **Gameplay** (`phoenix-benchmark`) | Balanced baseline — stage, HUD, notes, splashes, camera | ~60 s | `stage`, 120 BPM, 30 bars | ~500 |
| **Visual** (`phoenix-benchmark-visual`) | Render-heavy — chords + holds + splashes every 8th, both sides | ~60 s | `stage`, 120 BPM, 30 bars | ~900 |
| **Logic** (`phoenix-benchmark-logic`) | CPU-heavy — jacks, trills, 16th bursts | ~60 s | `stage`, 120 BPM, 30 bars | ~800 |
| **Synthetic** (`phoenix-benchmark-synthetic`) | CPU-only micro-benchmarks (no audio, no stage) | ~2 s | — | 9 samples |
| **Full Suite** (`phoenix-benchmark-suite`) | Synthetic now, then guidance for Visual/Logic to complete a profile | ~2 s + 2×60 s | — | combined |

All three gameplay kinds share the 60 s `Inst.ogg` so no new audio asset is
needed, and all are generated in code so nothing under `mods/` can shadow
them.

## Why a suite and not one number

One \"average FPS\" hides whether a device is **GPU-bound** (render/draw-call
heavy) or **CPU-bound** (spawn/sort/update heavy). The suite splits them:

- **Visual** hammers `renderTimeMs` and draw calls (chords on every 8th,
  long sustains on every downbeat, constant both-sides, splash-heavy finale).
- **Logic** hammers `updateTimeMs` and spawning (jack bursts, trills,
  dense 16ths).
- **Synthetic** ignores the GPU entirely and scores raw Haxe throughput:
  JSON parse, `BenchmarkChart.build()`, numeric sort (10k), path string ops,
  BPM math, string ops, alloc/GC, trig, map/hash.

The results screen's **Kind Analysis** block calls out which side dominated
(`render > 1.4× update` or `update > 1.4× render`) and cross-prints the last
synthetic score if one exists in the same boot, so a report can say
\"synthetic fast, visual slow ⇒ GPU\" without waiting for all three runs.

## Running

- **Options → Optimization → Benchmarks** opens the hub. Pick a row, press A.
- **Shortcuts** (same menu): Visual Benchmark, Logic Benchmark, Synthetic
  Benchmark, Full Benchmark Suite — each with its own confirm.
- **Device Benchmark** (the old single row) is kept for muscle memory and
  scripts; it just runs Gameplay.
- The pause menu drops **Restart Song** / **Change Difficulty** in all
  gameplay benchmarks — restarting would relaunch a different (or missing)
  dummy chart.
- **F3/F6 not needed.** The benchmark arms `FrameProfiler.reset()` the moment
  `Conductor.songPosition >= 0` (when the instrumental starts), not at state
  creation, so the loading screen and countdown are not counted. Leaving early
  discards the run; nothing is saved and no stats/achievements are touched.

## What the report contains

Gameplay/Visual/Logic reports:

```
Phoenix Engine - Device Benchmark (Visual Stress)
Run: fixed chart "phoenix-benchmark-visual" ...
Kind: VISUAL — Visual stress …

[FRAME PERFORMANCE]
Target FPS  | Total frames | Average FPS | 1% low | 0.1% low
Worst frame | P50/P95 frametime | 1% low (harmonic) | Dropped / Spikes
Avg update/render/ms | Max update/render/ms | Avg/max draw calls

[KIND ANALYSIS]
Visual stress leans on render time … / Logic stress leans on …

[SYNTHETIC (from this boot)]  ← if a synthetic run exists
Score … | … ms avg ( … )

[DEVICE]
OS / GPU / GPU vendor / driver / Graphics API / Audio / CPU / cores / RAM
Engine v… (commit …) / Window / target @ … FPS

[EXPORT]
Full FrameProfiler log: debug/log/benchmark_<kind>_<ts>.log
```

Synthetic/Suite reports:

```
Phoenix Engine - Synthetic Benchmark (non-visual)
[SYNTHETIC RESULTS]
Total time | Overall score (geometric mean)
Sample | Iters | Total ms | Avg ms | Score
… 9 rows …

[DEVICE (at synthetic run)]
…
```

The export path is the same `FrameProfiler.exportLog()` file the F6 overlay
uses; it contains the per-frame CSV and may include local paths — redact it
before posting publicly (`backend.LogUtils.redact`).

The one-line summary (`Benchmark.oneLineSummary()`) is `KIND | Avg … | 1% low … | worst …`
for gameplay and `Score … | … ms total | slowest …` for synthetic, so the
results screen's title line stays short.

## For modders and testers

- **Scripting:** `Benchmark.active` is true for any kind, so
  `RecoveryBoot.modsDisabled()` stays true and `PlayStateScripts` skips
  mod scripts, just like the original. `PlayState` forces `cpuControlled`
  (botplay) for all gameplay kinds.
- **Charts are code:** `backend.BenchmarkChart.buildGameplay()`,
  `buildVisual()`, `buildLogic()`, `buildKind(kind)` — no JSON files to
  shadow. All lanes are `0..7` (player `0..3`, opponent `4..7`), times are
  `step * 125 ms`, sections are 16 steps (2000 ms), 30 sections (60 s).
- **Determinism:** seeded LCG (`0x0BADC0DE` base, `^ 0x5A…` / `^ 0xA5…` for
  the variants) — two builds are byte-identical; `tests/haxe/run-benchmark.sh`
  pins this.
- **Wiring to check:** `OptionsState` → `BenchmarkMenuState` → `Benchmark`
  → `LoadingState` → `PlayState` → `PlayStatePlayback.endSong` →
  `Benchmark.finish()` → `BenchmarkResultsState`. Synthetic skips `PlayState`
  and lands directly on the results screen. `PlayState.destroy()` always
  calls `Benchmark.exitRun()` to restore `Mods.currentModDirectory` and
  invalidate the lookup cache.
- **Adding a new kind:** add it to `BenchmarkKind`, add a song-name/count
  constant and a `buildX()` to `BenchmarkChart`, wire it in `buildKind()` and
  `Benchmark.startKind()`, add a row to `OptimizationSubState` and to
  `BenchmarkMenuState.entries`, and give it a subtitle in
  `BenchmarkResultsState.subtitleFor()`.

## Spec

```bash
bash tests/haxe/run-benchmark.sh   # pins charts, kinds, synthetic, wiring
```

See `tests/haxe/BenchmarkSpec.hx` for the shape/timing/determinism invariants
and `source/backend/BenchmarkSynthetic.hx` for the micro-benchmark definitions.
