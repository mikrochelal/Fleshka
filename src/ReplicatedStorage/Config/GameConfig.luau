--!strict
-- Global tunables shared by server and client. Gameplay-specific values get their own
-- config module in this folder as each system is implemented.

return table.freeze({
	GameName = "THE LAST SIGNAL",
	Version = "0.1.0",

	MinPartySize = 1,
	MaxPartySize = 4,
})
