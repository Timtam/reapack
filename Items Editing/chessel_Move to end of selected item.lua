-- @description Move to end of selected item
-- @version 1.0
-- @about When there is only one selected item in the project, moves the edit cursor to the end of the item.  Works even when there is an envelope selected. 
-- @author Chessel (Chris Goodwin)

function Speak( str )
 if reaper.osara_outputMessage then
    reaper.osara_outputMessage(str)
  end
end


function main()
local item1, item2

--Should only use when on an envelope 
if reaper.GetSelectedEnvelope( 0 )  == nil then Speak( "No envelope selected" ) return end

local numSelectedItems = reaper.CountSelectedMediaItems( 0 )
if numSelectedItems ~= 1 then return end 

item1 = reaper.GetSelectedMediaItem( 0, 0 )
if item1 == nil then return end

local track = reaper.GetMediaItem_Track( item1 )
local numItems = reaper.CountTrackMediaItems( track )

--Search through track items to find the selected item
local found = false
local i = 0
while found == false and i < numItems do
  item1 = reaper.GetTrackMediaItem( track, i )
  if reaper.IsMediaItemSelected( item1 ) then  found = true  end
  i = i+1
end
if found == false then return end
i = i-1

--Get start time and move edit cursor to it 
local pos = reaper.GetMediaItemInfo_Value( item1, "D_POSITION")
local len = reaper.GetMediaItemInfo_Value( item1, "D_LENGTH")
pos = pos + len
reaper.ApplyNudge( 0, 1, 6, 1, pos, false, 0 ) -- project, set/nudge, edit cursor, time unit, amount, copy 

Speak( "Moved to end of item" )
end 
main()