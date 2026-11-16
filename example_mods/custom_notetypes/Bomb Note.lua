-- Bomb Note — Mario Madness custom note type ported to Phoenix.
--
-- Ported from Mario Madness (Dewott2501/Mario-Madness, Apache-2.0)
-- https://github.com/Dewott2501/Mario-Madness
-- The original hardcodes it as 'Nota bomba' (source/Note.hx) and subtracts a
-- full heart of health in source/PlayState.hx when you hit one. Here it lives
-- in a custom_notetypes script, so the engine itself needs no changes.
--
-- Behaviour (faithful to the original):
--   * hitting the note in your lane counts as a miss (hitCausesMiss)
--   * you lose BOMB_DAMAGE health on top of the normal miss damage
--   * the note does not count for score or accuracy (ignoreNote)
--   * opponent-lane notes of this type behave as normal opponent notes
--   * uses the "bomb_NOTE_assets" atlas when the mod ships one
--
-- Set SHAKE and BOMB_SOUND if you want feedback beyond the health bar; the
-- original has neither, so they default to off/silent.

local NOTE_TYPE  = 'Bomb Note' -- must match this file's name
local SKIN       = 'bomb_NOTE_assets'
local BOMB_DAMAGE = 1    -- the original's `health -= 1` (a full default health bar)
local BOMB_SOUND = ''    -- e.g. 'bomb_explode'; '' disables
local SHAKE      = false -- true: also shake camGame and camHUD on hit (not in the original)

-- Shared helpers. Every custom_notetypes script is self-contained because
-- notetype scripts may load before anything else does.
-- playSound() on a missing file is a no-op in Phoenix (Paths.sound returns null
-- and flixel skips it), so this only guards the '' disable sentinel.
local function playSoundIfExists(sound, volume)
	if sound == nil or sound == '' then return end
	playSound(sound, volume or 1)
end

local function targetGroup(isSustainNote)
	if isSustainNote then return 'sustainNotes' end
	return 'notes'
end

function onSpawnNote(id, noteData, noteType, isSustainNote, strumTime)
	if noteType ~= NOTE_TYPE then return end
	local group = targetGroup(isSustainNote)
	local mustPress = getPropertyFromGroup(group, id, 'mustPress')

	setPropertyFromGroup(group, id, 'hitCausesMiss', true)
	setPropertyFromGroup(group, id, 'ignoreNote', mustPress)
	if SKIN ~= '' then
		setPropertyFromGroup(group, id, 'texture', SKIN)
	end
end

function goodNoteHit(id, direction, noteType, isSustainNote)
	if noteType ~= NOTE_TYPE then return end
	-- fires through the shared hit path once per note, like the original's
	-- `health -= 1` on a hit bomb
	addHealth(-BOMB_DAMAGE)
	if SHAKE then
		cameraShake('camGame', 0.03, 0.75)
		cameraShake('camHUD', 0.015, 0.75)
	end
	playSoundIfExists(BOMB_SOUND, 1)
end
