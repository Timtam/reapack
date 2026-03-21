-- @version 1.1
-- @description Ripple items right on selected tracks by the length of the time selection if the item starts on or after the time selection 
-- @author Chessel and Gemini

-- Get the start and end of the time selection
local time_start, time_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
local selection_len = time_end - time_start

-- Exit if there is no time selection
if selection_len <= 0 then 
    return 
end

reaper.Undo_BeginBlock()

-- Loop through all selected tracks
local sel_tracks_count = reaper.CountSelectedTracks(0)

for i = 0, sel_tracks_count - 1 do
    local track = reaper.GetSelectedTrack(0, i)
    local item_count = reaper.CountTrackMediaItems(track)
    
    -- Loop through items backwards (from end to start)
    -- This prevents index shifting issues as we move items
    for j = item_count - 1, 0, -1 do
        local item = reaper.GetTrackMediaItem(track, j)
        local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        
        -- Check if the start of the item is after the start of the time selection
        if item_pos >= time_start then
            reaper.SetMediaItemInfo_Value(item, "D_POSITION", item_pos + selection_len)
        end
    end
end

reaper.Undo_EndBlock("Move items right by time selection", -1)
reaper.UpdateArrange()