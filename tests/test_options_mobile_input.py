"""Tests for OptionsState mobile virtual-pad null safety and bounds checks.

Verifies that OptionsState guards virtualPad and all its buttons against null dereference,
safely handles button absence (e.g., buttonC in A_B pad mode or removed virtualPad
during substate transitions), and performs bounds checks on konamiCode indexing.
"""
from __future__ import annotations

from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8-sig")


class OptionsMobileInputTests(unittest.TestCase):
    def setUp(self):
        self.source = read("source/options/OptionsState.hx")

    def test_virtual_pad_not_dereferenced_without_null_check_in_update(self):
        # Locate the update method
        self.assertIn("override function update(elapsed:Float)", self.source)
        update_body = self.source.split("override function update(elapsed:Float)", 1)[1].split(
            "function enterSuperSecretDebugMenu():Void", 1
        )[0]

        # Ensure no unguarded virtualPad.buttonX occurrences in update
        # Any access to virtualPad.button must be inside virtualPad != null checks
        self.assertNotIn("virtualPad.buttonUp.justPressed", update_body)
        self.assertNotIn("virtualPad.buttonDown.justPressed", update_body)
        self.assertNotIn("virtualPad.buttonLeft.justPressed", update_body)
        self.assertNotIn("virtualPad.buttonRight.justPressed", update_body)
        self.assertNotIn("virtualPad.buttonB.justPressed", update_body)
        self.assertNotIn("virtualPad.buttonA.justPressed", update_body)

        # Ensure virtualPad != null guard is present
        self.assertIn("if (virtualPad != null)", update_body)

    def test_button_c_safely_checked_in_update(self):
        update_body = self.source.split("override function update(elapsed:Float)", 1)[1].split(
            "function enterSuperSecretDebugMenu():Void", 1
        )[0]

        # buttonC must check for null before accessing justPressed
        # e.g., virtualPad != null && virtualPad.buttonC != null && virtualPad.buttonC.justPressed
        self.assertRegex(
            update_body,
            r"virtualPad\s*!=\s*null\s*&&\s*virtualPad\.buttonC\s*!=\s*null\s*&&\s*virtualPad\.buttonC\.justPressed",
        )

    def test_pad_buttons_checked_for_null_before_use(self):
        update_body = self.source.split("override function update(elapsed:Float)", 1)[1].split(
            "function enterSuperSecretDebugMenu():Void", 1
        )[0]

        # Each directional and action button used for the Konami sequence must be guarded against null
        for button_name in ("padUp", "padDown", "padLeft", "padRight", "padB", "padA"):
            self.assertRegex(
                update_body,
                rf"{button_name}\s*!=\s*null\s*&&\s*{button_name}\.justPressed",
            )

    def test_konami_code_bounds_and_null_checks(self):
        self.assertIn("function checkKonamiCode():Bool", self.source)
        konami_func = self.source.split("function checkKonamiCode():Bool", 1)[1].split(
            "}\n}", 1
        )[0]

        # Index bounds must be checked before array indexing
        self.assertIn("konamiIndex >= 0", konami_func)
        self.assertIn("konamiIndex < konamiCode.length", konami_func)
        self.assertIn("konamiCode != null", konami_func)
        self.assertIn("konamiCode[konamiIndex] != null", konami_func)
        self.assertIn("konamiCode[konamiIndex].justPressed", konami_func)


if __name__ == "__main__":
    unittest.main()
