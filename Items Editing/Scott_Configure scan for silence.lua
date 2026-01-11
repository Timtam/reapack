-- @description Configure Scan for Silence (set peak dB and duration)
-- @version 1.1
-- @author Scott Chesworth

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
