--[[
	GDI Effects Example Script
	===========================
	
	This demonstrates the Windows GDI effects ported from Slushi Engine.
	These effects draw directly on the desktop using raw GDI calls,
	running on a dedicated background thread so they never lag the game.
	
	Available effects (register first, then enable):
	- "DrawIcons"       -- Error/warning icons follow the mouse cursor
	- "ScreenBlink"     -- Invert desktop colors (flash)
	- "ScreenGlitches"  -- Copy random rectangles to random positions
	- "ScreenTunnel"    -- Recursive StretchBlt tunnel
	- "ScreenShake"     -- Shake screen with small random offsets
	- "SetTitleText"    -- Set custom text on all window title bars
	
	One-shot triggers (run immediately, no registration needed):
	- gdiDrawIcons()
	- gdiScreenBlink()
	- gdiScreenGlitches()
	- gdiScreenTunnel()
	- gdiScreenShake()
	- gdiSetTitleText(text)
]]

-- Initialize the GDI subsystem (call once at the start of your mod)
function onCreate()
	if not gdiInit() then
		debugPrint("GDI Effects not available on this platform")
		return
	end
	
	debugPrint("GDI Effects initialized!")
	debugPrint("Available effects: " .. table.concat(gdiGetAvailableEffects(), ", "))
	
	-- Register the effects you want to use
	gdiRegisterEffect("ScreenGlitches")
	gdiRegisterEffect("ScreenTunnel")
	gdiRegisterEffect("DrawIcons")
	
	-- Set wait times (ms between frames) to control speed/CPU usage
	gdiSetEffectWait("ScreenGlitches", 50)  -- 20 FPS
	gdiSetEffectWait("ScreenTunnel", 30)    -- ~33 FPS
	gdiSetEffectWait("DrawIcons", 16)       -- ~60 FPS
end

-- Example: Enable effects during a specific section
function onUpdatePost(elapsed)
	-- Enable glitches during the first 10 seconds
	if getSongTime() < 10 then
		gdiEnableEffect("ScreenGlitches")
	else
		gdiDisableEffect("ScreenGlitches")
	end
	
	-- Enable tunnel during the chorus
	if getSongTime() > 30 and getSongTime() < 60 then
		gdiEnableEffect("ScreenTunnel")
	else
		gdiDisableEffect("ScreenTunnel")
	end
	
	-- Draw icons when player misses
	if getProperty("misses") > 0 then
		gdiEnableEffect("DrawIcons")
	else
		gdiDisableEffect("DrawIcons")
	end
end

-- One-shot triggers for specific events
function goodNoteHit(id, direction, noteType, isSustainNote)
	-- Flash screen on perfect hit
	if getProperty("rating") == "SICK" then
		gdiScreenBlink()
	end
end

function noteMiss(id, direction, noteType, isSustainNote)
	-- Glitch on miss
	gdiScreenGlitches()
	
	-- Set custom title text
	gdiSetTitleText("You missed a note! :(")
end

function onGameOver()
	-- Shake screen on game over
	gdiScreenShake()
	gdiSetTitleText("GAME OVER")
end

function onEndSong()
	-- Clean up
	gdiSetTitleText("")  -- Restore normal titles
	gdiDestroy()
end

-- Helper to print table contents
function table.concat(t, sep)
	local result = ""
	for i, v in ipairs(t) do
		if i > 1 then result = result .. sep end
		result = result .. tostring(v)
	end
	return result
end