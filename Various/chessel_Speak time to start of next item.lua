-- @description Speak time to start of next item 
-- @version 1.0
-- @about Finds the first selected item and announces time to the start of the next item.  A positive number means there is space between the current item and the next one.
-- @author Chessel (Chris Goodwin), Pete Torpey

function Speak( str )
 if reaper.osara_outputMessage then
    reaper.osara_outputMessage(str)
  end
end


function main()
local ItemCount, Item1, Item2, SelectedItemTrack , i, GUID1, GUID2, Item1End, Item2Start, TimeBetween 

-- Only do something if there is one selected item 
ItemCount = reaper.CountSelectedMediaItems()
Item1 = reaper.GetSelectedMediaItem( 0, 0)
if Item1 then 
 -- We have a valid selected item so now need to find it in the main track list of items so we can then find the next one along 
 -- Get the parent track and loop through the items on it until we find a match on GUID's 
 SelectedItemTrack =  reaper.GetMediaItemTrack( Item1 )
 ItemCount = reaper.CountTrackMediaItems( SelectedItemTrack )
 for i = 0, ItemCount-1 do
  Item2 = reaper.GetTrackMediaItem( SelectedItemTrack, i )
  GUID1 = reaper.BR_GetMediaItemGUID( Item1  ) 
  GUID2 = reaper.BR_GetMediaItemGUID( Item2  )
  if GUID1 == GUID2  then 
   -- We have found our selected item in the main track list of items so now get the next one along 
   Item2 = reaper.GetTrackMediaItem( SelectedItemTrack, i+1 )
   if Item2 then
    -- We have our selected item and the next item to the right in time 
    Item1End  = reaper.GetMediaItemInfo_Value( Item1, "D_POSITION" ) + reaper.GetMediaItemInfo_Value( Item1, "D_LENGTH")
    Item2Start = reaper.GetMediaItemInfo_Value( Item2, "D_POSITION" )
    TimeBetween = Item2Start - Item1End
    -- convert to project default time mode
    TimeBetween = reaper.format_timestr_len( TimeBetween, TimeBetween, 0, -1 )

    Speak ( TimeBetween )
   else
    -- No next item 
    Speak( "No following item" )
   end   -- we found a following item and spoke it 
  end -- we found the first selected item 
  i =  ItemCount   -- end the looping around items on track as we have now finished 
 end -- cycle through track items 
end -- if there is at least one selected item 

end -- end main function 
main()