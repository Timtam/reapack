-- @description Export MIDI sequence to Chesseq sequence file
-- @version 1.0
-- @author Chessel (Chris Goodwin) 
-- @changelog
--   initial release
-- @about
--   Utility to create a Chessel sequencer file.
--   In a midi item, create a series of notes.  There should be no chords though this won't break the script if there are.
--   Timing of the notes is not important, just their order.  The velocity of each note is also important when making up your sequence.
--   When ready, select all the notes and run this script.  You will get a Save As dialogue to save the txt file.
--   Once saved, copy it to the Reaper Resource folder, in Data/ChessSeq
--   You may need to create this subfolder.
--   The text file, or sequence, will now be available when using the Chessel Sequencer plugin.

function main()
--Create a text file in media folder  and open it for writing 
local retval, filename = reaper.JS_Dialog_BrowseForSaveFile( "Save As", reaper.GetProjectPath(), "", "Text files\0*.txt\0\0" )

if retval ~= 1 then return end 

--Needs a txt extension.  Add it if it isn't there already 
if filename ~= "" then
  -- Get the file extension from the filename
  local extension = string.match(filename, "%.([^%.]+)$")
  if extension and extension ~= "txt" then
    -- Replace the existing extension with ".txt"
    filename = filename:gsub("%."..extension.."$", "") .. ".txt"
  elseif not extension then
    -- Append ".txt" extension to the filename
    filename = filename .. ".txt"
  end
end
local handle = io.open( filename, "w" )

if handle == nil then return end

handle:write( "//Chessel sequence file\r"  )
handle:write( "//Each line is a step in the sequence defining the semitone offset from the root note\r" ) 

--Go through midi notes and write out the offset and velocity
--First check there is an active take 
local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if take == nil then return end

--Populate index array with notes 
local cnt, index = 0, {}
local val = reaper.MIDI_EnumSelNotes(take, -1)
while val ~= - 1 do
  cnt = cnt + 1
  index[cnt] = val
  val = reaper.MIDI_EnumSelNotes(take, val)
end

--Go through the note array  extracting the pitch and velocity and writing this to file
local rootNote = -1
for i = 1, #index do
  local _, _, _, _, _, _, pitch, vel = reaper.MIDI_GetNote(take, index[i])
if rootNote == -1 then 
  rootNote = pitch 
end
  handle:write( pitch-rootNote .. "," .. vel .. "\r" )
end 
handle:close()
  end

main()