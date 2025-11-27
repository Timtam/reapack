-- @description ReaComp Sidechain Manager
-- @version 1.0
-- @about 
--   Provides a menu-based UI for making and managing sidechains with ReaComp.
-- @author CodyThePretender (Scott Chesworth)
-- @changelog
--   initial release

for key in pairs(reaper) do _G[key] = reaper[key] end

function Speak(str)
  if reaper.osara_outputMessage then
    reaper.osara_outputMessage(str)
  else
    reaper.ShowConsoleMsg(str .. "\n")
  end
end

function VF_CheckReaperVrs(rvrs, showmsg)
  local vrs_num = reaper.GetAppVersion()
  vrs_num = tonumber(vrs_num:match('[%d%.]+'))
  if rvrs > vrs_num then
    if showmsg then
      reaper.MB('You need to update REAPER before this script will work. Get version '..rvrs..' or newer.', '', 0)
    end
    return
  end
  return true
end

local defsendvol = 1

function EnumerateReaCompPresets()
  local track = reaper.GetMasterTrack(0)
  local fx = reaper.TrackFX_AddByName(track, "ReaComp (Cockos)", false, 1)
  if fx < 0 then return {}, {} end

  local seen, stock, user = {}, {}, {}
  local function read_preset()
    local _, nm = reaper.TrackFX_GetPreset(track, fx, "")
    return nm or ""
  end

  local function classify(name)
    local prefix = "stock - "
    if name:sub(1, #prefix) == prefix then
      table.insert(stock, name:sub(#prefix + 1))
    else
      table.insert(user, name)
    end
  end

  local first = read_preset()
  seen[first] = true
  classify(first)

  while true do
    if not reaper.TrackFX_NavigatePresets(track, fx, 1) then break end
    local name = read_preset()
    if seen[name] then break end
    seen[name] = true
    classify(name)
  end

  reaper.TrackFX_Delete(track, fx)
  return stock, user
end

function TrackNameOrNumber(tr)
  local _, nm = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
  if nm ~= "" then return nm end
  return "Track " .. math.floor(reaper.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER"))
end

function IsExcludedTrack(tr, exclude_trs)
  if not exclude_trs then return false end
  if type(exclude_trs) == "userdata" then
    return tr == exclude_trs
  elseif type(exclude_trs) == "table" then
    local tr_guid = reaper.GetTrackGUID(tr)
    for _, ex in ipairs(exclude_trs) do
      if reaper.GetTrackGUID(ex) == tr_guid then
        return true
      end
    end
  end
  return false
end

function BuildTrackMenu(exclude_trs, skip_selected, mode)
  local menu, items = "", {}
  local selected = {}
  for i = 0, reaper.CountSelectedTracks(0) - 1 do
    selected[reaper.GetSelectedTrack(0, i)] = true
  end

  local selected_list = {}
  for tr in pairs(selected) do table.insert(selected_list, tr) end

if mode ~= "dest" then
  if #selected_list > 1 then
    table.sort(selected_list, function(a, b)
      return reaper.GetMediaTrackInfo_Value(a, "IP_TRACKNUMBER") < reaper.GetMediaTrackInfo_Value(b, "IP_TRACKNUMBER")
    end)

    local names = {}
    for _, tr in ipairs(selected_list) do
      table.insert(names, TrackNameOrNumber(tr))
    end
    menu = menu .. "All selected tracks (" .. table.concat(names, ", ") .. ")|"
    table.insert(items, selected_list)

  elseif #selected_list == 1 then
    local name = TrackNameOrNumber(selected_list[1])
    menu = menu .. name .. " (selected)|"
    table.insert(items, selected_list)
  end
end

  for i = 0, reaper.CountTracks(0) - 1 do
    local tr = reaper.GetTrack(0, i)

    local skip = (skip_selected and selected[tr]) or IsExcludedTrack(tr, exclude_trs)
    if not skip then
      local _, name = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
      name = name ~= "" and name or ("Track " .. (i + 1))
      menu = menu .. name .. "|"
      table.insert(items, { tr })
    end
  end

  return menu, items
end

function PickSourceTracks()
  gfx.init("", 0, 0, 0, 0, 0)
  Speak("Choose source tracks, or hit Escape to cancel")
  local menu, items = BuildTrackMenu(nil, true)
  local choice = gfx.showmenu(menu)
  gfx.quit()
  if choice == 0 or not items[choice] then return nil end
  return items[choice]
end

function FlattenTrackList(list)
  local flat = {}
  for _, val in ipairs(list) do
    if type(val) == "userdata" then
      table.insert(flat, val)
    elseif type(val) == "table" then
      for _, sub in ipairs(val) do
        table.insert(flat, sub)
      end
    end
  end
  return flat
end

function PickDestinationTrack(prompt, exclude_tracks)
  gfx.init("", 0, 0, 0, 0, 0)
  Speak(prompt)
  local menu, items = BuildTrackMenu(exclude_tracks, false, "dest")
  local choice = gfx.showmenu(menu)
  gfx.quit()

  if choice == 0 or not items[choice] then return nil end
  return items[choice][1]
end

function PickReaCompPreset()
  local stock, user = EnumerateReaCompPresets()
  local menu = "Default Settings with Auxiliary detector input|"
  local preset_map = { [1] = "DEFAULT" }

  local idx = 2
  local item_count = 1  -- Tracks selectable items only (starts at 1 for "Default")

  if #stock > 0 then
    menu = menu .. ">Stock Presets|"
    for _, p in ipairs(stock) do
      menu = menu .. p .. "|"
      preset_map[idx] = "stock - " .. p
      idx = idx + 1
      item_count = item_count + 1
    end
    menu = menu .. "<|"
  end

  for _, p in ipairs(user) do
    menu = menu .. p .. "|"
    preset_map[idx] = p
    idx = idx + 1
    item_count = item_count + 1
  end

  gfx.init("", 0, 0, 0, 0, 0)
  Speak("Pick a ReaComp preset")
  local choice = gfx.showmenu(menu)
  gfx.quit()

  if choice == 0 then
    return false, nil
  end

  return true, preset_map[choice]
end

function FindExistingReaComp(tr)
  local fx_count = reaper.TrackFX_GetCount(tr)
  Speak("\nScanning track for sidechain comps...")  -- DEBUG: Start scan
  for i = 0, fx_count - 1 do
    local _, fx_name = reaper.TrackFX_GetFXName(tr, i, "")
    if fx_name:match("ReaComp") then
      local val = reaper.TrackFX_GetParam(tr, i, 8)
      Speak("ReaComp " .. i .. ": param8 = " .. tostring(val) .. ", name = '" .. fx_name .. "'")  -- DEBUG: Param{Name for each comp
      -- Check for exact Aux param + "sidechained from" in name
      local aux_val = 0.0018450184725225
      if math.abs(val - aux_val) < 1e-9 and fx_name:find("sidechained from") then
        Speak("Match found! Reusing comp at index " .. i)
        return i
      else
        Speak("No match for comp at index " .. i .. " (not sidechain)")  -- DEBUG: No match
      end
    end
  end
  Speak("No sidechain comp found— will add new one.")  -- DEBUG: No match for track
  return nil
end

function CollectSidechainSources(dest_tr)
  local sources = {}
  local recv = reaper.GetTrackNumSends(dest_tr, -1)

  for i = 0, recv - 1 do
    local src = reaper.GetTrackSendInfo_Value(dest_tr, -1, i, "P_SRCTRACK")
    local dstchan = reaper.GetTrackSendInfo_Value(dest_tr, -1, i, "I_DSTCHAN")
    if dstchan == 2 then
      local name = TrackNameOrNumber(src)
      local tracknum = math.floor(reaper.GetMediaTrackInfo_Value(src, "IP_TRACKNUMBER"))
      sources[#sources + 1] = { name = name, tracknum = tracknum }
    end
  end

  table.sort(sources, function(a,b) return a.tracknum < b.tracknum end)

  local out = {}
  for _, s in ipairs(sources) do out[#out + 1] = s.name end
  return out
end

function BuildReaCompName(list)
  if #list == 0 then return "ReaComp" end
  return "ReaComp sidechained from " .. table.concat(list, ", ")
end

function MPL_CreateReaCompSidechainRouting_addcomp(dest_tr, preset)
  local AUX = (1/1084)*2  -- Keep original (param 8 value for Aux input)
  local fx = reaper.TrackFX_AddByName(dest_tr, "ReaComp (Cockos)", false, 1)
  if preset and preset ~= "DEFAULT" then
    reaper.TrackFX_SetPreset(dest_tr, fx, preset)
  end
  reaper.TrackFX_SetParam(dest_tr, fx, 8, AUX)  -- Revert to param 8 (confirmed working for setting)
  
  local list = CollectSidechainSources(dest_tr)
  local name = BuildReaCompName(list)
  if VF_CheckReaperVrs(6.79, false) then
    reaper.TrackFX_SetNamedConfigParm(dest_tr, fx, "renamed_name", name)
  end
end

function MPL_CreateReaCompSidechainRouting_incresachan(dest_tr)
  local ch = reaper.GetMediaTrackInfo_Value(dest_tr, "I_NCHAN")
  reaper.SetMediaTrackInfo_Value(dest_tr, "I_NCHAN", math.max(4, ch))
end

function RoutingExists(src_tr, dest_tr)
  local destGUID = reaper.GetTrackGUID(dest_tr)
  for i = 0, reaper.GetTrackNumSends(src_tr, 0) - 1 do
    local ptr = reaper.GetTrackSendInfo_Value(src_tr, 0, i, "P_DESTTRACK")
    if reaper.GetTrackGUID(ptr) == destGUID then
      if reaper.GetTrackSendInfo_Value(src_tr, 0, i, "I_DSTCHAN") == 2 then
        return true
      end
    end
  end
  return false
end

function MPL_CreateReaCompSidechainRouting_addsend(src, dest)
  if RoutingExists(src, dest) then
    local sn = TrackNameOrNumber(src)
    local dn = TrackNameOrNumber(dest)
    reaper.MB("" .. sn .. " is already routed to " .. dn .. ".",
      "Uh, nope!", 0)
    return false
  end

  local id = reaper.CreateTrackSend(src, dest)
  reaper.SetTrackSendInfo_Value(src, 0, id, "D_VOL", defsendvol)
  reaper.SetTrackSendInfo_Value(src, 0, id, "I_SENDMODE", 3)
  reaper.SetTrackSendInfo_Value(src, 0, id, "I_DSTCHAN", 2)
  reaper.SetTrackSendInfo_Value(src, 0, id, "I_MIDIFLAGS", 31)
  return true
end

function RemoveSidechainSend(src_tr, dest_tr)
  local destGUID = reaper.GetTrackGUID(dest_tr)
  for i = 0, reaper.GetTrackNumSends(src_tr, 0) - 1 do
    local ptr = reaper.GetTrackSendInfo_Value(src_tr, 0, i, "P_DESTTRACK")
    if reaper.GetTrackGUID(ptr) == destGUID then
      local dstchan = reaper.GetTrackSendInfo_Value(src_tr, 0, i, "I_DSTCHAN")
      if dstchan == 2 then
        reaper.RemoveTrackSend(src_tr, 0, i)
        -- Collect updated sources and rename ReaComp if it exists
        local existing_fx = FindExistingReaComp(dest_tr)
        if existing_fx then
          local updated_list = CollectSidechainSources(dest_tr)
          local updated_name = BuildReaCompName(updated_list)
          if VF_CheckReaperVrs(6.79, false) then
            reaper.TrackFX_SetNamedConfigParm(dest_tr, existing_fx, "renamed_name", updated_name)
          end
        end
        return true  -- Indicate success
      end
    end
  end
  return false  -- No matching send found (can add logging if needed)
end

function main()
  local trackCount = reaper.CountTracks(0)
  if trackCount < 2 then
    reaper.MB(
      "There needs to be at least 2 tracks in your project to create a sidechain.",
      "Not enough tracks",
      0
    )
    return
  end

  local src_tracks = PickSourceTracks()
  if not src_tracks then return end

  local exclude_tracks = FlattenTrackList(src_tracks)
  local dest = PickDestinationTrack("Select Destination Track", exclude_tracks)
  if not dest then return end

  -- Check for and optionally remove already-existing routings
  local removed_sources = {}  -- Track names of sources where routing was removed
  local needs_routing = {}    -- Track sources that need new routing added
  for _, src in ipairs(src_tracks) do
    if RoutingExists(src, dest) then
      local src_name = TrackNameOrNumber(src)
      local dest_name = TrackNameOrNumber(dest)
      local choice = reaper.MB("Remove existing routing from " .. src_name .. " to " .. dest_name .. "?", "Already routed", 4)  -- 4 = Yes/No dialog
      if choice == 6 then  -- Yes (remove)
        if RemoveSidechainSend(src, dest) then  -- Only add to removed if successful
          table.insert(removed_sources, src_name)
        end
      else  -- No (quit)
        return  -- Exit with no changes
      end
    else
      table.insert(needs_routing, src)  -- This source needs new routing
    end
  end

  -- If no sources need new routing, skip to confirmation (removals were the only action)
  if #needs_routing == 0 then
    -- Handle selection and confirmation for removals only
    local selected_count = reaper.CountSelectedTracks(0)
    local is_dest_selected = false
    for i = 0, selected_count - 1 do
      if reaper.GetSelectedTrack(0, i) == dest then
        is_dest_selected = true
        break
      end
    end

    local selection_changed = false
    if not is_dest_selected then
      local move = reaper.MB("Move selection to destination track?", "", 4)
      if move == 6 then
        reaper.SetOnlyTrackSelected(dest)
        reaper.SetMixerScroll(dest)
        selection_changed = true
      end
    else
      reaper.SetMixerScroll(dest)
    end

    reaper.TrackList_AdjustWindows(false)

    if #removed_sources > 0 then
      local undo = "Routing removed from " .. table.concat(removed_sources, ", ") .. " to " .. TrackNameOrNumber(dest)
      local confirmation_report = undo
      if selection_changed then
        confirmation_report = confirmation_report .. ", " .. TrackNameOrNumber(dest) .. " selected"
      end
      Speak(confirmation_report)
      return undo
    else
      return  -- Nothing to do
    end
  end

  -- Proceed with new routing for remaining sources
  local added = false
  for _, src in ipairs(needs_routing) do
    if MPL_CreateReaCompSidechainRouting_addsend(src, dest) then
      added = true
    end
  end

  if not added then return end

  MPL_CreateReaCompSidechainRouting_incresachan(dest)

  local existing = FindExistingReaComp(dest)
  if not existing then
    -- No existing configured ReaComp found, so prompt for preset and add a new one
    local ok, preset = PickReaCompPreset()
    if not ok then return end
    MPL_CreateReaCompSidechainRouting_addcomp(dest, preset)
  else
    -- Existing configured ReaComp found, update its name only (no preset prompt)
    local list = CollectSidechainSources(dest)
    local name = BuildReaCompName(list)
    if VF_CheckReaperVrs(6.79, false) then
      reaper.TrackFX_SetNamedConfigParm(dest, existing, "renamed_name", name)
    end
  end

  -- Check selection as before
  local selected_count = reaper.CountSelectedTracks(0)
  local is_dest_selected = false
  for i = 0, selected_count - 1 do
    if reaper.GetSelectedTrack(0, i) == dest then
      is_dest_selected = true
      break
    end
  end

  local selection_changed = false
  if not is_dest_selected then
    local move = reaper.MB("Move selection to destination track?", "", 4)
    if move == 6 then
      reaper.SetOnlyTrackSelected(dest)
      reaper.SetMixerScroll(dest)
      selection_changed = true
    end
  else
    reaper.SetMixerScroll(dest)
  end

  reaper.TrackList_AdjustWindows(false)

  -- Handling confirmation with removals and new routing
  local source_names = {}
  for _, tr in ipairs(needs_routing) do table.insert(source_names, TrackNameOrNumber(tr)) end  -- Only include sources that were newly sidechained
  local undo = "Sidechained from " .. table.concat(source_names, ", ") .. " to " .. TrackNameOrNumber(dest)
  local confirmation_report = undo
  if #removed_sources > 0 then
    confirmation_report = confirmation_report .. ", removed routing from " .. table.concat(removed_sources, ", ")
  end
  if selection_changed then
    confirmation_report = confirmation_report .. ", " .. TrackNameOrNumber(dest) .. " selected"
  end
  Speak(confirmation_report)
  return undo
end

if VF_CheckReaperVrs(5.975, true) then
  reaper.Undo_BeginBlock()
  local undoname = main()
  reaper.Undo_EndBlock(undoname or "Create ReaComp sidechain routing", -1)
end
