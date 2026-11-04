#!/usr/bin/env python3
"""Static regression tests for the hardware-trigger keybinds (issue #81).

Volume buttons can be bound to the note lanes from the Controls menu. No Haxe
toolchain is required, so these tests pin the invariants that keep the feature
safe: the bind encoding cannot collide with keyboard keys, the section is
Android-only and unbound by default, volume keys are only captured while
gameplay is live (or while a trigger is being rebound), and the listeners are
always removed again.

Run:  python3 -m unittest discover -s tests -p 'test_*.py' -v
  or: python3 tests/test_hardware_keybinds.py
"""
from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

HARDWARE_KEYS = "source/backend/HardwareKeys.hx"
PREFS = "source/backend/ClientPrefs.hx"
INPUT_FORMATTER = "source/backend/InputFormatter.hx"
CONTROLS_MENU = "source/options/ControlsSubState.hx"
PLAY_STATE = "source/play/PlayState.hx"
PLAY_HW = "source/play/helpers/PlayStateHardwareInput.hx"
PLAY_INPUT = "source/play/helpers/PlayStateInput.hx"
ANDROID_HW = "source/android/platform/AndroidHardwareInput.hx"

LANES = ["left", "down", "up", "right"]


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8", errors="ignore")


def android_blocks(source: str) -> list[str]:
    """Bodies of every `#if android ... #end` block (no nesting in these files)."""
    return re.findall(r"#if android\b(.*?)#end", source, re.S)


def hex_or_int(text: str) -> int:
    return int(text, 0)


class HardwareKeyEncodingTests(unittest.TestCase):
    """Mirror of backend/HardwareKeys.hx: the arithmetic must round-trip and stay negative."""

    OFFSET = 0x10000

    def to_bind(self, code: int) -> int:
        return -(self.OFFSET + code)

    def key_code_of(self, bind: int) -> int:
        return -bind - self.OFFSET

    def test_encoding_is_negative_so_it_never_collides_with_keyboard_keys(self):
        for code in (24, 25, 0, 255):
            self.assertLess(self.to_bind(code), 0)

    def test_round_trip(self):
        for code in (24, 25, 300):
            self.assertEqual(self.key_code_of(self.to_bind(code)), code)

    def test_source_matches_the_mirrored_arithmetic(self):
        src = read(HARDWARE_KEYS)
        self.assertIn("static inline final OFFSET:Int = 0x10000;", src)
        self.assertIn("return cast -(OFFSET + keyCode);", src)
        self.assertIn("return -value - OFFSET;", src)
        self.assertIn("return value < 0;", src)

    def test_volume_keycodes_match_android_key_event_constants(self):
        hw = read(HARDWARE_KEYS)
        android = read(ANDROID_HW)
        self.assertIsNotNone(re.search(r"KEYCODE_VOLUME_UP:Int = 24;", hw))
        self.assertIsNotNone(re.search(r"KEYCODE_VOLUME_DOWN:Int = 25;", hw))
        self.assertIsNotNone(re.search(r"KEYCODE_VOLUME_UP:Int = 24;", android))
        self.assertIsNotNone(re.search(r"KEYCODE_VOLUME_DOWN:Int = 25;", android))


class DefaultsAndStorageTests(unittest.TestCase):
    def test_hardware_lanes_are_unbound_by_default(self):
        prefs = read(PREFS)
        for lane in LANES:
            self.assertRegex(prefs, rf"'hw_note_{lane}'\s*=>\s*\[NONE, NONE\]")

    def test_hardware_binds_reuse_the_keybind_map(self):
        # Stored in ClientPrefs.keyBinds so save/load/reset-to-default cover them for free.
        prefs = read(PREFS)
        self.assertIn("public static var keyBinds:Map<String, Array<FlxKey>>", prefs)
        self.assertNotIn("hardwareBinds", prefs)

    def test_menu_labels_hardware_keycodes(self):
        fmt = read(INPUT_FORMATTER)
        self.assertIn("if (HardwareKeys.isBind(key))", fmt)
        self.assertIn("return HardwareKeys.getName(key);", fmt)


