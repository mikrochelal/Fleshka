--!strict
-- Scripted transmissions and console read-outs: a list of timed steps played to every
-- player (Systems/RadioSystem.play). Speakers and lines are localization keys.
--
--   text          line shown as a subtitle for `hold` seconds (omit for silence)
--   hold          seconds this step lasts
--   flicker       flicker the lights of the room the source is in
--   interference  distort every player's screen
--   cue           key of Config/AudioConfig.Cues to play at the source
--
-- The radio grows more intense as the mission goes on: plain static first, then
-- interference, then whispers and voices, and finally the scream-like last signal.

export type Step = {
	speaker: string?,
	text: string?,
	hold: number,
	flicker: boolean?,
	interference: boolean?,
	cue: string?,
}

local RADIO = "SPEAKER_RADIO"
local CONSOLE = "SPEAKER_CONSOLE"
local PA = "SPEAKER_PA"
local SURFACE = "SPEAKER_SURFACE"
local UNKNOWN = "SPEAKER_UNKNOWN"

local Transmissions = {}

-- The main generator's status panel, read after emergency power returns.
Transmissions.GeneratorReadout = {
	{ speaker = CONSOLE, text = "CONSOLE_GENERATOR_1", hold = 3, cue = "TerminalBeep" },
	{ speaker = CONSOLE, text = "CONSOLE_GENERATOR_2", hold = 3.5, cue = "TerminalBeep" },
	{ speaker = CONSOLE, text = "CONSOLE_GENERATOR_3", hold = 4, cue = "WarningBeep" },
} :: { Step }

-- The receiver in the Monitor Room: the first transmission.
Transmissions.FirstContact = {
	{ speaker = RADIO, text = "RADIO_STATIC", hold = 2.5, cue = "RadioStaticBurst" },
	{ speaker = RADIO, text = "RADIO_FIRST_1", hold = 4, cue = "RadioVoice" },
	{ hold = 2.5 },
	{ speaker = RADIO, text = "RADIO_FIRST_2", hold = 3.5, cue = "RadioVoice" },
	{ hold = 3, flicker = true, cue = "RadioInterference" },
	{
		speaker = RADIO,
		text = "RADIO_FIRST_3",
		hold = 4.5,
		interference = true,
		cue = "RadioVoice",
	},
	{ hold = 2, flicker = true },
	{ speaker = RADIO, text = "RADIO_FIRST_4", hold = 4, cue = "RadioStaticBurst" },
} :: { Step }

-- The analysis console tracing the signal; the result names the carrier channel.
function Transmissions.trace(channel: number): { Step }
	return {
		{ speaker = CONSOLE, text = "CONSOLE_TRACE_1", hold = 3, cue = "TerminalBeep" },
		{ speaker = CONSOLE, text = "CONSOLE_TRACE_2", hold = 3, cue = "RadioTune" },
		{ speaker = CONSOLE, text = "CONSOLE_TRACE_3", hold = 3.5, flicker = true },
		{ speaker = CONSOLE, text = "CONSOLE_TRACE_4", hold = 4, cue = "RadioInterference" },
		{
			speaker = CONSOLE,
			-- An encoded text reference with one value (see Shared/Text); written out by
			-- hand so this module stays pure data.
			text = `CONSOLE_TRACE_5?channel={channel}`,
			hold = 5,
			cue = "TerminalBeep",
		},
		{ hold = 1.5 },
		{
			speaker = CONSOLE,
			text = "CONSOLE_TRACE_6",
			hold = 4,
			interference = true,
			flicker = true,
			cue = "RadioWhisper",
		},
		{ hold = 1.5 },
	}
end

-- The answer to the distress call. It comes too quickly, and from the wrong direction.
Transmissions.Reply = {
	{ speaker = CONSOLE, text = "CONSOLE_DISTRESS_1", hold = 3, cue = "TerminalBeep" },
	{ speaker = CONSOLE, text = "CONSOLE_DISTRESS_2", hold = 3.5, cue = "RadioTune" },
	{ hold = 2.5, cue = "RadioStaticBurst" },
	{ speaker = SURFACE, text = "RADIO_REPLY_1", hold = 4.5, cue = "RadioVoice" },
	{ speaker = SURFACE, text = "RADIO_REPLY_2", hold = 4.5, cue = "RadioVoice" },
	{ hold = 2, flicker = true, cue = "RadioInterference" },
	{ speaker = CONSOLE, text = "CONSOLE_DISTRESS_3", hold = 4, interference = true },
	{
		speaker = UNKNOWN,
		text = "RADIO_REPLY_3",
		hold = 4.5,
		interference = true,
		cue = "RadioWhisper",
	},
	{ hold = 1.5, flicker = true },
	{ speaker = CONSOLE, text = "CONSOLE_DISTRESS_4", hold = 5, cue = "WarningBeep" },
} :: { Step }

-- The station's public address system when the evacuation is authorised.
Transmissions.Evacuation = {
	{ speaker = PA, text = "PA_EVACUATION_1", hold = 4, cue = "WarningBeep" },
	{ speaker = PA, text = "PA_EVACUATION_2", hold = 4.5 },
	{
		speaker = PA,
		text = "PA_EVACUATION_3",
		hold = 4.5,
		interference = true,
		cue = "RadioWhisper",
	},
} :: { Step }

-- The ending. The lift climbs; the signal follows it, rising into a distorted, scream-like
-- shriek, and stops dead before the last words.
Transmissions.FinalWords = {
	{ hold = 3.5 },
	{ speaker = RADIO, text = "RADIO_STATIC", hold = 3, cue = "RadioStaticBurst" },
	{ speaker = RADIO, text = "RADIO_FINAL_1", hold = 4.5, cue = "RadioVoice" },
	{ hold = 2, cue = "RadioInterference" },
	{ speaker = RADIO, text = "RADIO_FINAL_2", hold = 5, interference = true, cue = "FinalSignal" },
	{ speaker = RADIO, text = "RADIO_FINAL_3", hold = 5, interference = true },
	{ speaker = RADIO, text = "RADIO_FINAL_4", hold = 4, interference = true },
	{ hold = 3 },
	{ speaker = UNKNOWN, text = "RADIO_FINAL_5", hold = 5.5, cue = "RadioWhisper" },
	{ hold = 2.5 },
	{ speaker = UNKNOWN, text = "RADIO_FINAL_6", hold = 5 },
	{ hold = 2 },
} :: { Step }

return Transmissions
