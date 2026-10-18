"""Static integration guards for the Lua/Python softmod sandbox (#77).

The dependency-free matcher itself is executed by tests/haxe/ModSecuritySpec.hx.
These checks make sure both interpreters and every runtime escape hatch remain wired to
that scanner before mod code can run.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8-sig")


class ModSecurityIntegration(unittest.TestCase):
    def test_lua_is_scanned_before_vm_or_array_registration(self):
        lua = read("source/psychlua/FunkinLua.hx")
        check = lua.index("ModSecurity.checkScript(scriptName, source, 'lua')")
        self.assertLess(check, lua.index("lua = LuaL.newstate()", check))
        self.assertLess(check, lua.index("game.luaArray.push(this)", check))
        self.assertIn("ModSecurity.luaBootstrap(securityAllowlist)", lua)
        self.assertIn("LuaL.loadbuffer(lua, source", lua)
        self.assertIn("haxe.io.Bytes.ofString(source).length", lua)

    def test_python_is_scanned_before_interpreter_or_array_registration(self):
        py = read("source/psychlua/PythonScript.hx")
        check = py.index("ModSecurity.checkScript(scriptName, code, 'python')")
        self.assertLess(check, py.index("interp = new Interp()", check))
        self.assertLess(check, py.index("game.pythonArray.push(this)", check))
        self.assertIn("interp.allowClassResolve = false", py)
        self.assertIn("ModSecurity.isRuntimeCallbackBlocked", py)

    def test_runtime_guards_cover_callbacks_reflection_and_hscript(self):
        convert = read("source/psychlua/Convert.hx")
        self.assertIn("isRuntimeCallbackBlocked(callbackName", convert)
        self.assertLess(convert.index("isRuntimeCallbackBlocked(callbackName"),
                        convert.index("callbackMethod:Dynamic", convert.index("isRuntimeCallbackBlocked(callbackName")))
        self.assertIn("activeScript.allowClassAccess(args[0])", convert)
        self.assertIn("py.allowClassAccess(classVar)",
                      read("source/psychlua/pystdlib/PyPropertyLib.hx"))
        hscript = read("source/psychlua/HScript.hx")
        self.assertIn("ScriptSecurityScanner.scan(codeToRun, 'haxe'", hscript)
        self.assertGreaterEqual(hscript.count("allowClassAccess(str + libName)"), 2)

    def test_denylist_has_required_categories_and_line_reports(self):
        scanner = read("source/backend/ScriptSecurityScanner.hx")
        for token in ("os\\s*", "io\\s*", "python.dangerous-import",
                      "process.shell", "network.url", "http", "saveFile",
                      "sys\\s*\\.\\s*io", "Sys\\s*\\.\\s*"):
            self.assertIn(token, scanner)
        security = read("source/backend/ModSecurity.hx")
        self.assertIn("line=${finding.line}", security)
        self.assertIn("mod=\"${check.modName}\"", security)
        self.assertIn("script=\"${check.displayPath}\"", security)

    def test_pack_policy_is_default_on_with_explicit_exceptions(self):
        security = read("source/backend/ModSecurity.hx")
        self.assertIn("var enabled:Bool = true", security)
        self.assertIn("scriptSandbox", security)
        self.assertIn("scriptSandboxAllowlist", security)
        self.assertIn("allowUnsafeScripts", security)
        docs = read("website/docs/modding/script-security.md")
        self.assertIn('"scriptSandbox": false', docs)
        self.assertIn('"scriptSandboxAllowlist"', docs)
        self.assertIn("not an operating-system sandbox", docs)

    def test_dependency_free_scanner_runs_in_haxe_ci(self):
        runner = read("tests/haxe/run-layout.sh")
        self.assertIn("ScriptSecurityScanner.hx", runner)
        self.assertIn("ModSecurity.hx", runner)
        self.assertIn("-main ModSecuritySpec --interp", runner)


if __name__ == "__main__":
    unittest.main()
