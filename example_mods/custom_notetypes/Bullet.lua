-- Bullet — Mario Madness custom note type ported to Phoenix.
--
-- Ported from Mario Madness (Dewott2501/Mario-Madness, Apache-2.0)
-- https://github.com/Dewott2501/Mario-Madness
-- The original hardcodes it in source/Note.hx ('Bullet') and reacts in
-- source/PlayState.hx: on hit it triggers the 'Pico Shoot' event; on miss it
-- runs the TooLateBG gun ammo cycle (ammo - 1, FAILGUN, gunAmmo sprite,
-- health = 0 at zero ammo). Here it lives in a custom_notetypes script, so
-- the engine itself needs no changes.
--
-- Behaviour (faithful to the original, minus the stage-specific parts):
--   * no sing animation on hit (the original excludes Bullet from the sing
--     anim check; noAnimation covers the same for both lanes and the miss
--     animation is kept, like the original)
--   * on hit, BULLET_HIT_EVENT is triggered (default 'Pico Shoot', the event
--     the Philly Blazin / Darnell handlers listen for — scripts can also
--     listen to it through onEvent)
--   * opponent-lane notes of this type behave as normal opponent notes
--   * uses the "bullet_NOTE_assets" atlas when the mod ships one
--
-- Not ported: the gun ammo counter, the FAILGUN sound, the gunAmmo HUD sprite
-- and the run-out-of-ammo death are TooLateBG/street-stage mechanics tied to
-- one song. Mario Madness re-adds those from noteMiss if you want them —
-- handle the ammo there, where the player's bullets are missed.

local NOTE_TYPE        = 'Bullet' -- must match this file's name
local SKIN             = 'bullet_NOTE_assets'
local BULLET_HIT_EVENT = 'Pico Shoot' -- '' disables the event

-- Shared helpers. Every custom_notetypes script is self-contained because
-- notetype scripts may load before anything else does.
local function targetGroup(isSustainNote)
	if isSustainNote then return 'sustainNotes' end
	return 'notes'
end

function onSpawnNote(id, noteData, noteType, isSustainNote, strumTime)
	if noteType ~= NOTE_TYPE then return end
	local group = targetGroup(isSustainNote)
	setPropertyFromGroup(group, id, 'noAnimation', true) -- the miss animation still plays, like the original
	if SKIN ~= '' then
		setPropertyFromGroup(group, id, 'texture', SKIN)
	end
end

function goodNoteHit(id, direction, noteType, isSustainNote)
	if noteType ~= NOTE_TYPE then return end
	if BULLET_HIT_EVENT ~= '' then
		-- fires onEvent so your custom_events/Pico Shoot.lua handler (or the
		-- built-in Philly Blazin / Darnell stages) do whatever they do
		triggerEvent(BULLET_HIT_EVENT, '', '', getSongPosition())
	end
end
