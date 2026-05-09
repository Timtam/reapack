-- @description Decrease Grid Size with OSARA Feedback
-- @version 1.0
-- @author Scott Chesworth
-- @provides [main=main] .
-- @About Adjusts arrange grid
-- @changelog
--   Initial release

function Speak(str)
  if reaper.osara_outputMessage then
    reaper.osara_outputMessage(str)
  end
end

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

local _, current = reaper.GetSetProjectGrid(0, false)

local prev_index = 1
for i = #divisions, 1, -1 do
  if math.abs(divisions[i][1] - current) < 0.00001 then
    prev_index = i - 1
    break
  end
end

if prev_index < 1 then prev_index = 1 end

local new_div = divisions[prev_index]
reaper.SetProjectGrid(0, new_div[1])
Speak(new_div[2] .. " grid")
