-- Bullet Bill — Mario Madness custom note type ported to Phoenix.
--
-- Ported from Mario Madness (Dewott2501/Mario-Madness, Apache-2.0)
-- https://github.com/Dewott2501/Mario-Madness
-- The original hardcodes it in source/Note.hx ('Bullet Bill') and reacts in
-- source/PlayState.hx: no sing animation, a custom splash skin, and a counter
-- that only splashes every 2nd bullet hit with a gunshot sound instead of the
-- per-note splashes of normal charts. Here it lives in a custom_notetypes
-- script, so the engine itself needs no changes.
--
-- Behaviour (faithful to the original where the engine allows it):
--   * no sing animation on hit (noAnimation); the miss animation is kept
--   * uses the "bulletbill_NOTE_assets" atlas when the mod ships one (a
--     missing one keeps the regular skin); SPLASH_SKIN also becomes the
--     note's splash skin — a missing splash atlas falls back to the default
--   * downScroll charts get flipY and a matching offsetY, like the original
--   * every 2nd hit plays GUN_SOUND
--   * opponent-lane notes of this type behave as normal opponent notes
--
-- Differences from the original to be aware of:
--   * Phoenix always plays the colour-based 'Scroll' animation from the skin;
--     there is no 'bullet bill note' looping frame support here. Ship the
--     atlas with standard note frames (purple0/blue0/...) and the note shows
--     its direction as usual.
--   * Phoenix always spawns the normal splash on 'sick' hits. The original
--     suppressed splashes and re-created one every second bullet; a script
--     cannot suppress the sick splash, so the every-2nd-hit gunshot sound is
--     kept but the splash counter is not replicated.
--   * The 1 second SHbulletmiss timer after a hit is song-specific timing
--     sugar from Mario's Madness TooLateBG stage, not a note property — not
--     ported.

local NOTE_TYPE   = 'Bullet Bill' -- must match this file's name
local SKIN        = 'bulletbill_NOTE_assets'
local SPLASH_SKIN = 'bulletbill_NOTE_assets' -- '' keeps the chart's splash skin
local OFFSET_X    = -50 -- the original's offsetX -= 50
local OFFSET_Y    = 10  -- the original's offsetY += 10
local GUN_SOUND   = 'SHbullethit' -- '' disables; every 2nd hit when the mod ships it

-- Bullet2 (the same note with a wider horizontal offset) is not a separate
-- file: copy this file to 'Bullet2.lua', set NOTE_TYPE = 'Bullet2' and
-- OFFSET_X = -163.

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

local bulletHits = 0

function onSpawnNote(id, noteData, noteType, isSustainNote, strumTime)
	if noteType ~= NOTE_TYPE then return end
	local group = targetGroup(isSustainNote)
	setPropertyFromGroup(group, id, 'noAnimation', true) -- the miss animation still plays, like the original
	if SKIN ~= '' then
		setPropertyFromGroup(group, id, 'texture', SKIN)
	end
	if SPLASH_SKIN ~= '' then
		setPropertyFromGroup(group, id, 'noteSplashData.texture', SPLASH_SKIN)
	end

	local offsetX = getPropertyFromGroup(group, id, 'offsetX')
	local offsetY = getPropertyFromGroup(group, id, 'offsetY')
	setPropertyFromGroup(group, id, 'offsetX', offsetX + OFFSET_X)
	setPropertyFromGroup(group, id, 'offsetY', offsetY + OFFSET_Y)
	if getPropertyFromClass('ClientPrefs', 'downScroll') then
		setPropertyFromGroup(group, id, 'flipY', true)
		local height = getPropertyFromGroup(group, id, 'height')
		local currentOffsetY = getPropertyFromGroup(group, id, 'offsetY')
		setPropertyFromGroup(group, id, 'offsetY', currentOffsetY - (height - 50))
	end
end

function goodNoteHit(id, direction, noteType, isSustainNote)
	if noteType ~= NOTE_TYPE then return end
	bulletHits = bulletHits + 1
	if bulletHits % 2 == 0 then
		playSoundIfExists(GUN_SOUND, 0.6)
	end
end

function onCreate()
	bulletHits = 0
end
