"""Regression guards for the color-key transparency smoke-test mod."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class TransparencyDemoTest(unittest.TestCase):
    def test_camera_uses_numeric_color_matching_native_key(self):
        script = (ROOT / "mods/transparency-test/data/transparency-test/transparency-test.lua").read_text()
        self.assertIn("local transparencyKey = '010101'", script)
        self.assertIn("setProperty('camGame.bgColor', getColorFromHex(transparencyKey))", script)
        self.assertIn("setWindowTransparencyColor(transparencyKey)", script)
        self.assertIn("if not setWindowTransparent(true) then", script)
        self.assertIn("setWindowTransparent(false)", script)


if __name__ == "__main__":
    unittest.main()
