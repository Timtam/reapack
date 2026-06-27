-- @noindex
-- @description Move to end of next silence on selected track

-- Implementation note:
-- Operates on the selected track, flowing forward across its items: it finds
-- where audio resumes after the next silence at/after the cursor (continuing into
-- later items if needed), moves the edit cursor there, and selects the item it
-- lands in. Detection reads REAPER's peak data (GetMediaItemTake_Peaks, the
-- .reapeaks cache). Peaks reflect the raw source level.

-- === SPEECH OUTPUT ===
local function Speak(str)
  if reaper.osara_outputMessage then
    reaper.osara_outputMessage(str)
  else
    reaper.ShowConsoleMsg(str .. "\n")
  end
end

local PEAKRATE = 200 -- peak bins per source second (5 ms resolution)
local CHUNK = 4096 -- peak points requested per call

-- Speaks how far the cursor moved (from -> to) in the primary ruler format,
-- OSARA style, with direction. Used when relative-movement reporting is enabled.
local function report_movement(from, to)
  local dir = to >= from and "forward" or "back"
  local a, b = math.min(from, to), math.max(from, to)
  local function trim(x) return (string.format("%.3f", x):gsub("%.?0+$", "")) end
  local phrase
  if reaper.GetToggleCommandState(40367) == 1 or reaper.GetToggleCommandState(40366) == 1 then
    -- Measures.Beats: bars, beats, and the sub-beat fraction as percent.
    local beatA, measA, cml = reaper.TimeMap2_timeToBeats(0, a)
    local beatB, measB = reaper.TimeMap2_timeToBeats(0, b)
    local bars = measB - measA
    local beats = beatB - beatA
    if beats < 0 then bars = bars - 1; beats = beats + cml end
    -- Round to the nearest beat: the boundary is only resolved to ~5 ms (one peak
    -- bin), so sub-beat precision is just noise (e.g. "17 bars 3 beats 99 percent"
    -- for what is really 18 bars), and the bin grid shifts with the search start.
    local wb = math.floor(beats + 0.5)
    if wb >= cml then wb = wb - cml; bars = bars + 1 end
    local p = {}
    if bars > 0 then p[#p + 1] = bars .. (bars == 1 and " bar" or " bars") end
    if wb > 0 then p[#p + 1] = wb .. (wb == 1 and " beat" or " beats") end
    phrase = #p > 0 and table.concat(p, " ") or "0 beats"
  elseif reaper.GetToggleCommandState(40365) == 1 then
    -- Minutes:Seconds.
    local t = b - a
    local m = math.floor(t / 60)
    phrase = (m > 0 and (m .. (m == 1 and " minute " or " minutes ")) or "") ..
      trim(t - m * 60) .. " seconds"
  elseif reaper.GetToggleCommandState(40368) == 1 then
    -- Seconds.
    phrase = trim(b - a) .. " seconds"
  else
    -- Samples / frames / h:m:s:f / other: REAPER's ruler-formatted length.
    phrase = reaper.format_timestr_len(b - a, "", a, -1)
  end
  Speak(phrase .. " " .. dir)
end

-- Scans [scan_lo, scan_hi] (project time, clamped to the item) for the end of the
-- next qualifying silence (where audio resumes) and returns its project-time
-- position, or nil. A silence that runs to scan_hi without audio resuming returns
-- nil, so navigation flows on to the next item.
local function find_in_item(item, scan_lo, scan_hi, threshold_amp, silence_duration)
  local take = reaper.GetActiveTake(item)
  if not take or reaper.TakeIsMIDI(take) then return nil end
  local source = reaper.GetMediaItemTake_Source(take)
  local ch = reaper.GetMediaSourceNumChannels(source)
  if ch < 1 then return nil end
  local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_end = item_start + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local start_offs = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
  local playrate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
  if playrate == 0 then playrate = 1 end

  local lo = math.max(item_start, scan_lo)
  local hi = math.min(item_end, scan_hi)
  if hi <= lo then return nil end

  local src_from = start_offs + (lo - item_start) * playrate
  local src_end = start_offs + (hi - item_start) * playrate
  local silence_src_dur = silence_duration * playrate

  local bin_dur = 1 / PEAKRATE
  local bins_needed = math.ceil(silence_src_dur * PEAKRATE)
  local total_bins = math.floor((src_end - src_from) / bin_dur)
  if total_bins < 1 then return nil end

  local buf = reaper.new_array(CHUNK * ch * 2)
  local silent_bins = 0
  local in_silence = false
  local processed = 0
  while processed < total_bins do
    local want = math.min(CHUNK, total_bins - processed)
    local ret = reaper.GetMediaItemTake_Peaks(take, PEAKRATE,
      src_from + processed * bin_dur, ch, want, 0, buf)
    local got = ret & 0xFFFFF
    if got == 0 then break end
    local min_base = want * ch
    local t = buf.table()
    for s = 0, got - 1 do
      local base = s * ch
      local amp = 0
      for c = 1, ch do
        local mx = math.abs(t[base + c])
        local mn = math.abs(t[min_base + base + c])
        if mx > amp then amp = mx end
        if mn > amp then amp = mn end
      end
      if amp < threshold_amp then
        silent_bins = silent_bins + 1
        if silent_bins >= bins_needed then in_silence = true end
      else
        if in_silence then
          local found_src = src_from + (processed + s) * bin_dur
          return item_start + (found_src - start_offs) / playrate
        end
        silent_bins = 0
      end
    end
    processed = processed + got
  end
  return nil
end

-- === MAIN ===
local _thr = reaper.GetExtState("SilenceFinder", "threshold_db")
local threshold_db = tonumber(_thr ~= "" and _thr or "-40")
local _dur = reaper.GetExtState("SilenceFinder", "silence_duration")
local silence_duration = tonumber(_dur ~= "" and _dur or "1.0")
local threshold_amp = 10 ^ (threshold_db / 20)

local track = reaper.GetSelectedTrack(0, 0)
if not track then Speak("No track selected.") return end

local items = {}
for j = 0, reaper.CountTrackMediaItems(track) - 1 do
  items[#items + 1] = reaper.GetTrackMediaItem(track, j)
end
if #items == 0 then Speak("No items on track.") return end
table.sort(items, function(a, b)
  return reaper.GetMediaItemInfo_Value(a, "D_POSITION") <
    reaper.GetMediaItemInfo_Value(b, "D_POSITION")
end)

local was_playing = (reaper.GetPlayState() & 1) == 1
-- Forward movers search from the play cursor when playing, else the edit cursor.
local cursor = was_playing and reaper.GetPlayPosition() or reaper.GetCursorPosition()
-- Relative movement is measured from the edit cursor, which stays put during
-- playback (the play cursor keeps advancing, which would shrink the reported jump).
local edit_pos = reaper.GetCursorPosition()

-- Flow forward across the track: scan the cursor's item from the cursor, then
-- each later item from its start, until a silence end is found.
local result, found_item
for i = 1, #items do
  local it = items[i]
  local is = reaper.GetMediaItemInfo_Value(it, "D_POSITION")
  local ie = is + reaper.GetMediaItemInfo_Value(it, "D_LENGTH")
  if ie > cursor then
    result = find_in_item(it, math.max(cursor, is), ie, threshold_amp,
      silence_duration)
    if result then
      found_item = it
      break
    end
  end
end

if result then
  reaper.SetEditCurPos(result, true, true)
  reaper.SelectAllMediaItems(0, false)
  reaper.SetMediaItemSelected(found_item, true)
  reaper.UpdateArrange()
  if reaper.GetExtState("SilenceFinder", "report_relative") == "y" then
    report_movement(edit_pos, result)
  else
    reaper.Main_OnCommand(reaper.NamedCommandLookup("_OSARA_CURSORPOS"), 0)
  end
  if was_playing then reaper.OnPlayButton() end
else
  Speak("No silence found after the cursor.")
end
