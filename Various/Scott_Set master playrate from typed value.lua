-- @description Set master playrate from typed value
-- @version 1.0
-- @author Scott Chesworth
-- @provides [main=main] .
-- @About Provides an edit field where you can type desired master playrate
--   
--   At its factory settings, REAPER will accept values from 0.25 to 4.0.
--   
--   This action can change the range if needed:
--   
--   SWS/BR: Adjust playrate options...
-- @changelog
--   Initial release

function Speak(str)
  if reaper.osara_outputMessage then
    reaper.osara_outputMessage(str)
  end
end

local current = reaper.Master_GetPlayRate(0)
local ok, input = reaper.GetUserInputs("Set master playrate", 1, "Playrate:", string.format("%.4g", current))
if not ok then return end

local rate = tonumber(input)
if not rate then
  Speak("Nope, playrate has to be a number")
  return
end

reaper.CSurf_OnPlayRateChange(rate)
Speak(string.format("%.4g", rate) .. " master playrate")
