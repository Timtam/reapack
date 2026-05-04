-- @description Speak percentage played of the selected item 
-- @version 1.0
-- @about Speaks a percentage matching how far through the play head is on the selected item
-- @author Chessel (Chris Goodwin) and Gemini

function Speak(str)
  if reaper.osara_outputMessage then
    reaper.osara_outputMessage(str)
  else
    -- Fallback to console if OSARA is not present
    reaper.ShowConsoleMsg(str .. "\n")
  end
end

function main()
  -- Count how many items are currently selected
  local selected_count = reaper.CountSelectedMediaItems(0)
  
  if selected_count == 0 then
    Speak("No item selected")
    return
  elseif selected_count > 1 then
    Speak("Too many items selected")
    return
  end

  -- Since we passed the checks, get the only selected item (index 0)
  local item = reaper.GetSelectedMediaItem(0, 0)

  -- Get item dimensions
  local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local item_end = item_start + item_length

  -- Get current play/edit position
  local play_pos = reaper.GetPlayPosition()
  
  -- If not playing, use the edit cursor position instead
  if reaper.GetPlayState() == 0 then
    play_pos = reaper.GetCursorPosition()
  end

  local progress = play_pos - item_start
  local percentage = (progress / item_length) * 100
  -- Round to the nearest whole number
  local rounded = math.floor(math.abs(percentage) + 0.5) * (percentage < 0 and -1 or 1)
  Speak(tostring(rounded) .. " percent")
end

main()