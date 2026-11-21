-- ExtraVocalsExample.lua — chart-declared extra vocal stems (docs/EXTRA_VOCALS.md).
--
-- A chart can declare extra vocal tracks beyond the player/opponent ones:
--
--     "extraVocals": [
--         { "name": "gf",   "file": "GF",   "side": "none"   },
--         { "name": "pico", "file": "Pico", "side": "player" }
--     ]
--
-- `file` resolves `Voices-<file>.ogg` in the song folder (difficulty variants
-- like `Voices-GF-hard.ogg` win first); `side` decides whether the stem mutes
-- with the player strumline, the opponent strumline, or never ("none" — the
-- right choice for GF-style third voices). Drop this into
-- mods/<your-mod>/scripts/ and play a chart that declares extraVocals — every
-- call below is a safe no-op for songs without stems.

function onSongStart()
	-- Which stems did this chart declare? In chart order.
	local names = getExtraVocalNames()
	for i, name in ipairs(names) do
		debugPrint('extra vocal stem: ' .. name)
	end

	-- Soften a stem by name. Miss-muting still applies to sided stems.
	setExtraVocalVolume('gf', 0.85)
end

function onBeatHit()
	-- Duck a stem every other beat, restore it in between.
	if getExtraVocalVolume('choir') > 0 then
		if curBeat % 2 == 0 then
			setExtraVocalVolume('choir', 0.25)
		else
			setExtraVocalVolume('choir', 1)
		end
	end
end

function onEvent(name, value1, value2)
	-- Handy with a "Set Extra Vocal Volume" custom event: value1 = stem name,
	-- value2 = volume.
	if name == 'Set Extra Vocal Volume' then
		setExtraVocalVolume(value1, tonumber(value2) or 1)
	end
end
