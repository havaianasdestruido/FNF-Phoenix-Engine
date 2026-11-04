"""Guards for the platform badge drawn on top of the engine version watermark.

Two halves:

* the artwork in ``source/backend/PlatformIcons.hx`` is parsed (by the same
  module the preview tool uses) and checked against the contract the renderer
  relies on: every platform resolves to a glyph, every glyph has a white body
  and nothing leaves the 0..100 grid;
* the call sites are checked so the badge keeps following the watermark: the
  HUD camera, the resize reflow, the alpha tweens, the preference and the
  options entry.

The Haxe side of the math (detection per target, density curve, raster sizes)
is exercised by ``tests/haxe/PlatformIconSpec.hx``; no Haxe SDK is needed here.
"""

import importlib.util
import re
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

_spec = importlib.util.spec_from_file_location("platform_icon_preview", REPO_ROOT / "tools" / "platform_icon_preview.py")
preview = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(preview)


def source(name: str) -> str:
    return (REPO_ROOT / "source" / name).read_text(encoding="utf-8-sig")


ARTWORK = source("backend/PlatformIcons.hx")
RENDERER = source("objects/PlatformIcon.hx")
DENSITY = source("backend/ScreenDensity.hx")


class Artwork(unittest.TestCase):
    def setUp(self):
        self.glyphs = preview.parse_glyphs(ARTWORK)
        self.kinds = preview.parse_kind_map(ARTWORK)
        self.constants = preview.parse_constants(ARTWORK)

    def test_every_platform_the_engine_builds_for_has_a_badge(self):
        declared = set(re.findall(r"var ([A-Z]+) = \"[a-z]+\";", ARTWORK))
        self.assertEqual(
            declared,
            {"WINDOWS", "MAC", "IOS", "LINUX", "ANDROID", "WEB", "AIR", "FLASH", "UNKNOWN"},
        )
        for kind in declared:
            self.assertIn(kind, self.kinds, f"{kind} has no glyph mapping")
            self.assertIn(self.kinds[kind], self.glyphs, f"{kind} maps to missing artwork")
        # macOS and iOS share the apple on purpose.
        self.assertEqual(self.kinds["MAC"], self.kinds["IOS"])

    def test_every_glyph_has_a_white_body(self):
        for name, parts in self.glyphs.items():
            self.assertTrue(parts, f"{name} is empty")
            self.assertTrue(any(part.ink == "BODY" for part in parts), f"{name} has no BODY part")
            for part in parts:
                self.assertIn(part.ink, {"BODY", "DETAIL", "MARK"})

    def test_artwork_stays_inside_the_grid(self):
        """The renderer only reserves one outline width of padding."""
        grid = self.constants["GRID"]
        for name, parts in self.glyphs.items():
            left, top, right, bottom = preview.bounds(parts)
            self.assertGreaterEqual(min(left, top), 0, f"{name} leaves the grid")
            self.assertLessEqual(max(right, bottom), grid, f"{name} leaves the grid")

    def test_glyphs_share_one_optical_box(self):
        """Consistency: no badge may be much smaller or wider than the rest."""
        for name, parts in self.glyphs.items():
            left, top, right, bottom = preview.bounds(parts)
            width, height = right - left, bottom - top
            self.assertGreaterEqual(max(width, height), 60, f"{name} is too small next to the others")
            self.assertLessEqual(max(width, height), 86, f"{name} is bigger than the others")
            self.assertGreater(min(width, height), 30, f"{name} is a sliver")

    def test_shapes_are_well_formed(self):
        for name, parts in self.glyphs.items():
            for part in parts:
                if part.shape in {"Rect", "RoundRect"}:
                    self.assertGreater(part.args[2], 0, f"{name}: zero width")
                    self.assertGreater(part.args[3], 0, f"{name}: zero height")
                if part.shape == "Circle":
                    self.assertGreater(part.args[2], 0, f"{name}: zero radius")
                if part.shape == "Ellipse":
                    self.assertGreater(min(part.args[2], part.args[3]), 0, f"{name}: zero radius")
                if part.shape == "Polygon":
                    self.assertGreaterEqual(len(part.args[0]), 6, f"{name}: polygon needs 3 points")
                    self.assertEqual(len(part.args[0]) % 2, 0, f"{name}: polygon needs x,y pairs")
                if part.shape in {"Contour", "Stroke"}:
                    commands = part.args[0]
                    self.assertEqual(commands[0][0], "Move", f"{name}: paths start with Move")
                    self.assertGreaterEqual(len(commands), 2, f"{name}: path too short")
                if part.shape == "Stroke":
                    self.assertEqual(part.ink, "MARK", f"{name}: open paths are only for marks")

    def test_density_constants_are_sane(self):
        self.assertEqual(self.constants["GRID"], 100)
        self.assertEqual(self.constants["DESKTOP_BASELINE_DPI"], 96)
        self.assertEqual(self.constants["MOBILE_BASELINE_DPI"], 160)
        self.assertGreater(self.constants["MAX_DENSITY_SCALE"], 1)
        self.assertGreaterEqual(self.constants["MAX_RASTER_SCALE"], 2)
        self.assertGreater(self.constants["OUTLINE_RATIO"], 0)
        self.assertLess(self.constants["OUTLINE_RATIO"], 0.12)

    def test_artwork_has_no_flixel_or_openfl_dependency(self):
        """So tests/haxe/run-platform-icons.sh can run it without haxelibs."""
        self.assertNotIn("import flixel", ARTWORK)
        self.assertNotIn("import openfl", ARTWORK)
        self.assertNotIn("import lime", ARTWORK)


