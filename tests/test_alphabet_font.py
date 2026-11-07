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


IMPORT_LINE = re.compile(r"^import\s+([\w.]+)(?:\s+as\s+(\w+))?", re.M)


def imported_names(source: str) -> set[str]:
    """Names an `import` list puts in scope, honouring `as` and skipping wildcards."""
    names = set()
    for path, alias in IMPORT_LINE.findall(source):
        names.add(alias if alias else path.rsplit(".", 1)[-1])
    return names


class AlphabetFontAssetsTest(unittest.TestCase):
    def test_bundled_fonts_exist_and_are_truetype(self):
        fonts = ROOT / "assets/fonts"
        self.assertTrue((fonts / "vcr.ttf").is_file(), "built in VCR font must stay bundled")
        for name in ("inconsolata.ttf", "inconsolata-bold.ttf", "tf2build.ttf"):
            path = fonts / name
            self.assertTrue(path.is_file(), f"{name} must be bundled")
            data = path.read_bytes()
            self.assertGreater(len(data), 20_000, f"{name} looks truncated")
            self.assertIn(data[:4], TRUETYPE_MAGIC, f"{name} is not a TrueType/OpenType font")

    def test_inconsolata_ships_its_license(self):
        license_text = (ROOT / "assets/fonts/LICENSE-inconsolata.txt").read_text(encoding="utf-8", errors="ignore")
        self.assertIn("SIL OPEN FONT LICENSE", license_text.upper())
        self.assertIn("Inconsolata Project Authors", license_text)

    def test_tf2_build_ships_its_usage_notice(self):
        notice = read("assets/fonts/LICENSE-tf2build.txt")
        self.assertIn("non-commercial", notice)
        self.assertIn("Andrea Wicklund", notice)
        self.assertIn("Jakadak", notice)

    def test_fonts_are_embedded_by_the_build(self):
        project = read("project.hxp")
        self.assertIn('addAssetPath("assets/fonts"', project, "assets/fonts must keep being embedded")


class AlphabetFontPreferencesTest(unittest.TestCase):
    def test_toggle_defaults_to_fonts(self):
        prefs = read("source/backend/ClientPrefs.hx")
        self.assertIn("public static var alphabetStyle:String = AlphabetFont.DEFAULT_STYLE;", prefs)
        self.assertIn("public static var alphabetFont:String = AlphabetFont.DEFAULT_FONT;", prefs)
        self.assertIn("public static var alphabetAntialiasing:Bool = true;", prefs)
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
        self.assertIn("FlxG.bitmap.add(bitmap, false, key)", renderer, "atlas pages must be cached, not redrawn")
        # Atlas pages outlive the letters using them, and clearing never destroys one in use.
        self.assertIn("graphic.persist = true;", renderer)
        self.assertIn("if (graphic.useCount <= 0) FlxG.bitmap.remove(graphic);", renderer)
        self.assertIn("else graphic.persist = false;", renderer)
        # An unloadable font must report failure instead of drawing nothing.
        self.assertIn("if (name == null) return false;", renderer)
        self.assertIn("if (!prepare(def, bold)) return null;", renderer)
        self.assertIn("if (bold && def.bold != def.regular) return familyName(def, false);", renderer)

    def test_font_glyphs_share_atlas_pages(self):
        """A menu must not need one GPU texture (and draw call) per character."""
        renderer = read("source/objects/AlphabetFontRenderer.hx")
        alphabet = read("source/objects/Alphabet.hx")
        self.assertIn("static var glyphs:Map<String, FlxFrame>", renderer)
        self.assertIn("static var pages:Array<AlphabetAtlasPage>", renderer)
        self.assertIn("frames: new FlxAtlasFrames(graphic)", renderer)
        self.assertIn("page.frames.addSpriteSheetFrame", renderer)
        self.assertIn("page.graphic.bitmap.draw", renderer)
        self.assertIn("AlphabetFont.metricsKey(def, bold, 'active-page')", renderer)
        self.assertIn("if (page.x + width > ATLAS_SIZE)", renderer, "full rows must wrap")
        self.assertIn("if (page.y + boxH > ATLAS_SIZE)", renderer, "full pages must roll over")
        self.assertIn("frames = FlxImageFrame.fromFrame(glyphFrame);", alphabet)
        self.assertNotIn("new BitmapData(width, boxH", renderer, "do not restore one bitmap per glyph")
        self.assertNotIn("loadGraphic(graphic);", alphabet, "loading the whole atlas would draw every glyph at once")
        self.assertIn(
            "FlxG.bitmap.getUniqueKey",
            renderer,
            "a fresh page must not overwrite a live page left by an earlier cache generation",
        )

    def test_alphabet_keeps_both_renderers(self):
        alphabet = read("source/objects/Alphabet.hx")
        self.assertIn("if (AlphabetFont.currentUsesImages()) createImageLetters(newText);", alphabet)
        self.assertIn("else createFontLetters(newText);", alphabet)
        self.assertIn("private function createImageLetters(newText:String)", alphabet)
        self.assertIn("private function createFontLetters(newText:String)", alphabet)
        self.assertIn("private function setupImageGlyph(bold:Bool)", alphabet)
        self.assertIn("private function setupFontGlyph(bold:Bool)", alphabet)
        self.assertIn("antialiasing = ClientPrefs.alphabetAntialiasing;", alphabet)
        self.assertIn("ClientPrefs.globalAntialiasing && ClientPrefs.alphabetAntialiasing", alphabet)
        # A font that fails to load must not leave the menus blank. A recycled letter must
        # also release its font frame collection and load the spritesheet animations.
        self.assertIn("if (graphic == null)\n\t\t{\n\t\t\tsetupImageGlyph(bold);", alphabet)
        self.assertIn("var needsAtlas:Bool = (frames == null || fontGlyph);", alphabet)
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
        self.assertIn("'alphabetAntialiasing',", visuals)
        self.assertIn("'Enable Alphabet anti-aliasing'", visuals)
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

    def test_alphabet_imports_every_flixel_type_it_names(self):
        """A type the engine does not import globally must be imported by the file.

        The native build failed with `Type not found : FlxGraphic` because the file named
        it without importing it, and the typecheck harness had its own import list that
        did. The harness is not runnable in CI (no haxelibs), so this is the guard that
        runs there.
        """
        alphabet = read("source/objects/Alphabet.hx")
        scope = imported_names(alphabet) | imported_names(read("source/import.hx"))
        scope |= set(re.findall(r"^(?:class|abstract|enum|typedef)\s+(\w+)", alphabet, re.M))
        named = set(re.findall(r"\b(Flx[A-Z]\w*)\b", alphabet))
        missing = sorted(named - scope)
        self.assertEqual(
            missing,
            [],
            f"import these in source/objects/Alphabet.hx: {missing} "
            "(source/import.hx does not provide them)",
        )

    def test_typecheck_harness_reuses_the_engine_import_list(self):
        script = read("tests/haxe/run-alphabet-typecheck.sh")
        self.assertIn("cp source/import.hx \"$test_source/import.hx\"", script)
        self.assertNotIn(
            'cat > "$test_source/import.hx"',
            script,
            "a hand written import list can resolve types the engine never imports",
        )


if __name__ == "__main__":
    unittest.main()
