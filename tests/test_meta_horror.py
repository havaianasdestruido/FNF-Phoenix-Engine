#!/usr/bin/env python3
"""4th-wall-breaking ("META_HORROR") API, second pass (#94 follow-up).

The first port covered the upstream horror-mod system effects (wallpaper,
taskbar, volume, mouse/keyboard). This suite pins the batch of effects that
build on them, plus the safety rules that keep the whole feature reversible:

  * every new public function is compiled on every target and degrades to a
    documented failure value without `-DMETA_HORROR`;
  * native code only exists behind `#if (META_HORROR && windows && cpp)`;
  * the effects that touch the player's desktop have an engine-wide undo
    (`restoreAll`) and the engine installs it at startup;
  * the Lua and Python bridges expose the same names, and never collide with
    the transparent-window callbacks registered before them;
  * privacy-sensitive script calls are sandbox-guarded like file access.

Run:  python3 tests/test_meta_horror.py -v
"""
from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

BACKEND = "source/backend/MetaHorror.hx"
HEADER = "source/backend/native/include/phoenix_meta_horror.h"
BUILD = "source/backend/native/meta_horror_build.xml"
LUA = "source/psychlua/callbacks/MetaHorrorCallbacks.hx"
PYTHON = "source/psychlua/pystdlib/PyMetaHorrorLib.hx"
WINDOW_LUA = "source/psychlua/callbacks/WindowCallbacks.hx"
WINDOW_PY = "source/psychlua/pystdlib/PyWindowLib.hx"
MAIN = "source/Main.hx"
SECURITY = "source/backend/ModSecurity.hx"
DOCS = "docs/META_HORROR.md"
SITE_DOCS = "website/docs/modding/meta-horror.md"

# Functions added in this pass: (name, expected failure value without the define).
NEW_API = {
    "getDesktopUsername": "'player'",
    "getSystemUptime": "0",
    "getLocalHour": "0",
    "getLocalTimeString": "'00:00'",
    "isLateNight": "false",
    "getLaunchCount": "0",
    "getPersistentValue": "defaultValue",
    "setPersistentValue": "false",
    "hasPersistentValue": "false",
    "addPersistentValue": "0",
    "clearPersistentValues": "false",
    "getClipboardText": "''",
    "setClipboardText": "false",
    "setWindowTitle": "false",
    "restoreWindowTitle": "false",
    "setAlwaysOnTop": "false",
    "isAlwaysOnTop": "false",
    "flashTaskbar": "false",
    "stopTaskbarFlash": None,  # Void
    "getOpenWindowTitles": "[]",
    "captureDesktop": "null",
    "restoreAll": None,  # Void
}

# Script-facing names, where they differ from the Haxe API (namespaced to avoid
# clobbering the transparent-window callbacks, or a friendlier spelling).
SCRIPT_ALIASES = {
    "restoreAll": "restoreAllMetaEffects",
    "setWindowAlpha": "setMetaWindowAlpha",
    "setWindowColorKey": "setMetaWindowColorKey",
    "resetWindowEffects": "resetMetaWindowEffects",
}

REGISTER = re.compile(r"registerFunction\(\s*[\"']([A-Za-z_]\w*)[\"']")


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8", errors="ignore")


def body(source: str, signature: str) -> str:
    """The brace-delimited body of the first definition matching `signature`."""
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


def script_name(api_name: str) -> str:
    return SCRIPT_ALIASES.get(api_name, api_name)


