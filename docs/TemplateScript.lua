-- Lua template — every hook the engine fires (Lua + Python parity).
-- See website/docs/modding/script-hooks.md for the authoritative table.
-- Drop this into mods/<mod>/scripts/ or mods/<mod>/data/<song>/ and watch the debug overlay.
--
-- Hooks that can cancel engine behaviour must `return Function_Stop` to do so;
-- `return Function_StopLua` stops propagation to later scripts.

-- ---------------------------------------------------------------------------
-- Lifecycle — called once per script load / unload, and every frame
-- ---------------------------------------------------------------------------

function onCreate()
	-- When the Lua file is first loaded; many PlayState fields do not exist yet.
	-- Prefer onCreatePost for normal setup.
end

function onCreatePost()
	-- End of create(), every PlayState field is ready — the recommended setup point.
end

function onDestroy()
	-- Song fade-out finished, the script is being removed.
end

function onUpdate(elapsed)
	-- Start of the frame, before engine logic.
end

function onUpdatePost(elapsed)
	-- End of the frame.
end

-- ---------------------------------------------------------------------------
-- Song flow — countdown, sections, timing
-- ---------------------------------------------------------------------------

function onStartCountdown()
	-- Before the countdown. Return Function_Stop to suppress it (use for dialogue),
	-- then call startCountdown() when ready.
	return Function_Continue;
end

function onCountdownStarted()
	-- The countdown actually began.
end

function onCountdownTick(counter)
	-- counter = 0 -> "Three", 1 -> "Two", 2 -> "One", 3 -> "Go!"
	-- counter = 4 -> nothing (fired alongside onSongStart, rarely useful)
end

function onSongStart()
	-- Vocals + inst started, songPosition = 0
end

function onEndSong()
	-- Song finished / transition starting. Return Function_Stop to block the transition.
	return Function_Continue;
end

function onBeatHit()
	-- Triggered 4 times per section (on every beat)
end

function onStepHit()
	-- Triggered 16 times per section (on every step)
end

function onSectionHit()
	-- Once per section
end

-- ---------------------------------------------------------------------------
-- Pause / resume / game-over / dialogue
-- ---------------------------------------------------------------------------

function onPause()
	-- Pause pressed while not in a cutscene. Return Function_Stop to block pausing.
	return Function_Continue;
end

function onResume()
	-- Game was resumed from pause (not necessarily the pause menu).
end

function onGameOver()
	-- Fired every frame while health <= 0. Return Function_Stop to block game over.
	return Function_Continue;
end

function onGameOverStart()
	-- The game-over screen just opened.
end

function onGameOverConfirm(retry)
	-- Player pressed Enter/Esc on game over. retry=false when Esc was pressed.
end

function onNextDialogue(line)
	-- Next dialogue line is about to show; line is 1-indexed.
end

function onSkipDialogue(line)
	-- A line was skipped while it was still typing; line is 1-indexed.
end

-- ---------------------------------------------------------------------------
-- Notes — hit / miss / spawn
-- ---------------------------------------------------------------------------

function onSpawnNote(id, noteData, noteType, isSustainNote, strumTime)
	-- A note is entering play. id is its group index; noteData 0..3 (L/D/U/R).
end

function goodNoteHit(id, direction, noteType, isSustainNote)
	-- Player hit a note (after calculations). direction 0=Left 1=Down 2=Up 3=Right.
end

function opponentNoteHit(id, direction, noteType, isSustainNote)
	-- Opponent hit a note — same arguments as goodNoteHit.
end

function goodNoteSkip(id, direction, noteType, isSustainNote)
	-- A player note was skipped (only when ClientPrefs.noSkipFuncs == false).
end

function opponentNoteSkip(id, direction, noteType, isSustainNote)
	-- Same as goodNoteSkip for the opponent side.
end

function noteMiss(id, direction, noteType, isSustainNote)
	-- Player missed a note by letting it pass.
end

function noteMissPress(direction)
	-- Ghost miss: player pressed with no note to hit.
end

function onGhostTap(key)
	-- A tap that hit nothing, with ghost tapping enabled.
end

function onKeyPress(key)
	-- Raw lane input pressed; key is 0..3
end

function onKeyRelease(key)
	-- Raw lane input released; key is 0..3
end

-- ---------------------------------------------------------------------------
-- Camera / rating / score
-- ---------------------------------------------------------------------------

function onMoveCamera(focus)
	if focus == 'boyfriend' then
		-- camera on boyfriend
	elseif focus == 'dad' then
		-- camera on dad
	elseif focus == 'gf' then
		-- camera on gf
	end
end

function onRecalculateRating()
	-- Fired BEFORE the rating calculation. Return Function_Stop and use
	-- setRatingPercent() / setRatingName() / setRatingFC() to supply your own.
	return Function_Continue;
end

function onUpdateScore(miss)
	-- Score text is about to update; miss==true if this was a miss update.
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------

function onEvent(name, value1, value2, strumTime)
	-- An event note fired (triggerEvent() does NOT call this).
	-- Example: if name == 'flashCamera' then cameraFlash('camGame', value2, value1) end
end

function eventEarlyTrigger(name, value1, value2, strumTime)
	-- Return a millisecond offset to fire the named event earlier.
	-- Example: if name == 'Kill Henchmen' then return 280 end
end

-- ---------------------------------------------------------------------------
-- Tweens / timers / sound — async completions
-- ---------------------------------------------------------------------------

function onTweenCompleted(tag)
	-- A tween started with doTweenX etc. finished
end

function onTimerCompleted(tag, loops, loopsLeft)
	-- A timer loop finished; loops / loopsLeft count completed vs remaining loops
end

function onSoundFinished(tag)
	-- A sound started with playSound(tag) finished
end

-- ---------------------------------------------------------------------------
-- Custom substates — opened from script via openCustomSubstate(name, pauseGame)
-- ---------------------------------------------------------------------------

function onCustomSubstateCreate(name)
end

function onCustomSubstateCreatePost(name)
end

function onCustomSubstateUpdate(name, elapsed)
end

function onCustomSubstateUpdatePost(name, elapsed)
end

function onCustomSubstateDestroy(name)
end
