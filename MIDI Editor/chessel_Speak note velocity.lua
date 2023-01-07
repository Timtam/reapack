-- @version 1.0
-- @author Chessel (Chris Goodwin)
-- @description Speak the first selected note velocity 
-- @about Announces the velocity of the first selected midi note 

function Speak( str )
 if reaper.osara_outputMessage then
    reaper.osara_outputMessage(str)
  end
end


function main()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if take == nil then return end

  local val = reaper.MIDI_EnumSelNotes(take, -1)
  if val ~= -1 then
    local _, _, _, _, _, _, _, vel = reaper.MIDI_GetNote(take, val)
    Speak (vel )
  end
end
main()