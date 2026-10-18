#!/usr/bin/env python3
"""Python callback parity + smoke-test coverage (#87).

These are static checks (no Haxe toolchain needed): they assert that
* every hook PlayState broadcasts reaches Python scripts,
* docs/TemplateScript.py and the new smoke test define each hook, and
* docs/python-scripting.md and script-hooks.md accurately describe the system.
"""
from __future__ import annotations

import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]

def read(rel: str) -> str:
	return (ROOT / rel).read_text(encoding="utf-8", errors="ignore")


def python_function_count() -> int:
	"""Unique functions registered for Python scripts (same rule as the generator).

	`website/scripts/generate-script-api.mjs` builds the Python page from every
	`registerFunction()` found under `source/psychlua/pystdlib/` plus
	`PythonScript.hx`, deduplicated by name. Counting it here too keeps the docs
	honest without hardcoding a number that drifts on every new function.
	"""
	names = set()
	for path in sorted((ROOT / "source" / "psychlua").rglob("*.hx")):
		rel = path.as_posix()
		if "/pystdlib/" not in rel and not rel.endswith("/PythonScript.hx"):
			continue
		names.update(re.findall(r'registerFunction\(\s*["\']([A-Za-z_]\w*)["\']', read(rel[len(str(ROOT)) + 1:])))
	return len(names)

# Canonical hook list from engine dispatch (PlayState + helpers + GameOverSubstate + CustomSubstate)
# Kept in sync with source/play/PlayState.hx and helpers.
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

