#!/usr/bin/env python3
"""Static regression tests for transparent-window support (#95).

The feature is a Win32 port (`backend.FlxTransWindow`) behind a platform guard
(`backend.TransparentWindow`) that also drives fullscreen. There is no Haxe
toolchain here, so these tests pin the boundaries that a compiler cannot check
for us, in the same style as test_deeplink_opt_in.py:

  * the native layer only exists behind `#if (cpp && windows)`;
  * every public entry point either works or reports "not supported";
  * transparency is suspended in fullscreen instead of fighting with it;
  * Lua and Python expose the same nine functions.

Run:  python3 -m unittest discover -s tests -p 'test_*.py' -v
  or: python3 tests/test_transparent_window.py
"""
from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

NATIVE = "source/backend/FlxTransWindow.hx"
API = "source/backend/TransparentWindow.hx"
LUA = "source/psychlua/callbacks/WindowCallbacks.hx"
PYTHON = "source/psychlua/pystdlib/PyWindowLib.hx"
MAIN = "source/Main.hx"

UPSTREAM_URL = (
    "https://github.com/notmagniill/psych-engine-modified-build/blob/stable/"
    "source/backend/FlxTransWindow.hx"
)
UPSTREAM_AUTHOR = "notmagniill"

# The functions every script (Lua *and* Python) must be able to call.
EXPECTED_FUNCTIONS = {
    "setWindowTransparent",
    "getWindowTransparent",
    "setWindowAlpha",
    "getWindowAlpha",
    "setWindowTransparencyColor",
    "setWindowClickThrough",
    "isWindowClickThrough",
    "isWindowTransparencySupported",
    "applyWindowTransparency",
}

REGISTER = re.compile(r"registerFunction\(\s*[\"']([A-Za-z_]\w*)[\"']")
DEFINITION = re.compile(r"(?:public\s+)?static\s+(?:public\s+)?function\s+(\w+)")


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8", errors="ignore")


def body(source: str, signature: str) -> str:
    """The brace-delimited body of the first definition matching `signature`.

    Conditional compilation blocks inside the body are returned verbatim, so the
    caller can assert on `#if` guards.
    """
    start = source.index(signature)
    brace = source.index("{", start)
    depth = 0
    for i in range(brace, len(source)):
        if source[i] == "{":
            depth += 1
        elif source[i] == "}":
            depth -= 1
            if depth == 0:
                return source[brace + 1 : i]
    raise AssertionError(f"unbalanced braces after {signature!r}")


def doc_comment(source: str, signature: str) -> str:
    """The `/** ... */` block directly above a definition."""
    start = source.index(signature)
    end = source.rfind("/**", 0, start)
    return source[end:start] if end != -1 else ""


def conditional_blocks(source: str) -> list[tuple[str, str]]:
    """Every `#if <expr> ... #end` pair, as (expression, block)."""
    blocks = []
    for match in re.finditer(r"#if\s*\(([^)]*)\)", source):
        start = match.end()
        end = source.index("#end", start)
        blocks.append((match.group(1), source[start:end]))
    return blocks


class NativeLayerTests(unittest.TestCase):
    def test_credits_the_upstream_port(self):
        source = read(NATIVE)
        self.assertIn(UPSTREAM_URL, source)
        self.assertIn(UPSTREAM_AUTHOR, source)

    def test_native_code_is_behind_the_windows_cpp_guard(self):
        source = read(NATIVE)
        guards = [expr for expr, _ in conditional_blocks(source)]
        self.assertIn("cpp && windows", guards)
        # `@:cppFileCode` / `@:functionCode` are only legal where the C++ backend
        # compiles them; anywhere else they would be dead metadata at best.
        for block in re.finditer(r"@:(?:cppFileCode|functionCode)\(", source):
            line_start = source.rfind("\n", 0, block.start()) + 1
            preceding = source[:line_start]
            self.assertTrue(
                preceding.rstrip().endswith("#if (cpp && windows)"),
                "native code found outside the `#if (cpp && windows)` guard",
            )

    def test_every_public_function_mentions_its_platform(self):
        source = read(NATIVE)
        names = DEFINITION.findall(source)
        self.assertEqual(
            {"getWindowsTransparent", "getWindowsbackward", "setTransparentWindow",
             "setAlphaWindow", "clearTransparentWindow", "setClickThrough"},
            set(names),
        )
        for name in names:
            with self.subTest(function=name):
                # Each one is a no-op outside the Windows C++ build, and says so.
                self.assertIn("Windows", doc_comment(source, f"function {name}("))


