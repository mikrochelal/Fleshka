--!strict
-- Scripted radio transmissions: a list of timed steps played to every player.
--
--   text          subtitle shown for `hold` seconds (omit for silence)
--   hold          seconds this step lasts
--   flicker       flicker the lights of the room the radio is in
--   interference  distort every player's screen
--   cue           key of Config/AudioConfig.Cues to play at the radio

export type Step = {
	speaker: string?,
	text: string?,
	hold: number,
	flicker: boolean?,
	interference: boolean?,
	cue: string?,
}

local FIRST_CONTACT: { Step } = {
	{ speaker = "RADIO", text = "[static]", hold = 2.5, cue = "RadioStatic" },
	{
		speaker = "RADIO",
		text = "Station Nine... can anyone hear me?",
		hold = 4,
		cue = "RadioVoice",
	},
	{ hold = 2.5 },
	{ speaker = "RADIO", text = "Do not trust the voices.", hold = 3.5, cue = "RadioVoice" },
	{ hold = 3, flicker = true },
	{
		speaker = "RADIO",
		text = "IT KNOWS WE ARE LISTENING.",
		hold = 4.5,
		interference = true,
		cue = "RadioVoice",
	},
	{ hold = 2, flicker = true },
}

-- Shown on the analysis console while it traces the signal.
local TRACE: { Step } = {
	{ speaker = "CONSOLE", text = "TRACE RUNNING...", hold = 3, cue = "RadioStatic" },
	{ speaker = "CONSOLE", text = "SOURCE IS NOT EXTERNAL.", hold = 3.5, flicker = true },
	{ speaker = "CONSOLE", text = "SOURCE DEPTH: BELOW STATION. BEARING: THIS ROOM.", hold = 4 },
	{ hold = 2 },
	{
		speaker = "CONSOLE",
		text = "SOURCE IS RESPONDING TO THIS TERMINAL.",
		hold = 4,
		interference = true,
		flicker = true,
	},
	{ hold = 1.5 },
}

-- The ending. The elevator rises; the signal follows, rising into a distorted, voice-like
-- shriek, and stops dead before the last line.
local FINAL_WORDS: { Step } = {
	{ hold = 3 },
	{ speaker = "RADIO", text = "[static]", hold = 2.5, cue = "RadioStatic" },
	{
		speaker = "RADIO",
		text = "[the signal climbs - layered static, something like voices, all of them yours]",
		hold = 4,
		interference = true,
		cue = "FinalSignal",
	},
	{
		speaker = "RADIO",
		text = "[it rises into a shriek no throat could make]",
		hold = 3.5,
		interference = true,
	},
	{ hold = 2.5 },
	{
		speaker = "UNKNOWN VOICE",
		text = "Thank you for bringing it outside.",
		hold = 5,
		cue = "RadioVoice",
	},
	{ hold = 2 },
}

return { FirstContact = FIRST_CONTACT, Trace = TRACE, FinalWords = FINAL_WORDS }