class Detection(unittest.TestCase):
    """The order of the ``#if`` ladder in ``detect()`` is the whole contract.

    Several defines are set at once on real builds - an AIR build also defines
    ``flash``, Lime sets ``windows``/``mac``/``linux`` next to ``android`` on
    some host setups - so the first matching branch decides the badge. The Haxe
    spec asserts the returned value on every target it can run (``--interp``),
    but ``flash`` is a reserved compiler flag that cannot be set with ``-D``
    and a SWF cannot be executed on CI, so the Flash/AIR ordering is pinned
    here instead.
    """

    LADDER = ["android", "ios", "html5", "air", "flash", "windows", "mac", "linux", "sys"]

    def setUp(self):
        body = re.search(r"function detect\(\):PlatformKind\s*\{(.*?)\n  \}", ARTWORK, re.S)
        self.assertIsNotNone(body, "detect() not found")
        self.branches = re.findall(r"#(?:else)?if (\w+)", body.group(1))

    def test_every_target_the_engine_ships_is_in_the_ladder(self):
        self.assertEqual(self.branches, self.LADDER)

    def test_air_is_checked_before_flash(self):
        self.assertLess(self.branches.index("air"), self.branches.index("flash"))

    def test_mobile_targets_are_checked_before_the_desktop_defines(self):
        for mobile in ("android", "ios"):
            for desktop in ("windows", "mac", "linux", "sys"):
                self.assertLess(self.branches.index(mobile), self.branches.index(desktop))

    def test_system_name_is_the_last_resort(self):
        self.assertEqual(self.branches[-1], "sys")
        self.assertIn("return fromSystemName(Sys.systemName());", ARTWORK)
        self.assertIn("return PlatformKind.UNKNOWN;", ARTWORK)


