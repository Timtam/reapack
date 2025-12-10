-- @description Copy times and names of project markers to clipboard
-- @version 1.0
-- @about Copies project marker times and names to clipboard, formatted ready for pasting chapters into the Description field of YouTube videos.
--   Requires SWS for CF_SetClipboard and uses OSARA to provide speech feedback.
-- @Author X-Raym and Scott Chesworth
-- @changelog
--   Initial release

function main()
  local output = "" -- collect all marker lines here

  -- LOOP THROUGH REGIONS
  local i = 0
  repeat
    local iRetval, bIsrgnOut, iPosOut, _, sNameOut = reaper.EnumProjectMarkers3(0,i)
    if iRetval >= 1 then
      if not bIsrgnOut then
        local abs_pos = tonumber(reaper.format_timestr_pos(math.floor(iPosOut), "", 3))
        if abs_pos and abs_pos >= 0 then
          local pos = reaper.format_timestr_pos(math.floor(iPosOut), "", 5)
          pos = pos:sub(2, -4)
          local marker = { name = sNameOut, pos = pos }
          table.insert(markers, marker)
          if abs_pos >= 3600 then hour = true end
        end
      end
      i = i + 1
    end
  until iRetval == 0

  for _, marker in ipairs(markers) do
    local pos = hour and marker.pos or marker.pos:sub(3)
    output = output .. pos .. " - " .. marker.name .. "\n"
  end

  -- Copy final string to clipboard (SWS required)
  reaper.CF_SetClipboard(output)

  -- Report feedback with OSARA
  local count = #markers
  if count > 0 then
    reaper.osara_outputMessage(count .. (count == 1 and " marker copied to clipboard" or " markers copied to clipboard"))
  end
end

-- INIT ---------------------------------------------------------------------

local _, num_markers, _ = reaper.CountProjectMarkers(-1)
if num_markers > 0 then
  reaper.PreventUIRefresh(1)
  reaper.Undo_BeginBlock()

  markers = {}
  main()

  reaper.Undo_EndBlock("Copy times and names of project markers to clipboard", -1)
  reaper.UpdateArrange()
  reaper.PreventUIRefresh(-1)
else
  -- Speak when no markers exist
  reaper.osara_outputMessage("Add project markers first, then run me")
end
-- Main function
function main()
  local output = "" -- collect all marker lines here

  -- LOOP THROUGH REGIONS
  local i = 0
  repeat
    local iRetval, bIsrgnOut, iPosOut, iRgnendOut, sNameOut = reaper.EnumProjectMarkers3(0,i)
    if iRetval >= 1 then
      if not bIsrgnOut then
        local abs_pos = tonumber(reaper.format_timestr_pos(math.floor(iPosOut), "", 3))
        if abs_pos and abs_pos >= 0 then
          local pos = reaper.format_timestr_pos(math.floor(iPosOut), "", 5)
          pos = pos:sub(2, -4)
          local marker = { name = sNameOut, pos = pos }
          table.insert(markers, marker)
          if abs_pos >= 3600 then hour = true end
        end
      end
      i = i + 1
    end
  until iRetval == 0

  for _, marker in ipairs(markers) do
    local pos = hour and marker.pos or marker.pos:sub(3)
    output = output .. pos .. " - " .. marker.name .. "\n"
  end

  -- Copy final string to clipboard (SWS required)
  reaper.CF_SetClipboard(output)
end

-- INIT ---------------------------------------------------------------------

local _, num_markers, _ = reaper.CountProjectMarkers(-1)
if num_markers > 0 then
  reaper.PreventUIRefresh(1)
  reaper.Undo_BeginBlock()

  markers = {}
  main()

  reaper.Undo_EndBlock("Export markers as YouTube timecode for video description", -1)
  reaper.UpdateArrange()
  reaper.PreventUIRefresh(-1)
end
