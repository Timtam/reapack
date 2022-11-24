-- @version 1.0
-- @author Chessel (Chris Goodwin) 
-- @about Call stock unfreeze track function and remove the word frozen to track name 
-- @description Unfreeze track and remove text from track name

  local script_title = 'Unfreeze track and remove from track name' 

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
-- Need a dummy boolean on start of next line 
z, TrackName = reaper.GetSetMediaTrackInfo_String( SelTrack, "P_NAME", '', 0)

-- if end of track name is equal to the word frozen including a leading space
local TrackEnd =  TrackName.sub( TrackName, TrackName.len( TrackName ) - 6 )
if TrackEnd == " frozen" then 
TrackName = TrackName.sub( TrackName, 1, TrackName.len(TrackName) - 7 )
reaper.GetSetMediaTrackInfo_String( SelTrack, "P_NAME", TrackName, 1 )
 end -- if track ended in frozen 
end -- if a valid track  object 
end -- for loop of selected tracks 

--  Call unfreeze 
reaper.Main_OnCommandEx( 41644, 0 , 0)

-- Kick the undo list back into life and refresh the visual display 
reaper.TrackList_AdjustWindows(0)
reaper.Undo_EndBlock("Unfreeze track and remove frozen from end of track name", -1)

end -- function 

main()


