"""Static integration checks for BPM-aware chart-editor conversions."""
from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8", errors="ignore")


class TestChartingBpmIntegration(unittest.TestCase):
    def test_section_math_uses_conductor_map_and_per_section_steps(self):
        grid = read("source/editors/charting/ChartingUIGrid.hx")
        timing = read("source/editors/charting/ChartingTiming.hx")
        self.assertIn("ChartingTiming.sectionStartTime", grid)
        self.assertIn("ChartingTiming.sectionIndexAtTime", grid)
        self.assertIn("ChartingTiming.sectionDuration", grid)
        self.assertIn("sectionStepCount(sections[i])", timing)
        self.assertNotIn("Conductor.crochet * 4", grid)
        self.assertNotIn("Conductor.stepCrochet * 16", grid)

    def test_scrubbing_and_section_shortcuts_are_bpm_aware(self):
        state = read("source/editors/ChartingState.hx")
        sections = read("source/editors/charting/ChartingUISections.hx")
        self.assertIn("sectionIndexAtTime(FlxG.sound.music.time)", state)
        self.assertIn("changeSection(sectionIndex, false)", state)
        self.assertIn("state.sectionIndexAtTime(Conductor.songPosition)", sections)
        self.assertNotIn("Conductor.crochet * 4", state)
        self.assertNotIn("Conductor.stepCrochet * 16", sections)

    def test_timing_edits_and_undo_refresh_the_bpm_map(self):
        state = read("source/editors/ChartingState.hx")
        grid = read("source/editors/charting/ChartingUIGrid.hx")
        save_load = read("source/editors/charting/ChartingSaveLoad.hx")
        self.assertIn("public function rebuildBPMMap()", state)
        self.assertGreaterEqual(state.count("rebuildBPMMap();"), 4)
        self.assertIn("state.rebuildBPMMap();", grid)
        self.assertIn("state.rebuildBPMMap();", save_load)

    def test_chart_conversions_use_song_base_bpm_without_a_synthetic_map_event(self):
        timing = read("source/editors/charting/ChartingTiming.hx")
        state = read("source/editors/ChartingState.hx")
        conductor = read("source/backend/Conductor.hx")
        self.assertIn("15000 / positiveNumber(baseBpm, 100)", timing)
        self.assertIn("ChartingTiming.stepAtTime(cast Conductor.bpmChangeMap, _song.bpm", state)
        self.assertIn("override function updateCurStep()", state)
        self.assertIn("Conductor.songPosition, ClientPrefs.noteOffset", state)
        self.assertNotIn("bpmChangeMap.push({", conductor)

    def test_haxe_regression_spec_covers_multi_bpm_boundaries(self):
        spec = read("tests/haxe/ChartingTimingSpec.hx")
        self.assertIn("first changed-BPM section duration", spec)
        self.assertIn("sectionIndexAtTime", spec)
        self.assertIn("section-zero BPM override", spec)
        self.assertIn("run-charting-timing.sh", read(".github/workflows/checks.yml"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
