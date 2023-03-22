-- @description Move to next item 
-- @version 1.0
-- @about When there is only one selected item in the project, moves to the next item and selects that instead.  Works even if an envelope has the focus.
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

local found = false
local i = 0
while found == false and i < numItems do
  item1 = reaper.GetTrackMediaItem( track, i )
  if reaper.IsMediaItemSelected( item1 ) then found = true end 
i = i+1
end
if found == false then return end
if i == numItems then Speak( "Last item on track already selected" ) return end 

--Is there an item after the selected one?
item2 = reaper.GetTrackMediaItem( track, i )
if item2 == nil then return end
reaper.SetMediaItemSelected( item1, false )
reaper.SetMediaItemSelected( item2, true )
local pos = reaper.GetMediaItemInfo_Value( item2, "D_POSITION")
reaper.ApplyNudge( 0, 1, 6, 1, pos, false, 0 ) -- project, set/nudge, edit cursor, time unit, amount, copy 

Speak( "Item " .. i+1 .. " on track selected" )
end 
main()