class Renderer(unittest.TestCase):
    def test_three_passes_in_order(self):
        silhouette = RENDERER.index("lineStyle(outline * 2, OUTLINE_COLOR, 1)")
        fill = RENDERER.index("beginFill(FILL_COLOR, 1)")
        detail = RENDERER.index("if (part.ink != GlyphInk.DETAIL) continue;")
        mark = RENDERER.index("if (part.ink != GlyphInk.MARK) continue;")
        self.assertLess(silhouette, fill, "the dark silhouette is painted first")
        self.assertLess(fill, detail, "details go over the white fill")
        self.assertLess(detail, mark)

    def test_each_part_gets_its_own_fill(self):
        """Overlapping sub-paths inside a single fill cancel out (even-odd)."""
        self.assertEqual(RENDERER.count("gfx.beginFill("), RENDERER.count("gfx.endFill()"))
        self.assertGreaterEqual(RENDERER.count("gfx.beginFill("), 3)
        for block in re.findall(r"for \(part in glyph\)\s*\{(.*?)\n    \}", RENDERER, re.DOTALL):
            if "beginFill" in block:
                self.assertIn("endFill", block, "fills are closed inside the same loop body")

    def test_outline_is_half_the_stroke(self):
        """lineStyle strokes are centred, so the visible halo is half of it."""
        self.assertIn("gfx.lineStyle(outline * 2, OUTLINE_COLOR, 1);", RENDERER)
        self.assertIn("PlatformIcons.outlineWidth(size)", RENDERER)
        self.assertIn("PlatformIcons.contentScale(size, outline)", RENDERER)
        self.assertIn("gfx.lineStyle();", RENDERER)

    def test_colours_are_white_on_a_dark_outline(self):
        self.assertIn("FILL_COLOR:Int = 0xFFFFFF", RENDERER)
        self.assertIn("OUTLINE_COLOR:Int = 0x000000", RENDERER)

    def test_contours_close_themselves_but_strokes_do_not(self):
        self.assertIn("if (close && started) gfx.lineTo(startX, startY);", RENDERER)
        self.assertIn("case Contour(commands):", RENDERER)
        self.assertIn("case Stroke(commands):", RENDERER)

    def test_bitmaps_are_cached_and_revalidated(self):
        self.assertIn("graphicCache", RENDERER)
        self.assertIn("FlxG.bitmap.get(cached.key) == cached", RENDERER)
        self.assertIn("graphic.persist = true;", RENDERER)
        self.assertIn("graphic.destroyOnNoUse = false;", RENDERER)

    def test_badge_is_resized_to_logical_pixels(self):
        self.assertIn("PlatformIcons.rasterSize(size, ScreenDensity.pixelsPerGamePixel())", RENDERER)
        self.assertIn("setGraphicSize(size, size);", RENDERER)
        self.assertIn("updateHitbox();", RENDERER)
        self.assertLess(RENDERER.index("setGraphicSize(size, size);"), RENDERER.index("reposition();"))

    def test_refresh_is_cheap_when_nothing_changed(self):
        self.assertIn("if (!force && raster == rasterSize && size == displaySize) return;", RENDERER)

    def test_badge_flips_under_the_text_when_there_is_no_room(self):
        self.assertIn("y = above >= 0 ? above : anchor.y + anchor.height + anchorGap;", RENDERER)
        self.assertIn("x = anchorRight ? anchor.x + anchor.width - width : anchor.x;", RENDERER)


class Density(unittest.TestCase):
    def test_dpi_comes_from_the_platform_that_knows_best(self):
        android = DENSITY.index("#if android")
        lime = DENSITY.index("#if (lime && !flash)")
        self.assertLess(android, lime, "Android's density bucket wins over SDL's panel DPI")
        self.assertIn("android.platform.AndroidDisplay.getInfo()", DENSITY)
        self.assertIn("lime.system.System.getDisplay(0)", DENSITY)
        self.assertIn("flash.system.Capabilities.screenDPI", DENSITY)

    def test_absurd_or_missing_values_fall_back_to_the_baseline(self):
        self.assertIn("if (!(value > 0) || value > MAX_PLAUSIBLE_DPI) value = baselineDpi();", DENSITY)

    def test_dpi_is_cached_because_android_answers_over_jni(self):
        self.assertIn("if (cachedDpi > 0) return cachedDpi;", DENSITY)
        self.assertIn("public static function invalidate()", DENSITY)

    def test_mobile_uses_the_mdpi_baseline(self):
        self.assertIn("#if mobile", DENSITY)
        self.assertIn("PlatformIcons.MOBILE_BASELINE_DPI", DENSITY)
        self.assertIn("PlatformIcons.DESKTOP_BASELINE_DPI", DENSITY)

    def test_window_scale_feeds_the_supersampling(self):
        self.assertIn("FlxG.scaleMode.scale.x", DENSITY)
        self.assertIn("ratio *= FlxG.stage.window.scale", DENSITY)
        self.assertIn("#if !flash", DENSITY)


