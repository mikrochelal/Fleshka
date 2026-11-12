--!strict
-- Tunable numbers for the mission's puzzles and set pieces (see Systems/SliceDirector).

export type Lock = {
	-- Number of digits in the code, generated anew every session.
	digits: number,
	-- Data/PropList id of the keypad the code is entered on.
	prop: string,
	-- Whether the keypad works from the start (otherwise the mission switches it on).
	powered: boolean,
}

return table.freeze({
	-- Relay load puzzle (Electrical Control): four feeders, each worth some kW; the closed
	-- ones must add up to the relay's demand exactly. Values are drawn from this pool.
	LoadPuzzle = table.freeze({
		Feeders = 4,
		Values = table.freeze({ 10, 15, 20, 25, 30, 35, 40, 45 }),
	}),

	-- Code locks, by lock id.
	Locks = table.freeze({
		CommDoor = { digits = 4, prop = "CommKeypad", powered = false },
		RestrictedArchive = { digits = 4, prop = "ArchiveKeypad", powered = true },
	} :: { [string]: Lock }),

	-- Radio desk: number of channels on the dial.
	TunerChannels = 9,

	-- The freight lift leaves when every living player is aboard, or this many seconds
	-- after it was first called (so one absent player cannot hold the team forever).
	BoardingGraceSeconds = 20,

	-- Seconds the laboratory stays dark after the trace before its lights return.
	LabBlackoutSeconds = 45,
})
