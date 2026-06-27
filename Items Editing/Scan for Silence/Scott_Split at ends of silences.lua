-- @noindex
-- @description Split at ends of silences (selected items, tracks, or time selection)

-- Implementation note:
-- Uses the same peak-cache silence detection as the Scan for Silence movers
-- (GetMediaItemTake_Peaks), but scans the whole item and splits at the END of
-- every qualifying silence (where audio resumes). Threshold and duration come
-- from the shared Configure scan for silence settings.

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

-- Returns a list of { start_src = , end_src = } in source seconds for every
-- qualifying silence in [src_from, src_end].
local function collect_silences(take, ch, src_from, src_end, threshold_amp,
    silence_src_dur)
  local bin_dur = 1 / PEAKRATE
  local bins_needed = math.ceil(silence_src_dur * PEAKRATE)
  local total_bins = math.floor((src_end - src_from) / bin_dur)
  local runs = {}
  if total_bins < 1 then return runs end

  local buf = reaper.new_array(CHUNK * ch * 2)
  local silent_run = 0
  local run_start = nil
  local processed = 0

  while processed < total_bins do
    local want = math.min(CHUNK, total_bins - processed)
    local ret = reaper.GetMediaItemTake_Peaks(take, PEAKRATE,
      src_from + processed * bin_dur, ch, want, 0, buf)
    local got = ret & 0xFFFFF
    if got == 0 then break end
    local min_base = want * ch
    local t = buf.table() -- bulk copy: far faster than per-element array indexing
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
        if silent_run == 0 then run_start = processed + s end
        silent_run = silent_run + 1
      else
        if silent_run >= bins_needed then
          runs[#runs + 1] = {
            start_src = src_from + run_start * bin_dur,
            end_src = src_from + (processed + s) * bin_dur,
          }
        end
        silent_run = 0
        run_start = nil
      end
    end
    processed = processed + got
  end

  if silent_run >= bins_needed then
    runs[#runs + 1] = {
      start_src = src_from + run_start * bin_dur,
      end_src = src_from + total_bins * bin_dur,
    }
  end
  return runs
end

-- Snap a project-time position to the nearest zero crossing (channel 1) within a
-- few milliseconds, to avoid clicks at the cut. Reads a tiny sample window via
-- the take audio accessor (cheap). Returns the original position if no crossing
-- is found (e.g. in true digital silence, where a cut is click-free anyway).
local function snap_to_zero(accessor, sr, ch, proj_pos, item_start, item_end)
  local win = 0.005 -- search +/- 5 ms
  local lo = math.max(item_start, proj_pos - win)
  local hi = math.min(item_end, proj_pos + win)
  local nsamp = math.floor((hi - lo) * sr)
  if nsamp < 2 then return proj_pos end
  local buf = reaper.new_array(nsamp * ch)
  buf.clear()
  reaper.GetAudioAccessorSamples(accessor, sr, ch, lo, nsamp, buf)
  local center = (proj_pos - lo) * sr
  local best_i, best_dist = nil, nil
  local prev = buf[1] -- channel 1 of sample 0
  for i = 1, nsamp - 1 do
    local cur = buf[i * ch + 1] -- channel 1 of sample i
    if (prev < 0 and cur >= 0) or (prev > 0 and cur <= 0) then
      local dist = math.abs(i - center)
      if not best_dist or dist < best_dist then
        best_dist, best_i = dist, i
      end
    end
    prev = cur
  end
  if not best_i then return proj_pos end
  return lo + best_i / sr
end

