#!/usr/bin/env python3
"""Real hxcpp cache/invalidation smoke test (opt in; needs Haxe + a C++ toolchain).

Run with PHOENIX_RUN_HXCPP_CACHE_TESTS=1 after installing the pinned hxcpp fork.
The fixture uses a temporary copy of the engine's real native build.xml/header;
it never edits the checkout or the user's regular object cache.
"""
from __future__ import annotations

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(
    os.environ.get("PHOENIX_RUN_HXCPP_CACHE_TESTS") == "1",
    "set PHOENIX_RUN_HXCPP_CACHE_TESTS=1 to run the native hxcpp smoke test",
)
class HxcppCacheIntegrationTests(unittest.TestCase):
    def test_cache_survives_clean_and_invalidates_for_native_headers_and_flags(self):
        if not shutil.which("haxe"):
            self.fail("haxe is required for the opted-in hxcpp cache test")

        with tempfile.TemporaryDirectory(prefix="phoenix cache test ") as temp:
            root = Path(temp)
            source = root / "source" / "backend"
            native = source / "native"
            include = native / "include"
            include.mkdir(parents=True)
            shutil.copy2(ROOT / "source/backend/NativeHardware.hx", source)
            build_xml = (ROOT / "source/backend/native/build.xml").read_text(encoding="utf-8")
            # Keep the real dependency declaration and add a test-only C++
            # flag. Toggling it must not reuse an object built with other flags.
            build_xml = build_xml.replace(
                '<files id="haxe">',
                '<files id="haxe">\n    <compilerflag value="-DPHOENIX_CACHE_PROBE_FLAG" if="PHOENIX_CACHE_PROBE_FLAG" />',
                1,
            )
            (native / "build.xml").write_text(build_xml, encoding="utf-8")
            header = include / "phoenix_hardware.h"
            original = (ROOT / "source/backend/native/include/phoenix_hardware.h").read_text(encoding="utf-8")

            def write_header(marker: str) -> None:
                # A macro after the real header changes an observable result,
                # without changing the generated Haxe C++ translation unit.
                header.write_text(
                    original
                    + "\n#include <stdio.h>\n"
                    + "#ifdef PHOENIX_CACHE_PROBE_FLAG\n"
                    + '#define PHOENIX_PROBE_SUFFIX "-flag"\n'
                    + "#else\n"
                    + '#define PHOENIX_PROBE_SUFFIX ""\n'
                    + "#endif\n"
                    + "#undef phoenixOsName\n"
                    + '#define phoenixOsName(out, cap) (snprintf((out), (cap), "%s", "'
                    + marker
                    + '" PHOENIX_PROBE_SUFFIX), 1)\n',
                    encoding="utf-8",
                )

            write_header("cache-one")
            (root / "CacheProbe.hx").write_text(
                "class CacheProbe {\n"
                "  static function main() {\n"
                "    Sys.println(backend.NativeHardware.osName());\n"
                "  }\n"
                "}\n",
                encoding="utf-8",
            )
            output = root / "build/release/smoke/obj"
            executable = output / ("CacheProbe.exe" if os.name == "nt" else "CacheProbe")
            env = os.environ.copy()
            env.update(
                HXCPP_COMPILE_CACHE=str(root / "object cache"),
                HXCPP_COMPILE_THREADS="4",
                HXCPP_CACHE_MB="2048",
            )

            def build(*extra: str) -> str:
                result = subprocess.run(
                    ["haxe", "-cp", "source", "-cp", ".", "-main", "CacheProbe", "-cpp", str(output), *extra],
                    cwd=root,
                    env=env,
                    capture_output=True,
                    text=True,
                    timeout=300,
                )
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                return result.stdout + result.stderr

            def run() -> str:
                return subprocess.run(
                    [str(executable)], cwd=root, env=env, check=True,
                    capture_output=True, text=True, timeout=30,
                ).stdout.strip()

            cold = build()
            self.assertIn("Compiling group: haxe", cold)
            self.assertEqual("cache-one", run())
            self.assertTrue(any((root / "object cache").rglob("*.obj" if os.name == "nt" else "*.o")))

            # A clean removes all generated C++ and binary output, but not the
            # content-addressed cache. No unchanged C++ group should recompile.
            shutil.rmtree(root / "build")
            warm = build()
            self.assertNotIn("Compiling group:", warm, warm)
            self.assertEqual("cache-one", run())

            # Preserve the header's old mtime: the declared dependency must be
            # hashed by content, not merely detected by filesystem timestamps.
            timestamp = header.stat().st_mtime_ns
            write_header("cache-two")
            os.utime(header, ns=(timestamp, timestamp))
            shutil.rmtree(root / "build")
            changed_header = build()
            self.assertIn("Compiling group: haxe", changed_header)
            self.assertEqual("cache-two", run())
            generated_cpp = (output / "src/backend/NativeHardware.cpp").read_bytes()

            shutil.rmtree(root / "build")
            changed_flags = build("-D", "PHOENIX_CACHE_PROBE_FLAG")
            self.assertEqual(generated_cpp, (output / "src/backend/NativeHardware.cpp").read_bytes())
            self.assertIn("Compiling group: haxe", changed_flags)
            self.assertEqual("cache-two-flag", run())


if __name__ == "__main__":
    unittest.main(verbosity=2)
