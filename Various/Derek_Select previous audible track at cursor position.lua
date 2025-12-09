-- @description Select previous audible track at cursor position
-- @version 1.1
-- @about Identifies and selects the previous audible track, reporting its name and peak info. We collect left and right peaks from track meters if playing, or read reapeak cache files for items if project is stopped. Muted tracks aren's aren't included.
-- @author Derek Lane, Scott Chesworth and GPT.
-- @changelog
--   Scott added speech feedback and fallback approach when transport is stopped.

local threshold = 0.001 -- approx -60 dBFS

function Speak(str)
  if reaper.osara_outputMessage then
    reaper.osara_outputMessage(str)
  end
end

local function to_dbfs(val)
  if val <= 0 then return -60.0 end
  return math.max(-60.0, 20 * math.log(val, 10))
end

local function get_cursor_item_peaks(tr)
  local cursor = reaper.GetCursorPosition()
  local item_count = reaper.CountTrackMediaItems(tr)
  local peakL, peakR = 0.0, 0.0

  for i = 0, item_count - 1 do
    local item = reaper.GetTrackMediaItem(tr, i)
    local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

    if cursor >= pos and cursor <= (pos + len) then
      local take = reaper.GetActiveTake(item)
      if take and not reaper.TakeIsMIDI(take) then
        local accessor = reaper.CreateTakeAudioAccessor(take)
        if accessor then
          local sample_rate = 44100
          local src = reaper.GetMediaItemTake_Source(take)
          local num_channels = reaper.GetMediaSourceNumChannels(src)
          if num_channels < 1 then
            reaper.DestroyAudioAccessor(accessor)
            break
          end

          local samples_per_ch = math.floor(sample_rate * 0.01)
          local total_samples = samples_per_ch * num_channels
          local buf = reaper.new_array(total_samples)
          reaper.GetAudioAccessorSamples(accessor, sample_rate, num_channels, cursor, samples_per_ch, buf)

          for j = 0, samples_per_ch - 1 do
            local base = j * num_channels
            if num_channels >= 1 then
              local L = math.abs(buf[base + 1])
              if L > peakL then peakL = L end
            end
            if num_channels >= 2 then
              local R = math.abs(buf[base + 2])
              if R > peakR then peakR = R end
            end
          end

          reaper.DestroyAudioAccessor(accessor)
          break
        end
      end
    end
  end

  return to_dbfs(peakL), to_dbfs(peakR)
end

local function get_peaks(tr)
  local playstate = reaper.GetPlayState()
  if playstate & 1 == 1 or playstate & 4 == 4 then
    return to_dbfs(reaper.Track_GetPeakInfo(tr, 0)), to_dbfs(reaper.Track_GetPeakInfo(tr, 1))
  else
    return get_cursor_item_peaks(tr)
  end
end

local function is_track_audible(tr)
  -- ✅ Skip muted tracks
  if reaper.GetMediaTrackInfo_Value(tr, "B_MUTE") == 1 then
    return false
  end

  local playstate = reaper.GetPlayState()
  if playstate & 1 == 1 or playstate & 4 == 4 then
    return reaper.Track_GetPeakInfo(tr, 0) > threshold or reaper.Track_GetPeakInfo(tr, 1) > threshold
  else
    local L, R = get_cursor_item_peaks(tr)
    return L > -60.0 or R > -60.0
  end
end

local function get_audible_tracks()
  local audible = {}
  for i = 0, reaper.CountTracks(0) - 1 do
    local tr = reaper.GetTrack(0, i)
    if is_track_audible(tr) then
      local idx = math.floor(reaper.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER"))
      table.insert(audible, { track = tr, index = idx })
    end
  end
  table.sort(audible, function(a, b) return a.index < b.index end)
  return audible
end

local function get_selected_track_index()
  local tr = reaper.GetSelectedTrack(0, 0)
  if not tr then return 0 end
  return math.floor(reaper.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER"))
end

local function get_track_name(tr)
  local _, name = reaper.GetTrackName(tr, "")
  return name or ""
end

-- MAIN
if reaper.CountTracks(0) == 0 then
  Speak("no tracks")
  return
end

local audible = get_audible_tracks()
if #audible == 0 then
  Speak("no audible tracks found at this cursor position")
  return
end

local current_idx = get_selected_track_index()
local chosen_track = nil
local wrapped = false

-- 🡐 PREVIOUS audible track
for i = #audible, 1, -1 do
  if audible[i].index < current_idx then
    chosen_track = audible[i].track
    break
  end
end

if not chosen_track then
  chosen_track = audible[#audible].track
  wrapped = true
end

reaper.SetOnlyTrackSelected(chosen_track)
reaper.TrackList_AdjustWindows(false)
reaper.UpdateArrange()

local track_num = math.floor(reaper.GetMediaTrackInfo_Value(chosen_track, "IP_TRACKNUMBER"))
local track_name = get_track_name(chosen_track)
local default_name = "Track " .. track_num
local is_unnamed = track_name == default_name

local peakL, peakR = get_peaks(chosen_track)
local peaks_text = string.format("left %.1f, right %.1f", peakL, peakR)

local speak_text
if is_unnamed then
  speak_text = (wrapped and "wrapped to " or "") .. "track " .. track_num .. ", " .. peaks_text
else
  speak_text = (wrapped and "wrapped to " or "") .. track_num .. " " .. track_name .. ", " .. peaks_text
end

Speak(speak_text)
