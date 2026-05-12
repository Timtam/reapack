-- @description Transpose selected MIDI notes excluding chosen notes
-- @version 1.0
-- @author Scott Chesworth
-- @about
--   Prompts for a semitone transpose amount and notes to exclude.
--   
--   Acts on selected notes. CC and other MIDI events are untouched.
-- @changelog
--   Initial release
-- @provides [main=midi_editor] .

local NOTE_NAMES = {
  c = 0,
  ["c#"] = 1,
  db = 1,
  d = 2,
  ["d#"] = 3,
  eb = 3,
  e = 4,
  f = 5,
  ["f#"] = 6,
  gb = 6,
  g = 7,
  ["g#"] = 8,
  ab = 8,
  a = 9,
  ["a#"] = 10,
  bb = 10,
  b = 11
}

local function trim(value)
  return value:match("^%s*(.-)%s*$")
end

local function parse_excluded_notes(input)
  local pitch_classes = {}
  local exact_pitches = {}

  for token in input:gmatch("[^,%s;]+") do
    token = trim(token):lower()

    local midi_note = tonumber(token)
    if midi_note and midi_note == math.floor(midi_note) and midi_note >= 0 and midi_note <= 127 then
      exact_pitches[midi_note] = true
    else
      local note_name, octave = token:match("^([a-g][#b]?)(%-?%d*)$")
      if note_name and NOTE_NAMES[note_name] then
        if octave and octave ~= "" then
          local exact_pitch = (tonumber(octave) + 1) * 12 + NOTE_NAMES[note_name]
          if exact_pitch >= 0 and exact_pitch <= 127 then
            exact_pitches[exact_pitch] = true
          end
        else
          pitch_classes[NOTE_NAMES[note_name]] = true
        end
      end
    end
  end

  return pitch_classes, exact_pitches
end

local function pitch_is_excluded(pitch, pitch_classes, exact_pitches)
  return exact_pitches[pitch] or pitch_classes[pitch % 12]
end

local function restore_midi_editor_focus(editor)
  reaper.defer(function()
    if reaper.SN_FocusMIDIEditor then
      reaper.PreventUIRefresh(1)
      reaper.SN_FocusMIDIEditor()
      reaper.PreventUIRefresh(-1)
    elseif reaper.JS_Window_SetFocus then
      reaper.JS_Window_SetFocus(editor)
    end
  end)
end

local editor = reaper.MIDIEditor_GetActive()
if not editor then
  reaper.ShowMessageBox("Open a MIDI editor before running this script.", "Transpose selected notes", 0)
  return
end

local take = reaper.MIDIEditor_GetTake(editor)
if not take or not reaper.TakeIsMIDI(take) then
  reaper.ShowMessageBox("The active MIDI editor does not have a MIDI take.", "Transpose selected notes", 0)
  restore_midi_editor_focus(editor)
  return
end

local item = reaper.GetMediaItemTake_Item(take)
local track = reaper.GetMediaItemTrack(item)

local ok, values = reaper.GetUserInputs(
  "Transpose selected notes",
  2,
  "Transpose semitones:,Exclude notes:",
  "0,"
)

if not ok then
  restore_midi_editor_focus(editor)
  return
end

local transpose_text, exclude_text = values:match("([^,]*),(.*)")
transpose_text = trim(transpose_text or "")
exclude_text = trim(exclude_text or "")

local transpose_amount = tonumber(transpose_text)
if not transpose_amount or transpose_amount ~= math.floor(transpose_amount) then
  reaper.ShowMessageBox("Transpose amount must be a whole number of semitones.", "Transpose selected notes", 0)
  restore_midi_editor_focus(editor)
  return
end

local excluded_pitch_classes, excluded_exact_pitches = parse_excluded_notes(exclude_text)
local _, note_count = reaper.MIDI_CountEvts(take)
local changes = {}

for note_index = 0, note_count - 1 do
  local retval, selected, muted, startppqpos, endppqpos, channel, pitch, velocity =
    reaper.MIDI_GetNote(take, note_index)

  if retval and selected and not pitch_is_excluded(pitch, excluded_pitch_classes, excluded_exact_pitches) then
    local new_pitch = pitch + transpose_amount
    if new_pitch < 0 then
      new_pitch = 0
    elseif new_pitch > 127 then
      new_pitch = 127
    end

    if new_pitch ~= pitch then
      changes[#changes + 1] = {
        note_index = note_index,
        selected = selected,
        muted = muted,
        startppqpos = startppqpos,
        endppqpos = endppqpos,
        channel = channel,
        pitch = new_pitch,
        velocity = velocity
      }
    end
  end
end

if #changes == 0 then
  reaper.ShowMessageBox("No selected notes were transposed.", "Transpose selected notes", 0)
  restore_midi_editor_focus(editor)
  return
end

reaper.MIDI_DisableSort(take)

for _, change in ipairs(changes) do
  reaper.MIDI_SetNote(
    take,
    change.note_index,
    change.selected,
    change.muted,
    change.startppqpos,
    change.endppqpos,
    change.channel,
    change.pitch,
    change.velocity,
    true
  )
end

reaper.MIDI_Sort(take)
reaper.MarkTrackItemsDirty(track, item)
reaper.UpdateItemInProject(item)
reaper.Undo_OnStateChange_Item(0, "Transpose selected MIDI notes excluding chosen notes", item)
restore_midi_editor_focus(editor)
