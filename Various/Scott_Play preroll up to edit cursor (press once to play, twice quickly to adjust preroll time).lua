-- @description Play preroll up to edit cursor (press once to play, twice quickly to adjust preroll time)
-- @version 1.0
-- @author Scott Chesworth
-- @about
--   Plays a configurable amount of audio up to the edit cursor, stopping when the playhead reaches edit cursor.
--   
--   Bind a keystroke to this script. Press it once to play, press twice quickly to set the preroll time.
-- @metapackage
-- @provides
--   [main] Scott_Play preroll up to edit cursor (press once to play, twice quickly to adjust preroll time).lua
--   Scott_Play preroll up to edit cursor helper.lua
-- @changelog
--   Initial release.

local DEFAULT_PREROLL_SECONDS = 2.0
local EXT_SECTION = "SC_PlayPrerollToEditCursor"
local EXT_KEY_PREROLL = "preroll_seconds"
local EXT_KEY_PENDING_TOKEN = "pending_token"
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
local DOUBLE_PRESS_SECONDS = 0.5
local HELPER_SCRIPT_NAME = "Scott_Play preroll up to edit cursor helper.lua"
local TOGGLE_STOP_PLAYBACK_AT_END_OF_LOOP = 41834
local TOGGLE_LOOP_POINTS_LINKED_TO_TIME_SELECTION = 40621
local OSARA_MUTE_NEXT_MESSAGE = reaper.NamedCommandLookup("_OSARA_MUTENEXTMESSAGE")

local function speak(message)
  if reaper.osara_outputMessage then
    reaper.osara_outputMessage(message)
  end
end

local function mute_next_osara_message()
  if OSARA_MUTE_NEXT_MESSAGE and OSARA_MUTE_NEXT_MESSAGE ~= 0 then
    reaper.Main_OnCommand(OSARA_MUTE_NEXT_MESSAGE, 0)
  end
end

local function read_number_setting(key, default_value)
  local value = tonumber(reaper.GetExtState(EXT_SECTION, key))

  if value and value >= 0 then
    return value
  end

  return default_value
end

local function save_settings(preroll_seconds)
  reaper.SetExtState(EXT_SECTION, EXT_KEY_PREROLL, tostring(preroll_seconds), true)
end

local function get_settings()
  return read_number_setting(EXT_KEY_PREROLL, DEFAULT_PREROLL_SECONDS)
end

local function configure_settings()
  local preroll_seconds = get_settings()
  local ok, value = reaper.GetUserInputs(
    "Play preroll up to edit cursor",
    1,
    "Preroll seconds",
    tostring(preroll_seconds)
  )

  if not ok then
    return
  end

  local new_preroll = tonumber(value:match("^%s*(.-)%s*$"))

  if not new_preroll or new_preroll < 0 then
    speak("time must be zero or greater")
    return
  end

  save_settings(new_preroll)
  speak("preroll time saved")
end

local function get_script_directory()
  local _, script_path = reaper.get_action_context()

  if not script_path then
    return nil
  end

  return script_path:match("^(.*)[/\\]")
end

local function launch_helper()
  local script_directory = get_script_directory()

  if not script_directory then
    speak("could not find helper script")
    return
  end

  local helper_path = script_directory .. "\\" .. HELPER_SCRIPT_NAME
  local helper_command_id = reaper.AddRemoveReaScript(true, 0, helper_path, true)

  if not helper_command_id or helper_command_id == 0 then
    speak("could not launch helper script")
    return
  end

  reaper.Main_OnCommand(helper_command_id, 0)
end

local function set_toggle_command(command_id, enabled)
  local state = reaper.GetToggleCommandState(command_id)

  if state == -1 then
    return false
  end

  local target_state = enabled and 1 or 0

  if state ~= target_state then
    mute_next_osara_message()
    reaper.Main_OnCommand(command_id, 0)
  end

  return true
end

