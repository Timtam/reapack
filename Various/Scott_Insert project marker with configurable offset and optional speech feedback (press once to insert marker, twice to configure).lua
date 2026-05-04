-- @description Insert project marker with configurable offset and optional speech feedback (press once to insert marker, twice to configure)
-- @version 1.0
-- @author Scott Chesworth
-- @about
--   Bind this script to a keystroke. Press once to insert a marker. Press twice
--   within 0.5 seconds to configure the offset in seconds.
--
--   Positive offsets insert after the play cursor. Negative offsets insert before
--   the play cursor. For example, -5 inserts the marker 5 seconds earlier.
-- @changelog
--   Initial release.

local DEFAULT_OFFSET_SECONDS = 0
local DOUBLE_PRESS_SECONDS = 0.5
local EXT_SECTION = "SC_InsertMarkerWithOffset"
local EXT_KEY_OFFSET = "offset_seconds"
local EXT_KEY_SPEECH_FEEDBACK = "speech_feedback"
local EXT_KEY_LAST_INVOKE = "last_invoke"
local EXT_KEY_LAST_MARKER_INDEX = "last_marker_index"
local EXT_KEY_LAST_MARKER_POSITION = "last_marker_position"
local EXT_KEY_LAST_MARKER_TIME = "last_marker_time"

local function speech_feedback_enabled()
  return reaper.GetExtState(EXT_SECTION, EXT_KEY_SPEECH_FEEDBACK):lower() ~= "n"
end

local function speak(message)
  if speech_feedback_enabled() and reaper.osara_outputMessage then
    reaper.osara_outputMessage(message)
  end
end

local function speak_if_enabled(enabled, message)
  if enabled and reaper.osara_outputMessage then
    reaper.osara_outputMessage(message)
  end
end

local function get_offset()
  local offset = tonumber(reaper.GetExtState(EXT_SECTION, EXT_KEY_OFFSET))

  if offset then
    return offset
  end

  return DEFAULT_OFFSET_SECONDS
end

local function save_offset(offset)
  reaper.SetExtState(EXT_SECTION, EXT_KEY_OFFSET, tostring(offset), true)
end

local function save_speech_feedback(enabled)
  reaper.SetExtState(EXT_SECTION, EXT_KEY_SPEECH_FEEDBACK, enabled and "y" or "n", true)
end

local function format_seconds(seconds)
  return string.format("%.6f", seconds):gsub("0+$", ""):gsub("%.$", "")
end

local function format_offset_direction(offset)
  if offset == 0 then
    return "at cursor"
  elseif offset < 0 then
    return format_seconds(math.abs(offset)) .. " secs behind"
  end

  return format_seconds(offset) .. " secs ahead"
end

local function format_speech_feedback(enabled)
  return enabled and "speech on" or "speech off"
end

local function configure_settings()
  local current_offset = get_offset()
  local current_speech_feedback = speech_feedback_enabled() and "Y" or "N"
  local ok, values = reaper.GetUserInputs(
    "Marker offset",
    2,
    "Offset seconds,Speech feedback? Y/N",
    tostring(current_offset) .. "," .. current_speech_feedback
  )

  if not ok then
    return
  end

  local offset_value, speech_feedback_value = values:match("^%s*([^,]*)%s*,%s*([^,]*)%s*$")
  local new_offset = tonumber(offset_value)
  local speech_feedback = speech_feedback_value and speech_feedback_value:lower()
  local speech_enabled = nil

  if not new_offset then
    speak("offset must be a number")
    return
  end

  if speech_feedback == "y" then
    speech_enabled = true
  elseif speech_feedback == "n" then
    speech_enabled = false
  else
    speak("enter Y or N")
    return
  end

  save_offset(new_offset)
  speak_if_enabled(speech_enabled, format_offset_direction(new_offset) .. " saved, " .. format_speech_feedback(speech_enabled))
  save_speech_feedback(speech_enabled)
end

local function get_play_cursor_position()
  local play_state = reaper.GetPlayState()

  if (play_state & 1) == 1 or (play_state & 2) == 2 or (play_state & 4) == 4 then
    return reaper.GetPlayPosition()
  end

  return reaper.GetCursorPosition()
end

local function clear_last_marker()
  reaper.SetExtState(EXT_SECTION, EXT_KEY_LAST_MARKER_INDEX, "", false)
  reaper.SetExtState(EXT_SECTION, EXT_KEY_LAST_MARKER_POSITION, "", false)
  reaper.SetExtState(EXT_SECTION, EXT_KEY_LAST_MARKER_TIME, "", false)
end

local function marker_matches_stored_marker(marker_index, marker_position)
  local _, marker_count, region_count = reaper.CountProjectMarkers(0)
  local total_count = marker_count + region_count

  for i = 0, total_count - 1 do
    local retval, is_region, position, _, _, current_marker_index = reaper.EnumProjectMarkers3(0, i)

    if retval > 0 and not is_region and current_marker_index == marker_index then
      return math.abs(position - marker_position) < 0.000001
    end
  end

  return false
end

local function remove_last_inserted_marker(now)
  local marker_index = tonumber(reaper.GetExtState(EXT_SECTION, EXT_KEY_LAST_MARKER_INDEX))
  local marker_position = tonumber(reaper.GetExtState(EXT_SECTION, EXT_KEY_LAST_MARKER_POSITION))
  local marker_time = tonumber(reaper.GetExtState(EXT_SECTION, EXT_KEY_LAST_MARKER_TIME))

  if marker_index and marker_position and marker_time
    and now - marker_time <= DOUBLE_PRESS_SECONDS
    and marker_matches_stored_marker(marker_index, marker_position) then
    reaper.Undo_BeginBlock()
    reaper.DeleteProjectMarker(0, marker_index, false)
    reaper.Undo_EndBlock("Cancel marker insert before configuring offset", -1)
    reaper.UpdateArrange()
  end

  clear_last_marker()
end

local function insert_marker(now)
  local offset = get_offset()
  local play_cursor_position = get_play_cursor_position()
  local marker_position = math.max(0, play_cursor_position + offset)
  local actual_offset = marker_position - play_cursor_position

  reaper.Undo_BeginBlock()
  local marker_index = reaper.AddProjectMarker(0, false, marker_position, 0, "", -1)
  reaper.Undo_EndBlock("Insert project marker at play cursor with offset", -1)
  reaper.UpdateArrange()

  if marker_index and marker_index >= 0 then
    reaper.SetExtState(EXT_SECTION, EXT_KEY_LAST_MARKER_INDEX, tostring(marker_index), false)
    reaper.SetExtState(EXT_SECTION, EXT_KEY_LAST_MARKER_POSITION, tostring(marker_position), false)
    reaper.SetExtState(EXT_SECTION, EXT_KEY_LAST_MARKER_TIME, tostring(now), false)
  else
    clear_last_marker()
  end

  if math.abs(actual_offset) < 0.000001 then
    speak("marked")
  else
    speak("marked " .. format_offset_direction(actual_offset))
  end
end

local now = reaper.time_precise()
local last_invoke = tonumber(reaper.GetExtState(EXT_SECTION, EXT_KEY_LAST_INVOKE)) or 0
local configure = (now - last_invoke) <= DOUBLE_PRESS_SECONDS

reaper.SetExtState(EXT_SECTION, EXT_KEY_LAST_INVOKE, tostring(now), false)

if configure then
  reaper.SetExtState(EXT_SECTION, EXT_KEY_LAST_INVOKE, "0", false)
  remove_last_inserted_marker(now)
  configure_settings()
  return
end

insert_marker(now)
