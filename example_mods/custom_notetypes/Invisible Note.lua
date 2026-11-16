-- Invisible Note — Mario Madness custom note type ported to Phoenix.
--
-- Ported from Mario Madness (Dewott2501/Mario-Madness, Apache-2.0)
-- https://github.com/Dewott2501/Mario-Madness
-- The original hardcodes it as 'Yoshi Note' (source/Note.hx), where it swaps
-- in an invisible note skin on a few stages (exesequel/betamansion/nesbeat) so
-- Memory Boxes-style charts can trick the player. Here it lives in a
-- custom_notetypes script, so the engine itself needs no changes and the
-- effect works on every stage.
--
-- Behaviour:
--   * the note renders at alpha 0 — invisible on screen
--   * it is fully playable: scrolling, hitting, splashes, opponent notes,
--     scoring — everything normal
--   * no atlas needed (unlike the original, which shipped an invisible
--     spritesheet); the note keeps the regular skin at alpha 0
--
-- Set SKIN if you would rather use custom atlas frames (e.g. fully
-- transparent); the alpha-0 fade below is always applied on top, so a script
-- never depends on the atlas actually existing — a missing one keeps the
-- regular skin at alpha 0 either way.

local NOTE_TYPE = 'Invisible Note' -- must match this file's name
local SKIN      = ''               -- e.g. 'invisible_NOTE_assets'; '' keeps the regular skin
local ALPHA     = 0                -- 0 = fully invisible, raise to tease the shape

-- Shared helpers. Every custom_notetypes script is self-contained because
-- notetype scripts may load before anything else does.
local function targetGroup(isSustainNote)
	if isSustainNote then return 'sustainNotes' end
	return 'notes'
end

function onSpawnNote(id, noteData, noteType, isSustainNote, strumTime)
	if noteType ~= NOTE_TYPE then return end
	local group = targetGroup(isSustainNote)
	if SKIN ~= '' then
		setPropertyFromGroup(group, id, 'texture', SKIN)
	end
	-- followStrum() rewrites note alpha every frame from strum.alpha *
	-- multAlpha (while copyAlpha is on), so alpha=0 alone would not stick.
	-- multAlpha=0 keeps it invisible regardless of the per-frame write.
	setPropertyFromGroup(group, id, 'multAlpha', 0)
	setPropertyFromGroup(group, id, 'copyAlpha', false)
	setPropertyFromGroup(group, id, 'alpha', ALPHA)
end