class PublicApiTests(unittest.TestCase):
    def test_support_flags_are_platform_guarded(self):
        source = read(API)
        for name in ("get_supportsColorKey", "get_supportsAlpha", "get_supportsClickThrough"):
            with self.subTest(getter=name):
                block = body(source, f"function {name}(")
                # Only the C++ desktop builds talk to the window; everything else
                # must fall through to `return false`.
                self.assertIn("#if (cpp &&", block)
                self.assertIn("return false", block)
        for name in ("get_supportsColorKey", "get_supportsClickThrough"):
            with self.subTest(windows_only=name):
                self.assertIn(
                    "cpp && windows", body(source, f"function {name}(")
                )

    def test_window_access_is_guarded_for_flash(self):
        # Flixel's stage has no `window` on Flash; touching it unguarded breaks
        # that build.
        source = read(API)
        for name in ("getWindow", "isFullscreenNow"):
            with self.subTest(function=name):
                block = body(source, f"function {name}(")
                self.assertIn("#if !flash", block)
                if name == "getWindow":
                    self.assertIn("return null", block)

    def test_native_calls_only_happen_under_the_windows_guard(self):
        source = read(API)
        for call in re.finditer(r"FlxTransWindow\.(\w+)\(", source):
            line_start = source.rfind("\n", 0, call.start()) + 1
            # Walk back to the innermost `#if (cpp && windows)` before the call.
            header = source[:line_start]
            opens = [m.start() for m in re.finditer(r"#if\s*\(", header)]
            self.assertTrue(opens, f"unguarded FlxTransWindow.{call.group(1)} call")
            last = header[opens[-1] :]
            self.assertTrue(
                last.startswith("#if (cpp && windows)"),
                f"FlxTransWindow.{call.group(1)} is not inside `#if (cpp && windows)`",
            )

    def test_unsupported_targets_report_once(self):
        source = read(API)
        unsupported = body(source, "function unsupported(")
        self.assertIn("trace(", unsupported)
        self.assertIn("reported", unsupported)  # no log spam from a looping mod
        for name in ("setEnabled", "setAlpha", "setColorKey", "setClickThrough"):
            with self.subTest(setter=name):
                self.assertIn("unsupported(", body(source, f"function {name}("))

    def test_enabling_leaves_fullscreen(self):
        enable = body(read(API), "function setEnabled(")
        self.assertIn("FlxG.fullscreen = false", enable)

    def test_fullscreen_suspends_and_restores(self):
        source = read(API)
        sync = body(source, "function syncFullscreenState(")
        self.assertIn("if (!enabled) return", sync)
        self.assertIn("suspended = true", sync)
        self.assertIn("apply()", sync)
        # Entering fullscreen drops the effect; leaving re-applies it.
        apply_block = body(source, "function apply(")
        self.assertIn("isFullscreenNow()", apply_block)
        self.assertIn("suspended", apply_block)

    def test_init_installs_a_single_watcher(self):
        source = read(API)
        init = body(source, "function init(")
        self.assertIn("initialized", init)
        self.assertIn("FlxG.signals.preUpdate.add", init)
        main = body(read(MAIN), "private function setupGame(")
        self.assertIn("TransparentWindow.init()", main)

    def test_parse_color_accepts_script_side_values(self):
        parse = body(read(API), "function parseColor(")
        self.assertIn("Std.isOfType(value, Int)", parse)
        self.assertIn("Std.isOfType(value, Float)", parse)
        self.assertIn('Std.parseInt("0x" + hex)', parse)


class ScriptBridgeTests(unittest.TestCase):
    def lua_functions(self):
        return set(REGISTER.findall(read(LUA)))

    def python_functions(self):
        return set(REGISTER.findall(read(PYTHON)))

    def test_lua_and_python_expose_the_same_functions(self):
        self.assertEqual(EXPECTED_FUNCTIONS, self.lua_functions())
        self.assertEqual(self.lua_functions(), self.python_functions())

    def test_bridges_only_talk_to_the_public_api(self):
        for rel in (LUA, PYTHON):
            with self.subTest(bridge=rel):
                source = read(rel)
                self.assertNotIn("FlxTransWindow", source)
                self.assertIn("TransparentWindow.", source)


if __name__ == "__main__":
    unittest.main()
