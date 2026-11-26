--[[
  WIN32MODCHART : song script
  ===========================

  Base song : Dad Battle (Erect) - chart + music by Kawai Sprite.
  Difficulty: Erect (the -erect stems are reused untouched).

  What this script does
  ---------------------
  Dad Battle hands sections back and forth between dad and bf. Every time the
  chart moves on to a new 4 beat block, this script gives the side that owns
  that block a new readable playfield move:

    * 12 moves in a fixed cycle (x slide, y lift, field tilt, inner swap,
      scale squash, scale puff, drunk sway, sawtooth climb, beat bounce,
      diagonal, tilt + slide, lane pinch),
    * the cycle advances every block, so the modchart visibly changes on every
      turn and also inside long stretches where only one side sings,
    * only the singing side moves, every move returns to neutral before the
      block is over, so the arrows never drift and never sit displaced,
    * how loud a move is follows the note density of its section: dense parts
      get the calm end of the range, sparse parts get the loud end.

  The climax (last chorus, beats 336-416) switches to the Windows GDI payloads
  that ship with the engine (`source/backend/GDIEffects.hx` plus the ported
  HPPD effects in `source/backend/native/`). It is driven only through the
  softmodding API: gdiInit / gdiRegisterEffect / gdiEnableEffect / gdiHppd*.

  Why the eases are scheduled from callbacks
  ------------------------------------------
  `ModchartEvent` captures an ease's start value on its first update. Two
  eases queued on the same percent would therefore both capture the value the
  first one left behind, and the earlier one would be overwritten. So each
  block schedules its opening and closing eases from its own `modCallback`
  hook: at that point the percent has been parked on its neutral value by
  `setPercent`, the ease starts from there, and the block has the percent to
  itself until the next block.

  Readability + safety budgets baked into this script
  --------------------------------------------------
  * |x| <= 64 px, |y| <= 40 px, |rotateZ| <= 8 deg, scale 0.84..1.12,
    so no arrow leaves the playfield and no receptor hides a note.
  * `ClientPrefs.reducedMotion` removes the two rotating moves and every
    camera shake; `ClientPrefs.flashing` disables the desktop blink payload.
  * GDI is Windows-only. Off Windows every call is a logged no-op, the HUD
    says "simulated" instead of pretending, and the climax still reads through
    the camera.
  * Every desktop payload is stopped in onPause / onGameOver / onEndSong /
    onDestroy, so the desktop is never left broken.
]]

----------------------------------------------------------------------
-- Tunables
----------------------------------------------------------------------

-- Sides, numbered the way the modchart API does.
local DAD = 0
local BF = 1

-- Last chorus: the chart locks to the player side and the density peaks here.
local CLIMAX_START_BEAT = 336
local CLIMAX_END_BEAT = 416

-- Every hand-over in the chart, with the note density of its sections.
-- `intensity` runs 0.60 (busy, calm) .. 1.00 (sparse, loud); it is measured
-- from the chart, not guessed.
local TURNS = {
  { beat =   0, beats =   8, who = DAD, intensity = 0.86 },
  { beat =   8, beats =   8, who = BF, intensity = 0.86 },
  { beat =  16, beats =   8, who = DAD, intensity = 0.88 },
  { beat =  24, beats =   8, who = BF, intensity = 0.88 },
  { beat =  32, beats =  16, who = DAD, intensity = 1.00 },
  { beat =  48, beats =  16, who = BF, intensity = 0.91 },
  { beat =  64, beats =  16, who = DAD, intensity = 0.88 },
  { beat =  80, beats =  48, who = BF, intensity = 0.76 },
  { beat = 128, beats =  28, who = DAD, intensity = 0.76 },
  { beat = 156, beats =  36, who = BF, intensity = 0.77 },
  { beat = 192, beats =   8, who = DAD, intensity = 0.75 },
  { beat = 200, beats =   8, who = BF, intensity = 0.86 },
  { beat = 208, beats =   8, who = DAD, intensity = 0.60 },
  { beat = 216, beats =   8, who = BF, intensity = 0.88 },
  { beat = 224, beats =  16, who = DAD, intensity = 0.81 },
  { beat = 240, beats = 144, who = BF, intensity = 0.67 },
  { beat = 384, beats =   8, who = DAD, intensity = 0.86 },
  { beat = 392, beats =   8, who = BF, intensity = 0.88 },
  { beat = 400, beats =   8, who = DAD, intensity = 0.99 },
  { beat = 408, beats =   8, who = BF, intensity = 0.99 },
}