class HaxeApiTests(unittest.TestCase):
    def test_every_new_function_exists_and_is_guarded(self):
        source = read(BACKEND)
        for name in NEW_API:
            with self.subTest(function=name):
                block = body(source, f"function {name}(")
                # The real implementation is opt-in, and the fallback path is
                # the documented failure value (never an exception).
                self.assertIn("#if", block)
                self.assertIn("META_HORROR", block)
                self.assertIn("#else", block)

    def test_documented_failure_values_match_the_code(self):
        source = read(BACKEND)
        for name, expected in NEW_API.items():
            if expected is None:
                continue
            with self.subTest(function=name):
                block = body(source, f"function {name}(")
                fallback = block[block.index("#else") :]
                self.assertIn(f"return {expected};", fallback)

    def test_void_functions_do_not_pretend_to_return_a_value(self):
        source = read(BACKEND)
        for name in ("restoreAll", "stopTaskbarFlash"):
            with self.subTest(function=name):
                self.assertIn(f"function {name}(", source)
                signature = re.search(
                    rf"public static function {name}\([^)]*\):\s*(\w+)", source
                )
                self.assertIsNotNone(signature)
                self.assertEqual("Void", signature.group(1))


class SafetyTests(unittest.TestCase):
    def test_restore_all_undoes_every_reversible_effect(self):
        restore = body(read(BACKEND), "function restoreAll(")
        for call in (
            "restoreWallpaper()",
            "restoreTaskbar()",
            "restoreAllWindows()",
            "resetWindowEffects()",
            "restoreWindowTitle()",
            "stopTaskbarFlash()",
            "setAlwaysOnTop(false)",
        ):
            with self.subTest(undone=call):
                self.assertIn(call, restore)
        # A pending typeText must be cancelled too, or text keeps arriving
        # after the game is gone.
        self.assertIn("typeToken++", restore)

    def test_restore_all_does_not_spam_traces_on_other_desktops(self):
        restore = body(read(BACKEND), "function restoreAll(")
        # The Windows-only effects are grouped behind one guard; on Linux and
        # macOS the exit hook must stay silent instead of tracing six times.
        self.assertIn("#if windows", restore)
        portable = restore[: restore.index("#if windows")]
        self.assertIn("restoreWindowTitle()", portable)
        for windows_only in ("restoreWallpaper()", "restoreTaskbar()", "stopTaskbarFlash()"):
            with self.subTest(guarded=windows_only):
                self.assertNotIn(windows_only, portable)

    def test_exit_cleanup_is_installed_by_the_engine(self):
        cleanup = body(read(BACKEND), "function installExitCleanup(")
        self.assertIn("Application.current.onExit.add", cleanup)
        self.assertIn("restoreAll()", cleanup)
        # Idempotent, so a second call cannot install the hook twice.
        self.assertIn("exitCleanupInstalled", cleanup)
        self.assertIn("MetaHorror.installExitCleanup()", read(MAIN))

    def test_launch_count_is_persisted_not_counted_per_state(self):
        cleanup = body(read(BACKEND), "function installExitCleanup(")
        self.assertIn("LAUNCH_COUNT_KEY", cleanup)
        # It must increment exactly once per process, from the exit/hook setup
        # path, not from a per-song callback.
        self.assertEqual(cleanup.count("Reflect.setField(values, LAUNCH_COUNT_KEY"), 1)

    def test_persistent_values_use_their_own_save_slot(self):
        save = body(read(BACKEND), "function getSessionSave(")
        self.assertIn("new FlxSave()", save)
        self.assertIn("PERSISTENT_SAVE_NAME", save)
        # Never write into the engine's shared save object.
        source = read(BACKEND)
        self.assertNotIn("FlxG.save.data.metaHorrorValues", source)

    def test_persistent_keys_cannot_reach_engine_fields(self):
        validator = body(read(BACKEND), "function validPersistentKey(")
        # Underscore-prefixed names are reserved for engine internals.
        self.assertIn("StringTools.startsWith(trimmed, '_')", validator)
        for guard in ("isDigit", "isUpper", "isLower"):
            with self.subTest(guard=guard):
                self.assertIn(guard, validator)

    def test_capture_desktop_writes_png_and_reports_failure(self):
        capture = body(read(BACKEND), "function captureDesktop(")
        self.assertIn("PNGEncoderOptions", capture)
        self.assertIn("saveBytes", capture)
        # Missing pixels must not create a zero-byte file.
        self.assertIn("return null", capture)

    def test_window_title_restore_keeps_the_engine_suffixes(self):
        setter = body(read(BACKEND), "function setWindowTitle(")
        restorer = body(read(BACKEND), "function restoreWindowTitle(")
        for field in ("windowNamePrefix", "windowNameSuffix", "windowNameSuffix2"):
            with self.subTest(field=field):
                # MusicBeatState rebuilds the title from these on every state
                # change, so the effects have to save and put them back.
                self.assertIn(field, setter)
                self.assertIn(field, restorer)


