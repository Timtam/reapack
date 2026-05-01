-- @description Preview skipping selected items, Sound Forge style (press once to preview, twice quickly to adjust pre and post roll times)
-- @version 1.0
-- @author Scott Chesworth
-- @about
--   Previews the edit around selected media items by playing configurable
--   preroll, temporarily using the selected item bounds as REAPER's time
--   selection, skipping that range with REAPER's native skip action, then
--   playing configurable postroll.
--   
--   Bind a keystroke to this script. Press it once to preview immediately. Press it twice
--   if you want to set the preroll and postroll times.
--   
--   When multiple items are selected, the skipped range spans from the earliest
--   selected item start to the latest selected item end.
--   
--   Requires the included helper script:
--   "Scott_Preview skipping selected items helper.lua".
-- @metapackage
-- @provides
--   [main] Scott_Preview skipping selected items Sound Forge style (press once to preview, twice quickly to adjust pre and post roll times).lua
--   Scott_Preview skipping selected items helper.lua
-- @changelog
--   Initial release.

local DEFAULT_PREROLL_SECONDS = 2.0
local DEFAULT_POSTROLL_SECONDS = 2.0
local PLAY_SKIP_TIME_SELECTION = 40317
local EXT_SECTION = "SC_PreviewSkippingSelectedItems"
local EXT_KEY_PREROLL = "preroll_seconds"
local EXT_KEY_POSTROLL = "postroll_seconds"
local EXT_KEY_PENDING_TOKEN = "pending_token"
local EXT_KEY_ACTIVE_TOKEN = "active_token"
local EXT_KEY_ORIGINAL_CURSOR = "original_cursor"
local EXT_KEY_ORIGINAL_TIME_SELECTION_START = "original_time_selection_start"
local EXT_KEY_ORIGINAL_TIME_SELECTION_END = "original_time_selection_end"
local EXT_KEY_PLAYBACK_STOP = "playback_stop"
local DOUBLE_PRESS_SECONDS = 0.5
local HELPER_SCRIPT_NAME = "Scott_Preview skipping selected items helper.lua"

local function speak(message)
  if reaper.osara_outputMessage then
    reaper.osara_outputMessage(message)
  end
end

local function read_number_setting(key, default_value)
  local value = tonumber(reaper.GetExtState(EXT_SECTION, key))

  if value and value >= 0 then
    return value
  end

  return default_value
end

local function save_settings(preroll_seconds, postroll_seconds)
  reaper.SetExtState(EXT_SECTION, EXT_KEY_PREROLL, tostring(preroll_seconds), true)
  reaper.SetExtState(EXT_SECTION, EXT_KEY_POSTROLL, tostring(postroll_seconds), true)
end

local function get_settings()
  return read_number_setting(EXT_KEY_PREROLL, DEFAULT_PREROLL_SECONDS),
    read_number_setting(EXT_KEY_POSTROLL, DEFAULT_POSTROLL_SECONDS)
end

local function configure_settings()
  local preroll_seconds, postroll_seconds = get_settings()
  local ok, values = reaper.GetUserInputs(
    "Preview skipping selected items",
    2,
    "Preroll seconds,Postroll seconds",
    tostring(preroll_seconds) .. "," .. tostring(postroll_seconds)
  )

  if not ok then
    return
  end

  local new_preroll, new_postroll = values:match("^%s*([^,]*)%s*,%s*([^,]*)%s*$")
  new_preroll = tonumber(new_preroll)
  new_postroll = tonumber(new_postroll)

  if not new_preroll or not new_postroll or new_preroll < 0 or new_postroll < 0 then
    speak("times must be zero or greater")
    return
  end

  save_settings(new_preroll, new_postroll)
  speak("preview times saved")
end

local function get_selected_item_bounds()
  local selected_item_count = reaper.CountSelectedMediaItems(0)

  if selected_item_count == 0 then
    return nil
  end

  local selection_start = math.huge
  local selection_end = 0

  for i = 0, selected_item_count - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local item_end = item_start + item_length

    selection_start = math.min(selection_start, item_start)
    selection_end = math.max(selection_end, item_end)
  end

  return selection_start, selection_end
end

local function get_script_directory()
  local _, _, _, _, _, _, script_path = reaper.get_action_context()
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

local function preview()
  local preroll_seconds, postroll_seconds = get_settings()
  local selection_start, selection_end = get_selected_item_bounds()

  if not selection_start or selection_end <= selection_start then
    speak("no selected items")
    return
  end

  local original_cursor_position = reaper.GetCursorPosition()
  local original_time_selection_start, original_time_selection_end =
    reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  local playback_start = math.max(0, selection_start - preroll_seconds)
  local playback_stop = selection_end + postroll_seconds
  local active_token = tostring(reaper.time_precise())
  local helper_is_running = reaper.GetExtState(EXT_SECTION, EXT_KEY_ACTIVE_TOKEN) ~= ""

  reaper.SetExtState(EXT_SECTION, EXT_KEY_ACTIVE_TOKEN, active_token, false)
  reaper.SetExtState(EXT_SECTION, EXT_KEY_ORIGINAL_CURSOR, tostring(original_cursor_position), false)
  reaper.SetExtState(
    EXT_SECTION,
    EXT_KEY_ORIGINAL_TIME_SELECTION_START,
    tostring(original_time_selection_start),
    false
  )
  reaper.SetExtState(
    EXT_SECTION,
    EXT_KEY_ORIGINAL_TIME_SELECTION_END,
    tostring(original_time_selection_end),
    false
  )
  reaper.SetExtState(EXT_SECTION, EXT_KEY_PLAYBACK_STOP, tostring(playback_stop), false)

  reaper.GetSet_LoopTimeRange(true, false, selection_start, selection_end, false)
  reaper.SetEditCurPos(playback_start, true, false)
  reaper.Main_OnCommand(PLAY_SKIP_TIME_SELECTION, 0)

  if not helper_is_running then
    launch_helper()
  end
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

preview()
