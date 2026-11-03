"""Per-area RAM attribution for the vlog (``backend.MemoryLedger``).

The vlog must report, every frame, how much RAM each *area* is using:
engine assets, mod assets, engine code, mod code and the Haxe/Flixel/etc.
runtime reserved stuff. These source checks pin the ledger, its wiring into
``VLog`` / ``Paths`` / the script hosts, and the accounting model that makes
the five areas an approximate partition of process RSS.
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


class MemoryLedgerCoreTests(unittest.TestCase):
    def setUp(self):
        self.ledger = read("source/backend/MemoryLedger.hx")

    def test_ledger_defines_the_five_areas(self):
        # The snapshot carries exactly the five requested areas.
        for area in ("engineAssets", "modAssets", "engineCode", "modCode", "runtime"):
            self.assertRegex(self.ledger, rf"var {area}:AreaRam")
        # …and each area reports RAM, GPU and an item count.
        self.assertRegex(self.ledger, r"typedef AreaRam\s*=\s*\{\s*var ram:Float;\s*var gpu:Float;\s*var count:Int;")

    def test_public_api_surface(self):
        for fn in (
            "trackImage", "trackSound", "untrackAsset",
            "registerCode", "unregisterCode",
            "estimateInterpBytes", "captureEngineBaseline",
            "snapshot", "formatCompact", "formatDetailed",
        ):
            self.assertRegex(self.ledger, rf"public static function {fn}\(")

    def test_asset_totals_are_incremental_not_rescanned(self):
        # Per-frame cost must stay O(1): totals are maintained on cache/clear,
        # never by walking the whole asset cache each frame.
        self.assertIn("modAssetCpu += cpu", self.ledger)
        self.assertIn("engineAssetCpu += cpu", self.ledger)
        self.assertIn("modAssetCpu = Math.max(0.0, modAssetCpu - entry.cpu)", self.ledger)
        # snapshot() must not iterate the asset map (only the small code map).
        snapshot = self.ledger.split("public static function snapshot")[1].split("public static function formatCompact")[0]
        self.assertNotIn("for (entry in assets)", snapshot)
        self.assertNotIn("assets.keys()", snapshot)

    def test_engine_vs_mod_classification(self):
        # A `mods/` path segment marks a mod asset and names the mod folder.
        self.assertIn("if (parts[i] == 'mods')", self.ledger)
        self.assertIn("area: 'mod'", self.ledger)
        self.assertIn("area: 'engine'", self.ledger)
        # Windows separators are normalised before classifying.
        self.assertIn("path.split('\\\\').join('/')", self.ledger)
        # Loose shared content directly under mods/ gets a stable label.
        self.assertIn("SHARED_MOD", self.ledger)

    def test_gpu_and_cpu_asset_bytes_are_split(self):
        self.assertIn("BYTES_PER_PIXEL", self.ledger)
        # GPU-cached images free CPU pixels and count as VRAM instead.
        self.assertIn("final cpu:Float = gpuCached ? 0.0 : pixels;", self.ledger)
        self.assertIn("final gpu:Float = gpuCached ? pixels : 0.0;", self.ledger)

    def test_sound_bytes_prefer_decoded_pcm(self):
        # Decoded PCM from the OpenFL audio buffer, compressed size as a floor.
        self.assertIn("sound.__buffer", self.ledger)
        self.assertIn("buffer.data.length", self.ledger)
        self.assertIn("sound.bytesTotal", self.ledger)
        self.assertIn("@:access(openfl.media.Sound)", self.ledger)

    def test_ledger_is_fail_safe(self):
        # Every measurement that can throw is wrapped; the ledger must never
        # take the game down.
        self.assertGreaterEqual(self.ledger.count("catch (_:Dynamic)"), 4)
        self.assertIn("static function safeBytes", self.ledger)

    def test_per_mod_breakdown(self):
        self.assertIn("topMods", self.ledger)
        self.assertIn("TOP_MODS", self.ledger)
        self.assertIn("modAssetRam", self.ledger)


class MemoryLedgerAccountingTests(unittest.TestCase):
    def setUp(self):
        self.ledger = read("source/backend/MemoryLedger.hx")

    def test_partition_identity(self):
        # engineCode = heap - assetCPU - interp; modCode = lua + interp;
        # runtime = RSS - heap - lua. Together the areas approximate RSS.
        self.assertIn("Math.max(0.0, heapBytes - assetCpu - interpBytes)", self.ledger)
        self.assertIn("final modCodeRam:Float = luaBytes + interpBytes;", self.ledger)
        self.assertIn("Math.max(0.0, rssBytes - heapBytes - luaBytes)", self.ledger)

    def test_partition_sums_to_rss(self):
        # Sanity-check the model itself: with the documented formulas the five
        # areas sum to RSS (when every term is non-negative and RSS is known).
        heap, rss = 100.0, 200.0
        engine_asset_cpu, mod_asset_cpu = 20.0, 30.0
        lua, interp = 15.0, 10.0
        asset_cpu = engine_asset_cpu + mod_asset_cpu
        engine_code = max(0.0, heap - asset_cpu - interp)
        mod_code = lua + interp
        runtime = max(0.0, rss - heap - lua)
        total = engine_asset_cpu + mod_asset_cpu + engine_code + mod_code + runtime
        self.assertAlmostEqual(total, rss)

    def test_lua_is_exact_interp_is_estimated(self):
        # Lua memory is read live from the allocator; interpreters are estimated.
        self.assertIn("if (entry.kind == 'lua')", self.ledger)
        self.assertIn("INTERP_SOURCE_FACTOR", self.ledger)
        self.assertIn("estimateInterpBytes", self.ledger)
        # The detailed line must label the interpreter figure as an estimate.
        self.assertIn("est)", self.ledger)

    def test_gc_reserved_reported(self):
        self.assertIn("MEM_INFO_RESERVED", self.ledger)
        self.assertIn("gcReserved", self.ledger)


class VLogMemoryWiringTests(unittest.TestCase):
    def setUp(self):
        self.vlog = read("source/backend/VLog.hx")

    def test_frame_line_carries_the_compact_breakdown(self):
        self.assertIn("MemoryLedger.snapshot(heap, lastRssBytes)", self.vlog)
        self.assertIn("MemoryLedger.formatCompact(ram)", self.vlog)
        # The compact breakdown is appended to the per-frame FRAME line…
        frame = self.vlog.split("log('FRAME'")[1].split(");")[0]
        self.assertIn("ramCompact", frame)
        # …and to lag-spike lines so stalls carry memory context.
        lag = self.vlog.split("log(extreme ? 'EXTREME LAG' : 'LAG SPIKE'")[1].split(");")[0]
        self.assertIn("ramCompact", lag)

    def test_periodic_detailed_ram_line(self):
        self.assertIn("RAM_DETAIL_EVERY_N_FRAMES", self.vlog)
        self.assertIn("log('RAM', MemoryLedger.formatDetailed(ram))", self.vlog)

    def test_state_change_logs_a_ram_snapshot(self):
        self.assertIn("public static function logMemoryDetail():Void", self.vlog)
        state = self.vlog.split("public static function stateChanged")[1].split("public static function logMemoryDetail")[0]
        self.assertIn("logMemoryDetail()", state)

    def test_footer_reports_per_area_peaks(self):
        for peak in ("peakEngineAssets", "peakModAssets", "peakEngineCode", "peakModCode", "peakRuntime"):
            self.assertIn(peak, self.vlog)
        self.assertIn("peakRam{engAssets=", self.vlog)


class PathsMemoryWiringTests(unittest.TestCase):
    def setUp(self):
        self.paths = read("source/backend/Paths.hx")

    def test_images_and_sounds_are_tracked(self):
        self.assertIn("MemoryLedger.trackImage(key, vlogSourcePath, bitmap, vlogGpuCached)", self.paths)
        self.assertIn("MemoryLedger.trackSound(file, file, sound)", self.paths)
        # The resolved source path (not just the cache key) drives classification.
        self.assertIn("var vlogSourcePath:String = key;", self.paths)
        self.assertIn("vlogSourcePath = file;", self.paths)

    def test_cleared_assets_are_untracked(self):
        self.assertIn("MemoryLedger.untrackAsset(key)", self.paths)
        # destroyGraphic is a safety net for any freed graphic.
        self.assertIn("MemoryLedger.untrackAsset(graphic.key)", self.paths)

    def test_image_asset_event_reports_size(self):
        self.assertIn("VLog.formatBytes(bitmap.width * bitmap.height * 4)", self.paths)


class ScriptHostMemoryWiringTests(unittest.TestCase):
    def test_lua_registers_exact_memory_and_unregisters_before_close(self):
        lua = read("source/psychlua/FunkinLua.hx")
        self.assertIn("backend.MemoryLedger.registerCode(scriptName, 'lua', modFolder", lua)
        # Exact Lua allocator total: GCCOUNT (KB) * 1024 + GCCOUNTB (remainder).
        self.assertIn("Lua.gc(lua, Lua.GCCOUNT, 0) * 1024.0 + Lua.gc(lua, Lua.GCCOUNTB, 0)", lua)
        self.assertIn("backend.MemoryLedger.unregisterCode(vlogCodeId)", lua)
        # Unregistration must happen before Lua.close so the provider is never
        # called against a freed state.
        stop = lua.split("public function stop()")[1]
        self.assertLess(stop.index("unregisterCode"), stop.index("Lua.close(lua)"))

    def test_python_registers_estimate_and_unregisters(self):
        py = read("source/psychlua/PythonScript.hx")
        self.assertIn("backend.MemoryLedger.registerCode(scriptName, 'python', modFolder", py)
        self.assertIn("backend.MemoryLedger.estimateInterpBytes(code, vlogHeapBefore, vlogHeapAfter)", py)
        self.assertIn("backend.MemoryLedger.unregisterCode(vlogCodeId)", py)
        self.assertIn("final vlogHeapBefore:Float = debug.Memory.gay();", py)

    def test_hscript_registers_estimate_and_unregisters(self):
        hx = read("source/psychlua/HScript.hx")
        self.assertIn("backend.MemoryLedger.registerCode(scriptName, 'hscript', modFolder", hx)
        self.assertIn("backend.MemoryLedger.estimateInterpBytes(code, vlogHeapBefore, vlogHeapAfter)", hx)
        self.assertIn("backend.MemoryLedger.unregisterCode(vlogCodeId)", hx)

    def test_haxescript_registers_estimate_and_unregisters(self):
        hs = read("source/psychlua/HaxeScript.hx")
        self.assertIn("backend.MemoryLedger.registerCode(scriptName, 'haxescript', null", hs)
        self.assertIn("backend.MemoryLedger.estimateInterpBytes(source, vlogHeapBefore, vlogHeapAfter)", hs)
        self.assertIn("backend.MemoryLedger.unregisterCode(vlogCodeId)", hs)


class MainBaselineTests(unittest.TestCase):
    def test_main_captures_the_engine_baseline(self):
        main = read("source/Main.hx")
        self.assertIn("backend.MemoryLedger.captureEngineBaseline();", main)
        # It must run during setupGame, after the engine is initialised.
        self.assertLess(main.index("FrameProfiler.init(game.framerate)"), main.index("captureEngineBaseline()"))


class MemoryLedgerStructureTests(unittest.TestCase):
    def test_structure_checker_passes_for_ledger_and_hosts(self):
        proc = subprocess.run(
            [sys.executable, str(ROOT / "tests" / "check_vlog_haxe_structure.py"), str(ROOT)],
            capture_output=True, text=True, timeout=300,
        )
        self.assertEqual(proc.returncode, 0, f"Haxe structure checker failed:\n{proc.stdout}\n{proc.stderr}")
        for name in ("MemoryLedger.hx", "FunkinLua.hx", "HScript.hx", "HaxeScript.hx", "PythonScript.hx"):
            self.assertIsNotNone(
                re.search(rf"^OK\s+\S+{re.escape(name)}$", proc.stdout, re.MULTILINE),
                f"checker did not report OK for {name}:\n{proc.stdout}",
            )


if __name__ == "__main__":
    unittest.main()
