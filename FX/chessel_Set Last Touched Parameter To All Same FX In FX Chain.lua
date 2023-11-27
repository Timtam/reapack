-- @description Set Last Touched Parameter  To All Same FX In FX Chain
-- @version 1.0
-- @author Chessel (Chris Goodwin)

function Speak( str )
 if reaper.osara_outputMessage then
    reaper.osara_outputMessage(str)
  end
end


function main()
mode = 0  --Indicates want last touched rather than focused 
retval,  -- Returns false if failed. 
trackIndex,  -- If successful, trackIndex will be track index (-1 is master track, 0 is first track). 
itemIndex,  -- will be 0-based item index if an item, or -1 if not an item.
takeIndex,   -- will be 0-based take index.
fxIndex,  --  fxIndex will be FX index, potentially with 0x2000000 set to signify container-addressing, or with 0x1000000 set to signify record-input FX.
paramIndex  --  parmOut will be set to the parameter index if querying last-touched. parmOut will have 1 set if querying focused state and FX is no longer focused but still open.
= reaper.GetTouchedOrFocusedFX( mode )  --mode can be 0 to query last touched parameter, or 1 to query currently focused FX. 

-- Basic call must have succeeded to proceed 
if retval ~= true  then return end  
if itemIndex ~= -1 then return end  --Only applies to track FX chains and not take FX 

--Get the value of the parameter
track =  reaper.GetTrack( 0, trackIndex )
-- retval, paramValue  = reaper.TrackFX_GetFormattedParamValue( track, fxIndex, paramIndex )
paramValue = reaper.TrackFX_GetParamNormalized( track, fxIndex, paramIndex )

--Get name of the parameter 
retval, paramName  = reaper.TrackFX_GetParamName( track, fxIndex, paramIndex )
--Get name of the FX
retval, uniqueName  = reaper.TrackFX_GetNamedConfigParm( track, fxIndex, "fx_name" )

--Get range of parameter and normalise the value before presenting it to user 
retval, paramMin, paramMax =  reaper.TrackFX_GetParam( track, fxIndex, paramIndex )
paramValue = ( paramMax - paramMin ) * paramValue + paramMin

--Set up title of dialog 
sTitle = uniqueName 
pos  =  sTitle:find( ":" )
if pos then sTitle = sTitle:sub( pos + 2 ) end 
sTitle = paramName  ..  " on " .. sTitle
sLabel =  "Parameter value (" .. paramMin .. ", " .. paramMax .. ")"
paramValue = math.floor( paramValue * 1000 ) / 1000
userOK, userInputCSV = reaper.GetUserInputs( sTitle, 1, sLabel, paramValue )
if not userOK then return end

--Get the numbers entered by user 
newParamValue = userInputCSV:match ( "(.*)")
newParamValue  = 1 * tonumber( newParamValue )  
if newParamValue == nil then 
  reaper.MB("Only numbers are allowed", "Error", 0)
return 
end 


--Only allow numbers between min and max
if newParamValue  < paramMin then newParamValue  = paramMin end 
if newParamValue > paramMax then newParamValue  = paramMax end 

-- Loop through all the FX on the track and update the same parameter on each if it is of the same type of FX
iFX = reaper.TrackFX_GetCount( track )
for i = 0, iFX-1 do
retval, fxName = reaper.TrackFX_GetNamedConfigParm( track, fxIndex, "fx_name" )
  if fxName and uniqueName and fxName == uniqueName then -- and string.sub( fxName, 1, 4 ) == string.sub( originalFXName, 1, 4 ) then 
     retval  = reaper.TrackFX_SetParam( track, i, paramIndex, newParamValue  )
  end  -- End of if same FX as original 
end   -- end of loop through FX chain 
end   -- end of main function 
main()