class NativeIncludeTests(unittest.TestCase):
    """The Windows CI build failed because the native code was unreachable.

    `MetaHorror` is an all-static class with no instance methods, so hxcpp
    never emits `#include "MetaHorror.h"` into the generated `MetaHorror.cpp`.
    A `@:headerCode` block therefore left every `@:functionCode` body
    compiling against undefined `IMMDeviceEnumerator`, `POINT`, `INPUT`, ...
    The fix is the repo-standard `@:cppFileCode` + dedicated header, and these
    tests keep it that way.
    """

    def test_native_code_is_injected_into_the_translation_unit(self):
        source = read(BACKEND)
        self.assertIn('@:cppFileCode(\'#include "phoenix_meta_horror.h"\')', source)
        # `@:headerCode` only reaches the .h, which this class never includes.
        # Match the annotation itself, not the comment that explains it.
        self.assertNotRegex(source, r"(?m)^\s*@:headerCode")

    def test_injection_metadata_is_attached_to_the_class(self):
        """The metadata must be at file level, immediately above `class`.

        Indented inside the class body both annotations would attach to the
        next field declaration instead of the class, and hxcpp would ignore
        them: no include, no build-XML include, and the Windows build fails
        with exactly the "undefined IMMDeviceEnumerator" errors this PR fixes.
        """
        lines = read(BACKEND).splitlines()
        class_at = next(i for i, line in enumerate(lines) if line.startswith("class MetaHorror"))
        preceding = [line for line in lines[:class_at] if line.strip()]
        self.assertTrue(preceding, "class has nothing above it?")
        # Walk back over the `#end`/`#if` guard to find the annotations.
        window = lines[max(0, class_at - 12):class_at]
        found = {meta: False for meta in ("@:buildXml", "@:cppFileCode")}
        for line in window:
            for meta in found:
                if line.startswith(meta):
                    found[meta] = True
                elif line.lstrip().startswith(meta):
                    self.fail(f"{meta} is indented inside the class body: {line!r}")
        self.assertEqual({m: True for m in found}, found)

    def test_header_lives_under_the_shared_native_include_folder(self):
        header = read(HEADER)
        self.assertIn("#ifndef PHOENIX_META_HORROR_H", header)
        self.assertIn("#if defined(_WIN32)", header)
        # The game-window lookup every helper depends on.
        self.assertIn('#include "phoenix_window.h"', header)

    def test_header_provides_the_types_the_function_bodies_use(self):
        header = read(HEADER)
        for include in ("<windows.h>", "<shellapi.h>", "<mmdeviceapi.h>", "<endpointvolume.h>"):
            with self.subTest(include=include):
                self.assertIn(include, header)
        # WASAPI needs Vista+ symbols.
        self.assertIn("_WIN32_WINNT 0x0600", header)

    def test_function_bodies_only_call_declared_helpers(self):
        """Every `phoenixMeta*` symbol a snippet calls must exist in the header."""
        header = read(HEADER)
        source = read(BACKEND)
        declared = set(re.findall(r"static\s+(?:PHOENIX_META_UNUSED\s+)?[\w:<>*&]+\s+(phoenixMeta\w+)\s*\(", header))
        called = set()
        for snippet in re.findall(r"@:functionCode\('(.*?)'\)", source, re.S):
            called.update(re.findall(r"(phoenixMeta\w+)\s*\(", snippet))
        self.assertTrue(called, "no native snippets found")
        missing = called - declared
        self.assertEqual(set(), missing, f"undeclared native helpers: {sorted(missing)}")

    def test_build_config_adds_include_path_and_libs(self):
        build = read(BUILD)
        self.assertIn('name="-I"', build)
        self.assertIn("include/", build)
        for lib in ("ole32.lib", "user32.lib", "shell32.lib", "gdi32.lib"):
            with self.subTest(lib=lib):
                self.assertIn(f'<lib name="{lib}"', build)
        # Same conditional shape as the other build files in the engine.
        self.assertIn('<section if="windows">', build)
        self.assertIn("meta_horror_build.xml", read(BACKEND))

    def test_snippets_are_valid_haxe_string_literals(self):
        """No raw `'` may appear inside a single-quoted Haxe metadata string.

        A single apostrophe (an English possessive in a C++ comment is enough)
        terminates the literal early and the file stops parsing - which fails
        the whole build on *every* platform before any C++ is compiled, so the
        error looks nothing like a native problem.
        """
        source = read(BACKEND)
        for match in re.finditer(r"@:(\w+)\('(.*?)'\)", source, re.S):
            with self.subTest(metadata=match.group(1), line=source[:match.start()].count("\n") + 1):
                self.assertNotIn("'", match.group(2),
                    "apostrophe inside a single-quoted @: metadata string")

    def test_snippets_stay_portable_for_the_mock_build(self):
        """No snippet may depend on a header the mock test cannot provide."""
        source = read(BACKEND)
        for snippet in re.findall(r"@:functionCode\('(.*?)'\)", source, re.S):
            with self.subTest(snippet=snippet.strip()[:40]):
                # File I/O and wide-string conversion belong in the header.
                self.assertNotIn("_wfopen", snippet)
                self.assertNotIn("ShellExecuteW", snippet)


