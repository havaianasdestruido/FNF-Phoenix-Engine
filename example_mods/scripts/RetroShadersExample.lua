-- RetroShadersExample.lua — runnable tour of the built-in retro screen effects.
--
-- Drop this into mods/<your-mod>/scripts/ (or a song's data/<song>/ folder) and
-- start any song. See docs/SHADERS.md for every parameter and for the HScript
-- and Python spellings of the same calls. Nothing here runs unless a script
-- attaches an effect, so deleting this file restores the vanilla picture.
--
-- Every call below is gated by the player's Options -> Graphics -> Shaders
-- toggle: with shaders off none of these functions is registered at all, so
-- guard your own calls if you also support that setting.
--
-- Each of these is a full-screen post-process pass. On the low-end phones this
-- engine targets, one is affordable and four is a slideshow, so pick the one the
-- song needs instead of stacking them.

function onCreatePost()
	-- Curved CRT: screen warp, scanlines, RGB shadow mask and a vignette.
	-- The most generally useful of the set for a retro mod. Eleven texture
	-- fetches per pixel, so give it one camera and nothing else.
	addCRTEffect('game')

	-- The same look, tuned: twice the curvature, harder scanlines, no shadow
	-- mask, a stronger vignette and a coarser emulated resolution.
	-- addCRTEffect('game', 2.0, -16.0, -4.0, 0.0, 0.6, 0.35)

	-- A flat screen with only the scanlines left:
	-- addCRTEffect('game', 0.0, -12.0, -3.0, 0.0, 0.0, 0.5)

	-- Broken old television: rolling picture-offset bar, sploches and static.
	-- `blur` is the expensive smear and defaults to 0 for that reason.
	-- addOldTVEffect('game', 0.08, 1.0, 0.0, true, 0.01)

	-- Untuned-channel static, the effect Mario Madness runs on its title screen.
	-- addTVStaticEffect('game', 1.0, 0.3, 0.8, 20.0)

	-- Water ripple, for a reflection or an underwater stage.
	-- addRippleEffect('game', 10.0, 0.5, 1.0)

	-- VHS tape fuzz without the glitch bursts of addVCREffect, plus the curved
	-- frame that used to ship next to it.
	-- addVCRFuzzEffect('game', 1.0, 0.003, 0.04, 800.0)
	-- addVCRBorderEffect('game', 1.0, 1.0, true)

	-- Dim a distracting stage while the notes and the HUD stay bright: this one
	-- sits on camGame only, and it is the cheapest effect in the list.
	-- addBrightnessContrastEffect('game', 0.65, 1.1)
end

function onBeatHit()
	-- Per-sprite shaders take the sprite's name where a camera name would go.
	-- A silhouette keeps the character's shape and flattens its colours; the
	-- colour accepts a number, a hex string or a colour name.
	if curBeat == 16 then
		addSilhouetteEffect('boyfriend', 0xFF0000, 1.0)
		addSilhouetteEffect('dad', 'red', 0.75)
	end

	-- Pixelate the whole screen for a "through a bad monitor" beat, then undo it.
	if curBeat == 32 then
		addMosaicEffect('game', 12.0)
		-- addSMWPixelBlurEffect('game', 16.0, 4.0) -- wide blocks, same shader
	end
	if curBeat == 40 then
		clearEffects('game') -- removes every effect this script put on camGame
	end
end
