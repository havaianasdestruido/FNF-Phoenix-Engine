--[[
  w32-window.lua : the game window itself reacts to your notes
  ===========================================================

  This is the "move the OS window on every note" idea, ported so the engine will
  actually load it and so it runs on every desktop the game ships for.

  Why it is not the original version
  ----------------------------------
  The original drove `openfl.Lib.application.window.x/y` through
  `setPropertyFromClass`. Two things stop that:

    1. `openfl.Lib` is on `ScriptSecurityScanner`'s native-class blacklist
       (`source/backend/ScriptSecurityScanner.hx`), so the script is refused
       before its first line runs. The finding is `engine.native-class`, and
       tools/validate_win32modchart.py reports it too.
    2. The Lua API has no window-position setter at all: `WindowCallbacks.hx`
       exposes the display mode and the size, not an origin.

  So the movement is applied to the one whole-window channel the engine does
  expose: `setWindowAlpha` / `getWindowAlpha` (Windows, Linux and macOS; a no-op
  that logs a reason where it is unsupported).

  What that costs
  ---------------
  A 35 px window slide moves the frame; an alpha drop dims the whole picture.
  `PX_TO_ALPHA` converts one pixel of the original travel into the same fraction
  of a 720 px frame, so the numbers keep their weight:

      35 px punch   -> 0.049 alpha of travel
      12 px vibrato -> 0.017 alpha of travel

  The punch never actually arrives: `returnSpeed` starts pulling the target home
  on the very next frame, so the smoother peaks around 0.65 of it -- and that is
  true of the original too, which is why the 35 px "move" reads as a ~23 px
  nudge. Measured here, on the real code:

      punch peak    ~23 px  -> alpha 0.968  (3.2 % dim)
      vibrato peak  ~11 px  -> alpha 0.985  (1.5 % dim)
      both at once          -> alpha 0.964  (3.6 % dim)

  `tools/simulate_win32_scripts.py` measures those numbers on every run and
  fails if the effect either stops being visible or starts being a flash.

  Alpha is a single number, so the punch cannot tell left from right any more;
  direction now only chooses which axis carries the sustain vibrato, exactly as
  the original did. The curve, the decay, the smoothing and the sustain hold are
  otherwise unchanged.

  Safety
  ------
  The alpha the player had before the song is read once and written back on
  `onEndSong`, `onGameOver` and `onDestroy`, so a story week cannot inherit a
  dimmed window.

  A whole-window brightness change *is* a flash, so this file is all or
  nothing: with `flashing` off or `reducedMotion` on it never writes alpha at
  all. The `modchart` persistent variable gates it the same way.
]]

----------------------------------------------------------------------
-- Tuning (same names as the original)
----------------------------------------------------------------------

local moveAmount = 35         -- punch distance, in pixels of the original idea
local returnSpeed = 8         -- how fast the punch settles back
local smoothSpeed = 20        -- how fast the window catches up to the target

local vibratoIntensity = 12   -- sustain shake, in the same pixel units
local vibratoSpeed = 45       -- oscillation speed
local vibratoDecay = 15       -- how fast the shake stops after the hold ends

--- Pixels of window travel to units of window alpha: the same fraction of the
--- frame the original slide covered, on this mod's 720 px target.
local PX_TO_ALPHA = 1 / 720

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------

local originAlpha = 1.0   -- what the window looked like before the song
local built = false       -- hooks own the window right now
local armed = false       -- the song wants the window and the prefs allow it
local active = false      -- prefs allow the effect at all

local targetOffsetX, targetOffsetY = 0, 0
local currentOffsetX, currentOffsetY = 0, 0

local vibratoTimer = 0
local currentVibrato = 0
local vibratoDir = 0

--- Last value actually handed to the window. `setWindowAlpha` is a native call,
--- so it is only made when the value moved by more than this; a 0.001 step is
--- well under one 8-bit alpha level and invisible.
local lastWritten = -1.0
local WRITE_EPSILON = 0.001

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

local function lerp(a, b, t)
  return a + (b - a) * math.min(t, 1)
end

local function pref(field, fallback)
  local ok, value = pcall(getPropertyFromClass, 'backend.ClientPrefs', field)
  if not ok or value == nil then
    return fallback
  end
  return value
end

local function log(message)
  debugPrint('[w32-window] ' .. message)
end

--- The scripting variable that turns the whole modchart off.
--- @return True when the modchart is enabled.
local function modchartEnabled()
  local ok, value = pcall(getProperty, 'modchart')
  if not ok or value == nil then
    return true
  end
  return value == true
