-- @description Add pitch bend vibrato 
-- @version 0.2
-- @about 
--   Adds a series of pitch bends to simulate vibrato  on a guitar so never goes below the neutral bend offset 
-- @author Chessel (Chris Goodwin)
-- @changelog
--   initial release

function Speak( str )
 if reaper.osara_outputMessage then
    reaper.osara_outputMessage(str)
  end
end


function main()
MIDIEditor = reaper.MIDIEditor_GetActive()
if MIDIEditor == nil then return end
take = reaper.MIDIEditor_GetTake(MIDIEditor)
if take == nil then return end
item = reaper.GetMediaItemTake_Item( take )
itempos = reaper.GetMediaItemInfo_Value( item, 'D_POSITION' )
if reaper.TakeIsMIDI( take ) == false then return end


-- Set the undo history to pause 
reaper.Undo_BeginBlock()
--Susppend sorting of notes to improve performance marginally 
reaper.MIDI_DisableSort(take)


--Get first selected note
selNote = reaper.MIDI_EnumSelNotes( take, -1 )
  if val == -1 then return end
--Get info about the selected note 
_, _, _, startPPQ, endPPQ, channel, _, _ = reaper.MIDI_GetNote( take, selNote )

--Ask user for number of vibrato wiggles the size and a randomize value 
numVibrato = reaper.GetExtState( "AddVibratoPitchBend", "NumberVibrato")
maxBend = reaper.GetExtState( "AddVibratoPitchBend", "MaxBend")
bendVariation = reaper.GetExtState( "AddVibratoPitchBend", "BendVariation")

if ( numVibrato == "") then numVibrato  = "5" end
if ( maxBend == "") then maxBend = "100" end
if ( bendVariation == "") then bendVariation = "5" end

userOK, userInputCSV = reaper.GetUserInputs("Add Vibrato", 3, "Number of vibrato, Range as a percentage, Variation of range as percentage", numVibrato .. ',' .. maxBend .. ',' .. bendVariation )
    if not userOK then return reaper.SN_FocusMIDIEditor() end
    numVibrato, maxBend, bendVariation = userInputCSV:match("(%d*),(%d*),(%d*)")
    if not tonumber(numVibrato) or not tonumber( maxBend ) or not tonumber( bendVariation )  then return reaper.SN_FocusMIDIEditor() end

-- Enforce number ranges before saving
--if  numVibrato < 1 then numVibrato = 1 end
--if numVibrato > 1000 then numVibrato = 1000 end
--if maxBend < 0 then maxBend = 0 end
--if maxBend > 100 then maxBend = 100 end
--if bendVariation < 0 then bendVariation = 0 end
--if bendVariation > 100 then bendVariation = 100 end

    reaper.SetExtState("AddVibratoPitchBend", "NumberVibrato", numVibrato , false)
    reaper.SetExtState( "AddVibratoPitchBend", "MaxBend", maxBend, false)
    reaper.SetExtState( "AddVibratoPitchBend", "BendVariation", bendVariation, false)

-- Before inserting cc events need to select all events so can delete cc events in time range of our note 
reaper.MIDI_SelectAll( take, true )

--Remove any 224 cc events between start and end of our selected note on same channel as our original note  
selEvent = reaper.MIDI_EnumSelEvts( take, -1 )
while selEvent ~= -1 do 
--Get cc general info
  retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC( take, selEvent )

if ppqpos >= startPPQ and ppqpos <= endPPQ and chanmsg == 224 and channel == chan then
  reaper.MIDI_DeleteCC( take, selEvent ) 
    selEvent = selEvent -1 
end

  --Go onto the next selected event
  selEvent = reaper.MIDI_EnumSelEvts( take, selEvent )
end

--Set up a loop to insert pairs of cc pitch bend events which start at centre and go to upper limit
-- Then we will add one more at the end.
ppqInterval = ( endPPQ - startPPQ ) / numVibrato 
for i = 0, numVibrato - 1 do
-- First insert a pitch bend at start of slot 
  ppq =   startPPQ + i * ppqInterval
--  sText = sText .. "Bend " .. i .. " has start pos " .. ppq
reaper.MIDI_InsertCC(take, 
  true,--boolean selected, 
  false,--boolean muted, 
  ppq,  --number ppqpos, 
  224,--integer chanmsg,  indicating a pitch bend 
  channel,--integer chan, 
  0,   -- msg2  lsb 
  64, --msg3 msb 
  true )  -- no sorting   

--Now insert the high pitch bends
  -- Calculate a variation for the amount of bend
  bendToDo = maxBend + maxBend * ( bendVariation / 100 ) * ( 2 * ( math.random()- 0.5 ) )
  if bendToDo < 0 then bendToDo = 0 end
  if bendToDo > 100 then bendToDo = 100 end 
bend14bit = 8192 + bendToDo  * 8192 / 100 - 1


bendMSB = math.floor( bend14bit / 128 )
bendLSB = math.floor( bend14bit  % 128  )
  ppq = startPPQ + i * ppqInterval + ppqInterval /2
  reaper.MIDI_InsertCC(take, 
    true,--boolean selected, 
    false,--boolean muted, 
    ppq,  --number ppqpos, 
    224,--integer chanmsg,  indicating a pitch bend 
    channel,--integer chan, 
    bendLSB,   -- msg2  lsb 
    bendMSB, --msg3 msb 
    true )  -- no sorting   

end --Vibrato number loop 

--Add the final pitch bend to put us back to centre
reaper.MIDI_InsertCC(take, 
  true,--boolean selected, 
  false,--boolean muted, 
  endPPQ,  --number ppqpos, 
  224,--integer chanmsg,  indicating a pitch bend 
  channel,--integer chan, 
  0,   -- msg2  lsb 
  64, --msg3 msb 
  true )  -- no sorting   


--Enumerate through ccevents and set shape if the ppq is in range of our initially selected note 
reaper.MIDI_Sort(take)
selEvent = reaper.MIDI_EnumSelEvts( take, -1 )
while selEvent ~= -1 do 
  --Get shape info
  _, shape, beztension = reaper.MIDI_GetCCShape( take, selEvent )

--Get cc general info
  retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC( take, selEvent )

  --Set shape info if is a 224 channel message and in range  and on same channel as our original note 
  if ppqpos>= startPPQ and ppqpos <= endPPQ and chanmsg == 224 and channel == chan then
    --Last cc event gets a different shape 
    if ppqpos == endPPQ then shapeID = 0 else shapeID = 4 end 
    reaper.MIDI_SetCCShape( take, selEvent, shapeID, beztension, true )
  end 

  --Go onto the next selected event
  selEvent = reaper.MIDI_EnumSelEvts( take, selEvent )
end

-- Tidy up by unselecting all events and then selecting the note we were working on 
reaper.MIDI_SelectAll( take, false )
reaper.MIDI_SetNote( take, selNote, true )

--Tidy up 
  reaper.Undo_EndBlock( "Add vibrato pitch bends", 4)
reaper.UpdateItemInProject(item)
end
  
main()
