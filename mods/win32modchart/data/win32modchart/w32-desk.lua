--[[
  w32-desk.lua : Windows desktop framing
  ======================================

  Wraps the playfield in the chrome of a 1998 desktop:

    * a scanline pass over the whole screen (on `camOther`, which draws above
      everything the game puts on screen, so the playfield's own shader stack on
      `camGame` is never touched)
    * a small window title chip with the executable path and its three buttons
    * a CRT vignette down the left and right edges
    * an "active window" line under the chip that brightens on the beat

  Keys
  ----
    1   cycle the dressing: everything -> scanlines only -> everything
    2   toggle the scanline pass by itself

  Those are read through `keyboardJustPressed`, not `onKeyPress`: that callback
  only fires for the four note keys, so it never sees 1 or 2.

  Where everything sits
  ---------------------
  The HUD is crowded and the modchart's own read-out flips between the top and
  the bottom with the player's scroll direction, so the chip goes in the left
  column under it: 14 px tall at y 216, under the turn counter (y 150) and the
  speed read-out (y 182). Everything else is either a full-screen overlay (the
  scanlines) or a 14 px side strip. `tools/simulate_win32_scripts.py` checks
  every rectangle against the engine's time bar, health bar, score text and the
  modchart's own five lines, for both scroll directions.

  Reduced motion: the scanline pass and the vignette stay, because neither
  moves, but the beat brightening on the window line is skipped entirely.

  The `modchart` persistent variable gates this file too: set it false and the
  dressing tears itself down on the next frame without anything being unloaded.
]]

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------

local TITLE = 'C:\\WINDOWS\\SYSTEM32\\FNF_PHOENIX.EXE'

-- The modchart HUD starts at y 74 upscroll but at y 18 downscroll, so the top
-- band is not reliably free. The left column below the modchart's three lines
-- is: the turn counter sits at y 150, the speed read-out at y 178, and nothing
-- else in this folder or the engine uses x 20..260 below that.
local TITLE_H = 14
local TITLE_W = 240
local TITLE_X = 20
local TITLE_Y = 216

local BORDER = 2
local BAR_Y = TITLE_Y + TITLE_H -- 230: the "active window" line
local EDGE = 14                 -- side vignette width

local ACCENT = 'c8ff7a'
local CHROME = '5f6b78'

--- Border opacity at rest, and on the beat. The 0.10 step is the same
--- magnitude as the window dim in `w32-window.lua`, so neither is a flash.
local REST_ALPHA = 0.35
local BEAT_ALPHA = 0.45

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------

