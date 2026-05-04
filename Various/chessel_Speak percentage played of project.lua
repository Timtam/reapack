-- @description Speak percentage played of project
-- @version 1.0
-- @about Speaks a percentage matching how far through the play head is of the project, or reports based on edit cursor position if not playing 
-- @author Chessel (Chris Goodwin) and Gemini

function Speak(str)
  if reaper.osara_outputMessage then
    reaper.osara_outputMessage(str)
  else
    reaper.ShowConsoleMsg(str .. "\n")
  end
end

function main()
  -- Get the total length of the project in seconds
  local project_length = reaper.GetProjectLength(0)
  
  if project_length <= 0 then
    Speak("Project is empty")
    return
  end

  -- Get current play/edit position
  local play_pos = reaper.GetPlayPosition()
  
  -- If not playing, use the edit cursor position instead
  if reaper.GetPlayState() == 0 then
    play_pos = reaper.GetCursorPosition()
  end

  -- Calculate percentage relative to the whole project
  local percentage = (play_pos / project_length) * 100
  
  -- Round to the nearest whole number
  local rounded = math.floor(percentage + 0.5)
  
Speak(tostring(rounded) .. " percent of project")
end

main()