end

--- Push the current offset (plus any vibrato) at the window.
--- @param vibX Horizontal vibrato contribution, in pixels.
--- @param vibY Vertical vibrato contribution, in pixels.
local function pushWindow(vibX, vibY)
  -- Alpha is scalar, so the two axes fold together here.
  local travel = math.abs(currentOffsetX + vibX) + math.abs(currentOffsetY + vibY)
  local value = originAlpha - travel * PX_TO_ALPHA
  if value < 0.35 then
    value = 0.35
  end
  if math.abs(value - lastWritten) < WRITE_EPSILON then
    return
  end
  lastWritten = value
  setWindowAlpha(value)
end

--- Put the window back the way it was found.
local function restore(why)
  if not built then
    return
  end
  setWindowAlpha(originAlpha)
  lastWritten = originAlpha
  built = false
  targetOffsetX, targetOffsetY = 0, 0
  currentOffsetX, currentOffsetY = 0, 0
  currentVibrato = 0
  log('window restored (' .. why .. ')')
end

----------------------------------------------------------------------
-- Hooks
----------------------------------------------------------------------

function onCreatePost()
  active = pref('flashing', true) == true and pref('reducedMotion', false) == false

  -- Read once: `getWindowAlpha` reports the last value set through
  -- `setWindowAlpha`, so saving it here is what makes the restore exact.
  local current = getWindowAlpha()
  if type(current) == 'number' and current >= 0.5 then
    originAlpha = current
  else
    originAlpha = 1.0
  end

  armed = modchartEnabled() and active
  built = armed
  lastWritten = originAlpha

  if not active then
    log('flashing is off or reduced motion is on, the window will not dim')
    return
  end

  if not isWindowTransparencySupported() then
    log('this platform cannot do window alpha, the script will idle')
  end
end

function onUpdate(elapsed)
  -- The switch can be flipped from options mid-song.
  if armed and not modchartEnabled() then
    armed = false
    restore('modchart off')
    return
  end

  if not built then
    return
  end

  -- Smoothly decay the directional offset back to zero.
  targetOffsetX = lerp(targetOffsetX, 0, elapsed * returnSpeed)
  targetOffsetY = lerp(targetOffsetY, 0, elapsed * returnSpeed)

  currentOffsetX = lerp(currentOffsetX, targetOffsetX, elapsed * smoothSpeed)
  currentOffsetY = lerp(currentOffsetY, targetOffsetY, elapsed * smoothSpeed)

  -- Vibrato wave.
  vibratoTimer = vibratoTimer + elapsed * vibratoSpeed
  currentVibrato = lerp(currentVibrato, 0, elapsed * vibratoDecay)

  local vibX, vibY = 0, 0
  if currentVibrato > 0.1 then
    local wave = math.sin(vibratoTimer) * currentVibrato
    -- Shake perpendicular to the held note's direction.
    if vibratoDir == 0 or vibratoDir == 3 then
      vibY = wave
    else
      vibX = wave
    end
  end

  pushWindow(vibX, vibY)
end

--- Apply a note to the window.
--- @param direction Lane the note was in, 0..3.
--- @param isSustainNote Whether the note was a hold.
local function handleNote(direction, isSustainNote)
  if isSustainNote then
    -- Keep the vibrato running while a hold is being held.
    currentVibrato = vibratoIntensity
    vibratoDir = direction
  else
    -- Regular smooth directional punch.
    if direction == 0 then
      targetOffsetX = -moveAmount
    elseif direction == 1 then
      targetOffsetY = moveAmount
    elseif direction == 2 then
      targetOffsetY = -moveAmount
    elseif direction == 3 then
      targetOffsetX = moveAmount
    end
  end
end

function goodNoteHit(id, direction, noteType, isSustainNote)
  if not built or type(direction) ~= 'number' then
    return
  end
  handleNote(direction, isSustainNote)
end

--[[
  The original left this commented out. Kept that way for the same reason: the
  opponent sings far more than the player, and a window that dims on every one
  of dad's notes never gets a chance to settle.

function opponentNoteHit(id, direction, noteType, isSustainNote)
  handleNote(direction, isSustainNote)
end
]]

function onPause()
  -- The pause screen must not keep dimming.
  restore('pause')
end

function onResume()
  if armed then
    built = true
  end
end

function onEndSong()
  armed = false
  restore('song end')
end

function onGameOver()
  restore('game over')
end

function onDestroy()
  armed = false
  restore('destroy')
end
