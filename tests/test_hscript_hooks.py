#!/usr/bin/env python3
"""Standalone HScript mod coverage (TODO 12.1, first-class .hx/.hscript).

Static checks (no Haxe toolchain needed), mirroring test_python_hooks.py:
* .hx/.hscript discovery exists in every script scope Lua/Python have,
* every hook PlayState broadcasts reaches standalone HScript scripts,
* docs/TemplateScript.hx defines each hook with matching arity, and
* the docs describe standalone scripts, their scope and sandboxing.
"""
from __future__ import annotations

import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]

def read(rel: str) -> str:
	return (ROOT / rel).read_text(encoding="utf-8", errors="ignore")


def lua_function_count() -> int:
	"""Unique Lua functions, counted with the API generator's exact rule.

	`website/scripts/generate-script-api.mjs` scans all of `source/psychlua/`
	for `registerFunction("name", function(...`, calls pystdlib/PythonScript
	files Python and everything else Lua, and deduplicates by name.
	"""
	names = set()
	for path in sorted((ROOT / "source" / "psychlua").rglob("*.hx")):
		rel = path.as_posix()
		if "/pystdlib/" in rel or rel.endswith("/PythonScript.hx"):
			continue
		names.update(re.findall(r'registerFunction\(\s*["\']([A-Za-z_]\w*)["\']\s*,\s*function\s*\(', read(rel[len(str(ROOT)) + 1:])))
	return len(names)

# Canonical hook list — same list as tests/test_python_hooks.py.
ENGINE_HOOKS = [
	"onCreate", "onCreatePost", "onDestroy",
	"onUpdate", "onUpdatePost",
	"onStartCountdown", "onCountdownStarted", "onCountdownTick",
	"onSongStart", "onEndSong",
	"onBeatHit", "onStepHit", "onSectionHit",
	"onSpawnNote", "goodNoteHit", "opponentNoteHit", "goodNoteSkip", "opponentNoteSkip",
	"noteMiss", "noteMissPress", "onGhostTap", "onKeyPress", "onKeyRelease",
	"onEvent", "eventEarlyTrigger",
	"onPause", "onResume", "onGameOver", "onGameOverStart", "onGameOverConfirm",
	"onNextDialogue", "onSkipDialogue",
	"onMoveCamera", "onRecalculateRating", "onUpdateScore",
	"onTweenCompleted", "onTimerCompleted", "onSoundFinished",
	"onCustomSubstateCreate", "onCustomSubstateCreatePost",
	"onCustomSubstateUpdate", "onCustomSubstateUpdatePost", "onCustomSubstateDestroy",
]

class TestHScriptDispatch(unittest.TestCase):
	def test_hooks_and_state_reach_hscript_scripts(self):
		pstate = read("source/play/PlayState.hx")
		self.assertIn("public var hscriptArray:Array<HScript>", pstate)
		self.assertIn("for (script in hscriptArray)", pstate,
			"PlayState.callOnScripts must iterate hscriptArray")
		self.assertIn("hscriptArray[i].set(variable, arg)", pstate,
			"PlayState.setOnScripts must publish to hscriptArray")
		self.assertIn("if (hscriptArray.length > 0) hasScripts = true;", pstate,
			"hasActiveScripts must count HScript-only mods, or callOnLuas returns early")
		self.assertIn("HScript.Function_StopLua", pstate)
		self.assertIn("HScript.Function_Continue", pstate)
		# HScript-only helpers used by CustomSubstate
		self.assertIn("public function callOnHScript(", pstate)
		self.assertIn("public function setOnHScript(", pstate)

	def test_destroy_lifecycle(self):
		pstate = read("source/play/PlayState.hx")
		self.assertIn("hx.call('onDestroy', [])", pstate)
		self.assertIn("hx.stop()", pstate)
		self.assertIn("HScript.customFunctions.clear()", pstate)
		self.assertIn("HScript.registeredFunctions.clear()", pstate)


