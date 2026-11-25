--[[
  w32-play.lua : gameplay helpers
  ==============================

  Three gameplay changes, all sharing one switch: the `modchart` persistent
  variable (set it false from Options, or at the top of another script, and this
  file goes quiet without unloading anything).

    * miss guard   : after a miss the playfield dims briefly; three misses in a
                     row put the count on screen
    * milestones   : a caption and a camera bump every 25 combo
    * speed control: 3 raises and 4 lowers the scroll speed, and every hand-over
                     snaps back to the speed the song asked for

  Keys
  ----
    3   raise scroll speed by 0.2, capped 2.0 above the chart's speed
    4   lower scroll speed by 0.2, floored 1.0 below the chart's speed

  How speed is written
  --------------------
  `songSpeed` is a `(default, set)` property: the setter also recomputes
  `noteKillOffset`, which is what decides how late a note may still be hit. That
  means it has to be written through the property, never through a raw field
  write, or late notes start disappearing at the wrong time.

  `setProperty('songSpeed', v)` and `startTween(..., 'songSpeed', ...)` both go
  through `Reflect.setProperty`, so both hit the setter. This file uses a tween
  for ramps (exactly what the engine's own "Change Scroll Speed" event does) and
  a direct write for snaps.

  The base speed is read once from the live `songSpeed` at song start, so a
  player's scroll-speed preference is already baked into it, and every restore
  goes back to that number rather than to a literal.
]]

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------

local COMBO_STEP = 25
local SPEED_STEP = 0.2
local SPEED_UP_LIMIT = 2.0
local SPEED_DOWN_LIMIT = 1.0
local DIM_ALPHA = 0.28
local MISS_STREAK_ALERT = 3

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------

local state = {
  enabled = true,
  canFlash = true,
  reducedMotion = false,
  built = false,
  baseSpeed = 2.4,
  speed = 2.4,
  lastComboStep = 0,
  dimming = false,
  missStreak = 0
}

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

--- Read a ClientPrefs field through the property bridge.
--- @param field Field name inside `backend.ClientPrefs`.
--- @param fallback Value returned when the field is missing.
--- @return The preference value.
local function pref(field, fallback)
  local ok, value = pcall(getPropertyFromClass, 'backend.ClientPrefs', field)
  if not ok or value == nil then
    return fallback
  end
  return value
end

--- Debug line with the script prefix.
--- @param message Text to print.
local function log(message)
  debugPrint('[w32-play] ' .. message)
end

--- The scripting variable that turns the modchart on and off.
--- @return True when the modchart is enabled.
local function modchartEnabled()
  local ok, value = pcall(getProperty, 'modchart')
  if not ok or value == nil then
    return true
  end
  return value == true
end

--- Flat-coloured, HUD-pinned sprite.
local function flat(tag, x, y, w, h, hex, alpha)
  makeLuaSprite(tag, nil, x, y)
  makeGraphic(tag, w, h, hex)
  setObjectCamera(tag, 'hud')
  setScrollFactor(tag, 0, 0)
  setProperty(tag .. '.alpha', alpha)
end

--- Live scroll speed, read through the property so the setter stays involved.
--- @param fallback Value returned when the property is unreadable.
--- @return Current songSpeed.
local function readSpeed(fallback)
  local ok, value = pcall(getProperty, 'songSpeed')
  if not ok or type(value) ~= 'number' or value <= 0 then
    return fallback
  end
  return value
end

----------------------------------------------------------------------
-- Speed control
----------------------------------------------------------------------

--- Show the current speed in the corner read-out.
local function showSpeed()
  if not state.built then
    return
  end
  setTextString('w32SpeedText', 'speed ' .. string.format('%.2f', state.speed))
end

--- Snap to a speed right now, killing any ramp in flight.
--- @param value Speed to write.
local function snapSpeed(value)
  cancelTween('w32SpeedTween')
  setProperty('songSpeed', value)
  state.speed = value
  showSpeed()
end

--- Ramp to a speed, the way the engine's own scroll-speed event does.
--- @param value Speed to reach.
--- @param seconds Length of the ramp.
local function rampSpeed(value, seconds)
  cancelTween('w32SpeedTween')
  startTween('w32SpeedTween', 'songSpeed', {songSpeed = value}, seconds, {ease = 'linear'})
  state.speed = value
  showSpeed()
end

--- Back to the speed the song shipped with.
--- @param instant True to skip the ramp.
local function resetSpeed(instant)
  if instant then
    snapSpeed(state.baseSpeed)
  else
    rampSpeed(state.baseSpeed, 0.25)
  end
end

----------------------------------------------------------------------
-- Layers
----------------------------------------------------------------------

--- Dim overlay, combo caption and the speed read-out.
local function build()
  if state.built then
    return
  end

  local w = screenWidth
  local h = screenHeight

  flat('w32MissDim', 0, 0, w, h, '000000', 0)
  addLuaSprite('w32MissDim', true)

  makeLuaText('w32ComboText', '', 360, w / 2 - 180, h * 0.30)
  setTextSize('w32ComboText', 26)
  setTextColor('w32ComboText', 'c8ff7a')
  setTextAlignment('w32ComboText', 'center')
  setObjectCamera('w32ComboText', 'hud')
  setScrollFactor('w32ComboText', 0, 0)
  setProperty('w32ComboText.alpha', 0)
  addLuaText('w32ComboText')

  -- Left column: turn counter at y 150 (17 pt), this at y 182 (13 pt), the
  -- window chip at y 216. The bottom-right belongs to the modchart's GDI/HPPD
  -- lines and to `scoreTxt`.
  makeLuaText('w32SpeedText', '', 240, 20, 182)
  setTextSize('w32SpeedText', 13)
  setTextColor('w32SpeedText', 'b9c2cc')
  setTextAlignment('w32SpeedText', 'right')
  setObjectCamera('w32SpeedText', 'hud')
  setScrollFactor('w32SpeedText', 0, 0)
  setProperty('w32SpeedText.alpha', 0.5)
  addLuaText('w32SpeedText')

  state.built = true
  log('gameplay layers in')
end

--- Show a caption for a moment, then fade it out.
--- @param text Caption body.
--- @param color Six hex digits.
local function flashCaption(text, color)
  setTextString('w32ComboText', text)
  setTextColor('w32ComboText', color)
  setProperty('w32ComboText.alpha', 1)
  setProperty('w32ComboText.y', screenHeight * 0.30)
  doTweenAlpha('w32ComboFade', 'w32ComboText', 0, 1.1, 'quadOut')
  doTweenY('w32ComboRise', 'w32ComboText', screenHeight * 0.26, 1.1, 'quadOut')
end

----------------------------------------------------------------------
-- Hooks
----------------------------------------------------------------------

function onCreatePost()
  state.canFlash = pref('flashing', true) == true
  state.reducedMotion = pref('reducedMotion', false) == true
  state.enabled = modchartEnabled()

  build()

  -- Read the live speed before anything writes it, so the restore is exact.
  state.baseSpeed = readSpeed(scrollSpeed or 2.4)
  state.speed = state.baseSpeed
  showSpeed()
end

function onSectionHit()
  if not state.enabled or not state.built then
    return
  end
  -- Hand-over: drop whatever the player dialled in, back to chart speed.
  resetSpeed(false)
end

function onBeatHit()
  if not state.built or not state.enabled then
    return
  end

  local current = combo or 0
  local step = math.floor(current / COMBO_STEP)
  if step > state.lastComboStep and step > 0 then
    state.lastComboStep = step
    flashCaption(step * COMBO_STEP .. ' COMBO', 'c8ff7a')
    if not state.reducedMotion then
      cameraShake('game', 0.006, 0.12)
    end
  end
end

--- Missed a note: dim, and count the streak for the message.
function noteMiss()
  if not state.built or not state.enabled then
    return
  end

  state.missStreak = state.missStreak + 1
  state.lastComboStep = 0

  if state.missStreak >= MISS_STREAK_ALERT then
    flashCaption('MISS x' .. state.missStreak, 'ff4d6d')
  end

  if state.dimming then
    return
  end
  state.dimming = true
  setProperty('w32MissDim.alpha', DIM_ALPHA)
  doTweenAlpha('w32MissDimFade', 'w32MissDim', 0, 0.45, 'quadOut')
end

--- Landed a note: the streak is over.
function goodNoteHit()
  state.missStreak = 0
end

function onUpdatePost()
  if not state.built then
    return
  end

  -- The dim tween ends on its own; stop calling it a dim once it is invisible.
  if state.dimming and (getProperty('w32MissDim.alpha') or 0) <= 0.001 then
    state.dimming = false
  end

  if not state.enabled then
    return
  end

  local ceiling = state.baseSpeed + SPEED_UP_LIMIT
  local floor = math.max(0.5, state.baseSpeed - SPEED_DOWN_LIMIT)

  if keyboardJustPressed('THREE') then
    state.speed = math.min(ceiling, state.speed + SPEED_STEP)
    rampSpeed(state.speed, 0.2)
  elseif keyboardJustPressed('FOUR') then
    state.speed = math.max(floor, state.speed - SPEED_STEP)
    rampSpeed(state.speed, 0.2)
  end
end

function onPause()
  -- A ramp must not keep running behind the pause screen.
  if state.built then
    resetSpeed(true)
  end
end

function onResume()
  if state.built and state.enabled then
    resetSpeed(false)
  end
end

function onEndSong()
  if state.built then
    resetSpeed(true)
  end
end

function onGameOver()
  if state.built then
    resetSpeed(true)
  end
end

function onDestroy()
  if not state.built then
    return
  end

  cancelTween('w32SpeedTween')
  cancelTween('w32ComboFade')
  cancelTween('w32ComboRise')
  cancelTween('w32MissDimFade')

  -- The chart speed has to be back before the state is destroyed, or the next
  -- song in a story week inherits the ramp.
  setProperty('songSpeed', state.baseSpeed)

  removeLuaSprite('w32MissDim', true)
  removeLuaText('w32ComboText', true)
  removeLuaText('w32SpeedText', true)
  state.built = false
  log('gameplay layers out')
end
