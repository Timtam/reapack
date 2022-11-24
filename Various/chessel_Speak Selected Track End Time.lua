-- @about Speak the time of the end of the last item on the first selected track 
-- @author Chessel (Chris Goodwin)
-- @version 1.0
-- @description Speak Selected Track End Time

function Speak( str )
 if reaper.osara_outputMessage then
    reaper.osara_outputMessage(str)
  end
end

function main()
local retval, measures, cml, beat, denom 
local strSpeak = ""

local track = reaper.GetSelectedTrack(0,0) -- Get the first selected track in the active project 
if track then
local numitems = reaper.GetTrackNumMediaItems( track )
if numitems  then 
local item = reaper.GetTrackMediaItem( track, numitems-1 )
local itempos = reaper.GetMediaItemInfo_Value( item, "D_POSITION" )
local itemlen = reaper.GetMediaItemInfo_Value( item, "D_LENGTH" )
local trackend = itempos + itemlen

-- retval, measures, cml, beat, denom = reaper.TimeMap2_timeToBeats( 0,  trackend  ) 
-- Speak( "Track stats are " .. measures .. ", " .. cml .. ", " .. beat .. ", " .. denom )  


-- Calculate minutes and seconds 
local minutes =  math.floor( 1 * trackend  / 60 ) 
local seconds =  math.floor( 100 * (trackend % 60 ) ) / 100 

-- Construct what to say
if minutes == 1 then
strSpeak = "1 minute" 
elseif minutes > 1 then
strSpeak = minutes .. " minutes"
end 

if seconds == 1 then 
strSpeak = strSpeak .. "1 second"
elseif seconds > 0 then
strSpeak = strSpeak .. seconds .. " seconds"
end 

-- Now say it 
Speak( strSpeak )

end -- if there are items on the track
end -- if there is a selected track 
end
main()