local state = {
  -- 1 = chrome and scanlines, 2 = scanlines only, 0 = bare
  mode = 1,
  enabled = true,
  scanlines = true,
  canFlash = true,
  reducedMotion = false,
  dressed = false,
  titleAdded = false,
  vignetteAdded = false,
  borderAdded = false
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
  debugPrint('[w32-desk] ' .. message)
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

--- Flat-coloured, HUD-pinned, unscrolled sprite.
--- @param tag Object tag.
--- @param x Left edge.
--- @param y Top edge.
--- @param w Width in pixels.
--- @param h Height in pixels.
--- @param hex Colour as six hex digits.
--- @param alpha Opacity.
local function flat(tag, x, y, w, h, hex, alpha)
  makeLuaSprite(tag, nil, x, y)
  makeGraphic(tag, w, h, hex)
  setObjectCamera(tag, 'hud')
  setScrollFactor(tag, 0, 0)
  setProperty(tag .. '.alpha', alpha)
end

--- HUD-pinned, unscrolled text.
local function label(tag, text, width, x, y, size, color, align)
  makeLuaText(tag, text, width, x, y)
  setTextSize(tag, size)
  setTextColor(tag, color)
  setTextAlignment(tag, align)
  setObjectCamera(tag, 'hud')
  setScrollFactor(tag, 0, 0)
end

----------------------------------------------------------------------
-- Layers
----------------------------------------------------------------------

--- Add the scanline pass to `camOther`.
local function addScanlines()
  if not state.scanlines then
    return
  end
  addScanlineEffect('other', false)
  log('scanlines on')
end

--- Remove the scanline pass from `camOther`.
local function removeScanlines()
  if not state.scanlines then
    return
  end
  clearEffects('other')
  log('scanlines off')
end

--- The title chip: one bar, the path, and the three window buttons.
local function addTitleBar()
  if state.titleAdded then
    return
  end

  flat('w32TitleBar', TITLE_X, TITLE_Y, TITLE_W, TITLE_H, CHROME, 0.95)
  addLuaSprite('w32TitleBar', false)

  -- A 14 px band fits one 10 pt string, so the filename and the buttons share
  -- the chip instead of stacking.
  label('w32TitleText', TITLE, TITLE_W - 62, TITLE_X + 4, TITLE_Y, 10, 'FFFFFF', 'left')
  addLuaText('w32TitleText')

  label('w32TitleButtonsText', '_ [] X', 54, TITLE_X + TITLE_W - 58, TITLE_Y,
        10, ACCENT, 'right')
  addLuaText('w32TitleButtonsText')

  state.titleAdded = true
  log('title chip in')
end

--- Drop the title chip and free its objects.
local function removeTitleBar()
  if not state.titleAdded then
    return
  end
  removeLuaSprite('w32TitleBar', true)
  removeLuaText('w32TitleText', true)
  removeLuaText('w32TitleButtonsText', true)
  state.titleAdded = false
  log('title chip out')
end

--- CRT vignette: two dark strips down the left and right edges, full height.
local function addVignette()
  if state.vignetteAdded then
    return
  end

  local w = screenWidth
  local h = screenHeight

  -- Side strips only. A bar across the bottom would sit on `scoreTxt`, which
  -- the engine puts at 0.89 * height + 50.
  flat('w32VinLeft', 0, 0, EDGE, h, '000000', 0.4)
  flat('w32VinRight', w - EDGE, 0, EDGE, h, '000000', 0.4)

  addLuaSprite('w32VinLeft', true)
  addLuaSprite('w32VinRight', true)

  state.vignetteAdded = true
  log('vignette in')
end

--- Drop the vignette strips.
local function removeVignette()
  if not state.vignetteAdded then
    return
  end
  removeLuaSprite('w32VinLeft', true)
  removeLuaSprite('w32VinRight', true)
  state.vignetteAdded = false
  log('vignette out')
end

--- The "active window" line, hugging the title chip from below.
local function addBorder()
  if state.borderAdded then
    return
  end
  flat('w32Border', TITLE_X, BAR_Y, TITLE_W, BORDER, ACCENT, REST_ALPHA)
  addLuaSprite('w32Border', false)
  state.borderAdded = true
end

--- Drop the line.
local function removeBorder()
  if not state.borderAdded then
    return
  end
  removeLuaSprite('w32Border', true)
  state.borderAdded = false
end

----------------------------------------------------------------------
-- Mode switching
----------------------------------------------------------------------

--- Show or hide everything except the scanline pass.
--- @param visible Whether the window chrome should be on screen.
local function setChrome(visible)
  if visible then
    addTitleBar()
    addVignette()
    addBorder()
  else
    removeTitleBar()
    removeVignette()
    removeBorder()
  end
end

--- Apply the current mode. Called on create, on every key press, on resume.
local function applyMode()
  if not state.dressed then
    return
  end
  if state.scanlines then
    addScanlines()
  else
    removeScanlines()
  end
  setChrome(state.mode == 1)
  log('mode ' .. state.mode .. (state.scanlines and ' +scanlines' or ''))
end

--- Tear every layer and every object down.
local function teardown()
  removeTitleBar()
  removeVignette()
  removeBorder()
  removeScanlines()
  state.dressed = false
end

--- Does the line get to brighten on the beat?
--- @return True when the layer exists and both prefs allow it.
local function canFlicker()
  return state.dressed and state.borderAdded and state.canFlash and not state.reducedMotion
end

----------------------------------------------------------------------
-- Hooks
----------------------------------------------------------------------

function onCreatePost()
  state.canFlash = pref('flashing', true) == true
  state.reducedMotion = pref('reducedMotion', false) == true
  state.enabled = modchartEnabled()

  state.dressed = state.enabled
  if state.dressed then
    applyMode()
  end
  log('desktop dressing ' .. (state.dressed and 'up' or 'off')
      .. (state.reducedMotion and ' (reduced motion)' or ''))
end

function onUpdatePost()
  if canFlicker() then
    -- Fade the line across each beat; `onBeatHit` snaps it back up.
    local alpha = getProperty('w32Border.alpha') or REST_ALPHA
    if alpha > REST_ALPHA then
      setProperty('w32Border.alpha', math.max(REST_ALPHA, alpha - 0.01))
    end
  end

  if not state.dressed then
    return
  end

  -- The switch can be flipped from options mid-song.
  if state.enabled and not modchartEnabled() then
    state.enabled = false
    teardown()
    return
  end

  if keyboardJustPressed('ONE') then
    state.mode = state.mode - 1
    if state.mode < 0 then
      state.mode = 2
    end
    applyMode()
  elseif keyboardJustPressed('TWO') then
    state.scanlines = not state.scanlines
    applyMode()
  end
end

function onBeatHit()
  if canFlicker() then
    setProperty('w32Border.alpha', BEAT_ALPHA)
  end
end

function onPause()
  -- Nothing to suspend: the line is a plain alpha value, not a tween. Park it
  -- at rest so the pause screen is not caught mid-fade.
  if state.borderAdded then
    setProperty('w32Border.alpha', REST_ALPHA)
  end
end

function onResume()
  applyMode()
end

function onDestroy()
  teardown()
  log('desktop dressing down')
end
