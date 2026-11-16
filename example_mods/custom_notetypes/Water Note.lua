-- Water Note — Mario Madness custom note type ported to Phoenix.
--
-- Ported from Mario Madness (Dewott2501/Mario-Madness, Apache-2.0)
-- https://github.com/Dewott2501/Mario-Madness
-- The original hardcodes it in source/Note.hx ('Water Note') and reacts in
-- source/PlayState.hx (a rising water flood object and a waterswitch sound on
-- hit). Here it lives in a custom_notetypes script, so the engine itself
-- needs no changes.
--
-- Behaviour (faithful to the original):
--   * no sing animation on hit (noAnimation); the miss animation is kept
--   * hitting it plays WATER_SOUND
--   * opponent-lane notes of this type behave as normal opponent notes
--   * uses the "water_NOTE_assets" atlas when the mod ships one
--
-- Not ported: the rising flood (flood sprite y tween per hit) is a
-- stage-specific object, not part of the note system. Mario Madness re-adds
-- it here — if you want the flood, create it in onCreatePost of your song's
-- global script and tween its y from goodNoteHit below.

local NOTE_TYPE   = 'Water Note' -- must match this file's name
local SKIN        = 'water_NOTE_assets'
local WATER_SOUND = 'waterswitch' -- '' disables; played on hit when the mod ships it

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
	setPropertyFromGroup(group, id, 'noAnimation', true)
	if SKIN ~= '' then
		setPropertyFromGroup(group, id, 'texture', SKIN)
	end
end

function goodNoteHit(id, direction, noteType, isSustainNote)
	if noteType ~= NOTE_TYPE then return end
	playSoundIfExists(WATER_SOUND, 1)
end
