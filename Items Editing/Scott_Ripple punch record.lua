-- @description Ripple punch record
-- @version 1.0
-- @author Scott Chesworth
-- @about
--   Punch-in recording that respects ripple editing behaviour, primarily aimed at non-linear spoken-word projects.
--   Bind to a key and press to insert a recording at the edit cursor, or at the play
--   cursor if the transport is already rolling. When the take commits, existing content is
--   pushed later by the length of what you just recorded, so nothing is overwritten.
--
--   With ripple off it records normally. Ripple per
--   track moves only the armed track's following content aside, leaving other tracks and all
--   markers and regions in place. Ripple all tracks moves every track along with
--   markers and regions, essentially you're punching in new timeline.
--
--   Native pre-roll and count-in are respected, and stopping during them aborts cleanly with
--   no leftover split. OSARA users hear punch-aware speech in place of the stock recording
--   announcement.
--
--   Note: undoing a successful ripple punch requires hitting undo twice at the moment.
-- @changelog
--   Initial release

local r = reaper

-- Debugging can be provided here, preserving in case there are any issues to chase.
local DEBUG = false
local dbglog = {}
local function dbg(s) if DEBUG then dbglog[#dbglog + 1] = tostring(s) end end
-- Speak the whole accumulated run as one OSARA message (fallback: console).
local function dbgflush()
  if not DEBUG or #dbglog == 0 then return end
  local msg = "ripple-punch: " .. table.concat(dbglog, " | ")
  dbglog = {}
  if r.APIExists("osara_outputMessage") then
    r.osara_outputMessage(msg)
  else
    r.ShowConsoleMsg(msg .. "\n")
  end
end

-- Action command IDs
local ACT_RECORD           = 1013
local ACT_STOP             = 1016
local ACT_RIPPLE_PER_TRACK = 40310
local ACT_RIPPLE_ALL       = 40311

-- Config var governing the "prompt to save/delete/rename new files on stop" dialog.
-- 0 = no prompt. We force it off during a punch and restore it after.
local CFG_PROMPT = "promptendrec"

-- OSARA named actions, resolved once at load (0 if OSARA is not installed). Used to
-- replace OSARA's stock recording announcement with punch-aware speech; see
-- osara_record_feedback.
local OSARA_REPORT_RECORD = r.NamedCommandLookup("_OSARA_CONFIG_reportRecord")
local OSARA_MUTE_NEXT     = r.NamedCommandLookup("_OSARA_MUTENEXTMESSAGE")

-- While waiting for recording to actually engage, how long to tolerate the transport
-- sitting NOT rolling and NOT recording before concluding the take was aborted.
-- Wall-clock, so frame rate and pre-roll length are irrelevant. Two cases: before we
-- have seen anything roll, allow a generous spin-up window for pre-roll / count-in to
-- begin; once we HAVE seen the transport roll, a drop back to idle (stopped or paused)
-- is a definitive abort (e.g. you stopped during pre-roll/count-in), so react quickly.
local STARTUP_GRACE_SEC       = 3.0
local PREROLL_ABORT_GRACE_SEC = 0.4
-- How long (wall-clock seconds) to keep waiting after stop for the take to appear
-- before concluding nothing was recorded and simply restoring. With the save/delete
-- prompt suppressed (see suppress_prompt) a real take commits within a frame or two,
-- so a short grace is plenty. If we could not suppress the prompt (older REAPER with
-- no config API), fall back to a generous wait so a slow manual Save is not cut off.
-- The value in force is chosen at start and held in stop_grace_sec.
local STOP_GRACE_SUPPRESSED = 8
local STOP_GRACE_PROMPT     = 60

-- Persistent state across defer cycles (script-chunk locals persist).
local P             -- punch point (edit cursor position at start)
local ripple_mode   -- "track" or "all"
local pre_items     -- set[item] = true : items present before recording
local parked        -- list of { item = , origpos = } : content moved out of the way
local parked_set    -- set[item] = true : quick membership test for parked items
local started       -- has recording actually begun?
local saw_active    -- have we seen the transport roll/record since issuing record?
local abort_since   -- wall-clock time the transport first went idle while not started
local stop_deadline -- wall-clock time by which the take must appear, else assume aborted
local finished      -- guard so finish() runs once
local gap_closed    -- has the gap been closed/restored yet? (guards atexit)
local stop_grace_sec  -- wall-clock seconds to wait after stop for a take (set at start)
local prompt_saved    -- original promptendrec value if we suppressed it, else nil

-- Forward declarations
local mainloop, finish, close_gap, ripple_markers, cleanup

-- Helpers:

local function get_ripple_mode()
  if r.GetToggleCommandState(ACT_RIPPLE_ALL) == 1 then return "all" end
  if r.GetToggleCommandState(ACT_RIPPLE_PER_TRACK) == 1 then return "track" end
  return "off"
end

local function all_tracks()
  local t = {}
  for i = 0, r.CountTracks(0) - 1 do t[#t + 1] = r.GetTrack(0, i) end
  return t
end

local function armed_tracks()
  local t = {}
  for i = 0, r.CountTracks(0) - 1 do
    local tr = r.GetTrack(0, i)
    if r.GetMediaTrackInfo_Value(tr, "I_RECARM") == 1 then t[#t + 1] = tr end
  end
  return t
end

local function snapshot_all_items()
  local set = {}
  for i = 0, r.CountMediaItems(0) - 1 do set[r.GetMediaItem(0, i)] = true end
  return set
end

-- True once an actual take exists: a new item (not pre-existing, not one of the
-- parked/split pieces we created) with real length. Used to ripple only after the
-- take is committed (e.g. after a prompt-on-stop dialog is resolved), never early.
local function recorded_ready()
  for i = 0, r.CountMediaItems(0) - 1 do
    local it = r.GetMediaItem(0, i)
    if not pre_items[it] and not parked_set[it]
       and r.GetMediaItemInfo_Value(it, "D_LENGTH") > 0 then
      return true
    end
  end
  return false
end

-- Move one item aside by a large offset, remembering its original position. When the
-- item is the right-hand half of a split we made, `sp` carries what an abort needs to
-- heal the split back into one item: the left half, its pre-split length, and the left
-- half's original fade-out state (so a split-added crossfade leaves no trace).
local function park_item(it, offset, sp)
  local pos = r.GetMediaItemInfo_Value(it, "D_POSITION")
  local e = { item = it, origpos = pos }
  if sp then
    e.split_left    = sp.left
    e.split_origlen = sp.origlen
    e.split_fout    = sp.fout
    e.split_fauto   = sp.fauto
  end
  parked[#parked + 1] = e
  parked_set[it] = true
  r.SetMediaItemInfo_Value(it, "D_POSITION", pos + offset)
end

-- Open the gap: split at P and move everything from P onward on the given tracks
-- far out of the record path, so the take records into empty space.
local function open_gap(tracks)
  local offset = r.GetProjectLength(0) + 100000  -- comfortably past everything
  for _, tr in ipairs(tracks) do
    -- Collect the track's items first, since splitting adds items mid-loop.
    local list = {}
    for i = 0, r.CountTrackMediaItems(tr) - 1 do list[#list + 1] = r.GetTrackMediaItem(tr, i) end
    for _, it in ipairs(list) do
      local pos = r.GetMediaItemInfo_Value(it, "D_POSITION")
      local len = r.GetMediaItemInfo_Value(it, "D_LENGTH")
      if pos < P and pos + len > P then
        -- Straddles the cursor: capture the item's fade-out state, then split and park
        -- the tail. The captured state lets an abort restore the item exactly.
        local fout  = r.GetMediaItemInfo_Value(it, "D_FADEOUTLEN")
        local fauto = r.GetMediaItemInfo_Value(it, "D_FADEOUTLEN_AUTO")
        local right = r.SplitMediaItem(it, P)
        if right then
          park_item(right, offset,
                    { left = it, origlen = len, fout = fout, fauto = fauto })
        end
      elseif pos >= P then
        park_item(it, offset)
      end
    end
  end
end

-- Put parked content back, each item moved right by `shift` from its original
-- position (shift = take length to ripple, or 0 to simply restore). When `heal` is set
-- (the nothing-was-recorded case) any split we made is undone instead of merely
-- repositioned: the left half is grown back to its full pre-split length and the parked
-- right half deleted, so no stray split is left behind on the armed tracks.
local function restore_parked(shift, heal)
  for _, e in ipairs(parked) do
    if r.ValidatePtr(e.item, "MediaItem*") then
      if heal and e.split_left and r.ValidatePtr(e.split_left, "MediaItem*") then
        -- Undo the split: grow the left half back to full length, restore its original
        -- fade-out (clearing any crossfade the split added), and drop the parked tail.
        r.SetMediaItemInfo_Value(e.split_left, "D_LENGTH", e.split_origlen)
        r.SetMediaItemInfo_Value(e.split_left, "D_FADEOUTLEN", e.split_fout)
        r.SetMediaItemInfo_Value(e.split_left, "D_FADEOUTLEN_AUTO", e.split_fauto)
        r.DeleteTrackMediaItem(r.GetMediaItem_Track(e.item), e.item)
      else
        r.SetMediaItemInfo_Value(e.item, "D_POSITION", e.origpos + shift)
      end
    end
  end
end

-- Temporarily force the save/delete/rename-on-stop prompt off, remembering the prior
-- value so cleanup() can restore it. Session-only (persist 0): the saved reaper.ini is
-- never touched, so a REAPER restart always brings your setting back. Returns true if
-- the prompt is off afterwards (already off, or we turned it off), so stop can use the
-- short grace; false if the config API is unavailable and the prompt may still be on.
local function suppress_prompt()
  if not r.APIExists("get_config_var_string")
     or not r.APIExists("set_config_var_string") then
    return false
  end
  local ok, val = r.get_config_var_string(CFG_PROMPT)
  if not ok then return false end
  if val ~= "0" then
    prompt_saved = val
    r.set_config_var_string(CFG_PROMPT, "0", 0)  -- session-only; restored on exit
  end
  return true
end

local function restore_prompt()
  if prompt_saved then
    r.set_config_var_string(CFG_PROMPT, prompt_saved, 0)
    prompt_saved = nil
  end
end

-- Replace OSARA's stock recording announcement with punch-aware speech, so hitting
-- record inside a ripple reads as what it actually is. Only acts when OSARA is present
-- and its "Report recording state" option is on; otherwise OSARA's own feedback is
-- left untouched. Mutes OSARA's next message so its usual "recording" report is
-- suppressed, then speaks ours. (Ripple off never reaches here, so plain-record
-- feedback from OSARA is unaffected.)
local function osara_record_feedback()
  if OSARA_REPORT_RECORD == 0 then return end                          -- OSARA not installed
  if r.GetToggleCommandState(OSARA_REPORT_RECORD) ~= 1 then return end -- reporting is off
  local msg = (ripple_mode == "track") and "ripple per track punch"
           or (ripple_mode == "all")   and "ripple all tracks punch"
  if not msg then return end                                           -- ripple off: leave OSARA alone
  if OSARA_MUTE_NEXT ~= 0 then r.Main_OnCommand(OSARA_MUTE_NEXT, 0) end
  if r.APIExists("osara_outputMessage") then r.osara_outputMessage(msg) end
end

-- Closing the gap after punching

ripple_markers = function(L)
  -- Collect first, then apply, so moving markers does not disturb enumeration.
  local marks, i = {}, 0
  while true do
    local rv, isrgn, pos, rgnend, name, idx, color = r.EnumProjectMarkers3(0, i)
    if rv == 0 then break end
    marks[#marks + 1] = { isrgn = isrgn, pos = pos, rgnend = rgnend,
                          name = name, idx = idx, color = color }
    i = i + 1
  end
  for _, m in ipairs(marks) do
    if not m.isrgn then
      if m.pos >= P then
        r.SetProjectMarker3(0, m.idx, false, m.pos + L, 0, m.name, m.color)
      end
    else
      local newpos, newend = m.pos, m.rgnend
      if m.pos >= P then
        newpos, newend = m.pos + L, m.rgnend + L      -- region entirely after: move it
      elseif m.rgnend > P then
        newend = m.rgnend + L                          -- region straddles insert: grow it
      end
      if newpos ~= m.pos or newend ~= m.rgnend then
        r.SetProjectMarker3(0, m.idx, true, newpos, newend, m.name, m.color)
      end
    end
  end
end

-- Returns true if a take was found and rippled, false if nothing was recorded.
close_gap = function()
  -- The take(s): new items that are not pre-existing and not parked. Measure length.
  local takes, L = 0, 0
  for i = 0, r.CountMediaItems(0) - 1 do
    local it = r.GetMediaItem(0, i)
    if not pre_items[it] and not parked_set[it] then
      takes = takes + 1
      local len = r.GetMediaItemInfo_Value(it, "D_LENGTH")
      if len > L then L = len end
    end
  end
  dbg(("close_gap: takes=%d  L=%.3f  parked=%d"):format(takes, L, #parked))

  if takes == 0 or L <= 0 then
    restore_parked(0, true)    -- nothing kept: restore content and heal any split
    return false
  end

  restore_parked(L)            -- ripple: content returns shifted by the take length
  if ripple_mode == "all" then ripple_markers(L) end

  -- Diagnostic: dump the resulting geometry on the armed tracks.
  for ti, tr in ipairs(armed_tracks()) do
    for i = 0, r.CountTrackMediaItems(tr) - 1 do
      local it = r.GetTrackMediaItem(tr, i)
      local tag = (not pre_items[it] and not parked_set[it]) and "TAKE"
                  or (parked_set[it] and "moved" or "old")
      dbg(("t%d i%d %s pos=%.3f len=%.3f"):format(ti, i, tag,
        r.GetMediaItemInfo_Value(it, "D_POSITION"),
        r.GetMediaItemInfo_Value(it, "D_LENGTH")))
    end
  end
  return true
end

-- Lifecycle

cleanup = function()
  -- Runs on atexit for any reason (normal end, error, or forced termination).
  -- If we opened a gap but never closed it (e.g. script killed mid-take), put the
  -- parked content back in its original place and heal any split so nothing is left
  -- displaced or fragmented.
  if not gap_closed and parked then
    restore_parked(0, true)
  end
  restore_prompt()  -- always put the save/delete prompt back the way we found it
  r.DeleteExtState("scottc_ripple_punch", "running", false)
  r.UpdateArrange()
end

finish = function()
  if finished then return end
  finished = true

  -- Cursor position REAPER left after stop (honours the move-cursor-on-stop pref).
  local cursor_after = r.GetCursorPosition()

  r.Undo_BeginBlock()
  local did = close_gap()
  gap_closed = true
  r.SetEditCurPos(cursor_after, false, false)
  r.Undo_EndBlock(
    did and "Ripple punch-in insert, undo again to remove the recording"
         or "Ripple punch-in (nothing recorded)", -1)
  r.UpdateArrange()
  dbgflush()
end

mainloop = function()
  local ps = r.GetPlayState()
  local recording = (ps & 4) == 4

  if not started then
    -- During pre-roll / count-in REAPER already reports recording (ps=5), but the play
    -- cursor is still BEFORE the punch point; real recording only begins once it
    -- reaches P. Gate on play position so a stop during pre-roll/count-in reads as an
    -- abort instead of being mistaken for a finished (but empty) take.
    if recording and r.GetPlayPosition() >= P then
      started = true
      dbg("recording engaged")
      osara_record_feedback()  -- punch-aware speech in place of OSARA's stock report
      r.defer(mainloop)
      return
    end
    -- Not yet at the punch point. Rolling or recording toward it (pre-roll/count-in)
    -- means keep waiting however long that lasts. If the transport has gone idle it is
    -- either still spinning up, or the take was aborted -- e.g. you stopped during
    -- pre-roll/count-in. Conclude abort only after a grace so nothing is left parked: a
    -- generous one before we have seen activity, a short one once we have.
    local active = (ps & 1) == 1 or recording
    if active then
      saw_active  = true
      abort_since = nil
    else
      abort_since = abort_since or r.time_precise()
      local grace = saw_active and PREROLL_ABORT_GRACE_SEC or STARTUP_GRACE_SEC
      if r.time_precise() - abort_since >= grace then
        dbg(saw_active and "stopped during pre-roll -> abort"
                        or "transport never engaged -> abort")
        finish(); return
      end
    end
    r.defer(mainloop)
    return
  end

  -- Recording has begun; wait for it to stop.
  if recording then r.defer(mainloop); return end

  -- Stopped. Content stays parked until the take commits, so nothing can be
  -- overwritten. With the prompt suppressed the take commits within a frame or two;
  -- close the gap the instant it appears. If none appears within the grace, nothing
  -- was recorded, so restore the parked content unchanged.
  if recorded_ready() then finish(); return end
  if not stop_deadline then stop_deadline = r.time_precise() + stop_grace_sec end
  if r.time_precise() >= stop_deadline then finish(); return end
  r.defer(mainloop)
end

-- Entry

local function main()
  ripple_mode = get_ripple_mode()
  dbg(("mode=%s  (toggle per-track=%d, all=%d)"):format(
        ripple_mode,
        r.GetToggleCommandState(ACT_RIPPLE_PER_TRACK),
        r.GetToggleCommandState(ACT_RIPPLE_ALL)))

  if ripple_mode == "off" then
    dbg("ripple off -> plain record fallback")
    dbgflush()
    r.Main_OnCommand(ACT_RECORD, 0)  -- stock behaviour, no insert
    return
  end

  -- If a take is already in progress from a previous press, this press stops it.
  if r.GetExtState("scottc_ripple_punch", "running") == "1" then
    dbg("already running -> sent Stop")
    dbgflush()
    r.Main_OnCommand(ACT_STOP, 0)
    return
  end

  -- Punch point: if the transport is already rolling, punch in where the play cursor
  -- is right now (so hitting the key mid-playback inserts at what you are hearing);
  -- otherwise use the edit cursor. GetPlayState bit 0 is set while playing (and while
  -- already recording), which is exactly the "rolling" case.
  local rolling = (r.GetPlayState() & 1) == 1
  P           = rolling and r.GetPlayPosition() or r.GetCursorPosition()
  pre_items   = snapshot_all_items()
  parked      = {}
  parked_set  = {}
  started     = false
  saw_active  = false
  abort_since = nil
  stop_deadline = nil
  finished    = false
  gap_closed  = false
  prompt_saved = nil

  r.SetExtState("scottc_ripple_punch", "running", "1", false)
  r.atexit(cleanup)

  -- Force the save/delete prompt off for the punch so the take commits immediately on
  -- stop: no dialog means no window to watch and no displaced-content limbo. Restored
  -- on exit by cleanup(). If suppression is unavailable, fall back to a generous grace.
  local suppressed = suppress_prompt()
  stop_grace_sec = suppressed and STOP_GRACE_SUPPRESSED or STOP_GRACE_PROMPT
  dbg(("prompt suppressed=%s  grace=%ds"):format(tostring(suppressed), stop_grace_sec))

  -- Move following content out of the record path (all tracks, or just the armed
  -- track in per-track mode) so the take records into empty space.
  local scope = (ripple_mode == "all") and all_tracks() or armed_tracks()
  r.PreventUIRefresh(1)
  open_gap(scope)
  r.PreventUIRefresh(-1)
  dbg(("start: P=%.3f  scope tracks=%d  parked items=%d"):format(P, #scope, #parked))
  r.UpdateArrange()

  r.Main_OnCommand(ACT_RECORD, 0)  -- honours native pre-roll; begins at the punch point
  r.defer(mainloop)
end

main()
