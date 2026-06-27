-- @noindex
-- @description Configure Scan for Silence

local function Speak(str)
  if reaper.osara_outputMessage then
    reaper.osara_outputMessage(str)
  else
    reaper.ShowConsoleMsg(str .. "\n")
  end
end

local function PromptUserForSettings()
  -- GetExtState returns "" when unset, so fall back explicitly.
  local thr = reaper.GetExtState("SilenceFinder", "threshold_db")
  if thr == "" then thr = "-40" end
  local dur = reaper.GetExtState("SilenceFinder", "silence_duration")
  if dur == "" then dur = "1.0" end
  local rel = reaper.GetExtState("SilenceFinder", "report_relative")
  if rel == "" then rel = "n" end

  local ok, input = reaper.GetUserInputs(
    "Configure Silence Detection",
    3,
    "Threshold (dB),Silence Duration (sec),Report relative movement (y/n)",
    thr .. "," .. dur .. "," .. rel
  )

  if not ok then
    Speak("Configuration cancelled.")
    return
  end

  -- Split into fields (tolerates empty fields).
  local fields = {}
  for f in (input .. ","):gmatch("([^,]*),") do
    fields[#fields + 1] = f
  end
  local thresh_str, dur_str, rel_str = fields[1], fields[2], fields[3]

  local threshold = tonumber(thresh_str)
  local duration = tonumber(dur_str)
  if not threshold or not duration then
    Speak("Invalid input. Threshold and duration must be numbers.")
    return
  end
  -- Anything but y/Y means off.
  local relative = ((rel_str or ""):lower():gsub("%s", "") == "y") and "y" or "n"

  reaper.SetExtState("SilenceFinder", "threshold_db", (thresh_str:gsub("%s", "")), true)
  reaper.SetExtState("SilenceFinder", "silence_duration", (dur_str:gsub("%s", "")), true)
  reaper.SetExtState("SilenceFinder", "report_relative", relative, true)

  Speak("Saved " .. threshold .. " dB, " .. duration .. " seconds, relative movement " ..
    (relative == "y" and "on" or "off") .. ".")
end

PromptUserForSettings()
