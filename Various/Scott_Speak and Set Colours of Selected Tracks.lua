-- @description Speak and Set Colours of Selected Tracks (press once to speak, twice quickly to set)
-- @version 1.0
-- @about Bind this to a keystroke, then press once to speak the colour of selected tracks through OSARA, press twice quickly to load an accessible menu of custom colours.
-- @author Scott Chesworth
-- @changelog
--   Initial release

local SCRIPT_TITLE = "Selected track colour menu"
local MENU_TITLE = "Choose a colour"
local EXTSTATE_SECTION = "TrackColourMenu"
local EXTSTATE_KEY = "LastInvokeTime"
local DOUBLE_PRESS_WINDOW = 0.5

-- Fixed palette used for both reporting and menu choices.
-- "Clear custom colour" menu entry is hidden when selected tracks are already Default.
local PALETTE = {
  { name = "Clear custom colour", clear = true, native = 0 },
  { name = "Red", rgb = { 224, 60, 49 } },
  { name = "Orange", rgb = { 214, 97, 0 } },
  { name = "Yellow", rgb = { 241, 196, 15 } },
  { name = "Green", rgb = { 34, 139, 34 } },
  { name = "Cyan", rgb = { 26, 188, 156 } },
  { name = "Blue", rgb = { 38, 98, 185 } },
  { name = "Purple", rgb = { 110, 64, 170 } },
  { name = "Pink", rgb = { 236, 112, 160 } },
  { name = "Brown", rgb = { 160, 106, 66 } },
  { name = "Grey", rgb = { 105, 105, 105 } },
  { name = "White", rgb = { 245, 245, 245 } },
  { name = "Black", rgb = { 35, 35, 35 } },
}

for i = 1, #PALETTE do
  local entry = PALETTE[i]
  if not entry.clear then
    entry.native = reaper.ColorToNative(entry.rgb[1], entry.rgb[2], entry.rgb[3]) | 0x1000000
  end
end

-- OSARA is preferred for speech. If it is not available, fall back to printing in REAPER's console.
function Speak(str)
  if reaper.osara_outputMessage then
    reaper.osara_outputMessage(str)
  else
    reaper.ShowConsoleMsg(str .. "\n")
  end
end

-- gfx.showmenu is used for the colour picker because it is accessible on Windows and Mac.
local function prompt_menu(title, menu_text)
  local mouse_x, mouse_y = reaper.GetMousePosition()
  gfx.init(title, 1, 1, 0, mouse_x, mouse_y)
  gfx.x = 0
  gfx.y = 0

  local choice = gfx.showmenu(menu_text)
  gfx.quit()

  return choice
end

