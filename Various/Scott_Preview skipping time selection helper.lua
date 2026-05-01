-- @description Internal helper for preview skipping time selection
-- @version 1.1
-- @author Scott Chesworth
-- @noindex
-- @about
--   This script is not intended to be run directly.
--   It's a helper launched by the user-facing preview skipping time selection
--   script. It monitors playback in the background, stops at the configured
--   postroll point, and restores the edit cursor according to stop or pause
--   behavior.
-- @changelog
--   Initial internal helper release.

local EXT_SECTION = "SC_PreviewSkippingTimeSelection"
local EXT_KEY_ACTIVE_TOKEN = "active_token"
local EXT_KEY_ORIGINAL_CURSOR = "original_cursor"
local EXT_KEY_PLAYBACK_STOP = "playback_stop"

local function get_preview_state()
  local active_token = reaper.GetExtState(EXT_SECTION, EXT_KEY_ACTIVE_TOKEN)

  if active_token == "" then
    return nil
  end

  local original_cursor_position = tonumber(reaper.GetExtState(EXT_SECTION, EXT_KEY_ORIGINAL_CURSOR))
  local playback_stop = tonumber(reaper.GetExtState(EXT_SECTION, EXT_KEY_PLAYBACK_STOP))

  if not original_cursor_position or not playback_stop then
    return nil
  end

  return {
    active_token = active_token,
    original_cursor_position = original_cursor_position,
    playback_stop = playback_stop,
  }
end

local function clear_active_preview(active_token)
  if reaper.GetExtState(EXT_SECTION, EXT_KEY_ACTIVE_TOKEN) == active_token then
    reaper.DeleteExtState(EXT_SECTION, EXT_KEY_ACTIVE_TOKEN, false)
  end
end

local function stop_and_restore_cursor(state)
  reaper.OnStopButton()
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
    reaper.SetEditCurPos(reaper.GetPlayPosition(), true, false)
    clear_active_preview(state.active_token)
    return
  end

  if play_state & 1 ~= 1 then
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
