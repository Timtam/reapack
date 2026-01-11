-- @description Configure Scan for Silence (set peak dB and duration)
-- @version 1.1
-- @author Scott Chesworth
-- @about
--   Run the Configure scan for silence script to set peak and duration of the silences you want to find. Those settings are stored in reaper-extstate, they'll be used in any project and also stick around after you've closed REAPER.
--   Use any combination of four scripts to move to the beginning or end of previous or next silence in the selected item.
--   Scanning for silence begins from the edit cursor position if stopped/paused, or from play cursor if the project is playing.
--   If the project is playing when you run the scripts, it will continue doing so after the edit cursor has been moved.
-- @provides
--   [main] . > Scan for Silence/Scott_Move to beginning of next silence in selected item.lua
--   [main] . > Scan for Silence/Scott_Move to beginning of previous silence in selected item.lua
--   [main] . > Scan for Silence/Scott_Move to end of next silence in selected item.lua
--   [main] . > Scan for Silence/Scott_Move to end of previous silence in selected item.lua
--   [main] . > Scan for Silence/Scott_Configure scan for silence.lua
-- changelog
--   Fixed packaging and improved readability

local function Speak(str)
  if reaper.osara_outputMessage then
    reaper.osara_outputMessage(str)
  else
    reaper.ShowConsoleMsg(str .. "\n")
  end
end

local function PromptUserForSettings()
  local defaults = {
    threshold = reaper.GetExtState("SilenceFinder", "threshold_db") or "-40",
    duration  = reaper.GetExtState("SilenceFinder", "silence_duration") or "1.0"
  }

  local ok, input = reaper.GetUserInputs(
    "Configure Silence Detection",
    2,
    "Threshold (dB),Silence Duration (sec)",
    defaults.threshold .. "," .. defaults.duration
  )

  if not ok then
    Speak("Configuration cancelled.")
    return
  end

  local thresh_str, dur_str = input:match("([^,]+),([^,]+)")
  local threshold = tonumber(thresh_str)
  local duration = tonumber(dur_str)

  if not threshold or not duration then
    Speak("Invalid input. This script only supports numeric values.")
    return
  end

  reaper.SetExtState("SilenceFinder", "threshold_db", thresh_str, true)
  reaper.SetExtState("SilenceFinder", "silence_duration", dur_str, true)

  Speak("Saved " .. thresh_str .. " dB, " .. dur_str .. " seconds.")
end

PromptUserForSettings()
