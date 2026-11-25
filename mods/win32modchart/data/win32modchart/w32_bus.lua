--[[
  w32_bus.lua : the turn counter
  =============================

  A small read-out in the top-left corner that says which hand-over the song is
  in, who owns it, and whether the GDI climax has started:

      TURN 07/20   YOU        (green)
      TURN 12/20   OPPONENT   (blue)
      TURN 18/20   CLIMAX     (orange)

  Why this is its own file
  ------------------------
  The per-turn modchart (`win32modchart-erect.lua`) already draws the move name
  and the GDI status. Those are about *what the playfield is doing*; this is
  about *where the song is*, and it stays readable when the modchart is off
  (`modchart` false) -- which is exactly when a player testing the chart wants
  the turn number most.

  Where the numbers come from
  ---------------------------
  Every script gets `curSection`, `mustHitSection` and `curBeat` pushed into it
  by the engine (`PlayState.hx` / `MusicBeatState.hx`), refreshed immediately
  before `onSectionHit` and `onBeatHit`. So this file parses nothing, reads no
  other script, and cannot go stale: `Turn counter, from the chart's own
  hand-overs` in the validator re-derives the 20 turns from the JSON and fails if
  this table drifts.

  Nothing to tear down: one text object, removed on destroy.
]]

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------

-- Hand-overs in beats, straight from the chart.
local TURN_BEATS = {
  0, 8, 16, 24, 32, 48, 64, 80, 128, 156, 192, 200, 208, 216, 224, 240,
  384, 392, 400, 408
}

local TOTAL_TURNS = #TURN_BEATS
local CLIMAX_BEAT = 336

local COLOR = {
  bf = 'c8ff7a',       -- the player's turns
  dad = '9ad1ff',      -- the opponent's turns
  climax = 'ffb35c',   -- the GDI climax
  idle = 'b9c2cc'
}

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------

local state = {
  built = false,
  turn = 1,
  side = 'dad',
  climax = false,
  lastLabel = ''
}

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

--- Debug line with the script prefix.
--- @param message Text to print.
local function log(message)
  debugPrint('[w32_bus] ' .. message)
end

--- 1-based index of the turn containing `beat`.
--- @param beat Song beat.
--- @return Turn index, clamped to the table.
local function turnAt(beat)
  local found = 1
  for index = 1, TOTAL_TURNS do
    if beat >= TURN_BEATS[index] then
      found = index
    end
  end
  return found
end

--- Redraw the read-out, but only when something actually changed.
local function refresh()
  if not state.built then
    return
  end

  local label
  if state.climax then
    label = string.format('TURN %02d/%d   CLIMAX', state.turn, TOTAL_TURNS)
    setTextColor('w32Turn', COLOR.climax)
  else
    local who = state.side == 'bf' and 'YOU' or 'OPPONENT'
    label = string.format('TURN %02d/%d   %s', state.turn, TOTAL_TURNS, who)
    setTextColor('w32Turn', state.side == 'bf' and COLOR.bf or COLOR.dad)
  end

  if label == state.lastLabel then
    return
  end
  state.lastLabel = label
  setTextString('w32Turn', label)
end

----------------------------------------------------------------------
-- Hooks
----------------------------------------------------------------------

function onCreatePost()
  -- Sits under the modchart's own three lines (title at y=74, side y=104, move
  -- y=128) and clear of the time bar (y 19..59) and the health bar.
  makeLuaText('w32Turn', 'TURN 01/20   OPPONENT', 420, 20, 152)
  setTextSize('w32Turn', 17)
  setTextColor('w32Turn', COLOR.dad)
  setTextAlignment('w32Turn', 'left')
  setObjectCamera('w32Turn', 'hud')
  setScrollFactor('w32Turn', 0, 0)
  addLuaText('w32Turn')

  state.built = true
  state.turn = 1
  state.side = mustHitSection and 'bf' or 'dad'
  state.climax = false
  state.lastLabel = ''
  refresh()
  log('turn counter up (' .. TOTAL_TURNS .. ' turns in the chart)')
end

function onSectionHit()
  if not state.built or curSection == nil then
    return
  end

  local beat = curSection * 4
  state.turn = turnAt(beat)
  state.side = mustHitSection and 'bf' or 'dad'
  state.climax = beat >= CLIMAX_BEAT
  refresh()
end

function onPause()
  -- The label is a static string; nothing to suspend. Hide it so the pause
  -- screen is not stamped with a turn number.
  if state.built then
    setProperty('w32Turn.alpha', 0)
  end
end

function onResume()
  if state.built then
    setProperty('w32Turn.alpha', 1)
    refresh()
  end
end

function onDestroy()
  if not state.built then
    return
  end
  removeLuaText('w32Turn', true)
  state.built = false
  log('turn counter down')
end
