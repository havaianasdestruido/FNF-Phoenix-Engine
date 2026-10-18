# TemplateScript.py — comprehensive Python hook demo (Lua + Python parity).
#
# This file used to ship as a tiny example; it is now the full template so
# new Python mods start with the same hook coverage as Lua. Drop it into
# mods/scripts/ (or any mod's scripts/ folder) and it will run on every song.
# Python modding mirrors Lua: define top-level `def` callbacks and call the same
# engine functions. See docs/TemplateScript.py and
# website/docs/modding/script-hooks.md for the authoritative tables.
#
# Callbacks with no `return` are treated as Function_Continue.
# You can return Function_Stop / Function_Continue / Function_StopLua (alias Function_StopAll).

def onCreate():
	# When the python file is first created; many PlayState vars do not exist yet.
	# For a demo sprite, defer to onCreatePost.
	pass

def onCreatePost():
	# End of create(), every PlayState field is ready — good place for setup.
	makeLuaSprite('myLittleSprite', '', 0, 0)
	makeGraphic('myLittleSprite', 64, 64, 'ff0000')
	setScrollFactor('myLittleSprite', 0, 0)
	setObjectCamera('myLittleSprite', 'hud')
	setProperty('myLittleSprite.alpha', 0.7)
	screenCenter('myLittleSprite')
	addLuaSprite('myLittleSprite', True)
	debugPrint('Python script loaded! (create)')

def onDestroy():
	# Song fade-out finished, script is being removed.
	pass

# ---------------------------------------------------------------------------
# Song flow
# ---------------------------------------------------------------------------

def onUpdate(elapsed):
	# Start of the frame, before engine logic.
	pass

def onUpdatePost(elapsed):
	# End of the frame.
	pass

def onStartCountdown():
	# Before the countdown. Return Function_Stop to suppress it.
	return Function_Continue

def onCountdownStarted():
	pass

def onCountdownTick(counter):
	# 0=Three 1=Two 2=One 3=Go! 4=none
	pass

def onSongStart():
	pass

def onEndSong():
	return Function_Continue

def onBeatHit():
	doTweenX('spriteX', 'myLittleSprite', 200, 0.5, 'sineOut')
	doTweenY('spriteY', 'myLittleSprite', 300, 0.5, 'sineOut')

def onStepHit():
	pass

def onSectionHit():
	pass

# ---------------------------------------------------------------------------
# Pause / game-over / dialogue
# ---------------------------------------------------------------------------

def onPause():
	return Function_Continue

def onResume():
	pass

def onGameOver():
	return Function_Continue

def onGameOverStart():
	pass

def onGameOverConfirm(retry):
	# retry == False when Esc was pressed
	pass

def onNextDialogue(line):
	pass

def onSkipDialogue(line):
	pass

# ---------------------------------------------------------------------------
# Notes — hit / miss / spawn
# ---------------------------------------------------------------------------

def onSpawnNote(id, noteData, noteType, isSustainNote, strumTime):
	pass

def goodNoteHit(id, direction, noteType, isSustainNote):
	pass

def opponentNoteHit(id, direction, noteType, isSustainNote):
	pass

def goodNoteSkip(id, direction, noteType, isSustainNote):
	pass

def opponentNoteSkip(id, direction, noteType, isSustainNote):
	pass

def noteMiss(id, direction, noteType, isSustainNote):
	pass

def noteMissPress(direction):
	pass

def onGhostTap(key):
	pass

def onKeyPress(key):
	pass

def onKeyRelease(key):
	pass

# ---------------------------------------------------------------------------
# Camera / rating / score
# ---------------------------------------------------------------------------

def onMoveCamera(focus):
	if focus == 'boyfriend':
		pass
	elif focus == 'dad':
		pass
	elif focus == 'gf':
		pass

def onRecalculateRating():
	return Function_Continue

def onUpdateScore(miss):
	pass

# ---------------------------------------------------------------------------
# Events
# ---------------------------------------------------------------------------

def onEvent(name, value1, value2, strumTime):
	pass

def eventEarlyTrigger(name, value1, value2, strumTime):
	pass

# ---------------------------------------------------------------------------
# Tweens / timers / sound
# ---------------------------------------------------------------------------

def onTweenCompleted(tag):
	pass

def onTimerCompleted(tag, loops, loopsLeft):
	pass

def onSoundFinished(tag):
	pass

# ---------------------------------------------------------------------------
# Custom substates — opened via openCustomSubstate(name, pauseGame)
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