-- Resting values. Everything else rests at 0.
local NEUTRAL = {
  xmod = 1,
  scale = 1,
  scaleX = 1,
  scaleY = 1,
  alpha = 1
}

-- Every percent a move may drive. Parked on its resting value at song start.
-- `invert`/`flip` are deliberately absent: both are 112 px per lane
-- (`Invert.hx`), which is a full lane of displacement and too much to read.
local PERCENTS = {
  'x', 'y', 'xoffset', 'yoffset',
  'x0', 'x1', 'x2', 'x3',
  'rotateZ', 'centerRotateZ',
  'scale', 'zoom',
  'drunkX', 'sawtooth', 'bounceY'
}

-- Modifiers that have to exist before a percent does anything.
local MODIFIERS = {
  'transform', 'rotate', 'centerrotate', 'scale', 'drunk', 'sawtooth',
  'bounce', 'zoom'
}

local COLOR = {
  accent = 'c8ff7a',
  soft = '9ad1ff',
  warn = 'ffb35c',
  hot = 'ff4d6d',
  dim = 'b9c2cc'
}

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------

local state = {
  -- GDI
  probed = false,
  ready = false,
  registered = {},
  active = false,
  running = {},
  climaxScheduled = false,
  teardownDone = false,

  -- preferences
  canFlash = true,
  reducedMotion = false,

  -- HUD
  hudReady = false,

  -- just-in-time queues, filled in scheduling order (so also in beat order)
  openQueue = {},
  openCursor = 1,
  closeQueue = {},
  closeCursor = 1
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

--- Resting value of a percent.
--- @param name Percent name.
--- @return The value the percent sits on while idle.
local function neutral(name)
  local value = NEUTRAL[name]
  if value == nil then
    return 0
  end
  return value
end

--- Debug line with the mod prefix.
--- @param message Text to print.
local function log(message)
  debugPrint('[win32modchart] ' .. message)
end

--- Camera shake that honours the player's reduced-motion preference.
--- @param camera Camera name accepted by `cameraShake`.
--- @param intensity Shake strength.
--- @param duration Duration in seconds.
local function safeShake(camera, intensity, duration)
  if state.reducedMotion then
    return
  end
  cameraShake(camera, intensity, duration)
end

--- Park one percent on its resting value, right now, on one side.
--- This is the anchor every ease starts from.
--- @param name Percent name.
--- @param side Owning side.
local function park(name, side)
  setPercent(name, neutral(name), side, 0)
end

--- Start a move: ease a percent away from neutral.
--- @param name Percent name.
--- @param beat Beat the move starts on.
--- @param beats Length of the move in beats.
--- @param value Target value.
--- @param ease Ease used for the travel.
--- @param side Owning side.
local function openEase(name, beat, beats, value, ease, side)
  modEase(name, beat, beats, value, ease or 'sineOut', side, 0)
end

--- Finish a move: ease the percent back to neutral.
--- @param name Percent name.
--- @param beat Beat the return starts on.
--- @param beats Length of the return in beats.
--- @param side Owning side.
local function closeEase(name, beat, beats, side)
  modEase(name, beat, beats, neutral(name), 'sineInOut', side, 0)
end

----------------------------------------------------------------------
-- HUD
----------------------------------------------------------------------

--- Build the HUD block: song / turn read-out top left, desktop status bottom
--- right, both clear of the time bar, the score text and the health bar.
local function buildHud()
  local w = screenWidth
  local h = screenHeight
  local downscroll = pref('downScroll', false) == true
  local top = downscroll and 18 or 74
  local width = math.max(300, w - 380)

  local function label(tag, text, size, y, color, align)
    makeLuaText(tag, text, width, 20, y)
    setTextSize(tag, size)
    setTextFont(tag, 'vcr.ttf')
    setTextColor(tag, color)
    setTextBorder(tag, 2, '000000')
    setTextAlignment(tag, align or 'left')
    addLuaText(tag)
  end

  label('w32Title', 'WIN32MODCHART', 24, top, COLOR.accent)
  label('w32Side', 'DAD SINGS / turn 1', 17, top + 30, COLOR.soft)
  label('w32Move', 'move: warm up', 15, top + 54, COLOR.dim)

  local infoY = h - 118
  label('w32Gdi', 'WIN32 GDI: standby', 15, infoY, COLOR.warn, 'right')
  setProperty('w32Gdi.x', w - 360)
  label('w32Hppd', 'HPPD payloads: idle', 15, infoY + 22, COLOR.dim, 'right')
  setProperty('w32Hppd.x', w - 360)

  state.hudReady = true
end

--- Write the current block to the HUD.
--- @param entry Queue entry describing the block.
--- @param beat Beat the callback fired on.
local function showBlock(entry, beat)
  if not state.hudReady then
    return
  end
  setTextString('w32Side', entry.header .. ' / turn ' .. entry.turn)
  local tint = COLOR.soft
  if entry.side == DAD then
    tint = COLOR.warn
  end
  if entry.header == 'CLIMAX' then
    tint = COLOR.hot
  end
  setTextColor('w32Side', tint)
  setTextString('w32Move', 'move: ' .. entry.move.label .. '  @' .. math.floor(beat))
  setProperty('w32Move.alpha', 0.45)
  doTweenAlpha('w32MoveIn', 'w32Move', 1, 0.3, 'quadOut')
end

----------------------------------------------------------------------
-- Moves
----------------------------------------------------------------------

-- A move is a label, the percents it drives, and the function that opens it.
-- `w32BlockClose` sends those percents home, so a move never has to close.
local MOVES = {}

--- Declare a move.
--- @param label Name shown on the HUD.
--- @param percents Percents the move drives.
--- @param open Function(side, beat, beats, power) scheduling the opening eases.
local function move(label, percents, open)
  MOVES[#MOVES + 1] = { label = label, percents = percents, open = open }
end

move('x slide', { 'x' }, function(side, beat, beats, power)
  openEase('x', beat, beats, 62 * power, 'quadOut', side)
end)

move('y lift', { 'y' }, function(side, beat, beats, power)
  openEase('y', beat, beats, -40 * power, 'sineOut', side)
end)

move('field tilt', { 'rotateZ' }, function(side, beat, beats, power)
  -- `rotate` pivots around the lane centre (Rotate.hx), so 6 degrees swings the
  -- outer columns by about 30 px: enough to read, far too little to lose one.
  openEase('rotateZ', beat, beats, 6 * power, 'sineOut', side)
end)

move('inner swap', { 'x1', 'x2' }, function(side, beat, beats, power)
  -- The two middle columns trade places. 30 px is under a third of a lane, so
  -- the arrows never reach a neighbour column.
  openEase('x1', beat, beats, 30 * power, 'quadOut', side)
  openEase('x2', beat, beats, -30 * power, 'quadOut', side)
end)

move('scale squash', { 'scale' }, function(side, beat, beats, power)
  openEase('scale', beat, beats, 1 - 0.16 * power, 'quadOut', side)
end)

move('scale puff', { 'scale' }, function(side, beat, beats, power)
  openEase('scale', beat, beats, 1 + 0.12 * power, 'quadOut', side)
end)

move('drunk sway', { 'drunkX' }, function(side, beat, beats, power)
  openEase('drunkX', beat, beats, 0.35 * power, 'sineOut', side)
end)

move('sawtooth climb', { 'sawtooth' }, function(side, beat, beats, power)
  openEase('sawtooth', beat, beats, 0.35 * power, 'sineOut', side)
end)

move('beat bounce', { 'bounceY' }, function(side, beat, beats, power)
  openEase('bounceY', beat, beats, 0.22 * power, 'quadOut', side)
end)

move('diagonal', { 'x', 'y' }, function(side, beat, beats, power)
  openEase('x', beat, beats, 34 * power, 'sineInOut', side)
  openEase('y', beat, beats, -22 * power, 'sineInOut', side)
end)

move('tilt + slide', { 'x', 'rotateZ' }, function(side, beat, beats, power)
  openEase('x', beat, beats, -44 * power, 'quadOut', side)
  openEase('rotateZ', beat, beats, -5 * power, 'sineOut', side)
end)

move('lane pinch', { 'x0', 'x1', 'x2', 'x3' }, function(side, beat, beats, power)
  -- Lane percents stack on top of the field `x`, and `Transform` adds each
  -- lane's own value to that column (`x + xoffset + x<lane>`), so a peak of
  -- 18 px is under a fifth of a lane: columns breathe, they never touch.
  openEase('x0', beat, beats, 18 * power, 'quadOut', side)
  openEase('x1', beat, beats, 9 * power, 'quadOut', side)
  openEase('x2', beat, beats, -9 * power, 'quadOut', side)
  openEase('x3', beat, beats, -18 * power, 'quadOut', side)
end)

-- The two moves that rotate the field. They stay in the cycle, but a player
-- who asked for reduced motion gets them swapped for calmer ones.
local MOTION_MOVES = { ['field tilt'] = true, ['tilt + slide'] = true }

--- Whether a move is allowed under the current preferences.
--- @param entry Move table.
--- @return True when the move may be used.
local function moveAllowed(entry)
  if not state.reducedMotion then
    return true
  end
  return MOTION_MOVES[entry.label] == nil
end

----------------------------------------------------------------------
-- Block scheduling
----------------------------------------------------------------------

--- Schedule one 4-ish beat block.
--- Only callbacks are queued here. The eases are created later, from those
--- callbacks, so each percent is guaranteed to be alone.
--- @param beat Beat the block starts on.
--- @param beatCount Length of the block in beats.
--- @param side Owning side.
--- @param power Intensity multiplier.
--- @param moveIndex Index into MOVES.
--- @param turn Human facing turn number.
--- @param climax Whether this block sits inside the climax.
local function scheduleBlock(beat, beatCount, side, power, moveIndex, turn, climax)
  local entry = MOVES[moveIndex]
  local openBeats = math.max(1, beatCount * 0.5)
  -- Close slightly before the next block so the two never share a frame.
  local closeBeats = math.max(0.75, beatCount * 0.5 - 0.25)

  local header = 'CLIMAX'
  if not climax then
    header = (side == BF) and 'BF SINGS' or 'DAD SINGS'
  end

  state.openQueue[#state.openQueue + 1] = {
    beat = beat,
    beats = openBeats,
    side = side,
    power = power,
    move = entry,
    header = header,
    turn = turn
  }
  state.closeQueue[#state.closeQueue + 1] = {
    beat = beat + openBeats,
    beats = closeBeats,
    side = side,
    move = entry
  }

  modCallback(beat, 'w32BlockOpen', 0)
  modCallback(beat + openBeats, 'w32BlockClose', 0)
end

--- Turn the TURNS table into blocks and queue the callbacks for all of them.
--- @return Number of blocks scheduled.
local function scheduleSong()
  for index = 1, #MODIFIERS do
    addModifier(MODIFIERS[index])
  end

  -- Park everything on both sides. This is the only place a percent is written
  -- outside the timeline, and it happens before the first callback fires.
  for index = 1, #PERCENTS do
    local name = PERCENTS[index]
    park(name, DAD)
    park(name, BF)
  end

  local moveIndex = 1
  local blocks = 0
  for turnIndex = 1, #TURNS do
    local turn = TURNS[turnIndex]
    local count = math.max(1, math.floor(turn.beats / 4))
    local blockLen = turn.beats / count

    for part = 0, count - 1 do
      -- The climax is decided per block: one BF turn can start before it and
      -- still run straight through it.
      local beat = turn.beat + part * blockLen
      local climax = beat >= CLIMAX_START_BEAT and beat < CLIMAX_END_BEAT
      local entry = MOVES[((moveIndex - 1) % #MOVES) + 1]
      if not moveAllowed(entry) then
        -- Skip to the next move without breaking the "different every block"
        -- cycle: the cursor still advances by one.
        moveIndex = moveIndex + 1
        entry = MOVES[((moveIndex - 1) % #MOVES) + 1]
      end
      scheduleBlock(beat, blockLen, turn.who, turn.intensity,
        ((moveIndex - 1) % #MOVES) + 1, turnIndex, climax)
      moveIndex = moveIndex + 1
      blocks = blocks + 1
    end
  end

  return blocks
end

--- Timeline hook: a block starts. Opens its move and refreshes the HUD.
--- @param beat Beat the callback fired on.
function w32BlockOpen(beat)
  local entry = state.openQueue[state.openCursor]
  if entry == nil then
    return
  end
  state.openCursor = state.openCursor + 1

  -- Re-park the percents this block drives. A previous block always closes its
  -- moves first, so this only removes float error, but it also makes the block
  -- self-healing if a move was interrupted (e.g. a seek).
  for index = 1, #entry.move.percents do
    park(entry.move.percents[index], entry.side)
  end

  -- Schedule from the block's nominal beat, not from `beat`: the callback
  -- fires on the first frame past the beat, and an ease that started a hair
  -- late would still be running when the close leg begins.
  entry.move.open(entry.side, entry.beat, entry.beats, entry.power)
  showBlock(entry, beat)
end

--- Timeline hook: a block hands over. Sends its move back to neutral.
--- @param beat Beat the callback fired on.
function w32BlockClose(beat)
  local entry = state.closeQueue[state.closeCursor]
  if entry == nil then
    return
  end
  state.closeCursor = state.closeCursor + 1
  -- The close leg starts from whatever the open leg left behind, so a seek or
  -- a dropped frame cannot make the return snap.
  for index = 1, #entry.move.percents do
    closeEase(entry.move.percents[index], entry.beat, entry.beats, entry.side)
  end
end

----------------------------------------------------------------------
-- GDI climax
----------------------------------------------------------------------

--- Probe the native bridge. `gdiInit` is a logged no-op off Windows, so the
--- probe is safe everywhere; the answer decides whether the desktop payloads
--- are really engaged or only announced as simulated.
--- @return True when the native GDI worker is live.
local function gdiProbe()
  if state.probed then
    return state.ready
  end
  state.probed = true
  state.ready = gdiInit() == true and gdiIsInitialized() == true
  if not state.ready then
    log('GDI unavailable on this target: the climax falls back to the camera')
  end
  if state.hudReady then
    setTextString('w32Gdi', state.ready and 'WIN32 GDI: armed' or 'WIN32 GDI: simulated')
    setTextColor('w32Gdi', state.ready and COLOR.accent or COLOR.warn)
  end
  return state.ready
end

--- Register (once) and enable a bundled GDI effect.
--- @param name Effect name: DrawIcons, ScreenBlink, ScreenGlitches, ScreenTunnel,
---   ScreenShake or SetTitleText.
--- @param waitMs Milliseconds between iterations, 0 keeps the driver default.
local function gdiOn(name, waitMs)
  if not state.ready then
    return
  end
  if state.registered[name] == nil then
    state.registered[name] = gdiRegisterEffect(name) == true
  end
  if not state.registered[name] then
    log('could not register GDI effect ' .. name)
    return
  end
  if waitMs and waitMs > 0 then
    gdiSetEffectWait(name, waitMs)
  end
  gdiEnableEffect(name)
  state.active = true
end

--- Fire one of the one-shot GDI payloads.
--- @param name icons | blink | glitch | tunnel | shake
local function gdiOnce(name)
  if not state.ready then
    return
  end
  if name == 'icons' then
    gdiDrawIcons()
  elseif name == 'blink' then
    if state.canFlash then
      gdiScreenBlink()
    end
  elseif name == 'glitch' then
    gdiScreenGlitches()
  elseif name == 'tunnel' then
    gdiScreenTunnel()
  elseif name == 'shake' then
    gdiScreenShake()
  end
end

--- Trigger one of the ported HPPD payloads (see docs/GDI_HPPD.md).
--- @param id Payload ID.
--- @param label Short name for the HUD.
local function hppd(id, label)
  if not state.ready then
    if state.hudReady then
      setTextString('w32Hppd', label .. ' (simulated)')
    end
    return
  end
  -- Heavy payloads serialise on one worker: never stack a second one.
  if gdiHppdIsHeavy(id) then
    for runningId, _ in pairs(state.running) do
      if gdiHppdIsRunning(runningId) then
        if state.hudReady then
          setTextString('w32Hppd', label .. ' queued after #' .. runningId)
        end
        return
      end
    end
  end
  if gdiHppdTrigger(id) == true then
    state.running[id] = true
    if state.hudReady then
      setTextString('w32Hppd', string.format('%s (#%d) painting', label, id))
      setTextColor('w32Hppd', COLOR.hot)
    end
  end
end

--- Stop and unregister every desktop payload this song started.
--- @param silent Skip the HUD update (used while the state is shutting down).
local function gdiStopAll(silent)
  if state.ready then
    gdiHppdStopAll()
    if state.registered.SetTitleText then
      -- Put the original window titles back before the effect goes away.
      gdiSetTitleText('')
    end
    for name, registered in pairs(state.registered) do
      if registered then
        gdiDisableEffect(name)
        gdiUnregisterEffect(name)
      end
    end
    gdiDestroy()
    state.registered = {}
    state.ready = false
    state.probed = false
  end
  state.active = false
  state.running = {}
  if not silent and state.hudReady then
    setTextString('w32Gdi', 'WIN32 GDI: restored')
    setTextColor('w32Gdi', COLOR.accent)
    setTextString('w32Hppd', 'HPPD payloads: stopped')
    setTextColor('w32Hppd', COLOR.dim)
  end
end

--- Climax phase 1: the desktop starts to glitch and window titles change.
--- @param beat Beat the callback fired on.
function w32ClimaxOpen(beat)
  if not state.ready then
    safeShake('camGame', 0.014, 0.45)
    if state.hudReady then
      setTextString('w32Gdi', 'WIN32 GDI: simulated (climax)')
    end
    return
  end
  gdiOn('ScreenGlitches', 55)
  gdiOn('SetTitleText', 400)
  gdiSetEffectTitleText('SetTitleText', 'WIN32MODCHART')
  gdiSetTitleText('WIN32MODCHART')
  gdiOnce('glitch')
end

--- Climax phase 2: error icons chase the cursor, the desktop blinks on the bar.
--- @param beat Beat the callback fired on.
function w32ClimaxIcons(beat)
  gdiOn('DrawIcons', 16)
  if state.canFlash then
    gdiOn('ScreenBlink', 200)
    gdiOnce('blink')
  end
  gdiOnce('icons')
end

--- Climax phase 3: tunnel + shake, then a light HPPD payload that tears the
--- desktop horizontally (payload 12).
--- @param beat Beat the callback fired on.
function w32ClimaxTunnel(beat)
  gdiOn('ScreenTunnel', 40)
  gdiOn('ScreenShake', 30)
  gdiOnce('tunnel')
  hppd(12, 'Horizontal tearing')
end

--- Climax phase 4: a fractured screen (payload 16) plus another glitch sweep.
--- @param beat Beat the callback fired on.
function w32ClimaxBurst(beat)
  hppd(16, 'Fractured screen')
  gdiOnce('glitch')
  safeShake('camGame', 0.016, 0.35)
end

--- Climax phase 5: the first heavy payload of the run, a full-screen plasma.
--- @param beat Beat the callback fired on.
function w32ClimaxPlasma(beat)
  hppd(7, 'Plasma hue')
  safeShake('camGame', 0.02, 0.5)
end

--- Climax phase 6: chromatic plasma (payload 13), the loudest colour pass.
--- @param beat Beat the callback fired on.
function w32ClimaxPeak(beat)
  hppd(13, 'Chromatic plasma')
  safeShake('camGame', 0.022, 0.5)
end

--- Climax phase 7: the biggest payload the API exposes (payload 24).
--- @param beat Beat the callback fired on.
function w32ClimaxCrescendo(beat)
  hppd(24, 'Absolute GDI chaos')
  safeShake('camGame', 0.024, 0.6)
end

--- Climax wind down: the desktop is restored before the last note, so the
--- results screen never sits on a glitching desktop.
--- @param beat Beat the callback fired on.
function w32ClimaxClose(beat)
  gdiStopAll(false)
end

--- Queue the GDI phases and the camera half of the climax.
local function scheduleClimax()
  if state.climaxScheduled then
    return
  end
  state.climaxScheduled = true

  modCallback(CLIMAX_START_BEAT, 'w32ClimaxOpen', 0)
  modCallback(CLIMAX_START_BEAT + 8, 'w32ClimaxIcons', 0)
  modCallback(CLIMAX_START_BEAT + 16, 'w32ClimaxTunnel', 0)
  modCallback(CLIMAX_START_BEAT + 24, 'w32ClimaxBurst', 0)
  modCallback(CLIMAX_START_BEAT + 40, 'w32ClimaxPlasma', 0)
  modCallback(CLIMAX_START_BEAT + 56, 'w32ClimaxPeak', 0)
  modCallback(CLIMAX_START_BEAT + 72, 'w32ClimaxCrescendo', 0)
  modCallback(CLIMAX_START_BEAT + 78, 'w32ClimaxIcons', 0)
  modCallback(CLIMAX_END_BEAT - 8, 'w32ClimaxClose', 0)

  -- Camera half, which reads on every platform: a slow push in on the field,
  -- two rocks, then home. Each of these percents is touched by exactly one
  -- ease at a time, so they can be queued up front.
  openEase('zoom', CLIMAX_START_BEAT, 8, 0.12, 'quadOut', BF)
  closeEase('zoom', CLIMAX_START_BEAT + 8, 6, BF)
  openEase('centerRotateZ', CLIMAX_START_BEAT + 32, 12, 5, 'sineInOut', BF)
  closeEase('centerRotateZ', CLIMAX_START_BEAT + 44, 8, BF)
  openEase('centerRotateZ', CLIMAX_START_BEAT + 64, 8, -4, 'sineInOut', BF)
  closeEase('centerRotateZ', CLIMAX_START_BEAT + 72, 8, BF)
end

----------------------------------------------------------------------
-- Engine hooks
----------------------------------------------------------------------

function onCreatePost()
  state.canFlash = pref('flashing', true) == true
  state.reducedMotion = pref('reducedMotion', false) == true

  buildHud()
  gdiProbe()
  local blocks = scheduleSong()
  scheduleClimax()

  setHealthBarColors(COLOR.accent, COLOR.soft)
  setTimeBarColors(COLOR.accent, COLOR.soft)

  log('ready: ' .. blocks .. ' blocks over ' .. #TURNS .. ' turns, climax '
    .. CLIMAX_START_BEAT .. '-' .. CLIMAX_END_BEAT)
end

function onBeatHit()
  if curBeat < CLIMAX_START_BEAT then
    return
  end
  if curBeat == CLIMAX_START_BEAT then
    safeShake('camGame', 0.02, 0.5)
    return
  end
  if curBeat % 4 == 0 and curBeat < CLIMAX_END_BEAT - 8 then
    -- A light HUD jitter on the bar: reads as "the desktop is leaking in"
    -- without ever moving the arrows.
    safeShake('camHUD', 0.005, 0.1)
  end
end

function onUpdatePost(elapsed)
  if not state.ready then
    return
  end
  -- Payloads finish by themselves; keep the read-out honest.
  local alive = false
  for id, _ in pairs(state.running) do
    if gdiHppdIsRunning(id) then
      alive = true
    else
      state.running[id] = nil
    end
  end
  if not alive and state.active and state.hudReady then
    if getProperty('w32Hppd.text') ~= 'HPPD payloads: idle' then
      setTextString('w32Hppd', 'HPPD payloads: idle')
      setTextColor('w32Hppd', COLOR.dim)
    end
  end
end

--- Pausing must not leave a desktop payload painting behind the pause menu.
function onPause()
  if state.ready then
    gdiSetPaused(true)
  end
end

function onResume()
  if state.ready then
    gdiSetPaused(false)
  end
end

function onGameOver()
  gdiStopAll(false)
end

function onEndSong()
  gdiStopAll(false)
end

--- Last hook of the state's life (`destroy()` calls the script's onDestroy
--- after `PlayStateModchart.reset()` has already cleared the timeline).
function onDestroy()
  if state.teardownDone then
    return
  end
  state.teardownDone = true
  gdiStopAll(true)
  resetModchart()
end
