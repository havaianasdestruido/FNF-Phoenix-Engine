"""VLog (vlog/log.txt) wiring checks.

The vlog is opt-in (off by default, enabled from Options -> Misc). When it is
on, it must write an aggressively verbose session log to ``vlog/log.txt`` and
expose it on Android through the SAF VLogs root, just like ``mods/`` and
``crash/``. These source checks pin the wiring: the default-off pref and menu
toggle, initialization order in ``Main``, the game-loop hooks in the patched
``FlxGame``, the RAM asset-cache hooks in ``Paths``, the crash mirror in
``CrashHandler`` and the Lua/Python/HScript trace capture.
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

import unittest

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8-sig")


class VLogCoreTests(unittest.TestCase):
    def setUp(self):
        self.vlog = read("source/backend/VLog.hx")

    def test_log_path_is_vlog_log_txt(self):
        self.assertIn('public static inline var DIR:String = "vlog";', self.vlog)
        self.assertIn('public static inline var FILE:String = "vlog/log.txt";', self.vlog)

    def test_opt_in_switch_and_runtime_toggle(self):
        # Off until the player asks for it.
        self.assertRegex(self.vlog, r"public static var enabled:Bool = false;")
        # Options -> Misc drives it at runtime; enabling starts a session,
        # disabling closes it and restores the original trace() printer.
        self.assertIn("public static function setEnabled(on:Bool, ?targetFps:Float = null):Void", self.vlog)
        # Nothing is created on disk while the log is off: `init()` seeds only
        # the in-memory tail and returns before the session starts.
        self.assertIn("if (initialized) return;\n    seedTail();\n    if (!enabled) return;", self.vlog)
        # …and `log()` still refuses to touch the session buffer/file when off.
        self.assertIn("appendTail(line);\n\n    if (!initialized) return;", self.vlog)
        self.assertIn("previousTrace = haxe.Log.trace;", self.vlog)
        self.assertIn("haxe.Log.trace = previousTrace;", self.vlog)

    def test_enabled_build_writes_or_buffers_the_log(self):
        # File targets create the directory and append to the file…
        self.assertRegex(self.vlog, r"if \(!FileSystem\.exists\(DIR\)\) FileSystem\.createDirectory\(DIR\)")
        # File.write() truncates; File.append() is what keeps the log across
        # flushes (Haxe 4.3: write(path, binary) has no append mode).
        self.assertRegex(self.vlog, r"final f = File\.append\(FILE, false\)")
        # …web builds (no writable filesystem) cap an in-memory buffer and
        # offer a browser download instead.
        self.assertIn("MAX_WEB_CHARS", self.vlog)
        self.assertIn("new js.html.Blob([exportText()]", self.vlog)
        self.assertIn("anchor.download = 'log.txt';", self.vlog)
        self.assertIn("public static function exportText():String", self.vlog)

    def test_trace_hook_captures_engine_lua_python_and_hscript(self):
        # Haxe 4.3 has no traceHook; trace() is rebound via haxe.Log.trace.
        self.assertIn("haxe.Log.trace = onTrace", self.vlog)
        for language in ("'Lua'", "'Python'", "'HScript'", "'Engine'"):
            self.assertIn(language, self.vlog)
        # The rebound trace must keep the console output (rebinding replaces
        # the default printer) — mirror it with haxe.Log.formatOutput. The
        # try body must be a block: Haxe 4.3 binds one expression as the try
        # body, so a `;`-terminated brace-less body orphans the catch clause
        # and fails to compile.
        self.assertRegex(self.vlog, r"#if sys\s*\n\s*try\s*\n\s*\{\s*\n\s*Sys\.println\(haxe\.Log\.formatOutput\(value, posInfos\)\)")
        # …and multi-argument trace() values ride on PosInfos.customParams.
        self.assertIn("posInfos.customParams", self.vlog)

    def test_frame_lines_ram_and_lag_spikes(self):
        # One line per frame with FPS, frametime, work time, heap and RSS.
        for token in ("'FRAME'", "fps=", "frame=", "work=", "heap=", "rss=", "state="):
            self.assertIn(token, self.vlog)
        # Lag spikes need a threshold and a dedicated line.
        self.assertIn("LAG_SPIKE_MIN_MS", self.vlog)
        self.assertIn("LAG_EXTREME_MS", self.vlog)
        self.assertIn("'LAG SPIKE'", self.vlog)
        self.assertIn("'EXTREME LAG'", self.vlog)
        # RAM: managed heap + process RSS, with peaks for the footer.
        self.assertIn("heapUsedBytes", self.vlog)
        self.assertIn("GetTotalMemory.getCurrentRSS()", self.vlog)
        self.assertIn("peakHeapBytes", self.vlog)
        self.assertIn("peakRssBytes", self.vlog)

    def test_session_header_footer_and_rotation(self):
        self.assertIn("SESSION START", self.vlog)
        self.assertIn("SESSION END", self.vlog)
        self.assertIn("Application.current.onExit", self.vlog)
        self.assertIn("rotateIfNeeded", self.vlog)
        self.assertIn("MAX_LOG_BYTES", self.vlog)
        self.assertIn("MAX_ROTATED", self.vlog)
        # The writer must never take the game down.
        self.assertRegex(self.vlog, r"flushFailed = true")

    def test_rss_header_uses_internal_linkage(self):
        # hxcpp includes memory.h into every generated .cpp that
        # references debug.mem.GetTotalMemory. VLog is the second
        # referencing module after debug.FPSCounter, so the header's
        # definitions must have internal linkage — without `static`,
        # the windows/android link fails with LNK2005 "multiply
        # defined symbols" for getCurrentRSS/getPeakRSS.
        mem = (ROOT / "source" / "debug" / "mem" / "include" / "memory.h").read_text(encoding="utf-8-sig")
        self.assertIn("static size_t getPeakRSS()", mem)
        self.assertIn("static size_t getCurrentRSS()", mem)

    def test_lag_thresholds_are_sane(self):
        # 25 ms floor (a 60 fps frame is 16.7 ms) and a 100 ms "extreme"
        # marker, both as floats so the comparison is not integer-truncated.
        self.assertRegex(self.vlog, r"LAG_SPIKE_MIN_MS:Float = 25\.0")
        self.assertRegex(self.vlog, r"LAG_EXTREME_MS:Float = 100\.0")


class VLogWiringTests(unittest.TestCase):
    def test_main_initializes_vlog_before_crash_handler_and_after_mobile_storage(self):
        main = read("source/Main.hx")
        # The saved opt-in flag is read straight from funkin.sol because
        # FlxG.save is only bound later, in InitState.
        self.assertIn("backend.VLog.init(game.framerate, ClientPrefs.readSavedBool('vlogEnabled'))", main)
        self.assertIn("public static function readSavedBool(field:String, defaultValue:Bool = false):Bool", read("source/backend/ClientPrefs.hx"))
        # Order: mobile storage (cwd) -> vlog -> crash handler.
        self.assertLess(main.index("backend.VLog.init("), main.index("CrashHandler.init()"))
        if "mobile.StorageUtil.initStorageDirectory()" in main:
            self.assertLess(main.index("mobile.StorageUtil.initStorageDirectory()"), main.index("backend.VLog.init("))
        # And it must run before setupGame so the whole boot is covered.
        self.assertLess(main.index("backend.VLog.init("), main.index("setupGame();"))

    def test_misc_options_menu_exposes_the_toggle(self):
        prefs = read("source/backend/ClientPrefs.hx")
        # Off by default, like every other opt-in pref.
        self.assertRegex(prefs, r"public static var vlogEnabled:Bool = false;")
        misc = read("source/options/MiscSettingsSubState.hx")
        self.assertIn("new Option('Enable VLog'", misc)
        self.assertIn("'vlogEnabled'", misc)
        # The option drives the live vlog, not just the saved pref.
        self.assertIn("option.onChange = () -> backend.VLog.setEnabled(ClientPrefs.vlogEnabled);", misc)

    def test_init_state_resyncs_the_toggle_after_load_prefs(self):
        # Safety net: if the early raw read could not open funkin.sol, the
        # value loadPrefs() just read is applied before anything else runs.
        init = read("source/states/InitState.hx")
        self.assertIn("backend.VLog.setEnabled(ClientPrefs.vlogEnabled);", init)
        self.assertLess(init.index("ClientPrefs.loadPrefs();"), init.index("backend.VLog.setEnabled(ClientPrefs.vlogEnabled);"))

    def test_flxgame_reports_every_frame_and_state_change_to_vlog(self):
        flxgame = read("source/source-haxelib-patches/flixel/FlxGame.hx")
        self.assertRegex(
            flxgame,
            r"backend\.VLog\.onFrame\(_elapsedMS, getTimer\(\) - vlogWorkStart,"
            r"\s*FlxG\.renderTile \? FlxDrawBaseItem\.drawCalls : 0, vlogUpdates, _lostFocus\)",
        )
        # The update count must track both the fixed-timestep and the
        # variable-timestep step() paths.
        self.assertEqual(flxgame.count("vlogUpdates++"), 2)
        self.assertIn("backend.VLog.stateChanged(vlogOldState", flxgame)
        # The outgoing state name is captured before the old state dies.
        self.assertLess(
            flxgame.index("final vlogOldState:String"),
            flxgame.index("_state.destroy();"),
        )

    def test_paths_logs_ram_asset_caching(self):
        paths = read("source/backend/Paths.hx")
        # Images entering the cache (CPU vs GPU), with dimensions.
        self.assertRegex(paths, r"VLog\.assetCached\('image', key, bitmap\.width")
        # Sounds decoded into RAM, decode failures and missing assets.
        self.assertRegex(paths, r"VLog\.assetCached\('sound', file, 'decoded into RAM")
        self.assertIn("VLog.assetCached('sound', file, 'DECODE FAILED:", paths)
        self.assertIn("VLog.assetCached('sound', file, 'MISSING", paths)
        # Note skins / splashes.
        self.assertIn("VLog.assetCached('noteskin', noteSkin", paths)
        self.assertIn("VLog.assetCached('noteskin', 'splash: '", paths)
        # Memory management events: clears and explicit GC with heap before/after.
        self.assertIn("VLog.memoryEvent('clearUnusedMemory:", paths)
        self.assertIn("VLog.memoryEvent('clearStoredMemory:", paths)
        self.assertIn("VLog.memoryEvent('explicit GC ", paths)
        self.assertIn("VLog.memoryEvent('heap compact", paths)

    def test_crash_handler_mirrors_crashes_into_the_vlog(self):
        crashes = read("source/backend/CrashHandler.hx")
        # Braced try body: a brace-less body would not compile (see the
        # VLog structure checker for the Haxe 4.3 try-body rule).
        self.assertRegex(crashes, r"try\s*\n\s*\{\s*\n\s*VLog\.crash\(errorMessage, stackLabel\)")

    def test_lua_and_python_traces_are_captured_even_when_debug_mode_is_off(self):
        lua = read("source/psychlua/LuaUtils.hx")
        self.assertIn("backend.VLog.scriptTrace('Lua', text)", lua)
        python = read("source/psychlua/PythonScript.hx")
        self.assertIn("backend.VLog.scriptTrace('Python', text)", python)
        # …and when debug mode IS on they go through trace(), which the
        # rebound haxe.Log.trace records as well (classifyTrace tags by the
        # caller file).
        self.assertIn("trace(text)", lua)
        self.assertIn("trace(text)", python)
        self.assertIn("LuaUtils.hx'", read("source/backend/VLog.hx"))
        self.assertIn("PythonScript.hx'", read("source/backend/VLog.hx"))

    def test_android_saf_exposes_the_vlog_root(self):
        provider = read("source/android/src/quack/fnf/phoenix/android/PhoenixDocumentsProvider.java")
        self.assertIn('private static final String ROOT_VLOG = "vlog";', provider)
        self.assertRegex(
            provider,
            r'new RootInfo\(ROOT_VLOG, new File\(storageDirectory, ROOT_VLOG\), "VLogs", '
            r'"Phoenix Engine verbose logs", false\)',
        )


class VLogStructureTests(unittest.TestCase):
    def test_haxe_structure_checker_passes(self):
        # Catches brace/paren imbalance, unbalanced #if blocks and the
        # Haxe 4.3 brace-less try/catch-body trap (a `;`-terminated brace-less
        # try body orphans its catch clause and fails compilation).
        proc = subprocess.run(
            [sys.executable, str(ROOT / "tests" / "check_vlog_haxe_structure.py"), str(ROOT)],
            capture_output=True, text=True, timeout=300,
        )
        self.assertEqual(
            proc.returncode, 0,
            f"Haxe structure checker failed:\n{proc.stdout}\n{proc.stderr}",
        )
        for line in ("VLog.hx", "Main.hx", "Paths.hx", "CrashHandler.hx"):
            self.assertIsNotNone(
                re.search(rf"^OK\s+\S+{line}$", proc.stdout, re.MULTILINE),
                f"checker did not report OK for {line}:\n{proc.stdout}",
            )


class VLogDocsTests(unittest.TestCase):
    def test_android_platform_docs_list_the_vlog_root(self):
        docs = read("docs/ANDROID_PLATFORM.md")
        self.assertRegex(docs, r"\|\s*\*\*VLogs\*\*\s*\|\s*`vlog/`\s*\|")
        self.assertIn("backend.VLog", docs)

    def test_debug_docs_explain_the_vlog(self):
        docs = read("website/docs/subsystems/debug-and-crash.md")
        self.assertIn("vlog/log.txt", docs)
        self.assertIn("backend.VLog", docs)


if __name__ == "__main__":
    unittest.main()
