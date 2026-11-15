-- Ring Note — Mario Madness custom note type ported to Phoenix.
--
-- Ported from Mario Madness (Dewott2501/Mario-Madness, Apache-2.0)
-- https://github.com/Dewott2501/Mario-Madness
-- The original hardcodes it in source/Note.hx ('Ring Note') and reacts in
-- source/PlayState.hx (a ring counter and a ring hit sound on hit). Here it
-- lives in a custom_notetypes script, so the engine itself needs no changes.
--
-- Behaviour (faithful to the original):
--   * a regular scoring note — it counts for score and accuracy as usual
--   * hitting it plays RING_SOUND and bumps the ring counter
--   * opponent-lane notes of this type behave as normal opponent notes
--   * uses the "ring_NOTE_assets" atlas when the mod ships one
--
-- The counter lives in this script; other scripts can read it with:
--   local rings = callScript('custom_notetypes/Ring Note.lua', 'getRings', {})
-- and reset it with resetRings(). The original's Sonic-style rule (missing
-- costs you half your rings, or kills you at zero) is stage-specific to
-- Somari and is not ported — re-add it from noteMiss if you want it (the
-- original does it right inside its noteMiss handler).

local NOTE_TYPE  = 'Ring Note' -- must match this file's name
local SKIN       = 'ring_NOTE_assets'
local RING_SOUND = 'ringhit' -- '' disables; played on hit when the mod ships it

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

local ringCount = 0

function onSpawnNote(id, noteData, noteType, isSustainNote, strumTime)
	if noteType ~= NOTE_TYPE then return end
	local group = targetGroup(isSustainNote)
	if SKIN ~= '' then
		setPropertyFromGroup(group, id, 'texture', SKIN)
	end
end

function goodNoteHit(id, direction, noteType, isSustainNote)
	if noteType ~= NOTE_TYPE then return end
	ringCount = ringCount + 1
	playSoundIfExists(RING_SOUND, 1)
end

function getRings()
	return ringCount
end

function resetRings()
	ringCount = 0
end

function onCreate()
	ringCount = 0
end
