-- @description Select tracks by status or type of content
-- @version 1.0
-- @about Shows a popup menu where you can select all tracks with statuses like empty or muted, and tracks with content like audio items or virtual instruments.
-- @author Scott Chesworth
-- @changelog
--   Initial release

-- Speak selection via OSARA
local function Speak(str)
  if reaper.osara_outputMessage then
    reaper.osara_outputMessage(str)
  end
end

-- Speak result counts with natural grammar
local function SpeakCount(label, count)
  if count == 0 then
    Speak("No " .. label .. " found.")
  elseif count == 1 then
    Speak("1 " .. label .. " selected.")
  else
    Speak(count .. " " .. label .. " selected.")
  end
end

-- Unselect all tracks
local function DeselectAllTracks()
  reaper.Main_OnCommand(40297, 0)
end

-- Check if track has routing
local function HasRouting(track)
  local sends = reaper.GetTrackNumSends(track, 0)
  local receives = reaper.GetTrackNumSends(track, -1)
  return (sends > 0 or receives > 0)
end

-- Armed tracks
local function SelectArmedTracks()
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  DeselectAllTracks()
  local count = 0
  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    if reaper.GetMediaTrackInfo_Value(track, "I_RECARM") == 1 then
      reaper.SetTrackSelected(track, true)
      count = count + 1
    end
  end
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Select armed tracks", -1)
  SpeakCount("armed tracks", count)
end

-- Empty tracks
local function SelectEmptyTracks()
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  DeselectAllTracks()
  local count = 0
  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local hasItems = reaper.CountTrackMediaItems(track) > 0
    local hasRouting = HasRouting(track)
    if not hasItems and not hasRouting then
      reaper.SetTrackSelected(track, true)
      count = count + 1
    end
  end
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Select empty tracks", -1)
  SpeakCount("empty tracks", count)
end

-- Folder tracks
local function SelectFolderTracks()
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  DeselectAllTracks()
  local count = 0
  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    if reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
      reaper.SetTrackSelected(track, true)
      count = count + 1
    end
  end
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Select folder tracks", -1)
  SpeakCount("folder tracks", count)
end

-- Muted tracks
local function SelectMutedTracks()
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  DeselectAllTracks()
  local count = 0
  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    if reaper.GetMediaTrackInfo_Value(track, "B_MUTE") == 1 then
      reaper.SetTrackSelected(track, true)
      count = count + 1
    end
  end
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Select muted tracks", -1)
  SpeakCount("muted tracks", count)
end

-- Soloed tracks
local function SelectSoloedTracks()
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  DeselectAllTracks()
  local count = 0
  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    if reaper.GetMediaTrackInfo_Value(track, "I_SOLO") > 0 then
      reaper.SetTrackSelected(track, true)
      count = count + 1
    end
  end
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Select soloed tracks", -1)
  SpeakCount("soloed tracks", count)
end

-- Audio or MIDI item tracks
local function SelectTracksByMediaType(isMIDI)
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  DeselectAllTracks()
  local count = 0
  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    for j = 0, reaper.CountTrackMediaItems(track) - 1 do
      local item = reaper.GetTrackMediaItem(track, j)
      local take = reaper.GetActiveTake(item)
      if take and reaper.TakeIsMIDI(take) == isMIDI then
        reaper.SetTrackSelected(track, true)
        count = count + 1
        break
      end
    end
  end
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  local label = isMIDI and "tracks with MIDI items" or "tracks with audio items"
  reaper.Undo_EndBlock("Select " .. label, -1)
  SpeakCount(label, count)
end

-- Virtual instrument tracks
local function SelectTracksWithInstruments()
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  DeselectAllTracks()
  local count = 0
  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    if reaper.TrackFX_GetInstrument(track) ~= -1 then
      reaper.SetTrackSelected(track, true)
      count = count + 1
    end
  end
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Select tracks with virtual instruments", -1)
  SpeakCount("tracks with virtual instruments", count)
end

-- Tracks with sends or receives
local function SelectTracksWithRouting()
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  DeselectAllTracks()
  local count = 0
  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    if HasRouting(track) then
      reaper.SetTrackSelected(track, true)
      count = count + 1
    end
  end
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Select tracks with routing", -1)
  SpeakCount("tracks with routing", count)
end

-- Tracks with any automation
local function SelectTracksWithAutomation()
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  DeselectAllTracks()
  local count = 0

  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local envCount = reaper.CountTrackEnvelopes(track)
    for j = 0, envCount - 1 do
      local env = reaper.GetTrackEnvelope(track, j)
      local armed = reaper.GetEnvelopeInfo_Value(env, "I_ARM") == 1
      local hasPoints = reaper.CountEnvelopePoints(env) > 0
      local hasAutoItems = reaper.CountAutomationItems(env) > 0
      if armed or hasPoints or hasAutoItems then
        reaper.SetTrackSelected(track, true)
        count = count + 1
        break
      end
    end
  end

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Select tracks with automation", -1)
  SpeakCount("tracks with envelopes", count)
end

-- Menu layout (with Automation sorted in)
local menu_options = {
  "#Select tracks that are...",
  "Armed",
  "Empty (has no media or routing)",
  "Folders",
  "Muted",
  "Soloed",
  "#Select all tracks with...",
  "Audio items",
  "Envelopes, points or auto-items",
  "MIDI items",
  "Routing (sends or receives)",
  "Virtual instruments"
}

-- Action mapping
local actions = {
  [2] = SelectArmedTracks,
  [3] = SelectEmptyTracks,
  [4] = SelectFolderTracks,
  [5] = SelectMutedTracks,
  [6] = SelectSoloedTracks,
  [8] = function() SelectTracksByMediaType(false) end, -- Audio
  [9] = SelectTracksWithAutomation,
  [10] = function() SelectTracksByMediaType(true) end, -- MIDI
  [11] = SelectTracksWithRouting,
  [12] = SelectTracksWithInstruments
}

-- Show popup menu
gfx.init("Track Selector Menu", 0, 0, 0, 0, 0)
local menu_str = table.concat(menu_options, "|")
local selection = gfx.showmenu(menu_str)
gfx.quit()

-- Run selected action
if actions[selection] then
  actions[selection]()
else
  Speak("Selection not changed")
end
