# Python stuff
# The function properties still work if you change the function names.
# For example:
#   def onEvent(name, v1, v2):
#       # value 1 is the camera flash length, value 2 is the flash color
#       if name == 'flashCamera':
#           cameraFlash('camGame', v2, v1)
#
# The functions still work, its just with different function names.

# Executes the `onCreate` operation.
# @note Callback documentation.
def onCreate():
	# When the python file is started/created, some variables weren't created yet
	pass

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
	pass

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
	# Return Function_Stop if you want to stop the countdown from happening (Can be used to trigger dialogues and stuff! You can trigger the countdown with startCountdown())
	return Function_Continue

# Executes the `onCountdownTick` operation.
# @param counter: Input value for `counter`.
# @note Callback documentation.
def onCountdownTick(counter):
	# counter = 0 -> "Three"
	# counter = 1 -> "Two"
	# counter = 2 -> "One"
	# counter = 3 -> "Go!"
	# counter = 4 -> Nothing happens lol, tho it is triggered at the same time as onSongStart i think
	pass

# Executes the `onSongStart` operation.
# @note Callback documentation.
def onSongStart():
	# Inst and Vocals start playing, songPosition = 0
	pass

# Executes the `onEndSong` operation.
# @note Callback documentation.
def onEndSong():
	# Song ended/starting transition (Will be delayed if you're unlocking an achievement)
	# return Function_Stop to stop the song from ending for playing a cutscene or something.
	return Function_Continue


# Substate interactions
# Executes the `onPause` operation.
# @note Callback documentation.
def onPause():
	# Called when you press Pause while not on a cutscene/etc
	# return Function_Stop if you want to stop the player from pausing the game
	return Function_Continue

# Executes the `onResume` operation.
# @note Callback documentation.
def onResume():
	# Called after the game has been resumed from a pause (WARNING: Not necessarily from the pause screen, but most likely is!!!)
	pass

# Executes the `onGameOver` operation.
# @note Callback documentation.
def onGameOver():
	# You died! Called every single frame your health is lower (or equal to) zero
	# return Function_Stop if you want to stop the player from going into the game over screen
	return Function_Continue

# Executes the `onGameOverConfirm` operation.
# @param retry: Input value for `retry`.
# @note Callback documentation.
def onGameOverConfirm(retry):
	# Called when you Press Enter/Esc on Game Over
	# If you've pressed Esc, value "retry" will be False
	pass


# Dialogue (When a dialogue is finished, it calls startCountdown again)
# Executes the `onNextDialogue` operation.
# @param line: Input value for `line`.
# @note Callback documentation.
def onNextDialogue(line):
	# Triggered when the next dialogue line starts, dialogue line starts with 1
	pass

# Executes the `onSkipDialogue` operation.
# @param line: Input value for `line`.
# @note Callback documentation.
def onSkipDialogue(line):
	# Triggered when you press Enter and skip a dialogue line that was still being typed, dialogue line starts with 1
	pass


# Note miss/hit
# Executes the `goodNoteHit` operation.
# @param id: Input value for `id`.
# @param direction: Input value for `direction`.
# @param noteType: Input value for `noteType`.
# @param isSustainNote: Input value for `isSustainNote`.
# @note Callback documentation.
def goodNoteHit(id, direction, noteType, isSustainNote):
	# Function called when you hit a note (after note hit calculations)
	# id: The note member id, you can get whatever variable you want from this note, example: "getPropertyFromGroup('notes', id, 'strumTime')"
	# direction: 0 = Left, 1 = Down, 2 = Up, 3 = Right
	# noteType: The note type string/tag
	# isSustainNote: If it's a hold note, can be either True or False
	pass

# Executes the `opponentNoteHit` operation.
# @param id: Input value for `id`.
# @param direction: Input value for `direction`.
# @param noteType: Input value for `noteType`.
# @param isSustainNote: Input value for `isSustainNote`.
# @note Callback documentation.
def opponentNoteHit(id, direction, noteType, isSustainNote):
	# Works the same as goodNoteHit, but for Opponent's notes being hit
	pass

# Executes the `noteMissPress` operation.
# @param direction: Input value for `direction`.
# @note Callback documentation.
def noteMissPress(direction):
	# Called after the note press miss calculations
	# Player pressed a button, but there was no note to hit (ghost miss)
	pass

# Executes the `noteMiss` operation.
# @param id: Input value for `id`.
# @param direction: Input value for `direction`.
# @param noteType: Input value for `noteType`.
# @param isSustainNote: Input value for `isSustainNote`.
# @note Callback documentation.
def noteMiss(id, direction, noteType, isSustainNote):
	# Called after the note miss calculations
	# Player missed a note by letting it go offscreen
	pass


# Other function hooks
# Executes the `onRecalculateRating` operation.
# @note Callback documentation.
def onRecalculateRating():
	# return Function_Stop if you want to do your own rating calculation,
	# use setRatingPercent() to set the number on the calculation and setRatingString() to set the funny rating name
	# NOTE: THIS IS CALLED BEFORE THE CALCULATION!!!
	return Function_Continue

# Executes the `onMoveCamera` operation.
# @param focus: Input value for `focus`.
# @note Callback documentation.
def onMoveCamera(focus):
	if focus == 'boyfriend':
		# called when the camera focus on boyfriend
		pass
	elif focus == 'dad':
		# called when the camera focus on dad
		pass


# Event notes hooks
# Executes the `onEvent` operation.
# @param name: Input value for `name`.
# @param value1: Input value for `value1`.
# @param value2: Input value for `value2`.
# @note Callback documentation.
def onEvent(name, value1, value2):
	# event note triggered
	# triggerEvent() does not call this function!!

	# print('Event triggered: ', name, value1, value2)
	pass

# Executes the `eventEarlyTrigger` operation.
# @param name: Input value for `name`.
# @note Callback documentation.
def eventEarlyTrigger(name):
	# Here's a port of the Kill Henchmen early trigger but on Python instead of Haxe:
	#
	# if name == 'Kill Henchmen':
	#     return 280
	#
	# This makes the "Kill Henchmen" event be triggered 280 miliseconds earlier so that the kill sound is perfectly timed with the song

	# write your shit under this line, the new return value will override the ones hardcoded on the engine
	pass


# Tween/Timer hooks
# Executes the `onTweenCompleted` operation.
# @param tag: Input value for `tag`.
# @note Callback documentation.
def onTweenCompleted(tag):
	# A tween you called has been completed, value "tag" is it's tag
	pass

# Executes the `onTimerCompleted` operation.
# @param tag: Input value for `tag`.
# @param loops: Input value for `loops`.
# @param loopsLeft: Input value for `loopsLeft`.
# @note Callback documentation.
def onTimerCompleted(tag, loops, loopsLeft):
	# A loop from a timer you called has been completed, value "tag" is it's tag
	# loops = how many loops it will have done when it ends completely
	# loopsLeft = how many are remaining
	pass
