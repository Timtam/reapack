-- @version 1.0
-- @description Freeze track and add text to track name
-- @author Chessel (Chris Goodwin)
-- @about Call stock freeze track to stereo action and append the word frozen to track name 

  local script_title = 'Freeze track and add to track name' 

function Speak( str )
 if reaper.osara_outputMessage then
    reaper.osara_outputMessage(str)
  end
end


function main()
local StrSpeak  = ""
local i, TrackCount, SelTrac, TrackName="" 

-- Set the undo history to pause 
reaper.Undo_BeginBlock(0) -- Pause the undo list 

TrackCount = reaper.CountSelectedTracks(0) -- Count the number of selected tracks 
for i = 0, TrackCount-1 do
SelTrack = reaper.GetSelectedTrack( 0, i )
if SelTrack then 
-- need to prefix next line with a dummy boolean variable 
z, TrackName = reaper.GetSetMediaTrackInfo_String( SelTrack, "P_NAME", '', 0)
-- Hard code the word frozen onto the end of the track name 
TrackName = TrackName .. " frozen"
reaper.GetSetMediaTrackInfo_String( SelTrack, "P_NAME", TrackName, 1 )
end -- if a valid track  object 
end -- for loop of selected tracks 

-- Call freeze to stereo 
reaper.Main_OnCommandEx( 41223, 0 , 0)


-- Kick the undo list back into life and refresh the visual display 
reaper.TrackList_AdjustWindows(0)
reaper.Undo_EndBlock("Freeze track to stereo and add frozen to track name", -1)

end -- function 

main()


