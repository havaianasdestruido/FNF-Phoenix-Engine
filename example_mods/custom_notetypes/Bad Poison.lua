-- Bad Poison — Mario Madness custom note type ported to Phoenix.
--
-- Ported from Mario Madness (Dewott2501/Mario-Madness, Apache-2.0)
-- https://github.com/Dewott2501/Mario-Madness
-- The original hardcodes it in source/Note.hx ('Bad Poison') and reacts in
-- source/PlayState.hx (a smw_scroll sound and the BadMario poison overlay
-- alpha going up on hit). Here it lives in a custom_notetypes script, so the
-- engine itself needs no changes.
--
-- Behaviour (faithful to the original):
--   * hitting the note in your lane counts as a miss (hitCausesMiss)
--   * no sing animation on hit (noAnimation); the miss animation is kept
--   * the note does not count for score or accuracy (ignoreNote)
--   * plays BAD_POISON_SOUND on hit when the mod ships it
--   * opponent-lane notes of this type behave as normal opponent notes
--
-- Not ported: the BadMario full-screen poison overlay (badPoisonVG) is a
-- stage-specific sprite, not part of the note system. Mario Madness re-adds
-- that here — if you want the overlay, create it in onCreatePost of your
-- song's global script and tween its alpha from goodNoteHit below.

local NOTE_TYPE        = 'Bad Poison' -- must match this file's name
local SKIN             = 'badpoison_NOTE_assets'
local BAD_POISON_SOUND = 'smw_scroll' -- '' disables

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
	setPropertyFromGroup(group, id, 'noAnimation', true) -- the miss animation still plays, like the original
	if SKIN ~= '' then
		setPropertyFromGroup(group, id, 'texture', SKIN)
	end
end

function goodNoteHit(id, direction, noteType, isSustainNote)
	if noteType ~= NOTE_TYPE then return end
	playSoundIfExists(BAD_POISON_SOUND, 0.8)
end
