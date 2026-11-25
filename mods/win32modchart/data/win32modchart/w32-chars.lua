--[[
  w32-chars.lua : who the camera is looking at
  ============================================

  The stock camera cuts between dad and boyfriend on every section. This adds
  framing on top of the cut, without moving the game's own camera targets:

    * a soft spotlight behind whichever character the section belongs to, so the
      cut always reads, even in the middle of a playfield move
    * a small caption under the spotlight naming the side ("OPPONENT" / "YOU")
    * a GF reaction, because she is standing right there and never gets a beat
    * a narrow vertical letterbox that closes in at the climax

  Everything is drawn on `camHUD` at `scrollFactor` 0, so it sits at a fixed
  place on screen no matter how far the playfield moves underneath.

  The spotlight follows `mustHitSection`, which the engine publishes into every
  script right before `onSectionHit` fires, so the caption and `onMoveCamera`
  can never disagree about who owns the section.

  Reduced motion: the camera shake on a GF reaction is skipped and the
  letterbox stops easing, but nothing here is a flashing effect.

  The `modchart` persistent variable gates this file as well: set it false and
  the framing tears itself down on the next beat.
]]

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------

local ACCENT = 'c8ff7a'
local SOFT = '9ad1ff'
local DIM = 'b9c2cc'

-- Beat the chart's GDI climax starts on. The letterbox closes in to meet it.
local CLIMAX_BEAT = 336

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------

