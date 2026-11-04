"""Guards for the font driven alphabet renderer and its toggle.

The alphabet used to be drawn only from the `images/alphabet` spritesheet. It can now be
drawn glyph by glyph from a real font (bundled VCR OSD Mono or the added Inconsolata), and
the player picks which one in Options -> Visuals and UI. The renderer itself needs OpenFL,
so the runtime rules are covered by tests/haxe/run-alphabet-font.sh; this file pins the
wiring around it: assets, license, preferences, options entry and the spritesheet fallback.

Run:  python3 -m unittest discover -s tests -p 'test_*.py' -v
  or: python3 tests/test_alphabet_font.py
"""
from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

TRUETYPE_MAGIC = (b"\x00\x01\x00\x00", b"true", b"ttcf", b"OTTO")


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8", errors="ignore")


class AlphabetFontAssetsTest(unittest.TestCase):
    def test_bundled_fonts_exist_and_are_truetype(self):
        fonts = ROOT / "assets/fonts"
        self.assertTrue((fonts / "vcr.ttf").is_file(), "built in VCR font must stay bundled")
        for name in ("inconsolata.ttf", "inconsolata-bold.ttf"):
            path = fonts / name
            self.assertTrue(path.is_file(), f"{name} must be bundled")
            data = path.read_bytes()
            self.assertGreater(len(data), 20_000, f"{name} looks truncated")
            self.assertIn(data[:4], TRUETYPE_MAGIC, f"{name} is not a TrueType/OpenType font")

    def test_inconsolata_ships_its_license(self):
        license_text = (ROOT / "assets/fonts/LICENSE-inconsolata.txt").read_text(encoding="utf-8", errors="ignore")
        self.assertIn("SIL OPEN FONT LICENSE", license_text.upper())
        self.assertIn("Inconsolata Project Authors", license_text)

    def test_fonts_are_embedded_by_the_build(self):
        project = read("project.hxp")
        self.assertIn('addAssetPath("assets/fonts"', project, "assets/fonts must keep being embedded")


class AlphabetFontPreferencesTest(unittest.TestCase):
    def test_toggle_defaults_to_fonts(self):
        prefs = read("source/backend/ClientPrefs.hx")
        self.assertIn("public static var alphabetStyle:String = AlphabetFont.DEFAULT_STYLE;", prefs)
        self.assertIn("public static var alphabetFont:String = AlphabetFont.DEFAULT_FONT;", prefs)
        self.assertIn("import objects.AlphabetFont;", prefs)

    def test_model_defaults(self):
        model = read("source/objects/AlphabetFont.hx")
        self.assertIn("public static final STYLE_FONT:String = 'Font';", model)
        self.assertIn("public static final STYLE_IMAGE:String = 'Image';", model)
        self.assertIn("public static final DEFAULT_STYLE:String = STYLE_FONT;", model)
        self.assertIn("public static final DEFAULT_FONT:String = 'VCR OSD Mono';", model)
        self.assertIn("regular: 'vcr.ttf'", model)
        self.assertIn("regular: 'inconsolata.ttf'", model)
        self.assertIn("bold: 'inconsolata-bold.ttf'", model)
        # Sizes stay calibrated to the spritesheet caps (~53px regular, ~68px bold).
        self.assertIn("capHeight: 0.732", model)
        self.assertIn("capHeight: 0.623", model)
        self.assertNotRegex(model, r"^import (flixel|openfl)\.", "model must stay renderer free")

    def test_registered_fonts_point_at_real_files(self):
        model = read("source/objects/AlphabetFont.hx")
        files = re.findall(r"(?:regular|bold): '([^']+)'", model)
        self.assertTrue(files, "no font files registered")
        for name in files:
            self.assertTrue((ROOT / "assets/fonts" / name).is_file(), f"assets/fonts/{name} is registered but missing")


class AlphabetRendererTest(unittest.TestCase):
    def test_renderer_loads_fonts_through_paths(self):
        renderer = read("source/objects/AlphabetFontRenderer.hx")
        self.assertIn("Paths.font(file)", renderer, "mods must be able to override the font file")
        self.assertIn("Assets.exists(path, AssetType.FONT)", renderer)
        self.assertIn("Assets.getFont(path)", renderer)
        self.assertIn("field.embedFonts = true;", renderer)
        self.assertIn("FlxG.bitmap.add(bitmap, false, key)", renderer, "glyphs must be cached, not redrawn")
        # Glyphs outlive the letters using them, and clearing never destroys one in use.
        self.assertIn("graphic.persist = true;", renderer)
        self.assertIn("if (graphic.useCount <= 0) FlxG.bitmap.remove(graphic);", renderer)
        self.assertIn("else graphic.persist = false;", renderer)
        # An unloadable font must report failure instead of drawing nothing.
        self.assertIn("if (name == null) return false;", renderer)
        self.assertIn("if (!prepare(def, bold)) return null;", renderer)
        self.assertIn("if (bold && def.bold != def.regular) return familyName(def, false);", renderer)

    def test_alphabet_keeps_both_renderers(self):
        alphabet = read("source/objects/Alphabet.hx")
        self.assertIn("if (AlphabetFont.currentUsesImages()) createImageLetters(newText);", alphabet)
        self.assertIn("else createFontLetters(newText);", alphabet)
        self.assertIn("private function createImageLetters(newText:String)", alphabet)
        self.assertIn("private function createFontLetters(newText:String)", alphabet)
        self.assertIn("private function setupImageGlyph(bold:Bool)", alphabet)
        self.assertIn("private function setupFontGlyph(bold:Bool)", alphabet)
        # A font that fails to load must not leave the menus blank.
        self.assertIn("if (graphic == null)\n\t\t{\n\t\t\tsetupImageGlyph(bold);", alphabet)
        # Widescreen auto wrap still applies to the font renderer.
        self.assertIn("ScreenLayout.BASE_WIDTH * 0.65", alphabet)
        self.assertIn("public static function reloadAll()", alphabet)
        self.assertIn("liveGroups.remove(this);", alphabet)

    def test_scripts_can_read_the_model(self):
        for path in ("source/psychlua/HScript.hx", "source/psychlua/HaxeScript.hx"):
            source = read(path)
            self.assertIn("import objects.AlphabetFont;", source)
            self.assertIn("interp.variables.set('AlphabetFont', AlphabetFont);", source)


class AlphabetOptionsTest(unittest.TestCase):
    def test_both_options_are_registered(self):
        visuals = read("source/options/VisualsUISubState.hx")
        self.assertIn("'alphabetStyle',", visuals)
        self.assertIn("AlphabetFont.styles());", visuals)
        self.assertIn("'alphabetFont',", visuals)
        self.assertIn("AlphabetFont.fontNames());", visuals)
        self.assertIn("function onChangeAlphabet()", visuals)
        self.assertIn("AlphabetFontRenderer.clearCache();", visuals)
        self.assertIn("Alphabet.reloadAll();", visuals)

    def test_cache_is_cleared_after_the_reload(self):
        visuals = read("source/options/VisualsUISubState.hx")
        handler = visuals.split("function onChangeAlphabet()", 1)[1]
        self.assertLess(
            handler.index("Alphabet.reloadAll();"),
            handler.index("AlphabetFontRenderer.clearCache();"),
            "letters must switch before the old glyphs are dropped",
        )

    def test_precache_follows_the_style(self):
        play = read("source/play/PlayState.hx")
        self.assertIn("if (AlphabetFont.currentUsesImages()) Paths.image('alphabet');", play)
        self.assertIn("else AlphabetFontRenderer.warmUp();", play)


if __name__ == "__main__":
    unittest.main()
