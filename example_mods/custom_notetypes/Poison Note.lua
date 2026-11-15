-- Poison Note — Mario Madness custom note type ported to Phoenix.
--
-- Ported from Mario Madness (Dewott2501/Mario-Madness, Apache-2.0)
-- https://github.com/Dewott2501/Mario-Madness
-- The original hardcodes this type as 'Nota veneno' (source/Note.hx) and
-- applies the damage-over-time in source/PlayState.hx (healthDrain += 0.0020,
-- a 2 second timer). Here it lives in a custom_notetypes script, so the
-- engine itself needs no changes.
--
-- Behaviour (faithful to the original):
--   * hitting the note in your lane counts as a miss (the engine treats
--     hitCausesMiss notes as misses: no score, combo reset, miss damage)
--   * you then keep losing health for POISON_TIME seconds
--   * the note does not count for score or accuracy (ignoreNote)
--   * opponent-lane notes of this type behave as normal opponent notes
--   * uses the "poison_NOTE_assets" atlas when the mod ships one, otherwise
--     the note keeps the player's regular note skin
--
-- Not ported: the BadMario poison overlay and the poison-mushroom event that
-- drains Luigi-life are stage/song mechanics, not part of the note type.
-- Mario Madness re-adds those from onEvent / your stage script.

local NOTE_TYPE    = 'Poison Note' -- must match this file's name
local SKIN         = 'poison_NOTE_assets'
local POISON_TIME  = 2.0   -- seconds the drain lasts after a hit
local POISON_DRAIN = 0.002 -- health lost per 1/60th of a second (the original's rate; 0.24 health total)

-- Shared helpers. Every custom_notetypes script is self-contained because
-- notetype scripts may load before anything else does.
local function targetGroup(isSustainNote)
	if isSustainNote then return 'sustainNotes' end
	return 'notes'
end

local poisonTimer = 0

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
	-- Hitting a hitCausesMiss note fires this through the shared hit path in
	-- Phoenix, once per note. Refresh the drain window instead of stacking.
	poisonTimer = POISON_TIME
end

function noteMiss(id, noteData, noteType, isSustainNote)
	if noteType ~= NOTE_TYPE then return end
	-- Untouched poison notes stay inert (ignoreNote), so nothing to do here;
	-- this hook exists in case your chart uses poison notes as obstacles the
	-- player must avoid and you want a sound or a screen effect on the miss.
end

function onUpdate(elapsed)
	if poisonTimer <= 0 then return end
	poisonTimer = poisonTimer - elapsed
	addHealth(-POISON_DRAIN * 60 * elapsed)
end

function onDestroy()
	poisonTimer = 0
end
