# TemplateScript.py

# This is a demo of the Work In progress
# python modding experiment;
# I recommend using python if you want to
# make extremely advanced softmodding.
# For anything more simpler, use Lua modding.

# Drop this into mods/scripts/ (or any mod's scripts/ folder) and it will run
# on every song. Python modding works exactly like Lua modding: define
# top-level `def` callbacks and call the same engine functions.
#
# Callbacks with no `return` are treated as Function_Continue.
# You can return Function_Stop / Function_Continue / Function_StopAll.

# Executes the `onCreate` operation.
# @note Callback documentation.
def onCreate():
	# When the python file is started/created, some variables weren't created yet
	makeLuaSprite('myLittleSprite', '', 0, 0)
	makeGraphic('myLittleSprite', 64, 64, 'ff0000')
	setScrollFactor('myLittleSprite', 0, 0)
	setObjectCamera('myLittleSprite', 'hud')
	setProperty('myLittleSprite.alpha', 0.7)
	screenCenter('myLittleSprite')
	addLuaSprite('myLittleSprite', True)
	debugPrint('Python script loaded! (create)')

# Executes the `onCreatePost` operation.
# @note Callback documentation.
def onCreatePost():
	# End of "create", all variables have already been loaded, recommended.
	pass

# Executes the `onDestroy` operation.
# @note Callback documentation.
def onDestroy():
	# When the python file is ended (Song fade out finished)
	pass

# Gameplay/Song interactions
# Executes the `onBeatHit` operation.
# @note Callback documentation.
def onBeatHit():
	# Triggered 4 times per section
	doTweenX('spriteX', 'myLittleSprite', 200, 0.5, 'sineOut')
	doTweenY('spriteY', 'myLittleSprite', 300, 0.5, 'sineOut')

# Executes the `onStepHit` operation.
# @note Callback documentation.
def onStepHit():
	# Triggered 16 times per section
	pass

# Executes the `onUpdate` operation.
# @param elapsed: Input value for `elapsed`.
# @note Callback documentation.
def onUpdate(elapsed):
	# Start of "update", some variables weren't updated yet
	pass

# Executes the `onUpdatePost` operation.
# @param elapsed: Input value for `elapsed`.
# @note Callback documentation.
def onUpdatePost(elapsed):
	# End of "update"
	pass

# Executes the `onStartCountdown` operation.
# @note Callback documentation.
def onStartCountdown():
	# Countdown started, duh
	# Return Function_Stop if you want to stop the countdown from happening
	return Function_Continue

# Executes the `onCountdownTick` operation.
# @param counter: Input value for `counter`.
# @note Callback documentation.
def onCountdownTick(counter):
	# counter = 0 -> "Three", 1 -> "Two", 2 -> "One", 3 -> "Go!"
	pass

# Executes the `onSongStart` operation.
# @note Callback documentation.
def onSongStart():
	# Inst and Vocals start playing, songPosition = 0
	pass

# Executes the `onEndSong` operation.
# @note Callback documentation.
def onEndSong():
	# return Function_Stop to stop the song from ending
	return Function_Continue

# Substate interactions
# Executes the `onPause` operation.
# @note Callback documentation.
def onPause():
	return Function_Continue

# Executes the `onResume` operation.
# @note Callback documentation.
def onResume():
	pass

# Executes the `onGameOver` operation.
# @note Callback documentation.
def onGameOver():
	return Function_Continue

# Executes the `onGameOverConfirm` operation.
# @param retry: Input value for `retry`.
# @note Callback documentation.
def onGameOverConfirm(retry):
	# If you've pressed Esc, value "retry" will be False
	pass

# Note miss/hit
# Executes the `goodNoteHit` operation.
# @param id: Input value for `id`.
# @param direction: Input value for `direction`.
# @param noteType: Input value for `noteType`.
# @param isSustainNote: Input value for `isSustainNote`.
# @note Callback documentation.
def goodNoteHit(id, direction, noteType, isSustainNote):
	# id: the note member id
	# direction: 0 = Left, 1 = Down, 2 = Up, 3 = Right
	# noteType: the note type string/tag
	# isSustainNote: True if it's a hold note
	pass

# Executes the `opponentNoteHit` operation.
# @param id: Input value for `id`.
# @param direction: Input value for `direction`.
# @param noteType: Input value for `noteType`.
# @param isSustainNote: Input value for `isSustainNote`.
# @note Callback documentation.
def opponentNoteHit(id, direction, noteType, isSustainNote):
	pass

# Executes the `noteMissPress` operation.
# @param direction: Input value for `direction`.
# @note Callback documentation.
def noteMissPress(direction):
	pass

# Executes the `noteMiss` operation.
# @param id: Input value for `id`.
# @param direction: Input value for `direction`.
# @param noteType: Input value for `noteType`.
# @param isSustainNote: Input value for `isSustainNote`.
# @note Callback documentation.
def noteMiss(id, direction, noteType, isSustainNote):
	pass

# Event notes hooks
# Executes the `onEvent` operation.
# @param name: Input value for `name`.
# @param value1: Input value for `value1`.
# @param value2: Input value for `value2`.
# @note Callback documentation.
def onEvent(name, value1, value2):
	pass

# Executes the `eventEarlyTrigger` operation.
# @param name: Input value for `name`.
# @note Callback documentation.
def eventEarlyTrigger(name):
	pass

# Tween/Timer hooks
# Executes the `onTweenCompleted` operation.
# @param tag: Input value for `tag`.
# @note Callback documentation.
def onTweenCompleted(tag):
	pass

# Executes the `onTimerCompleted` operation.
# @param tag: Input value for `tag`.
# @param loops: Input value for `loops`.
# @param loopsLeft: Input value for `loopsLeft`.
# @note Callback documentation.
def onTimerCompleted(tag, loops, loopsLeft):
	pass
