-- @description Export markers in relation to items on selected track
-- @version 1.0
-- @about 
--   This script will export all markers on the selected track in relation to the items on said track.
--   The resulting list of markers will be copied to the clipboard and look like the following.
--   track {item_number}, {time_into_item}, {marker_text}
--   Example:
--   
--   Track 1, 00:00:01.000, Marker 1 text
--   Track 2, 00:03:05.271, you need to cut a breath here
--   Track 7, 01:05:00.022, cut that outtake
-- @author Toni Barth (Timtam)
-- @changelog
--   initial release

-- Function to format time in hh:mm:ss.sss
local function format_time(time)
  local hours = math.floor(time / 3600)
  local minutes = math.floor((time % 3600) / 60)
  local seconds = time % 60
  return string.format("%02d:%02d:%06.3f", hours, minutes, seconds)
end

function main()
  -- Get currently selected track
  local track = reaper.GetSelectedTrack(0, 0)
       
  if not track then
    reaper.ShowMessageBox("No track currently selected.", "Marker Report", 0)
    return
  end

  -- Iterate through items on selected track
  local num_items = reaper.CountTrackMediaItems(track)
  local items = {}

  for i = 0, num_items - 1 do
    local item = reaper.GetTrackMediaItem(track, i)
    local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local item_end = item_start + item_length
    items[#items + 1] = {
      item_start = item_start,
      item_end = item_end
    }
  end
                
  -- Get number of project markers and regions
  local _, num_markers, _ = reaper.CountProjectMarkers(0)

  -- Prepare output string
  local output = ""

  -- Iterate through markers
  for i = 0, num_markers - 1 do
    local retval, isrgn, pos, _, name, markrgnindex, _ = reaper.EnumProjectMarkers(i)
    if not isrgn then
      local marker_time = pos
      local track_number = "unknown"
      local relative_time = 0
        
      for j = 1, #items do
        -- Check if marker time is within item time range
        if marker_time >= items[j].item_start and marker_time <= items[j].item_end then
          track_number = j  -- Track number (1-based)
          relative_time = marker_time - items[j].item_start
          break
        end
      end

      output = output .. string.format("Track %s: %s, %s\n", track_number, format_time(relative_time), name or (tostring(i + 1)))
    end
  end

  -- Copy to clipboard
  reaper.CF_SetClipboard(output)

  -- Show message when done
  reaper.ShowMessageBox("Marker report copied to clipboard.", "Marker Report", 0)
end

main()