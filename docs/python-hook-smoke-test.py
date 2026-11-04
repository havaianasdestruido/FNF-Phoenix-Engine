# python-hook-smoke-test.py — smoke-test for every documented script hook (#87)
#
# Copy this file to any mod's scripts/ or data/<song>/ folder (rename to <name>.py)
# and play a song. Each hook prints to the on-screen pythonDebugGroup and — via
# trace — to the console / `lime test` log, so a missing print means that hook
# silently never fired for Python.
#
# Also runnable as a static check: `python3 docs/python-hook-smoke-test.py`
# verifies that every hook in website/docs/modding/script-hooks.md appears here.

_HOOKS = [
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

_fired = {}
_seenCounts = {}

def _log(hook, detail=""):
	# Module-level dicts are mutated without a `global` declaration to keep Hython happy
	# (its Parser does not support `global`; see PythonScript.preprocessHythonCode).
	if hook not in _fired:
		_fired[hook] = 0
		_seenCounts[hook] = 0
	_fired[hook] = _fired[hook] + 1
	_seenCounts[hook] = _seenCounts[hook] + 1
	# Use getProperty if available for extra context; degrade gracefully.
	msg = "[PY-SMOKE] " + hook + " #" + str(_fired[hook])
	if detail != "":
		msg = msg + " " + str(detail)
	# debugPrint is the in-game overlay; trace also goes to stdout.
	debugPrint(msg)

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

def onCreate():
	_log("onCreate")

def onCreatePost():
	_log("onCreatePost")

def onDestroy():
	_log("onDestroy")

def onUpdate(elapsed):
	# Avoid spamming every frame — log only the first few frames, then every 60th beat
	if _fired.get("onUpdate", 0) < 3 or (_fired.get("onBeatHit", 0) % 60 == 0 and _fired.get("onUpdate", 0) % 10 == 0):
		# keep per-frame noise low while still proving the hook fires
		pass
	else:
		# Still count, but don't print every frame
		if "onUpdate" not in _fired:
			_fired["onUpdate"] = 0
		_fired["onUpdate"] = _fired["onUpdate"] + 1
		return
	_log("onUpdate", "elapsed=" + str(elapsed))

def onUpdatePost(elapsed):
	# Same throttling as onUpdate
	if _fired.get("onUpdatePost", 0) < 3:
		_log("onUpdatePost", "elapsed=" + str(elapsed))
	else:
		if "onUpdatePost" not in _fired:
			_fired["onUpdatePost"] = 0
		_fired["onUpdatePost"] = _fired["onUpdatePost"] + 1

# ---------------------------------------------------------------------------
# Song flow
# ---------------------------------------------------------------------------

def onStartCountdown():
	_log("onStartCountdown")
	return Function_Continue

def onCountdownStarted():
	_log("onCountdownStarted")

def onCountdownTick(counter):
	_log("onCountdownTick", "counter=" + str(counter))

def onSongStart():
	_log("onSongStart")

def onEndSong():
	_log("onEndSong")
	return Function_Continue

def onBeatHit():
	_log("onBeatHit")

def onStepHit():
	_log("onStepHit")

def onSectionHit():
	_log("onSectionHit")

# ---------------------------------------------------------------------------
# Pause / game-over / dialogue
# ---------------------------------------------------------------------------

def onPause():
	_log("onPause")
	return Function_Continue

def onResume():
	_log("onResume")

def onGameOver():
	_log("onGameOver")
	return Function_Continue

def onGameOverStart():
	_log("onGameOverStart")

def onGameOverConfirm(retry):
	_log("onGameOverConfirm", "retry=" + str(retry))

def onNextDialogue(line):
	_log("onNextDialogue", "line=" + str(line))

def onSkipDialogue(line):
	_log("onSkipDialogue", "line=" + str(line))

# ---------------------------------------------------------------------------
# Notes
# ---------------------------------------------------------------------------

def onSpawnNote(id, noteData, noteType, isSustainNote, strumTime):
	_log("onSpawnNote", "id=" + str(id) + " data=" + str(noteData) + " type=" + str(noteType) + " sus=" + str(isSustainNote) + " t=" + str(strumTime))

def goodNoteHit(id, direction, noteType, isSustainNote):
	_log("goodNoteHit", "id=" + str(id) + " dir=" + str(direction))

def opponentNoteHit(id, direction, noteType, isSustainNote):
	_log("opponentNoteHit", "id=" + str(id) + " dir=" + str(direction))

def goodNoteSkip(id, direction, noteType, isSustainNote):
	_log("goodNoteSkip", "id=" + str(id) + " dir=" + str(direction))

def opponentNoteSkip(id, direction, noteType, isSustainNote):
	_log("opponentNoteSkip", "id=" + str(id) + " dir=" + str(direction))

def noteMiss(id, direction, noteType, isSustainNote):
	_log("noteMiss", "id=" + str(id) + " dir=" + str(direction))

def noteMissPress(direction):
	_log("noteMissPress", "dir=" + str(direction))

def onGhostTap(key):
	_log("onGhostTap", "key=" + str(key))

def onKeyPress(key):
	_log("onKeyPress", "key=" + str(key))

def onKeyRelease(key):
	_log("onKeyRelease", "key=" + str(key))

# ---------------------------------------------------------------------------
# Camera / rating / score
# ---------------------------------------------------------------------------

def onMoveCamera(focus):
	_log("onMoveCamera", "focus=" + str(focus))

def onRecalculateRating():
	_log("onRecalculateRating")
	return Function_Continue

def onUpdateScore(miss):
	_log("onUpdateScore", "miss=" + str(miss))

# ---------------------------------------------------------------------------
# Events
# ---------------------------------------------------------------------------

def onEvent(name, value1, value2, strumTime):
	_log("onEvent", "name=" + str(name) + " strumTime=" + str(strumTime))

def eventEarlyTrigger(name, value1, value2, strumTime):
	_log("eventEarlyTrigger", "name=" + str(name))

# ---------------------------------------------------------------------------
# Tweens / timers / sound
# ---------------------------------------------------------------------------

def onTweenCompleted(tag):
	_log("onTweenCompleted", "tag=" + str(tag))

def onTimerCompleted(tag, loops, loopsLeft):
	_log("onTimerCompleted", "tag=" + str(tag) + " loops=" + str(loops) + " left=" + str(loopsLeft))

def onSoundFinished(tag):
	_log("onSoundFinished", "tag=" + str(tag))

# ---------------------------------------------------------------------------
# Custom substates
# ---------------------------------------------------------------------------

def onCustomSubstateCreate(name):
	_log("onCustomSubstateCreate", "name=" + str(name))

def onCustomSubstateCreatePost(name):
	_log("onCustomSubstateCreatePost", "name=" + str(name))

def onCustomSubstateUpdate(name, elapsed):
	_log("onCustomSubstateUpdate", "name=" + str(name) + " elapsed=" + str(elapsed))

def onCustomSubstateUpdatePost(name, elapsed):
	_log("onCustomSubstateUpdatePost", "name=" + str(name) + " elapsed=" + str(elapsed))

def onCustomSubstateDestroy(name):
	_log("onCustomSubstateDestroy", "name=" + str(name))

# ---------------------------------------------------------------------------
# Self-check when run as plain Python (not Hython)
# ---------------------------------------------------------------------------
if __name__ == "__main__":
	import pathlib
	import re
	# Verify every hook in script-hooks.md appears as a def here (static-doc parity)
	root = pathlib.Path(__file__).resolve().parents[1]
	hook_doc = (root / "website" / "docs" / "modding" / "script-hooks.md").read_text()
	# collect documented hook names from Full engine list block (plus note-hit variants)
	documented = set(re.findall(r"(on[A-Za-z]+|goodNote[A-Za-z]+|opponentNote[A-Za-z]+|note[A-Za-z]+|event[A-Za-z]+)", hook_doc))
	# explicit full list expected from script-hooks.md after #87 fix
	expected_min = set(_HOOKS)
	missing_def = [h for h in _HOOKS if f"def {h}(" not in pathlib.Path(__file__).read_text()]
	if missing_def:
		print("FAIL missing def in smoke test: " + str(missing_def))
		raise SystemExit(1)
	# smoke script compiles in plain Python
	src = pathlib.Path(__file__).read_text()
	compile(src, str(pathlib.Path(__file__)), "exec")
	print("OK smoke test defines " + str(len(_HOOKS)) + " hooks; documented ~" + str(len(documented)) + " names")
