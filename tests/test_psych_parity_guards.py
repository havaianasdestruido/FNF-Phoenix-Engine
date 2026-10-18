"""Cross-target import and AIR-guard regressions for the Psych port audit.

These checks cover the source-level boundaries that can be reviewed without a
local Haxe/Lime installation; the actual target builds remain CI's job.
"""
from __future__ import annotations

from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


def read_source(relative_path: str) -> str:
    return (ROOT / relative_path).read_text(encoding="utf-8-sig")


class PsychParityGuards(unittest.TestCase):
    def test_copy_state_imports_mobile_only_dependencies_inside_mobile_guard(self):
        source = read_source("source/mobile/CopyState.hx")
        mobile_guard = source.index("#if mobile")
        for import_path in (
            "import backend.CoolUtil;",
            "import backend.ViewportVisuals;",
            "import backend.MusicBeatState;",
        ):
            with self.subTest(import_path=import_path):
                self.assertGreater(source.index(import_path), mobile_guard)
        self.assertIn("class CopyState extends MusicBeatState", source)

    def test_waveform_extracted_dependencies_are_explicit_and_air_safe(self):
        source = read_source("source/editors/charting/ChartingUIWaveform.hx")
        for import_path in (
            "import backend.Conductor;",
            "import flixel.FlxG;",
            "import flixel.math.FlxMath;",
            "import flixel.sound.FlxSound;",
            "import flixel.util.FlxColor;",
            "import openfl.geom.Rectangle;",
        ):
            with self.subTest(import_path=import_path):
                self.assertIn(import_path, source)

        self.assertIn(
            "#if (desktop && !air)\n@:access(flixel.sound.FlxSound._sound)",
            source,
        )
        waveform_update = source.split(
            "public static function updateWaveform", 1
        )[1].split("public static function waveformData", 1)[0]
        self.assertIn("#if (desktop && !air)", waveform_update)
        self.assertIn("#if (lime_cffi && !macro && !flash && !air)", source)

        charting_state = read_source("source/editors/ChartingState.hx")
        self.assertNotIn("@:access(flixel.sound.FlxSound._sound)", charting_state)
        self.assertNotIn("@:access(openfl.media.Sound.__buffer)", charting_state)

    def test_native_window_resolution_paths_exclude_air(self):
        cool_util = read_source("source/backend/CoolUtil.hx")
        play_state = read_source("source/play/PlayState.hx")
        graphics = read_source("source/options/GraphicsSettingsSubState.hx")

        self.assertIn("#if (desktop && !air)\n\tpublic static var resW", cool_util)
        self.assertIn("#if (desktop && !air)\n\t\t\tvar resolutionValue", play_state)
        self.assertEqual(graphics.count("#if (desktop && !air)"), 2)
        self.assertNotIn("#if desktop", graphics)

    def test_funkin_game_keeps_air_constructor_but_excludes_hotkey_window_code(self):
        source = read_source("source/backend/FunkinGame.hx")
        self.assertIn("#if desktop\n\t// Keep this constructor on AIR", source)
        self.assertGreaterEqual(source.count("#if (desktop && !air)"), 3)
        self.assertIn("FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, fullscreenListener);", source)
        self.assertIn("AIR's window/input APIs differ", source)

        # This unrelated keyboard-only sequence is intentionally available on AIR.
        options = read_source("source/options/OptionsState.hx")
        self.assertIn("keyboard-only debug sequence is valid on AIR", options)
        self.assertIn("#if desktop kId++; #end", options)

    def test_changed_haxe_files_keep_preprocessor_blocks_balanced(self):
        changed_files = (
            "source/backend/CoolUtil.hx",
            "source/backend/FunkinGame.hx",
            "source/editors/ChartingState.hx",
            "source/editors/charting/ChartingUIWaveform.hx",
            "source/mobile/CopyState.hx",
            "source/options/GraphicsSettingsSubState.hx",
            "source/options/OptionsState.hx",
            "source/play/PlayState.hx",
        )
        for relative_path in changed_files:
            stack: list[int] = []
            with self.subTest(relative_path=relative_path):
                for line_number, line in enumerate(read_source(relative_path).splitlines(), 1):
                    if line.lstrip().startswith(("//", "/*", "*", "*/")):
                        continue
                    for match in re.finditer(r"#(if|elseif|else|end)\b", line):
                        directive = match.group(1)
                        if directive == "if":
                            stack.append(line_number)
                        elif directive in ("elseif", "else"):
                            self.assertTrue(stack, f"orphan #{directive} at {relative_path}:{line_number}")
                        else:
                            self.assertTrue(stack, f"orphan #end at {relative_path}:{line_number}")
                            stack.pop()
                self.assertEqual(stack, [], f"unclosed #if in {relative_path} at {stack}")


if __name__ == "__main__":
    unittest.main()
