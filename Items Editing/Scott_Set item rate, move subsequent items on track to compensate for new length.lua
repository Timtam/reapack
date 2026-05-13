-- @description Set item rate, move subsequent items on track to compensate for new length
-- @version 1.1
-- @author Scott Chesworth
-- @About
--   Select items that you want to speed up or slow down and enter a playback rate.
--   Anything higher than 1.0 speeds up, anything less than 1.0 slows down.
--   Can also cope with negative numbers, -1 is half speed, -2 is one-third speed, etc.
--
--   Should be possible to process contiguous and non-contiguous selected items, even across tracks if needed.
--
--   Shout outs to X-Raym and amagalma. I studdied scripts from them and reused some of their functions.
-- @changelog
--   Renamed script as it's now possible to increase and decrease rate.

function Speak(str)
  if reaper.osara_outputMessage then
    reaper.osara_outputMessage(str)
  end
end

local function msg(text)
  if reaper.osara_outputMessage then
    Speak(text)
  else
    reaper.ShowMessageBox(text, "Set Item Rate", 0)
  end
end

local function format_duration(seconds)
  if seconds < 60 then
    return string.format("%.2f seconds", seconds)
  end

  local total_seconds = math.floor(seconds + 0.5)
  local hours = math.floor(total_seconds / 3600)
  local minutes = math.floor((total_seconds % 3600) / 60)
  local secs = total_seconds % 60
  local parts = {}

  if hours > 0 then
    parts[#parts + 1] = string.format("%d hour%s", hours, hours == 1 and "" or "s")
  end

  if minutes > 0 then
    parts[#parts + 1] = string.format("%d minute%s", minutes, minutes == 1 and "" or "s")
  end

  if secs > 0 or #parts == 0 then
    parts[#parts + 1] = string.format("%d second%s", secs, secs == 1 and "" or "s")
  end

  return table.concat(parts, " ")
end

local function get_target_rate(input_rate)
  if input_rate < 0 then
    return 1 / (math.abs(input_rate) + 1)
  end

  return input_rate
end

local function save_selected_items()
  local t = {}
  local count = reaper.CountSelectedMediaItems(0)
  for i = 0, count - 1 do
    t[#t + 1] = reaper.GetSelectedMediaItem(0, i)
  end
  return t
end

local function restore_selected_items(items)
  reaper.SelectAllMediaItems(0, false)
  for i = 1, #items do
    reaper.SetMediaItemSelected(items[i], true)
  end
end

local function shift_subsequent_items(track, item, delta)
  local item_count = reaper.CountTrackMediaItems(track)
  local found = false
  local shifted = false

  for i = 0, item_count - 1 do
    local current = reaper.GetTrackMediaItem(track, i)
    if found then
      local current_pos = reaper.GetMediaItemInfo_Value(current, "D_POSITION")
      reaper.SetMediaItemPosition(current, current_pos + delta, false)
      shifted = true
    elseif current == item then
      found = true
    end
  end

  if shifted then
    return math.abs(delta)
  end

  return 0
end

local function collect_selected_items_by_track()
  local tracks = {}
  local seen_tracks = {}
  local selected_count = reaper.CountSelectedMediaItems(0)

  for i = 0, selected_count - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local track = item and reaper.GetMediaItem_Track(item)
    if track and not seen_tracks[track] then
      seen_tracks[track] = true
      tracks[#tracks + 1] = track
    end
  end

  local selected_by_track = {}

  for i = 1, #tracks do
    local track = tracks[i]
    local items = {}
    local item_count = reaper.CountTrackMediaItems(track)

    for j = 0, item_count - 1 do
      local item = reaper.GetTrackMediaItem(track, j)
      if reaper.IsMediaItemSelected(item) then
        items[#items + 1] = item
      end
    end

    if #items > 0 then
      selected_by_track[#selected_by_track + 1] = {
        track = track,
        items = items
      }
    end
  end

  return selected_by_track
end

local function process_item(item, new_rate, preserve_pitch)
  local take = reaper.GetActiveTake(item)
  if not take then
    return false, 0
  end

  local old_rate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
  local old_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local old_fade_in = reaper.GetMediaItemInfo_Value(item, "D_FADEINLEN")
  local old_fade_out = reaper.GetMediaItemInfo_Value(item, "D_FADEOUTLEN")
  local track = reaper.GetMediaItem_Track(item)

  if not track then
    return false, 0
  end

  local rate_ratio = math.abs(old_rate) / math.abs(new_rate)

  reaper.SetMediaItemTakeInfo_Value(take, "B_PPITCH", preserve_pitch and 1 or 0)
  reaper.SetMediaItemTakeInfo_Value(take, "D_PLAYRATE", new_rate)
  reaper.SetMediaItemInfo_Value(item, "D_LENGTH", old_len * rate_ratio)
  reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN", old_fade_in * rate_ratio)
  reaper.SetMediaItemInfo_Value(item, "D_FADEOUTLEN", old_fade_out * rate_ratio)

  local new_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local amount_moved = shift_subsequent_items(track, item, new_len - old_len)

  return true, amount_moved
end

local selected_count = reaper.CountSelectedMediaItems(0)
if selected_count == 0 then
  msg("No selected items")
  return
end

local dialog_title = string.format("Set rate for %d item%s", selected_count, selected_count == 1 and "" or "s")
local retval, rate_str = reaper.GetUserInputs(dialog_title, 1, "Rate (+speed, -slow):", "3.0")
if not retval then
  return
end

local input_rate = tonumber(rate_str)
if not input_rate or input_rate == 0 then
  msg("Enter a non-zero rate. No changes were made")
  return
end

local new_rate = get_target_rate(input_rate)

local selected_by_track = collect_selected_items_by_track()
if #selected_by_track == 0 then
  msg("Could not get the selected items.")
  return
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local saved_selection = save_selected_items()
local total_amount_moved = 0
local processed_count = 0

for i = 1, #selected_by_track do
  local items = selected_by_track[i].items
  for j = 1, #items do
    local changed, amount_moved = process_item(items[j], new_rate, false)
    if changed then
      processed_count = processed_count + 1
      total_amount_moved = total_amount_moved + amount_moved
    end
  end
end

restore_selected_items(saved_selection)

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock("adjust item rate and move subsequent items", -1)

if processed_count == 0 then
  msg("Selected items have no active take. No changes were made")
  return
end

msg(string.format("Adjusted following items by %s.", format_duration(total_amount_moved)))
