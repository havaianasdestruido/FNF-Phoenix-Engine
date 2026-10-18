"""Regression checks for safe native Linux/macOS crash dialogs."""
from __future__ import annotations

import pathlib
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
HEADER = ROOT / "source/utils/include/phoenix_desktop_dialog.h"
NATIVE = ROOT / "source/utils/PlatformUtilNative.hx"
PUBLIC = ROOT / "source/utils/PlatformUtil.hx"


class PlatformDialogTests(unittest.TestCase):
    def test_platform_bridge_uses_native_linux_and_macos_dialogs(self):
        native = NATIVE.read_text(encoding="utf-8")
        public = PUBLIC.read_text(encoding="utf-8")
        self.assertIn('@:include("phoenix_desktop_dialog.h")', native)
        self.assertIn("#elseif linux", native)
        self.assertIn("phoenixShowLinuxDesktopDialog", native)
        self.assertIn("#elseif mac", native)
        self.assertIn("phoenixShowMacDesktopDialog", native)
        self.assertNotIn("TODO: Linux and macOS", native + public)

    def test_dialog_commands_are_direct_argv_calls_with_console_fallback(self):
        header = HEADER.read_text(encoding="utf-8")
        self.assertIn("posix_spawnp", header)
        self.assertNotIn("system(", header)
        self.assertNotIn("popen(", header)
        self.assertIn('"osascript", "-e"', header)
        self.assertIn('"zenity", "--error"', header)
        self.assertIn('"kdialog", "--title"', header)
        self.assertIn("phoenixWriteDesktopDialogFallback", header)

    def test_applescript_message_escaping_compiles_and_preserves_literal_data(self):
        compiler = shutil.which("c++")
        if not compiler:
            self.skipTest("C++ compiler unavailable")

        source = r'''
#include "phoenix_desktop_dialog.h"
#include <assert.h>
#include <string>
int main()
{
  std::string message = "quote: \"; do shell script \"bad\\path\nnext\rline\tindent";
  std::string escaped = phoenixEscapeAppleScriptString(message);
  assert(escaped == "quote: \\\"; do shell script \\\"bad\\\\path\\nnext\\rline\\tindent");
  std::string script = phoenixMacDesktopAlertScript(message);
  assert(script.find("do shell script") != std::string::npos);
  assert(script.find("message \"") != std::string::npos);
  assert(script.find(escaped) != std::string::npos);
  return 0;
}
'''
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            program = root / "test"
            cpp = root / "test.cpp"
            cpp.write_text(source)
            subprocess.run([
                compiler, "-std=c++11", "-Wall", "-Wextra", "-Werror",
                "-I", str(HEADER.parent), str(cpp), "-o", str(program),
            ], check=True, capture_output=True, text=True)
            subprocess.run([str(program)], check=True, capture_output=True, text=True)


if __name__ == "__main__":
    unittest.main()