class TestHScriptDiscovery(unittest.TestCase):
	def test_all_scopes_discover_hx_and_hscript(self):
		pstate = read("source/play/PlayState.hx")
		# Folder-scanned scopes (global scripts + per-song data/)
		self.assertGreaterEqual(pstate.count("HScript.fromFile(folder + file)"), 2)
		self.assertIn("HScript.isHScriptFile(file)", pstate)
		# .hx and .hscript are one logical script in scanned folders
		self.assertIn("HScript.scriptBaseName(file)", pstate)
		self.assertIn("hscriptChoices", pstate)
		# Named scopes go through the shared loader (extension optional there)
		self.assertIn("startHScriptOnFolder('stages/' + curStage)", pstate)
		self.assertIn("startHScriptOnFolder('custom_notetypes/' + notetype)", pstate)
		self.assertIn("startHScriptOnFolder('custom_events/' + event)", pstate)
		chars = read("source/play/helpers/PlayStateCharacters.hx")
		self.assertIn("state.startHScriptOnFolder('characters/$name')", chars)

	def test_loader_prefers_hx_then_hscript_and_dedups(self):
		pstate = read("source/play/PlayState.hx")
		self.assertIn("[hxFile + '.hx', hxFile + '.hscript']", pstate)
		self.assertIn("if(script.scriptName == resolved) return false;", pstate)
		self.assertIn("public function removeHScript(hxFile:String)", pstate)
		self.assertIn("script.call('onDestroy', [])", pstate)

	def test_extension_helpers(self):
		hs = read("source/psychlua/HScript.hx")
		self.assertIn("lower.endsWith('.hx') || lower.endsWith('.hscript')", hs)
		self.assertIn("public static function isHScriptFile(", hs)
		self.assertIn("public static function scriptBaseName(", hs)


class TestStandaloneHost(unittest.TestCase):
	def test_no_lua_parent_required(self):
		"""The whole point of TODO 12.1: loading must not flow through FunkinLua."""
		hs = read("source/psychlua/HScript.hx")
		self.assertIn("public static function fromFile(scriptName:String", hs)
		self.assertIn("function loadStandalone(scriptName:String", hs)
		self.assertIn("game.hscriptArray.push(this)", hs)
		self.assertIn("call('onCreate', [])", hs)
		# parentLua only exists when Lua is compiled, so standalone HScript
		# works at -DMODDING_LEVEL=0 (no Lua at all).
		m = re.search(r"#if LUA_ALLOWED\s*\n\s*/\*\*.*?\*/\s*\n\s*public var parentLua:FunkinLua;", hs, re.S)
		self.assertIsNotNone(m, "parentLua must be LUA_ALLOWED-guarded")

	def test_security_checked_before_interpreter_exists(self):
		hs = read("source/psychlua/HScript.hx")
		self.assertIn("ModSecurity.checkScript(scriptName, code, 'haxe')", hs)
		load = hs[hs.index("function loadStandalone"):]
		self.assertLess(load.index("ModSecurity.checkScript"),
						load.index("interp = new Interp()"),
			"sandbox decision must precede interpreter creation (mirrors PythonScript)")
		# Sandboxed scripts cannot resolve host classes at runtime.
		self.assertIn("interp.importEnabled = !sandboxed", hs)
		# Runtime loader-callback guard parity with PythonScript.set()
		self.assertIn("ModSecurity.isRuntimeCallbackBlocked(variable, sandboxed, securityAllowlist)", hs)

	def test_sentinel_and_global_parity_with_lua_python(self):
		hs = read("source/psychlua/HScript.hx")
		for sentinel in ("##PSYCHLUA_FUNCTIONSTOP", "##PSYCHLUA_FUNCTIONCONTINUE", "##PSYCHLUA_FUNCTIONSTOPLUA"):
			self.assertIn(sentinel, hs)
			self.assertIn(sentinel, read("source/psychlua/PythonScript.hx"))
		for var in ("curBpm", "bpm", "scrollSpeed", "songName", "difficultyName", "week", "curStage",
					"curBeat", "curStep", "score", "misses", "phoenixVersion", "inGameOver",
					"noteSkin", "splashSkin", "user_path", "buildTarget", "scriptName", "modFolder",
					"hscriptDebugMode"):
			self.assertIn(f"set('{var}'", hs, f"HScript should publish initial global {var} like Lua/Python")

	def test_scope_seeding(self):
		hs = read("source/psychlua/HScript.hx")
		for name in ("'FlxG'", "'FlxSprite'", "'FlxTween'", "'game'", "'PlayState'", "'Paths'",
					 "'ClientPrefs'", "'Conductor'", "'Math'", "'Std'", "'FlxColor'",
					 "'debugPrint'", "'setVar'", "'getVar'", "'addHaxeLibrary'",
					 "'createGlobalCallback'", "'createCallback'", "'parentLua'"):
			self.assertIn(f"interp.variables.set({name}", hs, f"seedScope must seed {name}")
		# FlxColor is an abstract: scripts get a constructor shim instead
		self.assertIn("fromRGB: function(r:Int, g:Int, b:Int", hs)
		# Standalone-only inter-script API
		for fn in ("addHScript", "removeHScript", "addScript", "getRunningScripts", "isRunning", "callOnScripts"):
			self.assertIn(f"set('{fn}'", hs, f"standalone scripts must be seeded {fn}")
		# public/static top-level variables get their own buckets
		self.assertIn("interp.allowPublicVariables = true", hs)
		self.assertIn("interp.allowStaticVariables = true", hs)
		self.assertIn("interp.publicVariables.exists(name)", hs)

	def test_custom_substate_parity(self):
		sub = read("source/psychlua/CustomSubstate.hx")
		self.assertIn("public static function implementHScript(hscript:HScript)", sub)
		self.assertIn("setOnHScript('customSubstate', instance)", sub)
		hs = read("source/psychlua/HScript.hx")
		self.assertIn("CustomSubstate.implementHScript(this)", hs)


