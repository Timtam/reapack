-- @description Cycle Project Timebase
-- @version 1.0
-- @about Cycles through the 3 options for project time base 
-- @author Chessel (Chris Goodwin)


function Speak( str )
 if reaper.osara_outputMessage then
    reaper.osara_outputMessage(str)
  end
end


function main()
local command_timebase, command_beats, command_beatsonly  
local state1, state2, state3
local strSpeak 

command_timebase = reaper.NamedCommandLookup( '_SWS_AWTBASETIME' )
command_beats  = reaper.NamedCommandLookup( '_SWS_AWTBASEBEATALL' )
command_beatsonly  = reaper.NamedCommandLookup( '_SWS_AWTBASEBEATPOS' )

state1 = reaper.GetToggleCommandStateEx( 0, command_timebase )
state2 = reaper.GetToggleCommandStateEx( 0, command_beats )
state3 = reaper.GetToggleCommandStateEx( 0, command_beatsonly )


if state1 == 1 then
reaper.Main_OnCommandEx( command_beats ,0,0 )
strSpeak = "Beats (position, length, rate" 
end

if state2 == 1 then 
reaper.Main_OnCommandEx( command_beatsonly, 0, 0  ) 
strSpeak = "beats (position only )"
end 
if state3 == 1 then 
reaper.Main_OnCommandEx( command_timebase, 0, 0 )
strSpeak = "Time" 
end 
 
Speak( strSpeak )
end
main()