-- @description Increase MIDI Editor Grid Size with OSARA Feedback
-- @version 1.0
-- @author Scott Chesworth
-- @provides [main=midi_editor] .
-- @About Adjusts MIDI Editor grid
-- @changelog
--   Initial release

function Speak(str)
  if reaper.osara_outputMessage then
    reaper.osara_outputMessage(str)
  end
end

local editor = reaper.MIDIEditor_GetActive()
if not editor then
  Speak("No active MIDI editor")
  return
end

local take = reaper.MIDIEditor_GetTake(editor)
if not take then
  Speak("No active MIDI take")
  return
end

-- Musically sorted divisions with friendly names
local divisions = {
  {1, "whole note"},
  {2/3, "dotted half note"},
  {1/2, "half note"},
  {1/3, "dotted quarter note"},
  {1/4, "quarter note"},
  {1/6, "quarter triplet"},
  {1/8, "eighth note"},
  {1/12, "eighth triplet"},
  {1/16, "sixteenth note"},
  {1/24, "sixteenth triplet"},
  {1/32, "thirty-second note"},
  {1/48, "thirty-second triplet"},
  {1/64, "sixty-fourth note"},
  {1/96, "sixty-fourth triplet"},
  {1/128, "one hundred twenty-eighth note"},
  {1/5, "fifth note"},
  {1/7, "seventh note"},
  {1/9, "ninth note"},
  {1/10, "tenth note"},
  {1/18, "eighteenth note"}
}

local current = reaper.MIDI_GetGrid(take)

-- Find index and go to next
local next_index = 1
for i, v in ipairs(divisions) do
  if math.abs((v[1] * 4) - current) < 0.00001 then
    next_index = i + 1
    break
  end
end

if next_index > #divisions then next_index = #divisions end

local new_div = divisions[next_index]
reaper.SetMIDIEditorGrid(0, new_div[1])
Speak(new_div[2] .. " grid")
