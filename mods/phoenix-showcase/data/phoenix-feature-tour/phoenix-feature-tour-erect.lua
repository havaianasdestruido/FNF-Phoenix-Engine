--[[
  PHOENIX FEATURE TOUR - song script
  ==================================
  Base song : Dad Battle (Erect), chart by Kawai Sprite
  Modchart  : Lua, this file (no Python / HScript)

  What this song exercises, in order:
    * every one of the 34 ModifierRegistry entries
    * modSet / modEase / modAdd / modSetAdd / modCallback / modRepeater
    * two modchart playfields + setModchartPerspective (3D)
    * addModifier / setPercent / getPercent / resetModchart / isModchartActive
    * a mod shader (shaders/showcase.frag) + #pragma include + uniform tweens
    * built-in camera effects (chromatic, glitch, scanline, VCR, bloom,
      distant notes)
    * a custom FlxCamera created by createCamera()/addCamera() and used by
      setObjectCamera(), with a fake-desktop fourth-wall overlay
    * META_HORROR window effects (title, always-on-top, taskbar, flash) and
      the safe no-op path when the build has no META_HORROR
    * TransparentWindow whole-window alpha
    * health bar / time bar colours, custom rating hook, camera flash/shake,
      HUD zoom, early/late hit readout
    * Lua sprites, blend modes, tweens, a custom 4th-wall camera layer
    * tagged sounds and playback-rate changes
    * per-mod save data (plays / completions / early+late counters)
    * hardware info globals
    * script sandbox: no allowlisted file, clipboard, window-list or capture
      calls are used anywhere in this mod

  The script is defensive on purpose: shader calls are skipped when the user
  disabled shaders, META_HORROR is probed at runtime, and window transparency
  is gated by isWindowTransparencySupported(). It should never crash a build
  that is missing one of the optional systems.
]]

----------------------------------------------------------------------
-- Registry data
----------------------------------------------------------------------

local MOD_COUNT = 34
local PHASE_COUNT = 26

-- Every name ModifierRegistry accepts, in the order the phases use them.
local ALL_MODS = {
  'transform', 'rotate', 'scale',
  'reverse', 'boost', 'receptorscroll', 'zigZag',
  'drunk', 'tipsy', 'schmovinDrunk', 'schmovinTipsy', 'drugged',
  'bounce', 'beat', 'bumpy', 'sawtooth', 'square', 'tornado', 'schmovinTornado',
  'centerRotate', 'fieldRotate', 'localRotate', 'confusion', 'counterClockWise',
  'invert', 'opponentSwap', 'spiral', 'infinite', 'radionic',
  'zoom', 'stealth',
  'wiggle', 'vibrate', 'skew'
}

-- Neutral values for the percents this song actually drives. Everything not
-- listed here returns to 0.
local NEUTRAL = {
  alpha = 1,
  scale = 1,
  scaleX = 1,
  scaleY = 1,
  xmod = 1,
  waveMult = 1
}

-- Percent names reset at every phase boundary. Keep this list broad: unknown
-- percents are harmless, while a missed one would leak into later phases.
local RESET_PERCENTS = {
  'x', 'y', 'z',
  'xoffset', 'yoffset', 'zoffset',
  'x0', 'x1', 'x2', 'x3',
  'y0', 'y1', 'y2', 'y3',
  'rotateX', 'rotateY', 'rotateZ',
  'centerRotateX', 'centerRotateY', 'centerRotateZ',
  'fieldRotateX', 'fieldRotateY', 'fieldRotateZ',
  'localRotateX', 'localRotateY', 'localRotateZ',
  'confusion', 'counterClockWise',
  'scale', 'scaleX', 'scaleY',
  'tinyX', 'tinyY',
  'zoom', 'mini', 'localZoom', 'localMini',
  'alpha', 'stealth', 'dark', 'sudden', 'hidden',
  'invert', 'flip', 'opponentSwap',
  'spiral', 'infinite', 'radionic',
  'reverse', 'xmod', 'boost', 'brake',
  'receptorScroll', 'zigZag',
  'bounce', 'beat', 'bumpy',
  'sawtooth', 'square', 'tornado', 'schmovinTornado',
  'drunk', 'tipsy', 'schmovinDrunk', 'schmovinTipsy', 'drugged',
  'wiggle', 'vibrate', 'skewX', 'skewY'
}

local state = {
  started = false,
  phaseIndex = 0,
  tested = {},
  testedCount = 0,
  elapsed = 0,
  hudTimer = 0,
  shaderTimer = 0,
  plays = 0,
  metaRuns = 0,
  earlyCount = 0,
  lateCount = 0,
  metaEnabled = false,
  metaProbed = false,
  recording = false,
  windowSupported = false,
  shaders = false,
  shaderOn = false,
  reducedMotion = false,
  ratingOverride = false,
  modchartReset = false,
  cleanupDone = false,
  fwBuilt = false,
  fwVisible = false,
  fwCamAdded = false,
  fwCamRemoved = false,
  fwCam = 'camShowcaseFW',
  fwX = 0,
  fwY = 0,
  saveName = 'phoenix-showcase'
}

local FW_TAGS = {
  { 'fwDim', 0.45 },
  { 'fwTopBar', 1 },
  { 'fwTopText', 1 },
  { 'fwPanelEdge', 1 },
  { 'fwPanel', 0.97 },
  { 'fwTitle', 1 },
  { 'fwSub', 1 },
  { 'fwBody', 1 },
  { 'fwPrompt', 1 },
  { 'fwCursor', 0.9 }
}

----------------------------------------------------------------------
-- Small helpers
----------------------------------------------------------------------

local function safeString(value, fallback)
  if value == nil then
    return fallback
  end
  local text = tostring(value)
  if text == '' or text == 'nil' then
    return fallback
  end
  return text
end

local function safeNumber(value, fallback)
  local number = tonumber(value)
  if number == nil then
    return fallback
  end
  return number
end

local function setVisible(tag, value)
  setProperty(tag .. '.visible', value)
end

local function neutralFor(name)
  local value = NEUTRAL[name]
  if value == nil then
    return 0
  end
  return value
end

local function resetAllPercents()
  for index = 1, #RESET_PERCENTS do
    local name = RESET_PERCENTS[index]
    setPercent(name, neutralFor(name), -1, -1)
  end
end

local function scheduleReset(names, endBeat)
  for index = 1, #names do
    local name = names[index]
    modEase(name, endBeat - 2, 2, neutralFor(name), 'quadInOut')
  end
end

local function makeText(tag, text, size, x, y, width, color, align)
  makeLuaText(tag, text, width, x, y)
  setTextSize(tag, size)
  setTextFont(tag, 'vcr.ttf')
  setTextColor(tag, color)
  setTextBorder(tag, 2, '000000')
  setTextAlignment(tag, align or 'left')
  addLuaText(tag)
end