-- Splits one item at the END of each qualifying silence falling within
-- [scan_lo, scan_hi] (project time, clamped to the item). Returns the number of
-- splits made. Non-audio items are skipped.
local function process_item(item, scan_lo, scan_hi, threshold_amp, silence_duration)
  local take = reaper.GetActiveTake(item)
  if not take or reaper.TakeIsMIDI(take) then return 0 end
  local source = reaper.GetMediaItemTake_Source(take)
  local ch = reaper.GetMediaSourceNumChannels(source)
  if ch < 1 then return 0 end
  local sr = reaper.GetMediaSourceSampleRate(source)

  local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_end = item_start + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local start_offs = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
  local playrate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
  if playrate == 0 then playrate = 1 end

  -- Restrict scanning to the requested range, clamped to the item.
  local lo = math.max(item_start, scan_lo)
  local hi = math.min(item_end, scan_hi)
  if hi <= lo then return 0 end

  local src_from = start_offs + (lo - item_start) * playrate
  local src_end = start_offs + (hi - item_start) * playrate
  local silence_src_dur = silence_duration * playrate

  local runs = collect_silences(take, ch, src_from, src_end, threshold_amp,
    silence_src_dur)

  -- Build split positions from silence ends, snapping each to the nearest zero
  -- crossing and keeping only those strictly inside the item.
  local accessor = reaper.CreateTakeAudioAccessor(take)
  local positions = {}
  for _, r in ipairs(runs) do
    local pos = item_start + (r.end_src - start_offs) / playrate
    if pos > item_start + 1e-9 and pos < item_end - 1e-9 then
      if accessor then
        pos = snap_to_zero(accessor, sr, ch, pos, item_start, item_end)
      end
      positions[#positions + 1] = pos
    end
  end
  if accessor then reaper.DestroyAudioAccessor(accessor) end

  -- Sort and drop near-duplicates so progressive splitting stays ordered.
  table.sort(positions)
  local clean = {}
  for _, p in ipairs(positions) do
    if #clean == 0 or p > clean[#clean] + 1e-6 then
      clean[#clean + 1] = p
    end
  end
  positions = clean

  -- Split progressively, carrying the right-hand piece forward.
  local cur = item
  local count = 0
  for _, pos in ipairs(positions) do
    local right = reaper.SplitMediaItem(cur, pos)
    if right then
      cur = right
      count = count + 1
    end
  end
  return count
end

-- Gather the items to process for a context choice, plus the project-time scan
-- range to restrict to (whole item unless a time selection is used). Returns
-- items, scan_lo, scan_hi, err (items is nil and err set on failure).
local function gather_items(choice)
  local items = {}
  if choice == 1 then -- selected items
    local n = reaper.CountSelectedMediaItems(0)
    if n == 0 then return nil, nil, nil, "No items selected." end
    for i = 0, n - 1 do
      items[#items + 1] = reaper.GetSelectedMediaItem(0, i)
    end
    return items, -math.huge, math.huge
  elseif choice == 2 then -- all items on selected tracks
    local nt = reaper.CountSelectedTracks(0)
    if nt == 0 then return nil, nil, nil, "No tracks selected." end
    for i = 0, nt - 1 do
      local tr = reaper.GetSelectedTrack(0, i)
      for j = 0, reaper.CountTrackMediaItems(tr) - 1 do
        items[#items + 1] = reaper.GetTrackMediaItem(tr, j)
      end
    end
    if #items == 0 then return nil, nil, nil, "No items on the selected tracks." end
    return items, -math.huge, math.huge
  else -- all items within the time selection
    local ts_start, ts_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    if ts_end <= ts_start then return nil, nil, nil, "No time selection." end
    for t = 0, reaper.CountTracks(0) - 1 do
      local tr = reaper.GetTrack(0, t)
      for j = 0, reaper.CountTrackMediaItems(tr) - 1 do
        local it = reaper.GetTrackMediaItem(tr, j)
        local istart = reaper.GetMediaItemInfo_Value(it, "D_POSITION")
        local iend = istart + reaper.GetMediaItemInfo_Value(it, "D_LENGTH")
        if istart < ts_end and iend > ts_start then
          items[#items + 1] = it
        end
      end
    end
    if #items == 0 then return nil, nil, nil, "No items in the time selection." end
    return items, ts_start, ts_end
  end
end

-- === MAIN ===
local _thr = reaper.GetExtState("SilenceFinder", "threshold_db")
local threshold_db = tonumber(_thr ~= "" and _thr or "-40")
local _dur = reaper.GetExtState("SilenceFinder", "silence_duration")
local silence_duration = tonumber(_dur ~= "" and _dur or "1.0")
local threshold_amp = 10 ^ (threshold_db / 20)

-- Choose what to operate on via an accessible popup menu.
gfx.init("Scan for Silence", 0, 0)
gfx.x, gfx.y = gfx.mouse_x, gfx.mouse_y
local choice = gfx.showmenu(
  "Selected items|All items on selected tracks|All items in time selection")
gfx.quit()
if choice == 0 then return end -- cancelled

local items, scan_lo, scan_hi, err = gather_items(choice)
if not items then Speak(err) return end

-- Brief phrases so the spoken feedback is quick to hear. scan_phrase: the
-- up-front cue. added_suffix: appended to "N items added" (empty for the items
-- context, since items are already the subject). location: where silences were
-- searched, used when none are found.
local scan_phrase = ({ "items", "tracks", "time selection" })[choice]
local ntracks = (choice == 2) and reaper.CountSelectedTracks(0) or 0
local tracks_phrase = ntracks .. (ntracks == 1 and " track" or " tracks")
local added_suffix = ({ "", " on " .. tracks_phrase, " in time selection" })[choice]
local location = ({ "in items", "on " .. tracks_phrase, "in time selection" })[choice]

-- Announce, then wait briefly (polling via defer) before the blocking scan, so
-- the screen reader reliably starts speaking the message first. A single defer
-- only gives one message-pump cycle, which isn't always enough on longer items.
Speak("Scanning " .. scan_phrase .. "...")

local announce_at = reaper.time_precise()
local function do_work()
  if reaper.time_precise() - announce_at < 0.2 then
    reaper.defer(do_work)
    return
  end
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  local total = 0
  for _, it in ipairs(items) do
    total = total + process_item(it, scan_lo, scan_hi, threshold_amp,
      silence_duration)
  end
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()

  if total > 0 then
    Speak(total .. (total == 1 and " item added" or " items added") .. added_suffix .. ".")
  else
    Speak("No silences found " .. location .. ".")
  end

  reaper.Undo_EndBlock("Split items at ends of silences using Scan for Silence script", -1)
end
reaper.defer(do_work)