class Integration(unittest.TestCase):
    def test_gameplay_watermark_carries_the_badge(self):
        state = source("play/PlayState.hx")
        self.assertIn("public var platformIcon:PlatformIcon;", state)
        self.assertIn("if (ClientPrefs.platformWatermark && EngineWatermark != null)", state)
        self.assertIn("platformIcon.visible = EngineWatermark.visible;", state)
        self.assertIn("platformIcon.placeAbove(EngineWatermark, 3, ClientPrefs.watermarkStyle == 'Forever Engine');", state)
        self.assertIn("if (platformIcon != null) platformIcon.cameras = [camHUD];", state)
        # The badge is created after the watermark style picked its position.
        self.assertLess(state.index("switch(ClientPrefs.watermarkStyle)"), state.index("platformIcon = new PlatformIcon();"))

    def test_resize_redraws_and_reanchors_the_badge(self):
        layout = source("play/helpers/PlayStateLayout.hx")
        self.assertIn("ScreenDensity.invalidate();", layout)
        self.assertIn("state.platformIcon.refresh();", layout)
        self.assertIn("state.platformIcon.reposition();", layout)
        # A resize that keeps the logical width still changes the window scale.
        self.assertLess(layout.index("state.platformIcon.refresh();"), layout.index("if (oldWidth == FlxG.width) return;"))

    def test_badge_fades_with_the_rest_of_the_hud(self):
        camera = source("play/helpers/PlayStateCamera.hx")
        self.assertEqual(camera.count("state.EngineWatermark, state.platformIcon"), 2)

    def test_main_menu_version_stack_carries_the_badge(self):
        menu = source("states/MainMenuState.hx")
        self.assertIn("import objects.PlatformIcon;", menu)
        self.assertIn("platformIcon.placeAbove(PhoenixVersion, 4);", menu)
        self.assertIn("if (ClientPrefs.platformWatermark)", menu)
        self.assertIn("platformIcon.reposition();", menu)
        self.assertLess(menu.index("ScreenDensity.invalidate();"), menu.index("platformIcon.refresh();"))

    def test_players_can_turn_the_badge_off(self):
        prefs = source("backend/ClientPrefs.hx")
        options = (REPO_ROOT / "source" / "options" / "VisualsUISubState.hx").read_text(encoding="utf-8-sig")
        self.assertIn("public static var platformWatermark:Bool = true;", prefs)
        self.assertIn("'platformWatermark',", options)
        self.assertIn("'Platform Badge'", options)
        # Saving/loading is reflection based, so the option must not be blacklisted.
        self.assertNotIn('"platformWatermark"', prefs.split("saveBlackList")[-1][:400])


class PreviewTool(unittest.TestCase):
    def test_tool_round_trips_the_artwork(self):
        glyphs = preview.parse_glyphs(ARTWORK)
        self.assertEqual(len(glyphs), 8)
        windows = glyphs["WINDOWS"]
        self.assertEqual(len(windows), 4, "the flag has four panes")
        self.assertTrue(all(part.shape == "Polygon" for part in windows))

    def test_tool_mirrors_the_renderer_passes(self):
        tool = (REPO_ROOT / "tools" / "platform_icon_preview.py").read_text(encoding="utf-8")
        self.assertIn("pass 1: welded dark silhouette", tool)
        self.assertIn("pass 2: white fill, no stroke", tool)
        self.assertIn("pass 3: details and marks", tool)


if __name__ == "__main__":
    unittest.main()