-- Gather the current track selection.
-- The master track has to be checked separately because it is not always included in the
-- normal selected-track enumeration, even though REAPER can report it as selected.
local function get_selected_tracks()
  local tracks = {}
  local count = reaper.CountSelectedTracks(0)

  for i = 0, count - 1 do
    tracks[#tracks + 1] = reaper.GetSelectedTrack(0, i)
  end

  local master_track = reaper.GetMasterTrack(0)
  if master_track and reaper.IsTrackSelected(master_track) then
    tracks[#tracks + 1] = master_track
  end

  return tracks
end

-- Track names may be blank, so provide a readable fallback for confirmations/prompts.
local function get_track_name(track)
  local ok, name = reaper.GetTrackName(track)
  if ok and name ~= "" then
    return name
  end

  local track_number = math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER"))
  if track_number > 0 then
    return string.format("Track %d", track_number)
  end

  return "Unnamed track"
end

-- For folder-aware expansion, we treat either the folder parent itself or its immediate containing folder as the expansion root.
local function get_folder_root(track)
  if reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") > 0 then
    return track
  end

  return reaper.GetParentTrack(track)
end

-- Collect every track that belongs to a folder, including the folder parent itself.
-- We walk forward until REAPER reports a track depth at or above the folder root depth.
local function get_folder_tracks(folder_root)
  local tracks = {}
  local root_index = math.floor(reaper.GetMediaTrackInfo_Value(folder_root, "IP_TRACKNUMBER")) - 1
  local root_depth = reaper.GetTrackDepth(folder_root)
  local total_tracks = reaper.CountTracks(0)

  for i = root_index, total_tracks - 1 do
    local track = reaper.GetTrack(0, i)

    if i > root_index and reaper.GetTrackDepth(track) <= root_depth then
      break
    end

    tracks[#tracks + 1] = track
  end

  return tracks
end

-- Expand any selected folder-related tracks into the full folder contents, but preserve
-- ordering and remove duplicates when multiple selected tracks resolve to the same folder.
local function get_folder_expansion(tracks)
  local track_set = {}
  local ordered_tracks = {}
  local folder_count = 0

  for i = 1, #tracks do
    local folder_root = get_folder_root(tracks[i])

    if folder_root then
      folder_count = folder_count + 1

      local folder_tracks = get_folder_tracks(folder_root)
      for j = 1, #folder_tracks do
        local track = folder_tracks[j]
        if not track_set[track] then
          track_set[track] = true
          ordered_tracks[#ordered_tracks + 1] = track
        end
      end
    else
      local track = tracks[i]
      if not track_set[track] then
        track_set[track] = true
        ordered_tracks[#ordered_tracks + 1] = track
      end
    end
  end

  return ordered_tracks, folder_count > 0 and #ordered_tracks > #tracks
end

-- REAPER uses 0 for "no custom colour", but black is a special case that still carries
-- the 0x1000000 usage flag. Normalising here keeps black distinct from Default.
local function normalize_track_color(track_color)
  if track_color == 0 then
    return 0
  end

  if track_color == 0x1000000 then
    return 0x1000000
  end

  return (track_color & 0xFFFFFF) | 0x1000000
end

-- Return both the overall selection state and the matching palette index, if any.
-- This keeps the menu pre-check and spoken reporting in sync without re-scanning later.
local function get_selection_color_info(tracks)
  local first_color = nil

  for i = 1, #tracks do
    local color = normalize_track_color(reaper.GetTrackColor(tracks[i]))

    if first_color == nil then
      first_color = color
    elseif color ~= first_color then
      return "mixed", nil, nil
    end
  end

  if first_color == nil then
    return "none", nil, nil
  end

  for i = 1, #PALETTE do
    if PALETTE[i].native == first_color then
      return "uniform", first_color, i
    end
  end

  return "uniform", first_color, nil
end

-- Build the popup menu text and keep a parallel list of the visible entries so the menu
-- result can be mapped back safely even when "Clear custom colour" is omitted.
local function build_menu(current_index, include_clear)
  local items = {}
  local visible_entries = {}

  for i = 1, #PALETTE do
    local entry = PALETTE[i]

    if include_clear or not entry.clear then
      local prefix = current_index == i and "!" or ""
      items[#items + 1] = prefix .. entry.name
      visible_entries[#visible_entries + 1] = entry
    end
  end

  return table.concat(items, "|"), visible_entries
end

-- Friendly spoken/reporting text for the currently detected colour state.
local function describe_current_colour(state, color_value, palette_index)
  if state == "mixed" then
    return "mixed colours"
  end

  if color_value == 0 then
    return "Default"
  end

  if palette_index then
    return PALETTE[palette_index].name
  end

  local r, g, b = reaper.ColorFromNative(color_value & 0xFFFFFF)
  return string.format("custom RGB %d, %d, %d", r, g, b)
end

-- Apply the chosen colour to every target track and wrap the operation in one undo point.
-- Writing I_CUSTOMCOLOR directly avoids the black/default ambiguity seen with raw zero.
local function apply_colour_to_tracks(tracks, entry)
  reaper.Undo_BeginBlock()

  for i = 1, #tracks do
    reaper.SetMediaTrackInfo_Value(tracks[i], "I_CUSTOMCOLOR", entry.clear and 0 or entry.native)
  end

  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()

  local undo_name = entry.clear and "Clear selected track custom colours"
    or ("Set selected track custom colour to " .. entry.name)
  reaper.Undo_EndBlock(undo_name, -1)
end

local function get_status_text(tracks, state, current_text)
  if #tracks == 1 then
    return current_text
  end

  if state == "mixed" then
    return string.format("%d tracks with mixed colours", #tracks)
  end

  return string.format("%d %s tracks", #tracks, current_text)
end

local function confirmation_text(tracks, entry)
  local target = #tracks == 1 and get_track_name(tracks[1]) or string.format("%d tracks", #tracks)
  return string.format("Made %s %s", target, entry.clear and "Default" or entry.name)
end

-- If the selection is a folder parent or sits inside a folder, offer to expand the target
-- set to that folder's contents before applying the chosen colour.
local function should_expand_to_folders(tracks)
  local expanded_tracks, has_folder_context = get_folder_expansion(tracks)
  if not has_folder_context then
    return tracks
  end

  local folder_root = get_folder_root(tracks[1])
  local folder_label = "this folder"
  if folder_root then
    local folder_name = get_track_name(folder_root)
    folder_label = reaper.GetParentTrack(folder_root) and (folder_name .. " nested folder")
      or (folder_name .. " folder")
  end
  local folder_track_count = folder_root and #get_folder_tracks(folder_root) or #expanded_tracks

  local prompt = string.format("Apply to %d tracks in %s?", folder_track_count, folder_label)
  local result = reaper.ShowMessageBox(prompt, MENU_TITLE, 4)

  if result == 6 then
    return expanded_tracks
  end

  return tracks
end

-- Main flow:
-- 1. Validate the selection and reject unsupported master-track use.
-- 2. On first run, report the current colour state.
-- 3. On a second run within the timeout, open the colour menu.
local tracks = get_selected_tracks()
if #tracks == 0 then
  Speak("No selected tracks")
  return
end

local master_track = reaper.GetMasterTrack(0)
for i = 1, #tracks do
  if tracks[i] == master_track then
    Speak("Master track is not supported")
    return
  end
end

local state, color_value, current_index = get_selection_color_info(tracks)
local current_text = describe_current_colour(state, color_value, current_index)
local now = reaper.time_precise()
local last_invoke = tonumber(reaper.GetExtState(EXTSTATE_SECTION, EXTSTATE_KEY)) or 0
local open_menu = (now - last_invoke) <= DOUBLE_PRESS_WINDOW
local include_clear = state ~= "uniform" or color_value ~= 0

-- Persist the current run time so a quick second invocation can open the menu.
reaper.SetExtState(EXTSTATE_SECTION, EXTSTATE_KEY, tostring(now), false)

if not open_menu then
  Speak(get_status_text(tracks, state, current_text))
  return
end

-- Once the menu path is taken, clear the stored time so later runs do not inherit a stale double-press state.
reaper.SetExtState(EXTSTATE_SECTION, EXTSTATE_KEY, "0", false)

local menu_text, visible_entries = build_menu(current_index, include_clear)
local choice = prompt_menu(MENU_TITLE, menu_text)

if choice <= 0 then
  return
end

local entry = visible_entries[choice]
if not entry then
  Speak("The menu returned an invalid choice")
  return
end

local target_tracks = should_expand_to_folders(tracks)
apply_colour_to_tracks(target_tracks, entry)
Speak(confirmation_text(target_tracks, entry))
