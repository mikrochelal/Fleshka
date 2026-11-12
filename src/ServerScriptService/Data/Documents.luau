--!strict
-- Documents the players can read. Kept on the server and sent only when a player opens
-- one, so clues cannot be read out of the client ahead of time.
--
-- `body` is either text or a function of the session context (for clues that depend on
-- values the server generated for this session).

export type Context = {
	-- The breaker start-up order for this session, one line per step.
	breakerSteps: { string },
}

export type Document = {
	title: string,
	date: string,
	body: string | (context: Context) -> string,
}

local documents: { [string]: Document } = {
	IncidentLog = {
		title = "INCIDENT LOG - SECURITY DESK",
		date = "17 OCT 1998",
		body = table.concat({
			"02:10  Night shift reports voices on channel 4. Channel 4 has been unassigned since August.",
			"02:40  Dr. Hale called the desk from the laboratory. Dr. Hale is standing in front of me.",
			"03:05  Camera 6 shows someone at the east end of the main corridor. The corridor is empty. I checked twice.",
			"03:30  Director orders every receiver switched off. They keep switching themselves back on.",
			"03:52  Main power lost. Emergency breakers tripped. Evacuating through the freight elevator.",
			"",
			"The last line is in different handwriting:",
			"IT KNOWS WE ARE LISTENING.",
		}, "\n"),
	},

	StartupMemo = {
		title = "MAINTENANCE MEMO 14 - EMERGENCY START-UP",
		date = "02 SEP 1998",
		body = function(context: Context): string
			local lines = {
				"If main power is lost, the emergency supply has to be brought up by hand.",
				"",
				"Engage the breakers in this exact order:",
			}
			for index, step in context.breakerSteps do
				table.insert(lines, `   {index}.  {step}`)
			end
			table.insert(lines, "")
			table.insert(lines, "Then throw the main lever in the Power Room.")
			table.insert(lines, "")
			table.insert(
				lines,
				"A breaker thrown out of turn trips straight back out. It is also loud. "
					.. "Since last month I would rather not be loud down here."
			)
			table.insert(lines, "")
			table.insert(lines, "- R. Okafor, Maintenance")
			return table.concat(lines, "\n")
		end,
	},

	ResearchNote = {
		title = "RESEARCH NOTE - SIGNAL 9",
		date = "11 OCT 1998",
		body = table.concat({
			"The signal is not a message. We spent a year trying to decode it and there is nothing to decode.",
			"",
			"It is closer to a mirror. Whatever we transmit toward it comes back hours later, slightly wrong. "
				.. "First tones. Then our call signs. Last week it was Weller's voice, reading a report he has not written yet.",
			"",
			"The recordings never repeat what we said. They say what we would say.",
			"",
			"Recommendation: stop listening. I am aware of how that sounds.",
			"",
			"- Dr. M. Hale",
		}, "\n"),
	},

	FeederNote = {
		title = "SHIFT HANDOVER - ELECTRICAL CONTROL",
		date = "16 OCT 1998",
		body = table.concat({
			"Okafor to night shift:",
			"",
			"Emergency supply only feeds lighting. Anything else has to be switched in by hand "
				.. "from this room. The communications relay is on the big cabinet behind you - "
				.. "it will not take until the lever in the Power Room is up.",
			"",
			"Director wants the relay left OFF tonight. Says the receivers are 'more than "
				.. "switched on'. I do not know what that means and I did not ask.",
			"",
			"If you hear the relay close by itself, do not go and look. Call the desk.",
		}, "\n"),
	},

	ExaminationLog = {
		title = "MEDICAL - STAFF EXAMINATION LOG",
		date = "14 OCT 1998",
		body = table.concat({
			"Fourth technician this week reporting the same thing: hearing their own voice on "
				.. "the intercom while they were not speaking.",
			"",
			"Hearing normal. No fever. Each of them can repeat, word for word, what the voice "
				.. "said. None of them remembers ever saying it.",
			"",
			"Weller asked me today whether a recording can be made of something that has not "
				.. "happened yet. I have moved him to the patient room for observation.",
			"",
			"Requesting the quarantine corridor be sealed until we understand what is being "
				.. "copied, and from whom.",
			"",
			"- Dr. A. Reyes, Station Physician",
		}, "\n"),
	},

	TapeTranscript = {
		title = "TRANSCRIPT - TAPE 9-114",
		date = "12 OCT 1998",
		body = table.concat({
			"[Recorded in the signal chamber. Dr. Hale alone.]",
			"",
			"HALE: Test one hundred fourteen. Transmitting call sign.",
			"[11 seconds of carrier]",
			"VOICE: Test one hundred fifteen. Transmitting call sign.",
			"HALE: ...That is tomorrow's test.",
			"VOICE: That is tomorrow's test.",
			"HALE: Who is this?",
			"VOICE: Hale.",
			"",
			"[Note in margin, Hale's handwriting:] It answered before I finished asking.",
		}, "\n"),
	},
}

return documents