class ControlsMenuTests(unittest.TestCase):
    def setUp(self):
        self.menu = read(CONTROLS_MENU)

    def test_hardware_rows_only_exist_on_android(self):
        rows = [m for m in re.finditer(r"'hw_note_(left|down|up|right)'", self.menu)]
        self.assertEqual(len(rows), 4)
        blocks = android_blocks(self.menu)
        self.assertTrue(any("hardwareOptions" in b for b in blocks))
        for m in rows:
            self.assertTrue(
                any(m.group(0) in block for block in blocks),
                f"{m.group(0)} is outside an #if android block",
            )

    def test_menu_never_captures_volume_keys_outside_a_rebind(self):
        # Capture is started only by ACCEPT on a HARDWARE row and always stopped again.
        self.assertIn("startHardwareCapture();", self.menu)
        self.assertGreaterEqual(self.menu.count("stopHardwareCapture();"), 3)
        self.assertIn("AndroidHardwareInput.disableVolumeKeys();", self.menu)

    def test_keyboard_press_cannot_bind_a_hardware_row(self):
        # The keyboard branch only runs when the hardware branch is not capturing.
        branch = self.menu[self.menu.index("if (capturingHardware) {"):]
        self.assertLess(branch.index("} else"), branch.index("var keyPressed"))
        self.assertIn("} else\n\t\t\t#end", branch)

    def test_listener_is_removed_on_destroy(self):
        self.assertIn("AndroidHardwareInput.onKey.add(hardwareKeyListener);", self.menu)
        self.assertRegex(self.menu, r"override function destroy\(\):Void\s*\{\s*stopHardwareCapture\(\);\s*"
                                    r"AndroidHardwareInput\.onKey\.remove\(hardwareKeyListener\);")

    def test_warning_about_menus_is_shown(self):
        self.assertIn("Volume buttons play notes only during gameplay. Menus keep normal volume.", self.menu)


class GameplayInputTests(unittest.TestCase):
    def test_playstate_subscribes_and_unsubscribes(self):
        ps = read(PLAY_STATE)
        self.assertIn("AndroidHardwareInput.onKey.add(hardwareKeyHandler);", ps)
        self.assertIn("AndroidHardwareInput.onKey.remove(hardwareKeyHandler);", ps)
        self.assertIn("PlayStateHardwareInput.release(this);", ps)

    def test_volume_keys_are_captured_only_when_live(self):
        hw = read(PLAY_HW)
        self.assertRegex(hw, r"var wanted:Bool = !covered && state\.subState == null && !state\.paused && !state\.cpuControlled && hasBindings\(\);")
        # Handing the keys back must also forget held triggers (their releases won't arrive).
        self.assertRegex(hw, r"else\s*\{(?:\s|//[^\n]*)*clearHeld\(state\);\s*AndroidHardwareInput\.disableVolumeKeys\(\);")

    def test_playstate_syncs_every_frame(self):
        ps = read(PLAY_STATE)
        self.assertIn("PlayStateHardwareInput.syncVolumeKeys(this, true);", ps)  # openSubState
        update = ps[ps.index("override public function update(elapsed:Float)"):]
        self.assertLess(update.index("PlayStateHardwareInput.syncVolumeKeys(this);"), update.index("grpCrossFade.update"))

    def test_held_trigger_keeps_sustains_alive(self):
        self.assertIn("PlayStateHardwareInput.applyHeld(state);", read(PLAY_INPUT))

    def test_key_repeat_is_not_a_second_press(self):
        hw = read(PLAY_HW)
        self.assertRegex(hw, r"if \(state\.hardwareHeld\[lane\]\)\s*return;")

    def test_everything_android_only_is_guarded(self):
        hw = read(PLAY_HW)
        self.assertTrue(hw.lstrip().startswith("package play.helpers;"))
        self.assertIn("#if android", hw)
        self.assertTrue(hw.rstrip().endswith("#end"))


if __name__ == "__main__":
    unittest.main()
