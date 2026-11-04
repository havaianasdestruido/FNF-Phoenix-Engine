"""Wiring and accounting safeguards for the bounded hotspot report."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class HotspotTests(unittest.TestCase):
    def test_lifecycle_and_bounds(self):
        profiler = (ROOT / 'source/debug/profiler/HotspotProfiler.hx').read_text()
        frame = (ROOT / 'source/debug/FrameProfiler.hx').read_text()
        self.assertIn('MAX_NAMES:Int = 256', profiler)
        self.assertIn('count >= MAX_NAMES', profiler)
        self.assertIn('if (!inFrame || !debug.FrameProfiler.enabled)', profiler)
        self.assertIn('HotspotProfiler.setInFrame(true)', frame)
        self.assertIn('HotspotProfiler.setInFrame(false)', frame)
        self.assertGreaterEqual(frame.count('HotspotProfiler.reset()'), 2)
        self.assertIn('HotspotProfiler.report(sum.sessionDurationMs)', frame)
        self.assertIn('HotspotProfiler.report(summary.sessionDurationMs)', frame)
        self.assertIn('File.append(exported, false)', frame)

    def test_measurement_disclaimers(self):
        profiler = (ROOT / 'source/debug/profiler/HotspotProfiler.hx').read_text()
        self.assertIn('not CPU time', profiler)
        self.assertIn('nested calls overlap', profiler)
        self.assertIn('not retained RAM or allocations', profiler)
        self.assertIn('heap=N/A', profiler)
        self.assertIn('heap >= 0 && token.heap >= 0', profiler)

    def test_gameplay_hotspots(self):
        play = (ROOT / 'source/play/PlayState.hx').read_text()
        for label in ('Lua:', 'Python:', 'HScript:', 'spawn notes', 'note input',
                      'note update and sort', 'destroy notes', 'Flixel state/group update'):
            self.assertIn(label, play)
        self.assertIn('backend.MemoryLedger.formatDetailed',
                      (ROOT / 'source/debug/FrameProfiler.hx').read_text())


if __name__ == '__main__':
    unittest.main()
