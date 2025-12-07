-- @description Select all tracks with audio items
-- @version 1.0
-- @author Scott Chesworth
-- @provides [main]
-- @changelog
--   initial release

function Speak(str)
  if reaper.osara_outputMessage then
    reaper.osara_outputMessage(str)
  end
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

-- Deselect all tracks
reaper.Main_OnCommand(40297, 0) -- Track: Unselect all tracks

local trackCount = reaper.CountTracks(0)
local selectedTrackCount = 0

for i = 0, trackCount - 1 do
  local track = reaper.GetTrack(0, i)
  local itemCount = reaper.CountTrackMediaItems(track)
  for j = 0, itemCount - 1 do
    local item = reaper.GetTrackMediaItem(track, j)
    local take = reaper.GetActiveTake(item)
    if take and not reaper.TakeIsMIDI(take) then
      reaper.SetTrackSelected(track, true)
      selectedTrackCount = selectedTrackCount + 1
      break -- Stop checking once one audio item is found
    end
  end
end

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock("Select tracks with audio items", -1)

-- Speak the result
if selectedTrackCount == 0 then
  Speak("No tracks with audio items found.")
elseif selectedTrackCount == 1 then
  Speak("1 track with audio items selected.")
else
  Speak(selectedTrackCount .. " tracks with audio items selected.")
end
