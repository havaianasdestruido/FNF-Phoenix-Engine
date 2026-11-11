-- ModchartExample.lua — runnable tour of the modchart API.
--
-- Drop this into mods/<your-mod>/scripts/ (or a song's data/<song>/ folder)
-- and start any song. See docs/MODCHART.md for the full API and modifier
-- list. Nothing here runs unless a script adds a modifier, so removing this
-- file restores vanilla arrow behaviour immediately.

local beaten = false

function onCreatePost()
	-- Modifiers only do something once installed.
	addModifier('reverse')
	addModifier('drunk')
	addModifier('scale')
	addModifier('bounce')

	-- A second playfield transforms independently of the first, letting you
	-- build layers (the adapter applies playfields in index order).
	addPlayfield()

	-- Timeline: everything is in beats of the current song.
	modSet('reverse', 8, 1)                       -- flip the scroll on beat 8
	modEase('drunk', 8, 4, 0.2, 'quadOut')        -- ease wobble in
	modSet('xmod', 16, 0.6)                       -- slow the scroll offset
	modEase('reverse', 24, 2, 0, 'quadInOut')     -- unflip at beat 24
	modEase('drunk', 24, 4, 0, 'quadIn')          -- and settle it back down

	modSetAdd('bounce', 32, 0.5)                  -- instant nudge at the drop
	modCallback(32, 'onModchartDrop')
	modRepeater(36, 4, 'onModchartPulse')
end

function onUpdatePost(elapsed)
	-- Percentages can also be driven from the frame loop when you need
	-- something the timeline cannot express.
	if curBeat > 48 and not beaten then
		beaten = true
		setModchartPerspective(true, 90, 1)
	end
end

function onModchartDrop()
	setModchartPerspective(true, 90, 1)
	modEase('scale', 32, 1, 0.8, 'elasticOut')
end

function onModchartPulse(beat)
	-- Every 4 beats: pulse the field out and back. Callbacks receive the
	-- beat they fired on, so follow-up tweens are scheduled from it.
	modEase('bounce', beat, 2, 0.5, 'quadOut')
	modEase('bounce', beat + 2, 2, 0, 'quadIn')
end

function onDestroy()
	resetModchart()
end
