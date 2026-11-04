# Python template — every hook the engine fires (Lua + Python parity).
# See website/docs/modding/script-hooks.md for the authoritative table;
# this file is the executable checklist. Drop it into
# mods/<mod>/scripts/ or mods/<mod>/data/<song>/ and watch the debug overlay.
#
# Hooks that can cancel engine behaviour must `return Function_Stop` to do so;
# `return Function_StopLua` (alias `Function_StopAll`) stops propagation to later scripts.
# Hooks without a `return` are treated as `Function_Continue`.

# ---------------------------------------------------------------------------
# Lifecycle — called once per script load / unload, and every frame
# ---------------------------------------------------------------------------

def onCreate():
	# When the script is first loaded; many PlayState fields do not exist yet.
	# Prefer onCreatePost for normal setup.
	pass

def onCreatePost():
	# End of create(), every PlayState field is ready — the recommended setup point.
	# Example: makeLuaSprite / makeLuaText + addLuaSprite / addLuaText here.
	pass

def onDestroy():
	# Song fade-out finished, the script is being removed.
	pass

def onUpdate(elapsed):
	# Start of the frame, before engine logic.
	pass

def onUpdatePost(elapsed):
	# End of the frame.
	pass


# ---------------------------------------------------------------------------
# Song flow — countdown, sections, timing
# ---------------------------------------------------------------------------

def onStartCountdown():
	# Before the countdown. Return Function_Stop to suppress it (use for dialogue),
	# then call startCountdown() when ready.
	return Function_Continue

def onCountdownStarted():
	# The countdown actually began.
	pass

def onCountdownTick(counter):
	# counter = 0 -> "Three", 1 -> "Two", 2 -> "One", 3 -> "Go!"
	# counter = 4 -> nothing (fired alongside onSongStart, rarely useful)
	pass

def onSongStart():
	# Vocals + inst started, songPosition = 0
	pass

def onEndSong():
	# Song finished / transition starting.
	# Return Function_Stop to block the transition (for cutscenes).
	return Function_Continue

def onBeatHit():
	# Triggered 4 times per section (on every beat)
	pass

def onStepHit():
	# Triggered 16 times per section (on every step)
	pass

def onSectionHit():
	# Once per section
	pass


# ---------------------------------------------------------------------------
# Pause / resume / game-over / dialogue
# ---------------------------------------------------------------------------

def onPause():
	# Pause pressed while not in a cutscene.
	# Return Function_Stop to block pausing.
	return Function_Continue

def onResume():
	# Game was resumed from pause (not necessarily the pause menu).
	pass

def onGameOver():
	# Fired every frame while health <= 0.
	# Return Function_Stop to block entering the game-over screen.
	return Function_Continue

def onGameOverStart():
	# The game-over screen just opened.
	pass

def onGameOverConfirm(retry):
	# Player pressed Enter/Esc on game-over.
	# retry == False when Esc was pressed; True for Enter.
	pass

def onNextDialogue(line):
	# Next dialogue line is about to show; line is 1-indexed.
	pass

def onSkipDialogue(line):
	# A line was skipped while it was still typing; line is 1-indexed.
	pass


# ---------------------------------------------------------------------------
# Notes — hit / miss / spawn
# ---------------------------------------------------------------------------

def onSpawnNote(id, noteData, noteType, isSustainNote, strumTime):
	# A note is entering play. id is its group index; noteData 0..3 (L/D/U/R).
	pass

def goodNoteHit(id, direction, noteType, isSustainNote):
	# Player hit a note (after calculations)
	# direction 0=Left 1=Down 2=Up 3=Right; noteType is the type string
	pass

def opponentNoteHit(id, direction, noteType, isSustainNote):
	# Opponent hit a note — same arguments as goodNoteHit
	pass

def goodNoteSkip(id, direction, noteType, isSustainNote):
	# A player note was skipped (e.g. hidden/botplay path); only when
	# ClientPrefs.noSkipFuncs == False.
	pass

def opponentNoteSkip(id, direction, noteType, isSustainNote):
	# Same as goodNoteSkip for the opponent side
	pass

def noteMiss(id, direction, noteType, isSustainNote):
	# Player missed a note by letting it pass.
	pass

def noteMissPress(direction):
	# Ghost miss: player pressed with no note to hit.
	pass

def onGhostTap(key):
	# A tap that hit nothing, with ghost tapping enabled (noteMissPress wrapper)
	pass

def onKeyPress(key):
	# Raw lane input pressed; key is 0..3
	pass

def onKeyRelease(key):
	# Raw lane input released; key is 0..3
	pass


# ---------------------------------------------------------------------------
# Camera / rating / score
# ---------------------------------------------------------------------------

def onMoveCamera(focus):
	# focus is 'boyfriend', 'dad' or 'gf'
	if focus == 'boyfriend':
		pass
	elif focus == 'dad':
		pass
	elif focus == 'gf':
		pass

def onRecalculateRating():
	# Fired BEFORE the rating calculation.
	# Return Function_Stop and use setRatingPercent() / setRatingName() / setRatingFC()
	# to supply your own.
	return Function_Continue

def onUpdateScore(miss):
	# Score text is about to update; miss == True if this was a miss update.
	pass


# ---------------------------------------------------------------------------
# Events
# ---------------------------------------------------------------------------

def onEvent(name, value1, value2, strumTime):
	# An event note fired (triggerEvent() does NOT call this).
	pass

def eventEarlyTrigger(name, value1, value2, strumTime):
	# Return a millisecond offset to fire the named event earlier.
	# Example: if name == 'Kill Henchmen': return 280
	pass


# ---------------------------------------------------------------------------
# Tweens / timers / sound — async completions
# ---------------------------------------------------------------------------

def onTweenCompleted(tag):
	# A tween started with doTweenX / doTweenAlpha etc. finished
	pass

def onTimerCompleted(tag, loops, loopsLeft):
	# A timer loop finished; loops / loopsLeft count completed vs remaining loops
	pass

def onSoundFinished(tag):
	# A sound started with playSound(tag) finished
	pass


# ---------------------------------------------------------------------------
# Custom substates — opened from script via openCustomSubstate(name, pauseGame)
# ---------------------------------------------------------------------------

def onCustomSubstateCreate(name):
	pass

def onCustomSubstateCreatePost(name):
	pass

def onCustomSubstateUpdate(name, elapsed):
	pass

def onCustomSubstateUpdatePost(name, elapsed):
	pass

def onCustomSubstateDestroy(name):
	pass
