-- @description Preview skipping time selection, Sound Forge style (press once to preview, twice quickly to adjust pre and post roll times)
-- @version 1.1
-- @author Scott Chesworth
-- @about
--   Previews the edit around the current time selection by playing a configurable
--   pre-roll, skipping the time selection with REAPER's native skip action, then
--   playing configurable post-roll.
--   
--   Pre and post rolls are 2 seconds by default, the same as Sound Forge.
--   
--   Bind this script to a keystroke. Press it once to preview immediately. Press it twice
--   if you want to adjust the pre-roll and post-roll times.
--   
--   Requires the included helper script:
--   "Scott_Preview skipping time selection helper.lua".
-- @metapackage
-- @provides
--   [main] Scott_Preview skipping time selection Sound Forge style (press once to preview, twice quickly to adjust pre and post roll times).lua
--   Scott_Preview skipping time selection helper.lua
-- @changelog
--   Added configurable preroll/postroll times, respect REAPER's behaviour on pause.


local DEFAULT_PREROLL_SECONDS = 2.0
local DEFAULT_POSTROLL_SECONDS = 2.0
local PLAY_SKIP_TIME_SELECTION = 40317
local EXT_SECTION = "SC_PreviewSkippingTimeSelection"
local EXT_KEY_PREROLL = "preroll_seconds"
local EXT_KEY_POSTROLL = "postroll_seconds"
local EXT_KEY_PENDING_TOKEN = "pending_token"
local EXT_KEY_ACTIVE_TOKEN = "active_token"
local EXT_KEY_ORIGINAL_CURSOR = "original_cursor"
local EXT_KEY_PLAYBACK_STOP = "playback_stop"
local DOUBLE_PRESS_SECONDS = 0.5
local HELPER_SCRIPT_NAME = "Scott_Preview skipping time selection helper.lua"

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
    "Preview skipping time selection",
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
  local selection_start, selection_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)

  if selection_end <= selection_start then
    speak("no time selection")
    return
  end

  local original_cursor_position = reaper.GetCursorPosition()
  local playback_start = math.max(0, selection_start - preroll_seconds)
  local playback_stop = selection_end + postroll_seconds
  local active_token = tostring(reaper.time_precise())
  local helper_is_running = reaper.GetExtState(EXT_SECTION, EXT_KEY_ACTIVE_TOKEN) ~= ""

  reaper.SetExtState(EXT_SECTION, EXT_KEY_ACTIVE_TOKEN, active_token, false)
  reaper.SetExtState(EXT_SECTION, EXT_KEY_ORIGINAL_CURSOR, tostring(original_cursor_position), false)
  reaper.SetExtState(EXT_SECTION, EXT_KEY_PLAYBACK_STOP, tostring(playback_stop), false)

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
