"""Compile and execute the hardware header independently of Haxe/Lime.

The header is the only piece of the GPU/CPU detection feature that speaks
C, so it gets the same standalone treatment as ``phoenix_system.h``: the test
compiles it as C and as C++ (two translation units, to catch header-only
linkage regressions) and checks that the queries return sane values.

Run:  python3 -m unittest discover -s tests -p 'test_native_hardware.py' -v
"""
import pathlib
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
INCLUDE = ROOT / "source/backend/native/include"


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8", errors="ignore")


def registered_names(rel: str) -> set:
    """Names passed to registerFunction(...) inside a script host module."""
    source = read(rel)
    return set(re.findall(r'registerFunction\(\s*"([A-Za-z_]\w*)"', source))


class NativeHardwareTests(unittest.TestCase):
    def check_compiler(self, compiler, standard):
        if not shutil.which(compiler):
            self.skipTest(f"{compiler} is not installed")
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            # Two translation units catch header-only linkage regressions.
            (root / "other.c").write_text(
                '#include "phoenix_hardware.h"\n'
                "int other(void)\n{\n"
                "  char buffer[64];\n"
                "  return phoenixCpuModel(buffer, sizeof(buffer));\n"
                "}\n"
            )
            (root / "main.c").write_text(r'''
#include "phoenix_hardware.h"
#include "phoenix_hardware.h"
#include <assert.h>
#include <string.h>
extern int other(void);
int main(void)
{
  char vendor[64];
  char model[64];
  char osName[64];
  char osVersion[64];
  int ok;
  memset(vendor, 0, sizeof(vendor));
  memset(model, 0, sizeof(model));
  memset(osName, 0, sizeof(osName));
  memset(osVersion, 0, sizeof(osVersion));
  /* Every query must leave a NUL terminated string behind, even when the
     platform cannot answer it. */
  ok = phoenixCpuVendor(vendor, sizeof(vendor));
  assert(ok == 0 || ok == 1);
  assert(vendor[sizeof(vendor) - 1] == 0);
  ok = phoenixCpuModel(model, sizeof(model));
  assert(ok == 0 || ok == 1);
  assert(model[sizeof(model) - 1] == 0);
  ok = phoenixOsName(osName, sizeof(osName));
  assert(ok == 0 || ok == 1);
  assert(osName[sizeof(osName) - 1] == 0);
  ok = phoenixOsVersion(osVersion, sizeof(osVersion));
  assert(ok == 0 || ok == 1);
  assert(osVersion[sizeof(osVersion) - 1] == 0);
  /* A buffer of one byte can only hold the terminator. */
  {
    char tiny[1];
    tiny[0] = 'x';
    phoenixCpuModel(tiny, sizeof(tiny));
    assert(tiny[0] == 0);
  }
  assert(other() >= 0);
  return 0;
}
''')
            executable = root / "test"
            subprocess.run([
                compiler, f"-std={standard}", "-Wall", "-Wextra", "-Werror",
                "-I", str(INCLUDE), str(root / "main.c"), str(root / "other.c"),
                "-o", str(executable),
            ], check=True, capture_output=True, text=True)
            subprocess.run([str(executable)], check=True)

    def test_c(self):
        self.check_compiler("cc", "gnu99")

    def test_cpp(self):
        self.check_compiler("c++", "c++11")


class HardwareWiringTests(unittest.TestCase):
    """The Haxe side of the hardware detection, checked without a toolchain."""

    LUA = "source/psychlua/callbacks/HardwareCallbacks.hx"
    PYTHON = "source/psychlua/pystdlib/PyHardwareLib.hx"

    def test_public_api(self):
        source = read("source/backend/Native.hx")
        for name in (
            "getSystemInfo",
            "getGPUName",
            "getGPUVendor",
            "getGPUDriverVersion",
            "getCPUName",
            "getCPUVendor",
            "getOSName",
            "getOSVersion",
            "getGraphicsApi",
            "buildSystemInfo",
        ):
            self.assertIn(f"function {name}(", source, f"{name} missing from backend.Native")
        # The detection must never throw: unknown values are reported instead.
        self.assertIn('UNKNOWN:String = "Unknown"', source)

    def test_native_stub_for_other_targets(self):
        source = read("source/backend/NativeHardware.hx")
        self.assertIn("#if cpp", source)
        self.assertIn("#else", source)
        # The non-C++ branch has to answer with empty strings.
        stub = source.split("#else", 1)[1]
        for name in ("cpuVendor", "cpuModel", "osName", "osVersion"):
            self.assertIn(f"function {name}():String", stub)

    def test_build_xml_adds_include_path(self):
        source = read("source/backend/native/build.xml")
        self.assertIn('<compilervalue name="-I"', source)
        self.assertIn("include/", source)

    def test_lua_and_python_expose_the_same_functions(self):
        lua = registered_names(self.LUA)
        python = registered_names(self.PYTHON)
        self.assertTrue(lua, "no Lua hardware callbacks registered")
        # The Lua table helper has no Python twin on purpose (Hython cannot
        # return a Haxe structure), everything else must be symmetric.
        self.assertEqual(lua - {"getSystemInfoTable"}, python)
        for name in ("getGPUName", "getGPUVendor", "getGPUDriverVersion", "getCPUName"):
            self.assertIn(name, lua)
            self.assertIn(name, python)

    def test_hosts_register_the_callbacks(self):
        self.assertIn("HardwareCallbacks.register(this);", read("source/psychlua/FunkinLua.hx"))
        self.assertIn("PyHardwareLib.register(this);", read("source/psychlua/PythonScript.hx"))

    def test_hscript_exposes_the_class(self):
        source = read("source/psychlua/HScript.hx")
        self.assertIn("interp.variables.set('Native', Native);", source)

    def test_crash_log_contains_the_hardware(self):
        source = read("source/backend/CrashHandler.hx")
        self.assertIn("Native.buildSystemInfo()", source)
        # The crash log must still be written when the hardware query fails.
        self.assertIn("File.saveContent(path,", source)


if __name__ == "__main__":
    unittest.main()