class TestPythonCallbackParity(unittest.TestCase):
	def test_all_engine_hooks_dispatched_to_python(self):
		"""Every hook broadcast via callOnLuas / callOnScripts must also iterate pythonArray."""
		pstate = read("source/play/PlayState.hx")
		# callOnScripts is the unified dispatcher
		self.assertIn("for (script in pythonArray)", pstate, "PlayState.callOnScripts must iterate pythonArray")
		self.assertIn("for (script in luaArray)", pstate)
		# The old helper name still dispatches to both
		self.assertIn("callOnScripts(event", pstate)
		# Spot-check a few hooks that used to be Lua-only assumptions
		combined = read("source/play/PlayState.hx") + read("source/play/helpers/PlayStateNotes.hx") + read("source/play/helpers/PlayStateEvents.hx") + read("source/states/substates/GameOverSubstate.hx") + read("source/psychlua/CustomSubstate.hx")
		for hook in ("onCreate", "onUpdate", "onBeatHit", "onGameOver", "onEvent"):
			self.assertIn(f"'{hook}'", combined, f"hook {hook} should be dispatched via callOnScripts path")
		# goodNoteHit/opponentNoteHit are dispatched via ternary — check string presence in notes helper
		notes = read("source/play/helpers/PlayStateNotes.hx")
		for hook in ("goodNoteHit", "opponentNoteHit", "goodNoteSkip", "opponentNoteSkip"):
			self.assertIn(f"'{hook}'", notes)

	def test_python_script_initialises_same_globals_as_lua(self):
		"""PythonScript must publish the same initial globals FunkinLua does (#51, #87)."""
		py = read("source/psychlua/PythonScript.hx")
		lua = read("source/psychlua/FunkinLua.hx")
		# Sentinel parity
		self.assertIn("Function_StopLua:Dynamic", py)
		self.assertIn("set('Function_StopLua', Function_StopLua);", py)
		self.assertIn("set('Function_StopAll', Function_StopAll);", py)
		# Initial engine state — spot checks
		for var in ("curBpm", "bpm", "scrollSpeed", "songName", "difficultyName", "week", "curStage",
					"curBeat", "curStep", "score", "misses", "phoenixVersion", "inGameOver",
					"noteSkin", "splashSkin", "user_path", "buildTarget", "scriptName", "modFolder"):
			self.assertIn(f"set('{var}'", py, f"Python should publish initial global {var} like Lua")
		# Python debug flag uses its own name
		self.assertIn("set('pythonDebugMode'", py)
		self.assertIn("set('luaDebugMode'", lua)

	def test_python_has_script_interop_callbacks(self):
		"""Python must expose callOnLuas / addScript / getRunningScripts etc. (#87 callbacks)."""
		py_lib = read("source/psychlua/pystdlib/PyScriptLib.hx")
		python = read("source/psychlua/PythonScript.hx")
		self.assertIn("PyScriptLib.register(this)", python)
		for fn in ("getRunningScripts", "callOnLuas", "callOnScripts", "callScript",
				   "getGlobalFromScript", "setGlobalFromScript", "isRunning",
				   "addLuaScript", "addPythonScript", "removeLuaScript", "removePythonScript"):
			self.assertIn(fn, py_lib, f"PyScriptLib must expose {fn}")

	def test_python_dispatch_respects_both_sentinels(self):
		"""PlayState checks PythonScript.Function_StopAll, which shares value with Function_StopLua alias."""
		play = read("source/play/PlayState.hx")
		py = read("source/psychlua/PythonScript.hx")
		self.assertIn('Function_StopAll:Dynamic = "##PSYCHLUA_FUNCTIONSTOPLUA"', py)
		self.assertIn('Function_StopLua:Dynamic = "##PSYCHLUA_FUNCTIONSTOPLUA"', py)
		self.assertIn("PythonScript.Function_StopAll", play)

	def test_template_python_defines_every_hook(self):
		tmpl = read("docs/TemplateScript.py")
		for hook in ENGINE_HOOKS:
			self.assertIn(f"def {hook}(", tmpl, f"docs/TemplateScript.py missing {hook}")
		# Argument lists for the trickiest hooks must match docs/script-hooks.md
		hooks_md = read("website/docs/modding/script-hooks.md")
		# onSpawnNote has 5 args in engine and docs
		self.assertEqual(_count_call_args(read("source/play/helpers/PlayStateNotes.hx"), "onSpawnNote"),
						 _doc_params(hooks_md, "onSpawnNote"))
		for tmpl_path in ("docs/TemplateScript.py", "docs/TemplateScript.lua"):
			text = read(tmpl_path)
			for hook in ("onSpawnNote", "onEvent", "eventEarlyTrigger"):
				m = re.search(rf"{re.escape(hook)}\(([^)]*)\)", text)
				self.assertIsNotNone(m, f"{tmpl_path}:{hook}")
				params = [p for p in m.group(1).split(",") if p.strip()]
				self.assertEqual(len(params), _doc_params(hooks_md, hook), f"{tmpl_path}:{hook} param count")

	def test_smoke_test_covers_every_hook(self):
		smoke = ROOT / "docs/python-hook-smoke-test.py"
		self.assertTrue(smoke.exists(), "smoke test file must exist")
		src = smoke.read_text()
		compile(src, str(smoke), "exec")
		for hook in ENGINE_HOOKS:
			self.assertIn(f"def {hook}(", src, f"smoke test missing {hook}")
		# Must not use `global` (Hython parser doesn't support it)
		self.assertNotRegex(src, r"(?m)^\s*global\s+", "Hython parser does not support global; use captured refs")

	def test_script_hooks_doc_full_list_complete(self):
		hooks_md = read("website/docs/modding/script-hooks.md")
		self.assertIn("onDestroy", hooks_md)
		self.assertIn("goodNoteSkip", hooks_md)
		self.assertIn("opponentNoteSkip", hooks_md)
		self.assertIn("onDestroy", hooks_md.split("## Full engine list")[1])

	def test_python_scripting_doc_accuracy(self):
		doc = read("website/docs/modding/python-scripting.md")
		self.assertNotIn("128 functions", doc)
		# Counted from the engine instead of hardcoded: adding a Python function
		# without updating the docs should fail here, not silently rot.
		self.assertIn(f"{python_function_count()} functions", doc)
		self.assertIn("Python callbacks", doc)
		# Must document both sentinel names
		self.assertIn("Function_StopLua", doc)
		self.assertIn("Function_StopAll", doc)
		# Must note that Python and Lua share hook list
		self.assertIn("every hook", doc.lower())

	def test_character_python_files_loaded(self):
		"""PlayStateCharacters must load .py for characters (12.1 parity)."""
		chars = read("source/play/helpers/PlayStateCharacters.hx")
		self.assertIn("'characters/$name.py'", chars)
		self.assertIn("new PythonScript(pyFile)", chars)

def _count_call_args(source: str, hook: str) -> int:
	start = source.index(f"'{hook}'")
	open_bracket = source.index("[", start)
	depth = 0
	for i in range(open_bracket, len(source)):
		if source[i] == "[":
			depth += 1
		elif source[i] == "]":
			depth -= 1
			if depth == 0:
				inner = source[open_bracket + 1 : i]
				break
	else:
		raise AssertionError(f"unterminated arg list for {hook}")
	depth = 0
	count = 1 if inner.strip() else 0
	for ch in inner:
		if ch in "[(":
			depth += 1
		elif ch in "])":
			depth -= 1
		elif ch == "," and depth == 0:
			count += 1
	return count

def _doc_params(text: str, hook: str) -> int:
	match = re.search(rf"{re.escape(hook)}\(([^)]*)\)", text)
	assert match, f"{hook} not documented"
	params = [p for p in match.group(1).split(",") if p.strip()]
	return len(params)

if __name__ == "__main__":
	unittest.main(verbosity=2)
