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

local FINAL_WORDS: { Step } = {
	{ hold = 3 },
	{ speaker = "RADIO", text = "[static]", hold = 2, cue = "RadioStatic" },
	{
		speaker = "UNKNOWN VOICE",
		text = "Thank you for bringing it outside.",
		hold = 5,
		interference = true,
		cue = "RadioVoice",
	},
	{ hold = 2 },
}

return { FirstContact = FIRST_CONTACT, FinalWords = FINAL_WORDS }
