-- @description Start Recording After Countdown 
-- @version 0.1
-- @about Allows the user to state hours, minutes and seconds until recording starts 
-- @author Chessel (Chris Goodwin)
-- @changelog
--   Initial release

function Speak( str )
 if reaper.osara_outputMessage then
    reaper.osara_outputMessage(str)
  end
end


function main()

--Check if there is already a target time 
targetTime = reaper.GetExtState( "ChesselRecordAfterCountdown", "targetTime" )
if targetTime == "0" or targetTime == "" then 
  --Input info from user on how long to go until recording is to start  and use this to set a target time in seconds 
  numHours = reaper.GetExtState( "ChesselRecordAfterCountdown", "numHours" )
  numMinutes = reaper.GetExtState( "ChesselRecordAfterCountdown", "numMinutes" )
  numSeconds  = reaper.GetExtState( "ChesselRecordAfterCountdown", "numSeconds" )

  --Set up default values
  if numHours == "" then numHours = "1" end 
  if numMinutes == "" then numMinutes = "0" end
  if numSeconds == "" then numSeconds = "0" end 

  userOK, userInputCSV = reaper.GetUserInputs( "Countdown to Record", 3, "Hours, Minutes, Seconds", numHours .. ',' .. numMinutes .. "," .. numSeconds  )
  if not userOK then return reaper.SN_FocusMIDIEditor() end

  --Get the numbers entered by user 
  numHours, numMinutes, numSeconds  = userInputCSV:match( "(%d*),(%d*),(%d*)")
  if not tonumber( numHours ) or not tonumber( numMinutes ) or not tonumber( numSeconds )  then return end

  -- Enforce number ranges before saving
  --if  numHours < 0 then numHours = 0 end

  reaper.SetExtState( "ChesselRecordAfterCountdown",  "numHours", numHours , false)
  reaper.SetExtState( "ChesselRecordAfterCountdown",  "numMinutes", numMinutes , false)
  reaper.SetExtState( "ChesselRecordAfterCountdown",  "numSeconds", numSeconds, false)
  targetTime = os.time() + numHours*60*60 + numMinutes*60 + numSeconds 
reaper.SetExtState( "ChesselRecordAfterCountdown",  "targetTime", targetTime, false)
end --if targetTime was 0 

currentTime = os.time() --Gets epoch time, number of seconds since midnight on 1st Jan 1970 
if currentTime > tonumber( targetTime ) then 
  reaper.SetExtState( "ChesselRecordAfterCountdown",  "targetTime", 0, false)
  reaper.Main_OnCommandEx( 1013, 0 , 0)  -- Call transport toggle record action 
else
  reaper.defer(main)
end 
end
  
main()