local function makeOverlayText(tag, text, size, x, y, width, color, align)
  makeLuaText(tag, text, width, x, y)
  setTextSize(tag, size)
  setTextFont(tag, 'vcr.ttf')
  setTextColor(tag, color)
  setTextBorder(tag, 2, '000000')
  setTextAlignment(tag, align or 'left')
  setScrollFactor(tag, 0, 0)
  setObjectCamera(tag, state.fwCam)
  setVisible(tag, false)
  setProperty(tag .. '.alpha', 0)
  addLuaText(tag)
end

local function shake(camera, intensity, duration)
  if not state.reducedMotion then
    cameraShake(camera, intensity, duration)
  end
end

local function setPhaseText(name, detail)
  setTextString('tourPhase', name)
  setTextString('tourDetail', detail)
end

local function banner(text, color)
  cancelTween('tourBannerIn')
  cancelTween('tourBannerOut')
  cancelTimer('tourBannerTimer')
  setTextString('tourBanner', text)
  setTextColor('tourBanner', color or 'ffffff')
  setProperty('tourBanner.alpha', 0)
  doTweenAlpha('tourBannerIn', 'tourBanner', 1, 0.3, 'quadOut')
  runTimer('tourBannerTimer', 1.5, 1)
end

local function markTested(names)
  if names == nil then
    return
  end
  for index = 1, #names do
    local name = names[index]
    if not state.tested[name] then
      state.tested[name] = true
      state.testedCount = state.testedCount + 1
    end
  end
  setTextString('tourCounter', string.format('%d/%d modifiers', state.testedCount, MOD_COUNT))
end

local function hardwareLine()
  local osName = safeString(getOSName(), 'Unknown OS')
  local gpu = safeString(getGPUName(), 'Unknown GPU')
  if #gpu > 48 then
    gpu = string.sub(gpu, 1, 45) .. '...'
  end
  return osName .. ' | ' .. gpu
end

----------------------------------------------------------------------
-- Modchart setup
----------------------------------------------------------------------

