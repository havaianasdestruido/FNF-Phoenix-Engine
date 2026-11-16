-- FiltersExample.lua — runnable tour of the plain filters and chainable effects.
--
-- Two families live here, neither of which needs GLSL:
--
--   * OpenFL bitmap filters on a camera or on the whole window. These are the
--     filters `FlxG.camera.filters` / `FlxG.game.filters` take: blur, glow,
--     drop shadow, colour matrix, convolution kernels and displacement maps.
--   * `flixel.addons.effects.chainable` sprite effects, which rewrite one
--     sprite's pixels every frame: shake, wave, glitch, rainbow, outline, trail.
--
-- Drop this into mods/<your-mod>/scripts/ (or a song's data/<song>/ folder) and
-- start any song. Delete the file to get the vanilla picture back — everything
-- below is added by this script, and PlayState also drops scripted filters when
-- the song ends.
--
-- See docs/SHADERS.md for every parameter, the preset list, and the Python and
-- HScript spellings of the same calls. Unlike the shader effects these do not
-- depend on the Shaders option, so there is nothing to guard.

function onCreatePost()
	-- A named filter per target. `name` is how you address it afterwards;
	-- re-using a name replaces that filter instead of stacking a second one.
	-- `'global'` is FlxG.game: the whole window, under every camera.
	addColorFilter('global', 'handheld', 'gameboy')

	-- Soft HUD, so text reads on a busy background. blurX, blurY, quality.
	addBlurFilter('hud', 'soft', 3, 3)

	-- The same filters through the generic entry point: type, name, then that
	-- filter's own arguments in its own order.
	-- addFilter('game', 'glow', 'warm', 'orange', 0.8, 8, 8, 3, 1)

	-- Drop shadow behind everything the stage camera draws (distance, angle,
	-- colour, alpha, blurX, blurY, strength, quality, ...).
	-- addDropShadowFilter('game', 'shadow', 6, 45, 0x000000, 0.6, 6, 6, 2, 1)

	-- Sharpen the stage with a 3x3 convolution kernel. The divisor equals the
	-- sum of the entries so brightness does not change.
	-- addConvolutionFilter('game', 'sharpen', {0, -1, 0, -1, 5, -1, 0, -1, 0}, 3, 3, 1)

	-- Water warp: `rippleMap` must be a greyscale image in mods/<mod>/images/.
	-- addDisplacementMapFilter('game', 'water', 'rippleMap', 1, 2, 6, 6, 'wrap')

	-- Chainable effects: each call appends to that sprite's chain, in call
	-- order, and the engine swaps in a wrapper sprite that keeps the original's
	-- place in the draw order and camera assignment.
	addRainbowEffect('boyfriend', 1, 1, 6)                -- alpha, brightness, speed
	addSpriteOutlineEffect('boyfriend', 'white', 2, 'fast') -- colour, thickness, mode
end

function onUpdate(elapsed)
	-- Filter properties are live: naming the target and the filter is enough.
	if getProperty('health') > 1.5 then
		setFilterProperty('hud', 'soft', 'blurX', 12)
		setFilterProperty('hud', 'soft', 'blurY', 12)
	elseif getFilterProperty('hud', 'soft', 'blurX') ~= 3 then
		setFilterProperty('hud', 'soft', 'blurX', 3)
		setFilterProperty('hud', 'soft', 'blurY', 3)
	end
end

function onBeatHit()
	-- A one-shot jolt: intensity, duration, axes ('x', 'y' or 'xy').
	if curBeat % 16 == 0 then
		addSpriteShakeEffect('dad', 4, 0.4, 'xy')
	end

	-- Slices keep getting reshuffled while the effect is on (strength, size,
	-- delay, direction). Toggle it with the chain helpers rather than piling up
	-- duplicates: removeChainableEffect(tag, index) drops a single entry.
	if curBeat == 32 then
		addSpriteGlitchEffect('gf', 3, 1, 0.05)
		addSpriteWaveEffect('gf', 10, 0.5, 3, 5, 'all', 'vertical')
	elseif curBeat == 64 then
		removeChainableEffect('gf', 0)
		removeChainableEffect('gf', 0)
	end

	-- Trails are per-sprite and CPU-side: length, alpha, framesDelay,
	-- cachePixels (turn it off for animated sprites).
	if curBeat == 96 then
		addSpriteTrailEffect('boyfriend', 10, 0.5, 2, false)
	end

	-- Filter shortcuts for the "screen glitch" beat.
	if curBeat == 128 then
		addColorFilter('global', 'handheld', 'invert')
	elseif curBeat == 136 then
		removeFilter('global', 'handheld')
	end
end

function onEndSong()
	-- Unwraps the sprite and drops every chainable effect this script added.
	-- Filters clear themselves when the state is destroyed, but doing it here
	-- keeps a freeplay marquee from keeping a stale 'global' filter.
	removeChainableEffects('boyfriend')
	clearFilters('global')
end
