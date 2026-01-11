-- @description Move edit cursor to beginning of silence before cursor
-- @version 1.0
-- @author Scott Chesworth

-- SPEECH OUTPUT 
local function Speak(str)
  if reaper.osara_outputMessage then
    reaper.osara_outputMessage(str)
  else
    reaper.ShowConsoleMsg(str .. "\n")
  end
end

-- PEAK ANALYSIS 
local function calculate_peak(buf, samples, channels)
  local max_amp = 0
  for i = 1, samples * channels do
    local val = math.abs(buf[i] or 0)
    if val > max_amp then max_amp = val end
  end
  return max_amp
end

-- REVISED REVERSE SCAN 
local function find_silence_backward(item, take, scan_start, scan_end, threshold_amp, silence_duration, window_size, hop_size)
  local accessor = reaper.CreateTakeAudioAccessor(take)
  if not accessor then return nil end

  local source = reaper.GetMediaItemTake_Source(take)
  local sr = reaper.GetMediaSourceSampleRate(source)
  local ch = reaper.GetMediaSourceNumChannels(source)

  local silence_samples_needed = math.floor(silence_duration * sr)
  local silent_samples = 0
  local last_silent_offset = nil

  local total_samples = math.floor((scan_end - scan_start) * sr)
  local max_offset = total_samples - window_size
  local buffer = reaper.new_array(window_size * ch)

  local b = math.floor(max_offset / hop_size)
  while b >= 0 do
    local sample_offset = b * hop_size
    local window_start = scan_start + (sample_offset / sr)

    buffer.clear()
    reaper.GetAudioAccessorSamples(
      accessor,
      sr,
      ch,
      window_start,
      window_size,
      buffer
    )

    local peak = calculate_peak(buffer, window_size, ch)

    if peak < threshold_amp then
      if silent_samples == 0 then
        last_silent_offset = sample_offset
      end
      silent_samples = silent_samples + hop_size
    else
      if silent_samples >= silence_samples_needed and last_silent_offset then
        reaper.DestroyAudioAccessor(accessor)
        local silence_start_offset = last_silent_offset - (silent_samples - hop_size)
        return silence_start_offset / sr
      end
      silent_samples = 0
      last_silent_offset = nil
    end

    b = b - 1
  end

  -- Handle silence continuing to start of item
  if silent_samples >= silence_samples_needed and last_silent_offset then
    local silence_start_offset = last_silent_offset - (silent_samples - hop_size)
    reaper.DestroyAudioAccessor(accessor)
    return silence_start_offset / sr
  end

  reaper.DestroyAudioAccessor(accessor)
  return nil
end

-- MAIN 
reaper.Undo_BeginBlock()

-- Load saved settings
local threshold_db = tonumber(reaper.GetExtState("SilenceFinder", "threshold_db") or "-40")
local silence_duration = tonumber(reaper.GetExtState("SilenceFinder", "silence_duration") or "1.0")
local threshold_amp = 10 ^ (threshold_db / 20)
local window_size = 8192
local hop_size = 8192

local item = reaper.GetSelectedMediaItem(0, 0)
if not item then Speak("Select an audio item first.") return end

local take = reaper.GetActiveTake(item)
if not take or reaper.TakeIsMIDI(take) then
  Speak("Selected item is not an audio take.")
  return
end

local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
local item_end = item_start + item_len

local play_state = reaper.GetPlayState()
local was_playing = (play_state & 1) == 1

-- Use play cursor if playing, else use edit cursor
local cursor = was_playing and reaper.GetPlayPosition() or reaper.GetCursorPosition()

if cursor <= item_start or cursor > item_end then
  Speak("Cursor must be inside the selected item.")
  return
end

-- Scan from item_start up to cursor
local silence_offset = find_silence_backward(item, take, item_start, cursor, threshold_amp, silence_duration, window_size, hop_size)

if silence_offset then
  local silence_pos = item_start + silence_offset
  reaper.SetEditCurPos(silence_pos, true, true)
  reaper.Main_OnCommand(reaper.NamedCommandLookup("_OSARA_CURSORPOS"), 0)
  if was_playing then reaper.OnPlayButton() end
else
  Speak("No silence found before the cursor.")
end

reaper.Undo_EndBlock("Move cursor to previous silence (OSARA)", -1)
