-- Boo Note — Mario Madness custom note type ported to Phoenix.
--
-- Ported from Mario Madness (Dewott2501/Mario-Madness, Apache-2.0)
-- https://github.com/Dewott2501/Mario-Madness
-- The original hardcodes it as 'Nota boo' (source/Note.hx), where it is
-- exactly this: a texture swap and nothing else. Here it lives in a
-- custom_notetypes script, so the engine itself needs no changes.
--
-- Behaviour (faithful to the original):
--   * nothing but the skin change — scoring, accuracy, animations,
--     opponent behaviour: all normal
--   * uses the "boo_NOTE_assets" atlas when the mod ships one

local NOTE_TYPE = 'Boo Note' -- must match this file's name
local SKIN      = 'boo_NOTE_assets'

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
end
