"""Integration guards for the gameplay RAM graph and pause-menu preference."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class RamGraphIntegrationTest(unittest.TestCase):
    def test_default_and_persistence(self):
        prefs = (ROOT / 'source/backend/ClientPrefs.hx').read_text()
        pause = (ROOT / 'source/states/substates/PauseSubState.hx').read_text()
        self.assertIn('public static var showRamGraph:Bool = false;', prefs)
        self.assertIn("case 'Toggle RAM Graph':", pause)
        self.assertIn('PlayState.instance.ramGraph.setEnabled(ClientPrefs.showRamGraph);', pause)
        self.assertIn("Reflect.setField(FlxG.save.data, 'showRamGraph', ClientPrefs.showRamGraph);", pause)
        self.assertIn('FlxG.save.flush();', pause)
        self.assertIn("ramGraphMenuLabel()", pause)

    def test_gameplay_overlay_uses_fixed_camera_and_resize(self):
        play = (ROOT / 'source/play/PlayState.hx').read_text()
        graph = (ROOT / 'source/debug/RamGraph.hx').read_text()
        self.assertIn('ramGraph.cameras = [camOther];', play)
        self.assertIn('ramGraph.setEnabled(ClientPrefs.showRamGraph);', play)
        self.assertIn('ScreenLayout.contentLeft(FlxG.width)', graph)
        self.assertIn('GetTotalMemory.getCurrentRSS()', graph)
        self.assertIn('if (!enabled) return;', graph)
        self.assertIn('RamGraphHistory.interpolate(previousY, y, t)', graph)
        self.assertIn('graph.pixels.draw(drawing);', graph)


if __name__ == '__main__':
    unittest.main()