class NativeTests(unittest.TestCase):
    def test_native_helpers_are_windows_only(self):
        source = read(BACKEND)
        for name in (
            "getSystemUptimeNative",
            "setAlwaysOnTopNative",
            "flashTaskbarNative",
            "stopTaskbarFlashNative",
            "listWindowsNative",
            "captureDesktopToBmpNative",
        ):
            with self.subTest(native=name):
                self.assertIn(f"static function {name}(", source)

    def test_enumeration_helper_is_read_only(self):
        block = body(read(HEADER), "phoenixMetaListProc(")
        self.assertIn("GetWindowTextA", block)
        # Reading the window list must never hide, move or focus anything.
        for forbidden in ("ShowWindow", "SetWindowPos", "SetForegroundWindow"):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, block)

    def test_desktop_capture_uses_the_virtual_screen(self):
        source = read(HEADER)
        block = body(source, "phoenixMetaCaptureDesktopToBmp(")
        # Multi-monitor: the virtual-screen origin can be negative, so the
        # copy must be given a left/top rather than assuming 0,0.
        self.assertIn("SM_XVIRTUALSCREEN", source)
        self.assertIn("SM_YVIRTUALSCREEN", source)
        self.assertIn("BitBlt", block)
        self.assertIn("CAPTUREBLT", block)
        # 24-bit BGR rows with 4-byte padding, and alpha dropped (a screen
        # capture's alpha channel is 0, which would read as transparent).
        self.assertIn("biBitCount = 24", block)
        self.assertIn("padding", block)
        # Every exit path releases the DIB section.
        self.assertEqual(block.count("CreateDIBSection"), 1)
        self.assertGreaterEqual(block.count("DeleteObject(dib)"), 3)
        self.assertGreaterEqual(block.count("fclose(file)"), 1)

    def test_capture_converts_to_png_in_haxe_and_cleans_up(self):
        capture = body(read(BACKEND), "function captureDesktop(")
        # Pixel buffers never cross the hxcpp boundary as Haxe arrays: the
        # native side writes a BMP, OpenFL decodes and re-encodes it.
        self.assertIn("BitmapData.fromFile", capture)
        self.assertIn("PNGEncoderOptions", capture)
        self.assertIn("deleteFile(rawPath)", capture)
        self.assertIn("finally", capture)


