-- @description Internal helper for preview skipping selected items
-- @version 1.0
-- @author Scott Chesworth
-- @noindex
-- @about
--   This script is not intended to be run directly.
--   It's a helper launched by the user-facing preview skipping selected items
--   script. It monitors playback in the background, stops at the configured
--   postroll point, restores the temporary time selection, and restores the edit
--   cursor according to stop or pause behavior. 
-- @changelog
--   Initial internal helper release.

local EXT_SECTION = "SC_PreviewSkippingSelectedItems"
local EXT_KEY_ACTIVE_TOKEN = "active_token"
local EXT_KEY_ORIGINAL_CURSOR = "original_cursor"
local EXT_KEY_ORIGINAL_TIME_SELECTION_START = "original_time_selection_start"
local EXT_KEY_ORIGINAL_TIME_SELECTION_END = "original_time_selection_end"
local EXT_KEY_PLAYBACK_STOP = "playback_stop"

local function get_preview_state()
  local active_token = reaper.GetExtState(EXT_SECTION, EXT_KEY_ACTIVE_TOKEN)

  if active_token == "" then
    return nil
  end

  local original_cursor_position = tonumber(reaper.GetExtState(EXT_SECTION, EXT_KEY_ORIGINAL_CURSOR))
  local original_time_selection_start =
    tonumber(reaper.GetExtState(EXT_SECTION, EXT_KEY_ORIGINAL_TIME_SELECTION_START))
  local original_time_selection_end =
    tonumber(reaper.GetExtState(EXT_SECTION, EXT_KEY_ORIGINAL_TIME_SELECTION_END))
  local playback_stop = tonumber(reaper.GetExtState(EXT_SECTION, EXT_KEY_PLAYBACK_STOP))

  if not original_cursor_position
    or not original_time_selection_start
    or not original_time_selection_end
    or not playback_stop then
    return nil
  end

  return {
    active_token = active_token,
    original_cursor_position = original_cursor_position,
    original_time_selection_start = original_time_selection_start,
    original_time_selection_end = original_time_selection_end,
    playback_stop = playback_stop,
  }
end

local function restore_time_selection(state)
  reaper.GetSet_LoopTimeRange(
    true,
    false,
    state.original_time_selection_start,
    state.original_time_selection_end,
    false
  )
end

local function clear_active_preview(active_token)
  if reaper.GetExtState(EXT_SECTION, EXT_KEY_ACTIVE_TOKEN) == active_token then
    reaper.DeleteExtState(EXT_SECTION, EXT_KEY_ACTIVE_TOKEN, false)
  end
end

local function stop_and_restore_cursor(state)
  reaper.OnStopButton()
  restore_time_selection(state)
  reaper.SetEditCurPos(state.original_cursor_position, true, false)
  clear_active_preview(state.active_token)
end

local function stop_at_postroll()
  local state = get_preview_state()

  if not state then
    return
  end

  local play_state = reaper.GetPlayState()

  if play_state & 2 == 2 then
    restore_time_selection(state)
    reaper.SetEditCurPos(reaper.GetPlayPosition(), true, false)
    clear_active_preview(state.active_token)
    return
  end

  if play_state & 1 ~= 1 then
    restore_time_selection(state)
    reaper.SetEditCurPos(state.original_cursor_position, true, false)
    clear_active_preview(state.active_token)
    return
  end

  if reaper.GetPlayPosition() >= state.playback_stop then
    stop_and_restore_cursor(state)
    return
  end

  reaper.defer(stop_at_postroll)
end

reaper.defer(stop_at_postroll)
