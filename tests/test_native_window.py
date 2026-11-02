"""Native Windows window tests: mock behavior + optional real SDK cross-compile.

Run: python3 -m unittest discover -s tests -p 'test_native_window.py' -v
Set PHOENIX_WINDOWS_CXX to a Windows-targeting C++ compiler to also compile
against the real SDK (for example x86_64-w64-mingw32-g++).
"""
from __future__ import annotations
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
INCLUDE = ROOT / "source/backend/native/include"
MOCK = ROOT / "tests/native/windows"


class NativeWindowTests(unittest.TestCase):
    def test_lookup_rejects_foreign_and_ambiguous_windows(self):
        compiler = shutil.which("c++")
        if not compiler:
            self.skipTest("C++ compiler unavailable")
        with tempfile.TemporaryDirectory() as directory:
            program = Path(directory) / "window-test"
            subprocess.run([compiler, "-std=c++11", "-Wall", "-Wextra", "-Werror",
                            "-D_WIN32", "-I", str(MOCK), "-I", str(INCLUDE),
                            str(ROOT / "tests/native/test_window_lookup.cpp"), "-o", str(program)],
                           check=True, capture_output=True, text=True)
            subprocess.run([str(program)], check=True, capture_output=True, text=True)

    def test_real_windows_sdk_compile(self):
        compiler = os.environ.get("PHOENIX_WINDOWS_CXX")
        if not compiler:
            self.skipTest("PHOENIX_WINDOWS_CXX not set")
        with tempfile.TemporaryDirectory() as directory:
            # Two translation units verify header-only linkage.
            for index in range(2):
                subprocess.run(shlex.split(compiler) + ["-std=c++11", "-Wall", "-Wextra", "-Werror",
                               "-I", str(INCLUDE), "-x", "c++", "-c", str(INCLUDE / "phoenix_window.h"),
                               "-o", str(Path(directory) / f"window{index}.obj")],
                               check=True, capture_output=True, text=True)

    def test_dark_mode_uses_dwm_and_updates_legacy_cache_only_on_success(self):
        facade = (ROOT / "source/Windows.hx").read_text()
        self.assertIn("WindowNative.setDarkMode(enabled)", facade)
        legacy = (ROOT / "source/backend/WindowColorMode.hx").read_text()
        self.assertIn("if (Windows.setDarkMode(isDark)) isDarkMode = isDark", legacy)
        self.assertTrue((ROOT / "source/system/Window.hx").exists())

    def test_square_corners_are_opt_in_at_startup(self):
        main = (ROOT / "source/Main.hx").read_text()
        self.assertIn("#if (cpp && windows && NO_W11_CORNERS)", main)
        self.assertIn("Windows.setSquareCorners(true)", main)

    def test_lime_refresh_preserves_border_and_skips_fullscreen(self):
        source = (ROOT / "source/system/Window.hx").read_text()
        self.assertIn("window.fullscreen", source)
        self.assertIn("final original = window.borderless", source)
        self.assertIn("window.borderless = original", source)
        self.assertIn("catch (error:Dynamic)", source)
        self.assertIn("system.Window.darkMode(true)", (ROOT / "source/Main.hx").read_text())

    def test_dialogs_use_unicode_and_explicit_yes_result(self):
        header = (INCLUDE / "phoenix_window.h").read_text()
        self.assertIn("MessageBoxW", header)
        self.assertIn("MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS", header)
        dialog = (ROOT / "source/Dialog.hx").read_text()
        self.assertIn("== 6", dialog)
        self.assertIn("Windows.alert", (ROOT / "source/backend/CoolUtil.hx").read_text())
        self.assertNotIn("MessageBoxA", header)

    def test_notifications_are_native_and_chart_events_do_not_launch_powershell(self):
        header = (INCLUDE / "phoenix_window.h").read_text()
        self.assertIn("NOTIFYICONDATAW", header)
        self.assertIn("Shell_NotifyIconW", header)
        events = (ROOT / "source/play/helpers/PlayStateEvents.hx").read_text()
        self.assertNotIn("powershell", events.lower())
        self.assertNotIn("HiddenProcess", events)
        self.assertIn("PlatformUtil.sendNotification(title, desc)", events)
        self.assertIn("removeWindowsNotification", (ROOT / "source/Main.hx").read_text())

    def test_haxe_bridge_has_one_signature_per_method_and_rgb_conversion(self):
        bridge = (ROOT / "source/backend/WindowNative.hx").read_text()
        native, fallback = bridge.split("#else", 1)
        pattern = r"public static function (\w+)\(([^)]*)\):(\w+)"
        import re
        native_sigs = re.findall(pattern, native)
        fallback_sigs = re.findall(pattern, fallback)
        self.assertEqual(len(native_sigs), len({s[0] for s in native_sigs}))
        self.assertEqual(native_sigs, fallback_sigs)
        facade = (ROOT / "source/Windows.hx").read_text()
        self.assertIn("((color & 0xFF) << 16) | (color & 0xFF00) | ((color >> 16) & 0xFF)", facade)

    def test_legacy_backends_use_shared_lookup(self):
        self.assertIn("Windows.setWindowBorderColor", (ROOT / "source/backend/WindowBackend.hx").read_text())
        self.assertIn("Windows.__setWindowTransparencyAlpha", (ROOT / "source/backend/FlxTransWindow.hx").read_text())
        for name in ("backend/MetaHorror.hx",):
            with self.subTest(backend=name):
                source = (ROOT / "source" / name).read_text()
                self.assertNotIn("GetActiveWindow()", source)
                self.assertIn("phoenixWindowFind()", source)


if __name__ == "__main__":
    unittest.main()
