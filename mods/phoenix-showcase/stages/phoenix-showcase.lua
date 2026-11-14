--[[
  Phoenix Feature Tour - stage script
  ----------------------------------
  Owns the stage art and the `Dadbattle Spotlight` event that comes from the
  copied Erect Dad Battle event chart. The song-wide script lives in
  data/phoenix-feature-tour/phoenix-feature-tour-erect.lua.
]]

local ready = false
local spotlightOn = false

local function numberOf(value, fallback)
  local parsed = tonumber(value)
  if parsed == nil then
    return fallback
  end
  return parsed
end

local function setVisible(tag, value)
  setProperty(tag .. '.visible', value)
end

function onCreatePost()
  local w = screenWidth
  local h = screenHeight

  -- Solid backdrop for aspect ratios wider or taller than the art.
  makeLuaSprite('scBackdrop', '', 0, 0)
  makeGraphic('scBackdrop', 8, 8, '05030a')
  setGraphicSize('scBackdrop', math.floor(w * 1.12), math.floor(h * 1.12))
  setProperty('scBackdrop.x', -math.floor(w * 0.06))
  setProperty('scBackdrop.y', -math.floor(h * 0.06))
  setScrollFactor('scBackdrop', 0, 0)
  addLuaSprite('scBackdrop', false)

  -- Generated stage art, scaled to cover the viewport whatever its source size.
  makeLuaSprite('scBg', 'showcase/stage', 0, 0)
  local artWidth = getProperty('scBg.width')
  local artHeight = getProperty('scBg.height')
  local cover = math.max(w / artWidth, h / artHeight) * 1.08
  setGraphicSize('scBg', math.floor(artWidth * cover), math.floor(artHeight * cover))
  setProperty('scBg.x', math.floor((w - getProperty('scBg.width')) * 0.5))
  setProperty('scBg.y', math.floor((h - getProperty('scBg.height')) * 0.5))
  setScrollFactor('scBg', 0.92, 0.92)
  addLuaSprite('scBg', false)

  -- Thin neon line that pulses on beat (cheap: no giant glow textures).
  makeLuaSprite('scBeatLine', '', 0, 0)
  makeGraphic('scBeatLine', math.floor(w), 3, 'ff16d2')
  setProperty('scBeatLine.y', math.floor(h * 0.66))
  setProperty('scBeatLine.alpha', 0.10)
  setBlendMode('scBeatLine', 'add')
  setScrollFactor('scBeatLine', 0, 0)
  addLuaSprite('scBeatLine', false)

  -- The Dad Battle spotlight effect, drawn above the characters.
  makeLuaSprite('scSpotBlack', '', 0, 0)
  makeGraphic('scSpotBlack', 8, 8, '000000')
  setGraphicSize('scSpotBlack', math.floor(w * 1.12), math.floor(h * 1.12))
  setProperty('scSpotBlack.x', -math.floor(w * 0.06))
  setProperty('scSpotBlack.y', -math.floor(h * 0.06))
  setProperty('scSpotBlack.alpha', 0.35)
  setScrollFactor('scSpotBlack', 0, 0)
  setVisible('scSpotBlack', false)
  addLuaSprite('scSpotBlack', true)

  makeLuaSprite('scSpotLight', 'spotlight', 0, 0)
  setGraphicSize('scSpotLight', 686, 1198)
  setProperty('scSpotLight.alpha', 0)
  setBlendMode('scSpotLight', 'add')
  setScrollFactor('scSpotLight', 0, 0)
  setVisible('scSpotLight', false)
  addLuaSprite('scSpotLight', true)

  ready = true
end

function onBeatHit()
  if not ready then
    return
  end
  if curBeat % 2 == 0 then
    setProperty('scBeatLine.alpha', 0.35)
    doTweenAlpha('scBeatLineOut', 'scBeatLine', 0.10, 0.38, 'quadOut')
  end
end

function onEvent(name, value1, value2)
  if name ~= 'Dadbattle Spotlight' then
    return
  end

  local val = numberOf(value1, 0)

  if val == 1 or val == 2 or val == 3 then
    if not spotlightOn then
      spotlightOn = true
      cancelTween('scSpotBlackOut')
      cancelTween('scSpotlightOut')
      setVisible('scSpotBlack', true)
      setVisible('scSpotLight', true)
      setProperty('scSpotBlack.alpha', 0.35)
      setProperty('scSpotLight.alpha', 0)
      doTweenAlpha('scSpotBlackIn', 'scSpotBlack', 0.35, 0.25, 'quadOut')
      doTweenAlpha('scSpotlightIn', 'scSpotLight', 0.45, 0.25, 'quadOut')
      setProperty('defaultCamZoom', getProperty('defaultCamZoom') + 0.12)
    else
      setProperty('scSpotLight.alpha', 0)
      doTweenAlpha('scSpotlightIn', 'scSpotLight', 0.45, 0.2, 'quadOut')
    end

    local who = 'dad'
    if val > 2 then
      who = 'boyfriend'
    end

    local lightWidth = getProperty('scSpotLight.width')
    local lightHeight = getProperty('scSpotLight.height')
    local targetX = getGraphicMidpointX(who)
    local targetY = getProperty(who .. '.y') + getProperty(who .. '.height')

    setProperty('scSpotLight.x', targetX - lightWidth * 0.5)
    setProperty('scSpotLight.y', targetY - lightHeight + 50)
    return
  end

  if spotlightOn then
    spotlightOn = false
    cancelTween('scSpotBlackIn')
    cancelTween('scSpotlightIn')
    doTweenAlpha('scSpotlightOut', 'scSpotLight', 0, 0.45, 'quadIn')
    doTweenAlpha('scSpotBlackOut', 'scSpotBlack', 0, 0.45, 'quadIn')
    setProperty('defaultCamZoom', getProperty('defaultCamZoom') - 0.12)
  end
end

function onTweenCompleted(tag)
  if tag == 'scSpotlightOut' then
    setVisible('scSpotLight', false)
  elseif tag == 'scSpotBlackOut' then
    setVisible('scSpotBlack', false)
  end
end
