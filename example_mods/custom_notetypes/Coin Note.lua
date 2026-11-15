-- Coin Note — Mario Madness custom note type ported to Phoenix.
--
-- Ported from Mario Madness (Dewott2501/Mario-Madness, Apache-2.0)
-- https://github.com/Dewott2501/Mario-Madness
-- The original hardcodes it in source/Note.hx ('Coin Note') and reacts in
-- source/PlayState.hx (a luigilife counter and the refill sound on hit).
-- Here it lives in a custom_notetypes script, so the engine itself needs no
-- changes.
--
-- Behaviour (faithful to the original):
--   * counts for nothing — ignored by score and accuracy (ignoreNote)
--   * hitting it plays COIN_SOUND and bumps the coin counter
--   * opponent-lane notes of this type behave as normal opponent notes
--   * uses the "coin_NOTE_assets" atlas when the mod ships one
--
-- The counter lives in this script; other scripts can read it with:
--   local coins = callScript('custom_notetypes/Coin Note.lua', 'getCoins', {})
-- and a dialogue or cutscene script can zero it with resetCoins(). The
-- original's luigilife/dad-hop/refill-sound interplay is stage-specific, so
-- it is not ported — re-add it in your own stage or song scripts if you want
-- it (Mario Madness does it right where the coin sound plays below).

local NOTE_TYPE  = 'Coin Note' -- must match this file's name
local SKIN       = 'coin_NOTE_assets'
local COIN_SOUND = 'smw_coin' -- '' disables; played on hit when the mod ships it

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

local coinCount = 0

function onSpawnNote(id, noteData, noteType, isSustainNote, strumTime)
	if noteType ~= NOTE_TYPE then return end
	local group = targetGroup(isSustainNote)
	local mustPress = getPropertyFromGroup(group, id, 'mustPress')

	setPropertyFromGroup(group, id, 'ignoreNote', mustPress)
	if SKIN ~= '' then
		setPropertyFromGroup(group, id, 'texture', SKIN)
	end
end

function goodNoteHit(id, direction, noteType, isSustainNote)
	if noteType ~= NOTE_TYPE then return end
	coinCount = coinCount + 1
	playSoundIfExists(COIN_SOUND, 1)
end

function getCoins()
	return coinCount
end

function resetCoins()
	coinCount = 0
end

function onCreate()
	coinCount = 0
end
