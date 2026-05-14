-- @description Internal helper for playing preroll up to edit cursor
-- @version 1.0
-- @author Scott Chesworth
-- @noindex
-- @about
--   This script is not intended to be run directly.
--   It's a helper launched by the user-facing play preroll up to edit cursor
--   script. It monitors playback in the background and restores temporary
--   transport state after REAPER stops at the original edit cursor position.
--   It also handles cleanup if playback is paused or stopped manually.
-- @changelog
--   Initial internal helper release.

local EXT_SECTION = "SC_PlayPrerollToEditCursor"
local EXT_KEY_ACTIVE_TOKEN = "active_token"
local EXT_KEY_ORIGINAL_CURSOR = "original_cursor"
local EXT_KEY_PLAYBACK_STOP = "playback_stop"
local EXT_KEY_ORIGINAL_TIME_SELECTION_START = "original_time_selection_start"
local EXT_KEY_ORIGINAL_TIME_SELECTION_END = "original_time_selection_end"
local EXT_KEY_ORIGINAL_LOOP_START = "original_loop_start"
local EXT_KEY_ORIGINAL_LOOP_END = "original_loop_end"
local EXT_KEY_ORIGINAL_REPEAT = "original_repeat"
local EXT_KEY_ORIGINAL_STOP_LOOP_STATE = "original_stop_loop_state"
local EXT_KEY_ORIGINAL_LINK_LOOP_TIME_STATE = "original_link_loop_time_state"
local TOGGLE_STOP_PLAYBACK_AT_END_OF_LOOP = 41834
local TOGGLE_LOOP_POINTS_LINKED_TO_TIME_SELECTION = 40621
local OSARA_MUTE_NEXT_MESSAGE = reaper.NamedCommandLookup("_OSARA_MUTENEXTMESSAGE")

local function mute_next_osara_message()
  if OSARA_MUTE_NEXT_MESSAGE and OSARA_MUTE_NEXT_MESSAGE ~= 0 then
    reaper.Main_OnCommand(OSARA_MUTE_NEXT_MESSAGE, 0)
  end
end

local function read_number_state(key)
  return tonumber(reaper.GetExtState(EXT_SECTION, key))
end

local function get_preview_state()
  local active_token = reaper.GetExtState(EXT_SECTION, EXT_KEY_ACTIVE_TOKEN)

  if active_token == "" then
    return nil
  end

  local original_cursor_position = read_number_state(EXT_KEY_ORIGINAL_CURSOR)
  local playback_stop = read_number_state(EXT_KEY_PLAYBACK_STOP)
  local original_time_selection_start = read_number_state(EXT_KEY_ORIGINAL_TIME_SELECTION_START)
  local original_time_selection_end = read_number_state(EXT_KEY_ORIGINAL_TIME_SELECTION_END)
  local original_loop_start = read_number_state(EXT_KEY_ORIGINAL_LOOP_START)
  local original_loop_end = read_number_state(EXT_KEY_ORIGINAL_LOOP_END)
  local original_repeat = read_number_state(EXT_KEY_ORIGINAL_REPEAT)
  local original_stop_loop_state = read_number_state(EXT_KEY_ORIGINAL_STOP_LOOP_STATE)
  local original_link_loop_time_state = read_number_state(EXT_KEY_ORIGINAL_LINK_LOOP_TIME_STATE)

  if not original_cursor_position
    or not playback_stop
    or not original_time_selection_start
    or not original_time_selection_end
    or not original_loop_start
    or not original_loop_end
    or original_repeat == nil
    or original_stop_loop_state == nil
    or original_link_loop_time_state == nil then
    return nil
  end

  return {
    active_token = active_token,
    original_cursor_position = original_cursor_position,
    playback_stop = playback_stop,
    original_time_selection_start = original_time_selection_start,
    original_time_selection_end = original_time_selection_end,
    original_loop_start = original_loop_start,
    original_loop_end = original_loop_end,
    original_repeat = original_repeat,
    original_stop_loop_state = original_stop_loop_state,
    original_link_loop_time_state = original_link_loop_time_state,
  }
end

local function set_toggle_command(command_id, enabled)
  local state = reaper.GetToggleCommandState(command_id)

  if state == -1 then
    return
  end

  local target_state = enabled and 1 or 0

  if state ~= target_state then
    mute_next_osara_message()
    reaper.Main_OnCommand(command_id, 0)
  end
end

local function restore_transport_options(state)
  set_toggle_command(TOGGLE_LOOP_POINTS_LINKED_TO_TIME_SELECTION, false)
  reaper.GetSet_LoopTimeRange(true, true, state.original_loop_start, state.original_loop_end, false)
  reaper.GetSet_LoopTimeRange(
    true,
    false,
    state.original_time_selection_start,
    state.original_time_selection_end,
    false
  )
  reaper.GetSetRepeat(state.original_repeat)
  set_toggle_command(TOGGLE_STOP_PLAYBACK_AT_END_OF_LOOP, state.original_stop_loop_state == 1)
  set_toggle_command(
    TOGGLE_LOOP_POINTS_LINKED_TO_TIME_SELECTION,
    state.original_link_loop_time_state == 1
  )
end

local function clear_active_preview(active_token)
  if reaper.GetExtState(EXT_SECTION, EXT_KEY_ACTIVE_TOKEN) == active_token then
    reaper.DeleteExtState(EXT_SECTION, EXT_KEY_ACTIVE_TOKEN, false)
  end
end

local function finish_preview(state, cursor_position)
  restore_transport_options(state)
  reaper.SetEditCurPos(cursor_position, true, false)
  clear_active_preview(state.active_token)
end

local function stop_and_restore_cursor(state)
  reaper.OnStopButton()
  finish_preview(state, state.original_cursor_position)
end

local function stop_at_edit_cursor()
  local state = get_preview_state()

  if not state then
    return
  end

  local play_state = reaper.GetPlayState()

  if play_state & 2 == 2 then
    finish_preview(state, reaper.GetPlayPosition())
    return
  end

  if play_state & 1 ~= 1 then
    finish_preview(state, state.original_cursor_position)
    return
  end

  if reaper.GetPlayPosition() >= state.playback_stop then
    stop_and_restore_cursor(state)
    return
  end

  reaper.defer(stop_at_edit_cursor)
end

reaper.defer(stop_at_edit_cursor)
