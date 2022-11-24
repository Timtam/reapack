-- @version 1.0
-- @author Chessel (Chris Goodwin)
-- @description Butt right edge of selected item up to next item
-- @about Move selected item so right edge touches left edge of next item on track
-- @changelog
--    # use VF version check

  local script_title = 'Butt right edge of selected item up to next item' 

function Speak( str )
 if reaper.osara_outputMessage then
    reaper.osara_outputMessage(str)
  end
end


function main()
local StrSpeak  = ""
local Item1, Item2, ItemCount, NewPosition, Length1
local GUID1, GUID2 

-- Set the undo history to pause 
reaper.Undo_BeginBlock(0) -- Pause the undo list 


-- Only do something if there is one selected item 
ItemCount = reaper.CountSelectedMediaItems()
      Item1 = reaper.GetSelectedMediaItem( 0, ItemCount)
if Item1 then 
-- We have a valid selected item so now need to find it in the main track list of items so we can then find the next one along to butt up to 
-- Get the parent track and loop through the items on it until we find a match on GUID's 
local SelectedItemTrack =  reaper.GetMediaItemTrack( Item1 )
ItemCount = reaper.CountTrackMediaItems( SelectedItemTrack )
for i = 0, ItemCount-1 do
Item2 = reaper.GetTrackMediaItem( SelectedItemTrack, i )
GUID1 = reaper.BR_GetMediaItemGUID( Item1  ) 
GUID2 = reaper.BR_GetMediaItemGUID( Item2  )
if GUID1 == GUID2  then 
-- We have found our selected item in the main track list of items so now get the next one along 
Item2 = reaper.GetTrackMediaItem( SelectedItemTrack, i+1 )
if Item2 then
-- We have our selected item and the next item to the right in time so move selected item so it butts up 
      NewPosition  = reaper.GetMediaItemInfo_Value( Item2, "D_POSITION" ) 
Length1 = reaper.GetMediaItemInfo_Value( Item1, "D_LENGTH")
 reaper.SetMediaItemPosition( Item1, NewPosition - Length1, true )
break  -- We have finished so break out of for loop 
end -- if a second item 
end -- if item1 and item 2 are the same item 
    end -- loop through items on track 
end -- if found a selected item on track 

-- Kick the undo list back into life and refresh the visual display 
reaper.Undo_EndBlock("Butt right edge of selected item up to next item", -1)

end -- function 

main()