class ScriptBridgeTests(unittest.TestCase):
    def lua_functions(self):
        return set(REGISTER.findall(read(LUA)))

    def python_functions(self):
        return set(REGISTER.findall(read(PYTHON)))

    def test_new_api_reaches_both_script_languages(self):
        lua = self.lua_functions()
        python = self.python_functions()
        for name in NEW_API:
            exported = script_name(name)
            with self.subTest(function=exported):
                self.assertIn(exported, lua)
                self.assertIn(exported, python)

    def test_lua_and_python_export_the_same_surface(self):
        self.assertEqual(self.lua_functions(), self.python_functions())

    def test_python_lib_is_registered(self):
        self.assertIn("PyMetaHorrorLib.register(this)", read("source/psychlua/PythonScript.hx"))

    def test_bridges_never_shadow_the_transparent_window_api(self):
        window_names = set(REGISTER.findall(read(WINDOW_LUA)))
        window_python = set(REGISTER.findall(read(WINDOW_PY)))
        self.assertEqual(window_names, window_python)
        for name in window_names:
            with self.subTest(collision=name):
                self.assertNotIn(name, self.lua_functions())
                self.assertNotIn(name, self.python_functions())

    def test_bridges_only_call_the_public_backend(self):
        for rel in (LUA, PYTHON):
            with self.subTest(bridge=rel):
                source = read(rel)
                self.assertNotIn("Sys.", source)
                self.assertIn("MetaHorror.", source)

    def test_hscript_can_reach_the_backend(self):
        hscript = read("source/psychlua/HScript.hx")
        self.assertIn("interp.variables.set('MetaHorror', backend.MetaHorror)", hscript)

    def test_hscript_seeding_is_withheld_from_sandboxed_mods(self):
        hscript = read("source/psychlua/HScript.hx")
        start = hscript.index("interp.variables.set('MetaHorror'")
        # Walk back to the guard that wraps the seeding block.
        guard = hscript.rindex("if(!effectiveSandboxed())", 0, start)
        between = hscript[guard:start]
        self.assertIn("interp.variables.set('MetaHorror'", hscript[guard:])
        self.assertLess(len(between), 1200, "the seeding must be inside the sandbox guard")
        # Reaching the class directly would bypass the runtime callback rules.
        self.assertLess(guard, start)


class SandboxTests(unittest.TestCase):
    EXPECTED = {
        "getClipboardText": "engine.clipboard",
        "setClipboardText": "engine.clipboard",
        "getOpenWindowTitles": "engine.window-list",
        "captureDesktop": "engine.screen-capture",
    }

    def test_privacy_sensitive_calls_are_sandbox_guarded(self):
        security = read(SECURITY)
        for callback, rule in self.EXPECTED.items():
            with self.subTest(callback=callback):
                self.assertIn(f"'{callback}' => '{rule}'", security)

    def test_guarded_names_match_the_bridges(self):
        lua = set(REGISTER.findall(read(LUA)))
        python = set(REGISTER.findall(read(PYTHON)))
        for callback in self.EXPECTED:
            with self.subTest(callback=callback):
                # The guard keys off the registered name, so a rename in one
                # bridge without the other would silently open a hole.
                self.assertIn(callback, lua)
                self.assertIn(callback, python)


class DocsTests(unittest.TestCase):
    def test_docs_list_the_new_functions(self):
        docs = read(DOCS)
        for name in NEW_API:
            exported = script_name(name)
            with self.subTest(function=exported):
                self.assertIn(exported, docs)

    def test_site_docs_list_the_new_functions(self):
        docs = read(SITE_DOCS)
        for name in NEW_API:
            exported = script_name(name)
            with self.subTest(function=exported):
                self.assertIn(exported, docs)

    def test_docs_warn_about_the_intrusive_effects(self):
        for rel in (DOCS, SITE_DOCS):
            with self.subTest(doc=rel):
                text = read(rel).lower()
                self.assertIn("warn", text)
                self.assertIn("restore", text)


if __name__ == "__main__":
    unittest.main()
