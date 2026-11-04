"""Runtime flags file packaging, defaults, and integration regression checks."""
from __future__ import annotations

import configparser
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class RuntimeFlagsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        parser = configparser.ConfigParser(interpolation=None)
        parser.read(ROOT / "flags.ini", encoding="utf-8")
        cls.flags = parser

    def test_runtime_config_declares_requested_categories(self):
        for section, keys in {
            "editors": {"enabled"},
            "transitions": {"enabled"},
            "warnings": {"beta"},
            "scripts": {"defaultstate"},
            "graphics": {"glslversion"},
            "urls": {"repository", "releases", "releasesapi", "issues"},
            "window": {"title", "icon"},
        }.items():
            with self.subTest(section=section):
                self.assertTrue(self.flags.has_section(section))
                self.assertTrue(keys.issubset({key.lower() for key in self.flags[section]}))

    def test_ini_is_packaged_as_a_loose_asset(self):
        project = read("project.hxp")
        self.assertIn('addAsset("flags.ini", "flags.ini", "default", false)', project)
        runtime = read("source/backend/RuntimeFlags.hx")
        self.assertIn('FILE_NAME:String = "flags.ini"', runtime)
        self.assertIn('FileSystem.exists(path)', runtime)

    def test_settings_are_used_by_the_runtime(self):
        self.assertIn('RuntimeFlags.load()', read("source/Main.hx"))
        state = read("source/backend/MusicBeatState.hx")
        self.assertIn('RuntimeFlags.getBool("editors.enabled", true)', state)
        self.assertIn('RuntimeFlags.getBool("transitions.enabled", true)', state)
        self.assertIn('RuntimeFlags.getBool("warnings.beta", true)', state)
        self.assertIn('RuntimeFlags.windowTitle(defaultTitle)', state)
        shader = read("source/backend/FlxFixedShader.hx")
        self.assertIn('RuntimeFlags.getString("graphics.glslVersion", "auto")', shader)
        self.assertIn('RuntimeFlags.getString("scripts.defaultState", "")', read("source/psychlua/StateScripts.hx"))

    def test_external_links_reject_non_http_schemes(self):
        runtime = read("source/backend/RuntimeFlags.hx")
        self.assertIn('StringTools.startsWith(value, "https://")', runtime)
        self.assertIn('StringTools.startsWith(value, "http://")', runtime)


if __name__ == "__main__":
    unittest.main()