local function save_ext_number(key, value)
  reaper.SetExtState(EXT_SECTION, key, tostring(value), false)
end

local function save_preview_state(state)
  reaper.SetExtState(EXT_SECTION, EXT_KEY_ACTIVE_TOKEN, state.active_token, false)
  save_ext_number(EXT_KEY_ORIGINAL_CURSOR, state.cursor_position)
  save_ext_number(EXT_KEY_PLAYBACK_STOP, state.cursor_position)
  save_ext_number(EXT_KEY_ORIGINAL_TIME_SELECTION_START, state.time_selection_start)
  save_ext_number(EXT_KEY_ORIGINAL_TIME_SELECTION_END, state.time_selection_end)
  save_ext_number(EXT_KEY_ORIGINAL_LOOP_START, state.loop_start)
  save_ext_number(EXT_KEY_ORIGINAL_LOOP_END, state.loop_end)
  save_ext_number(EXT_KEY_ORIGINAL_REPEAT, state.repeat_state)
  save_ext_number(EXT_KEY_ORIGINAL_STOP_LOOP_STATE, state.stop_loop_state)
  save_ext_number(EXT_KEY_ORIGINAL_LINK_LOOP_TIME_STATE, state.link_loop_time_state)
end

local function play_to_edit_cursor()
  local preroll_seconds = get_settings()
  local cursor_position = reaper.GetCursorPosition()

  if cursor_position <= 0 then
    speak("edit cursor is at project start")
    return
  end

  local playback_start = math.max(0, cursor_position - preroll_seconds)
  local time_selection_start, time_selection_end =
    reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  local loop_start, loop_end =
    reaper.GetSet_LoopTimeRange(false, true, 0, 0, false)
  local state = {
    active_token = tostring(reaper.time_precise()),
    cursor_position = cursor_position,
    time_selection_start = time_selection_start,
    time_selection_end = time_selection_end,
    loop_start = loop_start,
    loop_end = loop_end,
    repeat_state = reaper.GetSetRepeat(-1),
    stop_loop_state = reaper.GetToggleCommandState(TOGGLE_STOP_PLAYBACK_AT_END_OF_LOOP),
    link_loop_time_state = reaper.GetToggleCommandState(TOGGLE_LOOP_POINTS_LINKED_TO_TIME_SELECTION),
  }

  if not set_toggle_command(TOGGLE_LOOP_POINTS_LINKED_TO_TIME_SELECTION, false) then
    speak("could not unlink loop points from time selection")
    return
  end

  if not set_toggle_command(TOGGLE_STOP_PLAYBACK_AT_END_OF_LOOP, true) then
    set_toggle_command(TOGGLE_LOOP_POINTS_LINKED_TO_TIME_SELECTION, state.link_loop_time_state == 1)
    speak("could not enable stop playback at end of loop")
    return
  end

  save_preview_state(state)
  reaper.GetSetRepeat(0)

  reaper.PreventUIRefresh(1)
  reaper.GetSet_LoopTimeRange(true, true, playback_start, cursor_position, false)
  reaper.SetEditCurPos(playback_start, false, false)
  reaper.OnPlayButton()
  reaper.SetEditCurPos(cursor_position, false, false)
  reaper.PreventUIRefresh(-1)

  launch_helper()
end

local pending_token = reaper.GetExtState(EXT_SECTION, EXT_KEY_PENDING_TOKEN)
local pending_time = tonumber(pending_token)

if pending_time and reaper.time_precise() - pending_time <= DOUBLE_PRESS_SECONDS then
  reaper.DeleteExtState(EXT_SECTION, EXT_KEY_PENDING_TOKEN, false)
  reaper.OnStopButton()
  configure_settings()
  return
end

local current_token = tostring(reaper.time_precise())
reaper.SetExtState(EXT_SECTION, EXT_KEY_PENDING_TOKEN, current_token, false)

play_to_edit_cursor()