class TestInteropAndSecurityRules(unittest.TestCase):
	def test_lua_and_python_can_manage_hscript(self):
		lua_lib = read("source/psychlua/callbacks/ScriptCallbacks.hx")
		py_lib = read("source/psychlua/pystdlib/PyScriptLib.hx")
		for fn in ("addHScript", "removeHScript"):
			self.assertIn(f'registerFunction("{fn}"', lua_lib, f"Lua must expose {fn}")
			self.assertIn(f'registerFunction("{fn}"', py_lib, f"Python must expose {fn}")
		self.assertIn("hscriptArray", lua_lib, "Lua getRunningScripts must list HScript")
		self.assertIn('candidates.push(file + ".hx")', py_lib)
		self.assertIn('candidates.push(file + ".hscript")', py_lib)
		self.assertIn("PlayState.instance.hscriptArray", py_lib)

	def test_script_loader_blocked_like_lua_python(self):
		sec = read("source/backend/ModSecurity.hx")
		self.assertIn("'addHScript' => 'engine.script-loader'", sec)
		scanner = read("source/backend/ScriptSecurityScanner.hx")
		self.assertIn("addLuaScript|addPythonScript|addHScript|addScript", scanner)


class TestTemplateAndDocs(unittest.TestCase):
	def test_template_defines_every_hook(self):
		tmpl = read("docs/TemplateScript.hx")
		self.assertEqual(tmpl, read("example_mods/scripts/TemplateScript.hx"),
			"docs/ and example_mods/ templates must stay identical")
		for hook in ENGINE_HOOKS:
			self.assertIn(f"function {hook}(", tmpl, f"docs/TemplateScript.hx missing {hook}")
		hooks_md = read("website/docs/modding/script-hooks.md")
		for hook in ("onSpawnNote", "onEvent", "eventEarlyTrigger"):
			self.assertEqual(_count_params(tmpl, hook), _count_params(hooks_md, hook),
							 f"TemplateScript.hx:{hook} arity must match script-hooks.md")

	def test_docs_describe_standalone_scripts(self):
		doc = read("website/docs/modding/hscript.md")
		self.assertIn("Standalone scripts", doc)
		self.assertIn("No Lua parent required", doc)
		self.assertIn("stages/<stage>.hx", doc)
		self.assertIn("characters/<name>.hx", doc)
		self.assertIn("TemplateScript.hx", doc)
		folders = read("website/docs/modding/mod-folder-structure.md")
		self.assertIn("*.hscript", folders)
		self.assertIn("characters/<name>.lua` / `.py` / `.hx` / `.hscript`", folders)
		runtime = read("website/docs/subsystems/scripting-runtime.md")
		self.assertIn("hscriptArray", runtime)

	def test_api_function_counts_in_docs(self):
		# Counted from the engine (generator rule above) instead of hardcoded:
		# adding a Lua function without updating the docs should fail here.
		count = lua_function_count()
		self.assertIn(f"{count} Lua functions", read("website/docs/modding/overview.md"))
		self.assertIn(f"all {count} functions", read("website/docs/modding/lua-scripting.md"))

def _count_params(text: str, hook: str) -> int:
	m = re.search(rf"{re.escape(hook)}\(([^)]*)\)", text)
	assert m, f"{hook} not found"
	return len([p for p in m.group(1).split(",") if p.strip()])


if __name__ == "__main__":
	unittest.main(verbosity=2)