local function installModchart()
  for index = 1, #ALL_MODS do
    addModifier(ALL_MODS[index])
  end

  -- A second layer. Field 1 starts empty; it gets its own transform chain so
  -- the layered-playfield phase can move notes twice.
  addPlayfield()
  -- Keep field 1 additive/multiplicative only. Mirror modifiers such as
  -- `reverse` would cancel themselves if they ran on both fields.
  addModifier('transform', 1)
  addModifier('rotate', 1)
  addModifier('scale', 1)

  resetAllPercents()
  debugPrint('[showcase] modchart installed: ' .. tostring(#getModchartModifiers()) .. ' modifiers across 2 playfields')
end

----------------------------------------------------------------------
-- HUD / overlays
----------------------------------------------------------------------

local function buildHud()
  local w = screenWidth
  local h = screenHeight

  local textWidth = math.max(320, w - 380)
  -- Keep the top-left block clear of the song time bar, which sits at the top
  -- in upscroll and at the bottom in downscroll.
  local downscroll = getPropertyFromClass('backend.ClientPrefs', 'downScroll') == true
  local topY = 70
  if downscroll then topY = 16 end
  makeText('tourTitle', 'PHOENIX ENGINE // FEATURE TOUR', 26, 24, topY, textWidth, 'ff16d2', 'left')
  makeText('tourPhase', 'BOOTING TEST HARNESS', 20, 24, topY + 34, textWidth, 'ffffff', 'left')
  makeText('tourDetail', '', 16, 24, topY + 62, textWidth, 'caff4d', 'left')
  makeText('tourCounter', '0/' .. MOD_COUNT .. ' modifiers', 16, w - 320, h - 150, 296, 'caff4d', 'right')
  makeText('tourMeta', 'META_HORROR: ?', 16, w - 320, h - 124, 296, 'ff16d2', 'right')
  makeText('tourTiming', '--', 16, w - 320, h - 98, 296, 'ffffff', 'right')
  local beatY = h - 60
  local footerY = h - 20
  if downscroll then
    beatY = h - 88
    footerY = h - 70
  end
  makeText('tourBeat', 'beat 0 | active modifiers 34 | phase 0/' .. PHASE_COUNT, 14, 24, beatY, textWidth, 'ffffff', 'left')
  makeText('tourFooter', 'Lua modchart | 34 modifiers | runtime shaders | 4th wall | custom camera', 14, 24, footerY, w - 48, 'ffffff', 'center')
  makeText('tourBanner', '', 34, 0, math.floor(h * 0.22), w, 'ffffff', 'center')
  setProperty('tourBanner.alpha', 0)

  makeLuaSprite('tourLogo', 'phoenix_logo', 0, 0)
  setGraphicSize('tourLogo', 300, 300)
  setProperty('tourLogo.alpha', 0)
  setProperty('tourLogo.antialiasing', true)
  screenCenter('tourLogo', 'xy')
  setObjectCamera('tourLogo', 'camHUD')
  addLuaSprite('tourLogo', true)

  setTextString('tourMeta', 'META_HORROR: ?')
end

local function buildFourthWall()
  local w = screenWidth
  local h = screenHeight
  local panelW = math.min(780, w - 100)
  local panelH = math.min(360, h - 140)
  local panelX = math.floor((w - panelW) * 0.5)
  local panelY = 70
  state.fwX = panelX
  state.fwY = panelY

  createCamera(state.fwCam, {
    x = 0,
    y = 0,
    width = w,
    height = h,
    zoom = 1,
    defaultDrawTarget = false
  })
  -- Explicit camera targets only: do not make this a default camera, or notes
  -- and popups created later would be drawn into the overlay layer too.
  addCamera(state.fwCam, nil, false)
  state.fwCamAdded = true
  -- Extra cameras paint their bgColor over every camera below them. Make it
  -- transparent so this layer composites instead of covering the game.
  setProperty(state.fwCam .. '.bgColor', 0x00000000)

  makeLuaSprite('fwDim', '', 0, 0)
  makeGraphic('fwDim', 8, 8, '000000')
  setGraphicSize('fwDim', math.floor(w * 1.12), math.floor(h * 1.12))
  setProperty('fwDim.x', -math.floor(w * 0.06))
  setProperty('fwDim.y', -math.floor(h * 0.06))
  setProperty('fwDim.alpha', 0)
  setScrollFactor('fwDim', 0, 0)
  setObjectCamera('fwDim', state.fwCam)
  setVisible('fwDim', false)
  addLuaSprite('fwDim', true)

  makeLuaSprite('fwTopBar', '', 0, 0)
  makeGraphic('fwTopBar', 8, 8, '12000f')
  setGraphicSize('fwTopBar', w, 42)
  setProperty('fwTopBar.alpha', 0)
  setScrollFactor('fwTopBar', 0, 0)
  setObjectCamera('fwTopBar', state.fwCam)
  setVisible('fwTopBar', false)
  addLuaSprite('fwTopBar', true)

  makeLuaSprite('fwPanelEdge', '', 0, 0)
  makeGraphic('fwPanelEdge', 8, 8, 'ff16d2')
  setGraphicSize('fwPanelEdge', panelW, 3)
  setProperty('fwPanelEdge.x', panelX)
  setProperty('fwPanelEdge.y', panelY - 3)
  setProperty('fwPanelEdge.alpha', 0)
  setScrollFactor('fwPanelEdge', 0, 0)
  setObjectCamera('fwPanelEdge', state.fwCam)
  setVisible('fwPanelEdge', false)
  addLuaSprite('fwPanelEdge', true)

  makeLuaSprite('fwPanel', '', 0, 0)
  makeGraphic('fwPanel', 8, 8, '0d0d14')
  setGraphicSize('fwPanel', panelW, panelH)
  setProperty('fwPanel.x', panelX)
  setProperty('fwPanel.y', panelY)
  setProperty('fwPanel.alpha', 0)
  setScrollFactor('fwPanel', 0, 0)
  setObjectCamera('fwPanel', state.fwCam)
  setVisible('fwPanel', false)
  addLuaSprite('fwPanel', true)

  makeOverlayText('fwTopText', 'PHOENIX OS // META_HORROR: OFF // (not a real OS)', 18, 20, 11, w - 40, 'ff16d2', 'left')
  makeOverlayText('fwTitle', 'PHOENIX ENGINE', 28, panelX + 28, panelY + 22, panelW - 56, 'ff16d2', 'left')
  makeOverlayText('fwSub', 'session report // fourth wall', 16, panelX + 28, panelY + 58, panelW - 56, 'caff4d', 'left')
  makeOverlayText('fwBody', '', 16, panelX + 28, panelY + 90, panelW - 56, 'ffffff', 'left')
  makeOverlayText('fwPrompt', '> the fourth wall is a suggestion_', 15, panelX + 28, panelY + panelH - 46, panelW - 56, 'caff4d', 'left')

  makeLuaSprite('fwCursor', '', 0, 0)
  makeGraphic('fwCursor', 10, 18, 'ffffff')
  setProperty('fwCursor.x', panelX + panelW - 90)
  setProperty('fwCursor.y', panelY + panelH - 58)
  setProperty('fwCursor.alpha', 0)
  setScrollFactor('fwCursor', 0, 0)
  setObjectCamera('fwCursor', state.fwCam)
  setVisible('fwCursor', false)
  addLuaSprite('fwCursor', true)

  state.fwBuilt = true
end

local function buildFourthWallBody()
  local lines = { 'PLAYER PROFILE' }

  if state.metaEnabled then
    lines[#lines + 1] = '  user       : ' .. safeString(getDesktopUsername(), 'player')
    lines[#lines + 1] = '  local time : ' .. safeString(getLocalTimeString(), '--:--')
    lines[#lines + 1] = '  launch     : #' .. tostring(getLaunchCount())
    local uptime = math.floor(safeNumber(getSystemUptime(), 0) / 60)
    lines[#lines + 1] = string.format('  uptime     : %dh %dm', math.floor(uptime / 60), uptime % 60)
    lines[#lines + 1] = '  memory     : ' .. tostring(getSystemRAM()) .. ' MB'
    lines[#lines + 1] = '  tour runs  : ' .. tostring(state.metaRuns)
    if isLateNight() then
      lines[#lines + 1] = '  note       : it is late. the engine noticed.'
    end
  else
    lines[#lines + 1] = '  user       : unavailable'
    lines[#lines + 1] = '  local time : --:--'
    lines[#lines + 1] = '  note       : this build did not enable META_HORROR'
    lines[#lines + 1] = '               every 4th-wall call was a safe no-op.'
  end

  lines[#lines + 1] = ''
  lines[#lines + 1] = 'this overlay is a normal FlxCamera, not a real window.'
  lines[#lines + 1] = 'the title / taskbar / alpha tricks are real.'

  return table.concat(lines, '\n')
end

local function showFourthWall()
  if not state.fwBuilt or state.fwVisible then
    return
  end

  state.fwVisible = true
  setTextString('fwBody', buildFourthWallBody())
  setTextString('fwTopText', 'PHOENIX OS // META_HORROR: ' .. (state.metaEnabled and 'ON' or 'OFF') .. ' // (not a real OS)')
  setTextString('fwPrompt', '> the fourth wall is a suggestion_')

  for index = 1, #FW_TAGS do
    local tag = FW_TAGS[index][1]
    local target = FW_TAGS[index][2]
    cancelTween('fwIn_' .. tag)
    cancelTween('fwOut_' .. tag)
    setVisible(tag, true)
    setProperty(tag .. '.alpha', 0)
    doTweenAlpha('fwIn_' .. tag, tag, target, 0.35, 'quadOut')
  end
end

local function hideFourthWall()
  if not state.fwVisible then
    return
  end

  state.fwVisible = false
  for index = 1, #FW_TAGS do
    local tag = FW_TAGS[index][1]
    cancelTween('fwIn_' .. tag)
    doTweenAlpha('fwOut_' .. tag, tag, 0, 0.3, 'quadIn')
  end
end

local function cleanupMeta()
  if state.metaEnabled then
    -- Restores the title, taskbar, always-on-top and window styles in one go.
    restoreAllMetaEffects()
  end
  if state.windowSupported then
    setWindowAlpha(1.0)
  end
end

local function cleanupAll()
  if state.cleanupDone then
    return
  end
  state.cleanupDone = true

  if state.shaders then
    removeSpriteShader('boyfriend')
    removeSpriteShader('dad')
    clearShadersFromCamera('hud')
    clearShadersFromCamera('game')
  end
  state.shaderOn = false

  cleanupMeta()
  hideFourthWall()
  setPlaybackSpeed(1.0)
  stopSound('tourConfirm')
  stopSound('tourScroll')
  stopSound('tourGlitch')
end

----------------------------------------------------------------------
-- 4th-wall callbacks (scheduled with modCallback)
----------------------------------------------------------------------

function introLogoOut(beat)
  doTweenAlpha('tourLogoOut', 'tourLogo', 0, 1.2, 'quadIn')
end

function timelineCallback(beat)
  banner('modCallback @ beat ' .. string.format('%.0f', beat), 'caff4d')
  debugPrint(string.format('[showcase] modCallback fired at %.1f | x=%.1f', beat, getPercent('x', 1, 0)))
  triggerEvent('Add Camera Zoom', '0.012', '0.02')
end

function timelinePulse(beat)
  if beat >= 32 then
    return
  end
  modEase('bounce', beat, 1.5, 0.2, 'quadOut')
  modEase('bounce', beat + 1.5, 1.5, 0, 'quadIn')
  triggerEvent('Add Camera Zoom', '0.006', '0.01')
end

function perspectiveOff(beat)
  setModchartPerspective(false)
end

function hideTaskbarGag(beat)
  if state.metaEnabled and not state.recording then
    hideTaskbar()
  end
end

function restoreTaskbarGag(beat)
  if state.metaEnabled then
    restoreTaskbar()
  end
end

function endWindowGag(beat)
  if state.metaEnabled then
    restoreTaskbar()
    restoreWindowTitle()
    setAlwaysOnTop(false)
    resetMetaWindowEffects()
  end
  if state.windowSupported then
    setWindowAlpha(1.0)
  end
  state.recording = false
end

function endPlayerGag(beat)
  hideFourthWall()
  cleanupMeta()
end

function endRatingOverride(beat)
  state.ratingOverride = false
  doTweenZoom('hudZoomOut', 'camHUD', 1, 0.6, 'quadIn')
end

function endSpriteGag(beat)
  doTweenAlpha('tourHaloOut', 'tourHalo', 0, 0.6, 'quadIn')
  doTweenAlpha('tourLogoOut2', 'tourLogo', 0, 0.8, 'quadIn')
  runTimer('tourHaloRemove', 0.7, 1)
end

function audioSpeedNormal(beat)
  setPlaybackSpeed(1.0)
end

function audioSecondBlip(beat)
  playSound('scrollMenu', 0.6, 'tourScroll')
end

function clearPhaseShaders(beat)
  if not state.shaders then
    return
  end
  removeSpriteShader('boyfriend')
  removeSpriteShader('dad')
  clearShadersFromCamera('hud')
  clearShadersFromCamera('game')
  state.shaderOn = false
end

function dropCleanup(beat)
  clearPhaseShaders(beat)
  setModchartPerspective(false)
  resetAllPercents()
end

----------------------------------------------------------------------
-- Phase bodies
----------------------------------------------------------------------

local function phaseIntro(b, e)
  banner('PHOENIX FEATURE TOUR', 'ff16d2')
  setTextString('tourPhase', 'INTRO // TEST HARNESS')
  setTextString('tourDetail',
    'Phoenix ' .. safeString(phoenixVersion, '?') .. ' | ' .. hardwareLine() .. '\n' ..
    '34 modifiers | 2 playfields | runtime shaders | 4th wall | custom camera | save data\n' ..
    'shaders: ' .. (state.shaders and 'on' or 'off') ..
    ' | window alpha: ' .. (state.windowSupported and 'yes' or 'no') ..
    ' | META_HORROR: ' .. (state.metaProbed and (state.metaEnabled and 'ON' or 'OFF') or 'probed at 0:50') .. '\n' ..
    '4th-wall window effects start around 0:50 and are restored afterwards.')
  doTweenAlpha('tourLogoIn', 'tourLogo', 0.9, 1.0, 'quadOut')
  modCallback(b + 12, 'introLogoOut', 0)
end

local function phaseTimeline(b, e)
  -- Plain percentage moves plus the three timeline verbs.
  modEase('x', b, 4, -70, 'quadOut')
  modEase('x', b + 4, 4, 45, 'sineInOut')
  modEase('x', e - 4, 4, 0, 'quadInOut')
  modEase('y', b + 2, 4, 36, 'sineOut')
  modEase('y', e - 4, 4, 0, 'quadInOut')
  modEase('rotateZ', b, 4, 8, 'quadOut')
  modEase('rotateZ', b + 4, 4, -6, 'sineInOut')
  modEase('rotateZ', e - 4, 4, 0, 'quadInOut')
  modEase('scale', b, 2, 1.08, 'quadOut')
  modEase('scale', e - 4, 4, 1, 'quadInOut')

  modSet('bounce', b + 8, 0.25)
  modEase('bounce', b + 10, 2, 0, 'quadIn')
  modAdd('xoffset', b + 8, 2, 40, 'quadOut')
  modEase('xoffset', e - 4, 4, 0, 'quadInOut')
  modSetAdd('yoffset', b + 12, 20)
  modEase('yoffset', e - 3, 3, 0, 'quadOut')

  -- One lane only, through the transform modifier's `x0` percent.
  modEase('x0', b + 6, 2, -45, 'quadOut')
  modEase('x0', e - 4, 4, 0, 'quadInOut')

  modCallback(b + 4, 'timelineCallback', 0)
  modRepeater(b + 8, 4, 'timelinePulse', 0)
end

local function phaseScroll(b, e)
  modEase('reverse', b, 1, 1, 'quadOut')
  modEase('reverse', e - 2, 2, 0, 'quadIn')
  modEase('xmod', b + 4, 2, 0.55, 'sineInOut')
  modEase('xmod', e - 4, 4, 1, 'sineInOut')
  modEase('boost', b + 4, 2, 1.5, 'quadOut')
  modEase('boost', b + 6, 2, 0, 'quadIn')
  modEase('brake', b + 8, 2, 1.5, 'quadOut')
  modEase('brake', b + 10, 2, 0, 'quadIn')
  modEase('receptorScroll', b + 8, 2, 0.6, 'sineInOut')
  modEase('receptorScroll', e - 4, 4, 0, 'sineInOut')
  modEase('zigZag', b + 12, 2, 1, 'quadOut')
  modEase('zigZag', e - 2, 2, 0, 'quadIn')
end

local function phaseDrunk(b, e)
  modEase('drunk', b, 2, 0.35, 'quadOut')
  modEase('tipsy', b + 2, 2, 0.30, 'quadOut')
  modEase('schmovinDrunk', b + 4, 2, 1, 'quadOut')
  modEase('schmovinTipsy', b + 6, 2, 1, 'quadOut')
  modEase('drugged', b + 8, 2, 0.25, 'quadOut')
  scheduleReset({ 'drunk', 'tipsy', 'schmovinDrunk', 'schmovinTipsy', 'drugged' }, e)
end

local function phaseGeometry(b, e)
  local names = { 'bounce', 'beat', 'bumpy', 'sawtooth', 'square', 'tornado', 'schmovinTornado' }
  local values = { 0.25, 0.15, 0.2, 0.5, 0.4, 0.4, 0.6 }

  for index = 1, #names do
    modEase(names[index], b + (index - 1) * 2, 2, values[index], 'quadOut')
  end
  scheduleReset(names, e)
end

local function phaseRotation(b, e)
  modEase('rotateZ', b, 3, 10, 'quadOut')
  modEase('rotateZ', b + 3, 2, 0, 'quadIn')

  modEase('centerRotateZ', b + 4, 3, 8, 'quadOut')
  modEase('centerRotateZ', b + 7, 2, 0, 'quadIn')

  modEase('fieldRotateX', b + 8, 3, 9, 'quadOut')
  modEase('fieldRotateX', b + 11, 2, 0, 'quadIn')

  modEase('localRotateZ', b + 12, 3, 10, 'quadOut')
  modEase('localRotateZ', e - 2, 2, 0, 'quadIn')

  modEase('confusion', b + 4, 4, 12, 'sineInOut')
  modEase('confusion', b + 8, 4, 0, 'sineInOut')

  modEase('counterClockWise', b + 10, 4, 0.5, 'sineInOut')
  modEase('counterClockWise', e - 2, 2, 0, 'quadIn')
end

local function phaseLanes(b, e)
  modEase('invert', b, 1, 1, 'quadOut')
  modEase('invert', b + 4, 1, 0, 'quadIn')

  modEase('opponentSwap', b + 8, 2, 0.4, 'sineInOut')
  modEase('opponentSwap', e - 4, 4, 0, 'sineInOut')

  modEase('spiral', b + 8, 4, 0.5, 'sineInOut')
  modEase('spiral', e - 4, 3, 0, 'sineInOut')

  modEase('infinite', b + 10, 4, 0.4, 'sineInOut')
  modEase('infinite', e - 2, 2, 0, 'quadIn')

  modEase('radionic', b + 12, 2, 0.5, 'quadOut')
  modEase('radionic', e - 2, 2, 0, 'quadIn')
end

local function phaseScaleStealth(b, e)
  modEase('scale', b, 2, 1.12, 'quadOut')
  modEase('scale', b + 4, 2, 1, 'quadIn')
  modEase('zoom', b + 4, 3, 0.35, 'sineInOut')
  modEase('zoom', b + 9, 3, 0, 'sineInOut')
  modEase('stealth', b + 8, 2, 0.5, 'quadOut')
  modEase('stealth', e - 2, 2, 0, 'quadIn')
  modEase('alpha', b + 8, 2, 0.9, 'quadOut')
  modEase('alpha', e - 2, 2, 1, 'quadIn')
end

local function phasePerspective(b, e)
  setModchartPerspective(true, 68, 1.0)
  modEase('z', b, 4, 260, 'quadOut', -1, 0)
  modEase('z', e - 4, 4, 0, 'quadInOut', -1, 0)

  modEase('rotateX', b + 4, 4, 15, 'sineInOut', -1, 0)
  modEase('rotateY', b + 8, 4, 15, 'sineInOut', -1, 0)
  modEase('rotateX', e - 4, 4, 0, 'quadInOut', -1, 0)
  modEase('rotateY', e - 4, 4, 0, 'quadInOut', -1, 0)

  -- Player only, field 0.
  modEase('x', b + 2, 4, 70, 'sineInOut', 1, 0)
  modEase('x', e - 4, 4, 0, 'sineInOut', 1, 0)

  modCallback(e - 2, 'perspectiveOff', 0)
end

local function phaseShaders(b, e)
  if not state.shaders then
    setTextString('tourDetail', 'Shaders are disabled (Options -> Visuals -> Shaders). The tour continues without them.')
    return
  end

  initLuaShader('showcase')
  addChromaticAbberationEffect('hud', 0.008)
  addGlitchEffect('game', 0.10, 0.10, 0.16)
  addScanlineEffect('hud', false)
  addVCREffect('game', 0.12, true, true, true)
  addDistantNoteEffect('game', downscroll, 0.42, 0.8)
  addBloomEffect('game', 0.35, 1.2)

  setSpriteShader('boyfriend', 'showcase')
  setSpriteShader('dad', 'showcase')

  setShaderFloat('boyfriend', 'uTimer', 0)
  setShaderFloat('dad', 'uTimer', 0)
  setShaderFloat('boyfriend', 'uIntensity', 0)
  setShaderFloat('dad', 'uIntensity', 0)
  setShaderFloat('boyfriend', 'uTintMix', 0.45)
  setShaderFloat('dad', 'uTintMix', 0.45)

  setShaderFloatArray('boyfriend', 'uTint', { 1.0, 0.25, 0.62 })
  setShaderFloatArray('dad', 'uTint', { 0.80, 0.30, 1.0 })
  tweenShaderFloat('charShaderInBf', 'boyfriend', 'uIntensity', 1.0, 1.5, 'quadOut')
  tweenShaderFloat('charShaderInDad', 'dad', 'uIntensity', 1.0, 1.5, 'quadOut')
  tweenShaderFloatArray('charTintBf', 'boyfriend', 'uTint', { 0.35, 0.95, 1.0 }, 4.0, 'sineInOut')
  tweenShaderFloatArray('charTintDad', 'dad', 'uTint', { 1.0, 0.55, 0.2 }, 4.0, 'sineInOut')

  state.shaderOn = true
  modCallback(e - 2, 'clearPhaseShaders', 0)
end

local function phaseFourthWallWindow(b, e)
  if not state.metaProbed then
    state.metaProbed = true
    -- The only reliable support probe: unsupported builds return false and
    -- log a one-line warning instead of changing the title.
    state.metaEnabled = setWindowTitle('PHOENIX // FEATURE TOUR')
    if not state.metaEnabled then
      debugPrint('[showcase] META_HORROR is not compiled in this build; 4th-wall calls will no-op')
    end
  end

  state.windowSupported = isWindowTransparencySupported()
  if state.windowSupported then
    setWindowAlpha(0.92)
  end

  local detail = 'setWindowTitle / setAlwaysOnTop / flashTaskbar'

  if state.metaEnabled then
    state.recording = isRecording()
    state.metaRuns = math.floor(safeNumber(getPersistentValue('phoenix_tour_runs', 0), 0)) + 1
    setPersistentValue('phoenix_tour_runs', state.metaRuns)

    flashTaskbar(4)
    setAlwaysOnTop(true)
    modCallback(b + 4, 'hideTaskbarGag', 0)
    modCallback(b + 8, 'restoreTaskbarGag', 0)

    detail = detail .. ' | ' .. (state.recording and 'recording detected: taskbar gag skipped' or 'not recording')
  else
    detail = 'META_HORROR not compiled: every window call was a safe no-op'
  end

  -- Window alpha is not gated behind META_HORROR, so always restore it.
  modCallback(e - 2, 'endWindowGag', 0)

  if state.windowSupported then
    detail = detail .. ' | window alpha 0.92'
  end

  setTextString('tourDetail', detail)
  setTextString('tourMeta', state.metaEnabled and 'META_HORROR: ON' or 'META_HORROR: OFF')
end

local function phaseFourthWallPlayer(b, e)
  showFourthWall()
  playSound('crash', 0.35, 'tourGlitch')
  soundFadeOut('tourGlitch', 0.8, 0)
  if state.windowSupported then
    setWindowAlpha(0.86)
  end
  if state.metaEnabled then
    setMetaWindowAlpha(0.9)
    setWindowTitle('PHOENIX // ' .. safeString(getDesktopUsername(), 'PLAYER'))
  end
  -- The overlay is deliberately brief: eight beats of a translucent top panel,
  -- then the rest of the phase is text-only so the chart stays playable.
  modCallback(b + 8, 'endPlayerGag', 0)
end

local function phaseHud(b, e)
  setHealthBarColors('ff16d2', 'caff4d')
  setTimeBarColors('ff16d2', 'caff4d')
  state.ratingOverride = true
  modCallback(e - 2, 'endRatingOverride', 0)
  doTweenZoom('hudZoomIn', 'camHUD', 1.04, 1.0, 'quadOut')
  cameraFlash('hud', 'ff16d2', 0.25, false)
  shake('hud', 0.004, 0.4)
  setTextString('tourDetail', 'health/time bars | onRecalculateRating custom hook | cameraFlash / cameraShake | early-late readout')
end

function onRecalculateRating()
  if state.ratingOverride then
    setRatingName('PHOENIX')
    setRatingFC('TOUR')
    return Function_Stop
  end
  return Function_Continue
end

local function phaseCamerasSprites(b, e)
  doTweenAlpha('tourLogoReturn', 'tourLogo', 0.85, 1.0, 'quadOut')
  doTweenAngle('tourLogoSpin', 'tourLogo', 360, 8, 'linear')

  makeLuaSprite('tourHalo', 'spotlight', 0, 0)
  setGraphicSize('tourHalo', math.floor(screenHeight * 1.45 * 0.573), math.floor(screenHeight * 1.45))
  screenCenter('tourHalo', 'xy')
  setProperty('tourHalo.alpha', 0)
  setBlendMode('tourHalo', 'add')
  setObjectCamera('tourHalo', 'camHUD')
  addLuaSprite('tourHalo', true)
  doTweenAlpha('tourHaloIn', 'tourHalo', 0.25, 1.0, 'quadOut')
  doTweenAngle('tourHaloSpin', 'tourHalo', -180, 8, 'linear')

  shake('game', 0.008, 0.5)
  setTextString('tourDetail', 'createCamera()/addCamera() built camShowcaseFW | sprites, blend modes, tweens, scroll factors')
  modCallback(e - 2, 'endSpriteGag', 0)
end

local function phaseAudio(b, e)
  playSound('confirmMenu', 0.8, 'tourConfirm')
  soundFadeOut('tourConfirm', 2.0, 0)
  setPlaybackSpeed(1.03)
  modCallback(b + 4, 'audioSpeedNormal', 0)
  modCallback(b + 8, 'audioSecondBlip', 0)
  setTextString('tourDetail', 'tagged playSound / soundFadeOut / getSoundVolume / setPlaybackSpeed 1.03 -> 1.0')
  debugPrint(string.format('[showcase] tagged sound volume = %.2f', getSoundVolume('tourConfirm')))
end

local function phasePlayfieldTwo(b, e)
  -- Field 0 and field 1 both transform the same receptors: the visible result
  -- is the composition, which is what layered playfields are for.
  modEase('y', b, 8, 18, 'sineInOut', -1, 0)
  modEase('y', e - 4, 4, 0, 'sineInOut', -1, 0)

  modEase('x', b, 4, 80, 'sineInOut', -1, 1)
  modEase('rotateZ', b, 4, 6, 'sineInOut', -1, 1)
  modEase('scale', b, 4, 1.06, 'sineInOut', -1, 1)
  modEase('x', e - 4, 4, 0, 'sineInOut', -1, 1)
  modEase('rotateZ', e - 4, 4, 0, 'sineInOut', -1, 1)
  modEase('scale', e - 4, 4, 1, 'sineInOut', -1, 1)
end

local function phaseChaos(b, e)
  modEase('wiggle', b, 2, 1, 'quadOut')
  modEase('wiggle', e - 4, 4, 0, 'quadIn')
  modEase('vibrate', b + 2, 2, 0.5, 'quadOut')
  modEase('vibrate', e - 4, 4, 0, 'quadIn')
  modEase('skewX', b + 4, 2, 20, 'quadOut')
  modEase('skewY', b + 4, 2, 10, 'quadOut')
  modEase('skewX', e - 4, 4, 0, 'quadInOut')
  modEase('skewY', e - 4, 4, 0, 'quadInOut')
  setTextString('tourCounter', '34/34 modifiers driven')
end

local function phasePerspectiveFinale(b, e)
  setModchartPerspective(true, 62, 1.3)
  modEase('z', b, 3, 220, 'quadOut')
  modEase('rotateY', b, 6, 24, 'sineInOut')
  modEase('rotateX', b + 3, 6, 10, 'sineInOut')
  modEase('x', b, 6, 90, 'sineInOut', 1)
  modEase('z', e - 2, 2, 0, 'quadIn')
  modEase('rotateY', e - 2, 2, 0, 'quadIn')
  modEase('rotateX', e - 2, 2, 0, 'quadIn')
  modEase('x', e - 2, 2, 0, 'quadIn', 1)
  modCallback(e - 2, 'perspectiveOff', 0)
end

local function phaseCombo(b, e)
  modEase('reverse', b, 2, 0.5, 'quadOut')
  modEase('drunk', b, 2, 0.18, 'quadOut')
  modEase('bounce', b, 2, 0.18, 'quadOut')
  modEase('scale', b, 2, 1.05, 'quadOut')
  modEase('rotateZ', b, 2, 4, 'quadOut')
  modEase('spiral', b, 2, 0.2, 'quadOut')
  modEase('invert', b, 2, 0.4, 'quadOut')
  modEase('xmod', b, 2, 0.85, 'quadOut')
  scheduleReset({ 'reverse', 'drunk', 'bounce', 'scale', 'rotateZ', 'spiral', 'invert', 'xmod' }, e)
end

local function phaseFinaleBuild(b, e)
  modEase('drunk', b, 4, 0.3, 'quadOut')
  modEase('tipsy', b, 4, 0.3, 'quadOut')
  modEase('bounce', b, 4, 0.25, 'quadOut')
  modEase('scale', b, 4, 1.1, 'quadOut')
  modEase('rotateZ', b, 4, 6, 'quadOut')
  modEase('zoom', b, 4, 0.2, 'quadOut')
  modEase('reverse', b, 2, 0.5, 'quadOut')
  if state.shaders then
    addChromaticAbberationEffect('hud', 0.006)
    addBloomEffect('game', 0.4, 1.4)
  end
  shake('game', 0.01, 4.0)
  scheduleReset({ 'drunk', 'tipsy', 'bounce', 'scale', 'rotateZ', 'zoom', 'reverse' }, e)
end

local function phaseFinaleDrop(b, e)
  setModchartPerspective(true, 60, 1.4)
  modSet('z', b, 160)
  modEase('rotateY', b, 4, 20, 'quadOut')
  modEase('bounce', b, 2, 0.3, 'quadOut')
  modEase('drunk', b, 2, 0.3, 'quadOut')
  modEase('reverse', b, 1, 0.5, 'quadOut')
  if state.shaders then
    addGlitchEffect('game', 0.12, 0.12, 0.2)
    addChromaticAbberationEffect('hud', 0.01)
  end
  cameraFlash('game', 'ffffff', 0.2, false)
  shake('game', 0.02, 1.0)
  modCallback(e - 4, 'dropCleanup', 0)
end

local function phaseCooldown(b, e)
  resetAllPercents()
  setModchartPerspective(false)
  if state.shaders then
    clearShadersFromCamera('hud')
    clearShadersFromCamera('game')
  end
  setTextString('tourDetail', 'all percentages returned to neutral; shader filters cleared')
end

local function phaseResetCheck(b, e)
  if not state.modchartReset then
    resetModchart()
    state.modchartReset = true
  end
  setTextString('tourDetail', 'resetModchart() -> isModchartActive() = ' .. tostring(isModchartActive()))
  setTextString('tourCounter', '34/34 modifiers tested')
  debugPrint('[showcase] resetModchart: active=' .. tostring(isModchartActive()))
end

local function phaseEngineInfo(b, e)
  local info = 'engine: Phoenix ' .. safeString(phoenixVersion, '?') .. ' | ' .. hardwareLine() .. '\n'
    .. 'cpu: ' .. safeString(getCPUName(), 'Unknown CPU') .. ' | renderer: ' .. safeString(getGraphicsApi(), 'Unknown API') .. '\n'
    .. 'plays: ' .. tostring(state.plays) .. ' | tour runs: ' .. tostring(state.metaRuns)
  setTextString('tourDetail', info)
end

local function phaseCredits(b, e)
  cancelTimer('tourBannerTimer')
  cancelTween('tourBannerIn')
  cancelTween('tourBannerOut')
  setTextString('tourBanner', 'CHART: KAWAI SPRITE\nERECT DAD BATTLE\nMODCHART: PHOENIX ENGINE')
  setTextColor('tourBanner', 'ff16d2')
  setProperty('tourBanner.alpha', 1)
  setTextString('tourPhase', 'CREDITS')
  setTextString('tourDetail', 'Thank you for testing every optional system.')
end

local function phaseEnd(b, e)
  cleanupAll()
  banner('THANK YOU FOR TESTING', 'ff16d2')
  setTextString('tourPhase', 'END // CLEANUP COMPLETE')
  setTextString('tourDetail', 'META effects restored | window alpha restored | shaders removed | playback 1.0')
end

----------------------------------------------------------------------
-- Phase table (16 beats each, 0-415; the chart's last note is ~414)
----------------------------------------------------------------------

local PHASES = {
  { beat = 0,   name = 'INTRO // TEST HARNESS',            detail = '', mods = nil, run = phaseIntro },
  { beat = 16,  name = 'MODCHART 01 // TIMELINE',           detail = 'modSet, modEase, modAdd, modSetAdd, modCallback, modRepeater', mods = { 'transform', 'rotate', 'scale' }, run = phaseTimeline },
  { beat = 32,  name = 'MODCHART 02 // SCROLL',             detail = 'reverse, xmod, boost, brake, receptorScroll, zigZag', mods = { 'reverse', 'boost', 'receptorscroll', 'zigZag' }, run = phaseScroll },
  { beat = 48,  name = 'MODCHART 03 // DRUNK FAMILY',       detail = 'drunk, tipsy, schmovinDrunk, schmovinTipsy, drugged', mods = { 'drunk', 'tipsy', 'schmovinDrunk', 'schmovinTipsy', 'drugged' }, run = phaseDrunk },
  { beat = 64,  name = 'MODCHART 04 // GEOMETRY',           detail = 'bounce, beat, bumpy, sawtooth, square, tornado, schmovinTornado', mods = { 'bounce', 'beat', 'bumpy', 'sawtooth', 'square', 'tornado', 'schmovinTornado' }, run = phaseGeometry },
  { beat = 80,  name = 'MODCHART 05 // ROTATION',           detail = 'rotate, centerRotate, fieldRotate, localRotate, confusion, counterClockWise', mods = { 'centerRotate', 'fieldRotate', 'localRotate', 'confusion', 'counterClockWise' }, run = phaseRotation },
  { beat = 96,  name = 'MODCHART 06 // LANES',              detail = 'invert, opponentSwap, spiral, infinite, radionic', mods = { 'invert', 'opponentSwap', 'spiral', 'infinite', 'radionic' }, run = phaseLanes },
  { beat = 112, name = 'MODCHART 07 // SCALE & STEALTH',    detail = 'scale, zoom, stealth (early notes hidden), alpha', mods = { 'zoom', 'stealth' }, run = phaseScaleStealth },
  { beat = 128, name = 'MODCHART 08 // 3D PERSPECTIVE',     detail = 'setModchartPerspective + z / rotateX / rotateY, one player side', mods = nil, run = phasePerspective },
  { beat = 144, name = 'SHADERS // RUNTIME & BUILT-IN',     detail = 'showcase.frag + include, uniform tweens, chromatic, glitch, scanline, VCR, distant-note preview, bloom', mods = nil, run = phaseShaders },
  { beat = 160, name = '4TH WALL // THE WINDOW',            detail = 'setWindowTitle, setAlwaysOnTop, flashTaskbar, hideTaskbar, persistent values', mods = nil, run = phaseFourthWallWindow },
  { beat = 176, name = '4TH WALL // THE PLAYER',            detail = 'custom camera desktop overlay, username, clock, uptime, isLateNight', mods = nil, run = phaseFourthWallPlayer },
  { beat = 192, name = 'HUD // RATING & TIMING',            detail = 'health/time bar colours, onRecalculateRating, camera flash/shake, early-late readout', mods = nil, run = phaseHud },
  { beat = 208, name = 'CAMERAS & SPRITES',                 detail = 'createCamera/addCamera, setObjectCamera, sprites, blend modes, tweens', mods = nil, run = phaseCamerasSprites },
  { beat = 224, name = 'AUDIO & PLAYBACK',                  detail = 'tagged sound, fade, volume/time reads, playback rate', mods = nil, run = phaseAudio },
  { beat = 240, name = 'PLAYFIELD 2 // LAYERED',            detail = 'two playfields transform the same receptors', mods = nil, run = phasePlayfieldTwo },
  { beat = 256, name = 'CHAOS // ALL 34 DONE',              detail = 'wiggle, vibrate, skewX, skewY - registry fully exercised', mods = { 'wiggle', 'vibrate', 'skew' }, run = phaseChaos },
  { beat = 272, name = '3D FINALE',                         detail = 'deep perspective, rotation and player-only offset', mods = nil, run = phasePerspectiveFinale },
  { beat = 288, name = 'COMBO STRESS TEST',                 detail = 'eight modifiers at once', mods = nil, run = phaseCombo },
  { beat = 304, name = 'FINALE BUILD',                      detail = 'rising drunk/tipsy/bounce/scale, bloom and chromatic', mods = nil, run = phaseFinaleBuild },
  { beat = 320, name = 'FINALE DROP',                       detail = 'z 160, glitch, chromatic, camera flash/shake', mods = nil, run = phaseFinaleDrop },
  { beat = 336, name = 'COOLDOWN',                          detail = 'everything neutral again', mods = nil, run = phaseCooldown },
  { beat = 352, name = 'RESET CHECK',                       detail = 'resetModchart() clears the whole manager', mods = nil, run = phaseResetCheck },
  { beat = 368, name = 'ENGINE INFO',                       detail = 'hardware globals and per-mod save stats', mods = nil, run = phaseEngineInfo },
  { beat = 384, name = 'CREDITS',                           detail = 'Erect Dad Battle by Kawai Sprite', mods = nil, run = phaseCredits },
  { beat = 400, name = 'END // CLEANUP',                    detail = 'restore every optional system', mods = nil, run = phaseEnd }
}

local function runPhase(index)
  local phase = PHASES[index]
  if phase == nil then
    return
  end

  state.phaseIndex = index

  resetAllPercents()
  setModchartPerspective(false)
  setPlaybackSpeed(1.0)
  state.ratingOverride = false

  if state.shaderOn and state.shaders then
    removeSpriteShader('boyfriend')
    removeSpriteShader('dad')
    clearShadersFromCamera('hud')
    clearShadersFromCamera('game')
    state.shaderOn = false
  end

  setPhaseText(phase.name, phase.detail)
  banner(phase.name, 'ff16d2')
  markTested(phase.mods)

  if phase.run ~= nil then
    phase.run(phase.beat, phase.beat + 16)
  end
end

----------------------------------------------------------------------
-- Engine hooks
----------------------------------------------------------------------

function onCreatePost()
  -- The add*Effect functions are only registered when the platform and the
  -- user's preference both allow shaders, so probe for one of them instead of
  -- trusting the preference alone.
  state.shaders = shadersEnabled == true and addChromaticAbberationEffect ~= nil
  state.windowSupported = isWindowTransparencySupported()
  state.reducedMotion = getPropertyFromClass('backend.ClientPrefs', 'reducedMotion') == true

  initSaveData(state.saveName)
  state.plays = math.floor(safeNumber(getDataFromSave(state.saveName, 'plays'), 0)) + 1
  setDataFromSave(state.saveName, 'plays', state.plays)
  flushSaveData(state.saveName)

  buildHud()
  installModchart()
  buildFourthWall()

  setTextString('tourBeat', 'beat 0 | modifiers 34 | phase 1/' .. tostring(PHASE_COUNT))
  debugPrint(string.format('[showcase] setup: shaders=%s windowAlpha=%s save=%s', tostring(state.shaders), tostring(state.windowSupported), state.saveName))
end

function onSongStart()
  state.started = true
  runPhase(1)
end

function onUpdatePost(elapsed)
  state.elapsed = state.elapsed + elapsed
  if not state.started then
    return
  end

  local beat = getProperty('curDecBeat')
  if type(beat) ~= 'number' then
    beat = curDecBeat or 0
  end

  while state.phaseIndex < #PHASES and beat >= PHASES[state.phaseIndex + 1].beat do
    runPhase(state.phaseIndex + 1)
  end

  -- Shader clock: 12 updates a second is plenty for a sine scanline.
  if state.shaderOn and state.shaders then
    state.shaderTimer = state.shaderTimer + elapsed
    if state.shaderTimer >= 0.08 then
      state.shaderTimer = 0
      local tick = math.floor(state.elapsed * 10) % 1000
      setShaderFloat('boyfriend', 'uTimer', tick)
      setShaderFloat('dad', 'uTimer', tick)
    end
  end

  if state.fwVisible then
    local panelWidth = getProperty('fwPanel.width')
    local panelHeight = getProperty('fwPanel.height')
    local cursorX = state.fwX + panelWidth * 0.5 + math.sin(state.elapsed * 1.3) * 90
    local cursorY = state.fwY + panelHeight * 0.72 + math.cos(state.elapsed * 1.7) * 24
    setProperty('fwCursor.x', cursorX)
    setProperty('fwCursor.y', cursorY)
  end

  state.hudTimer = state.hudTimer + elapsed
  if state.hudTimer >= 0.2 then
    state.hudTimer = 0
    local active = isModchartActive() and #getModchartModifiers() or 0
    setTextString('tourBeat', string.format('beat %d | active modifiers %d | phase %d/%d',
      math.floor(beat), active, state.phaseIndex, #PHASES))
  end
end

function onBeatHit()
  if not state.started then
    return
  end
  if state.phaseIndex >= 18 and state.phaseIndex <= 21 then
    shake('game', 0.006, 0.16)
  end
end

function goodNoteHit(id, noteData, noteType, isSustainNote)
  if isSustainNote then
    return
  end

  local diff = math.abs(safeNumber(noteDiff, 0))
  local label = 'ON TIME'
  local color = 'ffffff'

  if hitTiming == 'early' then
    state.earlyCount = state.earlyCount + 1
    label = string.format('EARLY +%dms', math.floor(diff + 0.5))
    color = 'caff4d'
  elseif hitTiming == 'late' then
    state.lateCount = state.lateCount + 1
    label = string.format('LATE -%dms', math.floor(diff + 0.5))
    color = 'ff16d2'
  end

  setTextString('tourTiming', label .. '  E' .. state.earlyCount .. '/L' .. state.lateCount)
  setTextColor('tourTiming', color)
end

function noteMiss(id, noteData, noteType, isSustainNote)
  if isSustainNote then
    return
  end
  setTextString('tourTiming', 'MISS')
  setTextColor('tourTiming', 'ff0000')
end

function onTimerCompleted(tag, loops, loopsLeft)
  if tag == 'tourBannerTimer' then
    doTweenAlpha('tourBannerOut', 'tourBanner', 0, 0.8, 'quadIn')
  elseif tag == 'tourHaloRemove' then
    cancelTween('tourHaloIn')
    cancelTween('tourHaloOut')
    cancelTween('tourHaloSpin')
    removeLuaSprite('tourHalo', true)
  end
end

function onTweenCompleted(tag)
  if string.sub(tag, 1, 6) == 'fwOut_' then
    setVisible(string.sub(tag, 7), false)
  end
end

function onSongEnd()
  cleanupAll()
  setDataFromSave(state.saveName, 'early', state.earlyCount)
  setDataFromSave(state.saveName, 'late', state.lateCount)
  setDataFromSave(state.saveName, 'lastModifiers', state.testedCount)
  if state.testedCount >= MOD_COUNT then
    setDataFromSave(state.saveName, 'completed', 1)
  end
  flushSaveData(state.saveName)
  debugPrint(string.format('[showcase] song end: %d/%d modifiers, E%d/L%d', state.testedCount, MOD_COUNT, state.earlyCount, state.lateCount))
end

function onGameOver()
  -- Death can happen during the 4th-wall section; never leave the title, taskbar
  -- or window alpha changed on the game-over screen.
  cleanupAll()
end

function onDestroy()
  cleanupAll()
  if state.fwCamAdded and not state.fwCamRemoved then
    state.fwCamRemoved = true
    removeCamera(state.fwCam)
  end
end
