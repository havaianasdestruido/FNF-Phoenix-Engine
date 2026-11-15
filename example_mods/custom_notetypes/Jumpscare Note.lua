-- Jumpscare Note — Mario Madness custom note type ported to Phoenix.
--
-- Ported from Mario Madness (Dewott2501/Mario-Madness, Apache-2.0)
-- https://github.com/Dewott2501/Mario-Madness
-- The original hardcodes it as 'jumpscareM' (source/Note.hx) and reacts in
-- source/PlayState.hx: on hit it plays the CAUSA sound and, when the player's
-- flashing option is on, shakes the extra/game/HUD cameras and slams a
-- black-bars + scare-image overlay fullscreen for a beat. Here it lives in a
-- custom_notetypes script, so the engine itself needs no changes.
--
-- Behaviour (faithful to the original):
--   * hitting the note in your lane counts as a miss (hitCausesMiss)
--   * the note does not count for score or accuracy (ignoreNote)
--   * plays SCREAM_SOUND on hit
--   * if the player's Options flashing setting is on, shakes camGame and
--     camHUD on hit
--   * opponent-lane notes of this type behave as normal opponent notes
--   * uses the "jumpscare_NOTE_assets" atlas when the mod ships one
--
-- Not ported: the black bars and scare-image overlay sprites (blackBarThingie/
-- susto/estatica) are stage-specific art, not part of the note system. Mario
-- Madness re-adds those from goodNoteHit if you want them.

local NOTE_TYPE    = 'Jumpscare Note' -- must match this file's name
local SKIN         = 'jumpscare_NOTE_assets'
local SCREAM_SOUND = 'CAUSA' -- '' disables; played on hit when the mod ships it

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
	playSoundIfExists(SCREAM_SOUND, 1)
	if getPropertyFromClass('ClientPrefs', 'flashing') then
		cameraShake('camGame', 0.01, 1)
		cameraShake('camHUD', 0.01, 1)
	end
end