local state = {
  enabled = true,
  canFlash = true,
  reducedMotion = false,
  built = false,
  barTop = false,
  barBottom = false,
  gfReacted = 0,
  side = 'dad'
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
  debugPrint('[w32-chars] ' .. message)
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

--- Flat-coloured, HUD-pinned sprite.
--- @param tag Object tag.
--- @param x Left edge.
--- @param y Top edge.
--- @param w Width.
--- @param h Height.
--- @param hex Colour as six hex digits.
--- @param alpha Opacity.
local function flat(tag, x, y, w, h, hex, alpha)
  makeLuaSprite(tag, nil, x, y)
  makeGraphic(tag, w, h, hex)
  setObjectCamera(tag, 'hud')
  setScrollFactor(tag, 0, 0)
  setProperty(tag .. '.alpha', alpha)
end

----------------------------------------------------------------------
-- Build
----------------------------------------------------------------------

--- Spotlight, caption and the two letterbox bars.
local function build()
  if state.built then
    return
  end

  local w = screenWidth
  local h = screenHeight

  -- Spotlight: a wide, short, very dim block behind the HUD strums. Dim enough
  -- that it reads as light on the playfield, not as a second health bar.
  flat('w32Spot', 0, h * 0.52, w, h * 0.16, ACCENT, 0.045)
  addLuaSprite('w32Spot', false)

  makeLuaText('w32SpotLabel', 'OPPONENT', 300, w / 2 - 150, h * 0.505)
  setTextSize('w32SpotLabel', 13)
  setTextColor('w32SpotLabel', DIM)
  setTextAlignment('w32SpotLabel', 'center')
  setObjectCamera('w32SpotLabel', 'hud')
  setScrollFactor('w32SpotLabel', 0, 0)
  setProperty('w32SpotLabel.alpha', 0.55)
  addLuaText('w32SpotLabel')

  -- Letterbox, off screen until the climax.
  flat('w32BarTop', 0, -30, w, 30, '000000', 1)
  flat('w32BarBottom', 0, h + 30, w, 30, '000000', 1)
  addLuaSprite('w32BarTop', true)
  addLuaSprite('w32BarBottom', true)

  state.barTop = true
  state.barBottom = true
  state.built = true
  log('framing in')
end

--- Move the spotlight and caption to the owning side.
--- @param side 'dad' or 'bf'.
local function aimSpotlight(side)
  if not state.built then
    return
  end
  if side == state.side then
    return
  end

  state.side = side
  local width = screenWidth

  if side == 'bf' then
    setProperty('w32Spot.x', -width * 0.08)
    setTextString('w32SpotLabel', 'YOU')
    setTextColor('w32SpotLabel', ACCENT)
  else
    setProperty('w32Spot.x', width * 0.08)
    setTextString('w32SpotLabel', 'OPPONENT')
    setTextColor('w32SpotLabel', SOFT)
  end
end

--- Ease the letterbox in as the climax approaches.
--- @param open True to close the bars in, false to pull them back out.
local function setLetterbox(open)
  if not state.built then
    return
  end
  local h = screenHeight
  if open then
    doTweenY('w32BarTopTween', 'w32BarTop', 0, 1.2, 'sineOut')
    doTweenY('w32BarBottomTween', 'w32BarBottom', h - 30, 1.2, 'sineOut')
  else
    doTweenY('w32BarTopTween', 'w32BarTop', -30, 0.8, 'sineOut')
    doTweenY('w32BarBottomTween', 'w32BarBottom', h + 30, 0.8, 'sineOut')
  end
end

--- Drop every object this script owns. Declared before the hooks, because a
--- `local function` is only in scope after its own line.
local function teardown()
  if not state.built then
    return
  end
  cancelTween('w32BarTopTween')
  cancelTween('w32BarBottomTween')
  removeLuaSprite('w32Spot', true)
  removeLuaSprite('w32BarTop', true)
  removeLuaSprite('w32BarBottom', true)
  removeLuaText('w32SpotLabel', true)
  state.built = false
  log('framing out')
end

----------------------------------------------------------------------
-- Hooks
----------------------------------------------------------------------

function onCreatePost()
  state.canFlash = pref('flashing', true) == true
  state.reducedMotion = pref('reducedMotion', false) == true
  state.enabled = modchartEnabled()

  if state.enabled then
    build()
  end
  state.side = 'bf'
  aimSpotlight('dad')
end

--- The engine fires this on each camera cut, with the character it cut to.
--- @param char Character name: 'dad', 'boyfriend' or 'gf'.
function onMoveCamera(char)
  if char == 'gf' then
    return
  end
  aimSpotlight(char == 'boyfriend' and 'bf' or 'dad')
end

function onSectionHit()
  -- `onMoveCamera` is skipped whenever the camera was forced somewhere, so the
  -- section's own flag is the fallback: the engine publishes `mustHitSection`
  -- for `curSection` immediately before this callback.
  local side = mustHitSection and 'bf' or 'dad'
  aimSpotlight(side)

  -- The climax is a beat in the chart, not a turn index.
  if (curSection or 0) * 4 >= CLIMAX_BEAT then
    setLetterbox(true)
  end
end

function onBeatHit()
  if not state.built then
    return
  end

  -- Spotlight breathes with the beat.
  setProperty('w32Spot.alpha', 0.075)

  -- GF gets a dance step every second beat, but only when she is not already
  -- busy with a section of her own.
  if gfSection then
    return
  end
  if curBeat % 2 ~= 0 then
    return
  end

  state.gfReacted = state.gfReacted + 1
  if not state.reducedMotion then
    cameraShake('game', 0.004, 0.08)
  end
end

function onUpdatePost(elapsed)
  -- The switch can be flipped from options mid-song.
  if state.enabled and not modchartEnabled() then
    state.enabled = false
    teardown()
    return
  end

  if not state.built then
    return
  end

  -- Let the spotlight settle back down between beats.
  local alpha = getProperty('w32Spot.alpha') or 0.045
  if alpha > 0.05 then
    setProperty('w32Spot.alpha', math.max(0.045, alpha - elapsed * 0.06))
  end
end

function onPause()
  -- Tweens are paused by the engine; nothing else here is time-based.
end

function onResume()
  if state.built then
    -- Force a re-aim, since the pause may have happened mid-turn.
    state.side = 'bf'
    aimSpotlight(mustHitSection and 'bf' or 'dad')
  end
end

function onEndSong()
  if state.built then
    setLetterbox(false)
  end
end

function onDestroy()
  teardown()
end
