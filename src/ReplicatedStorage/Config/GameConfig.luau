--!strict
-- Global tunables shared by server and client. Gameplay-specific values get their own
-- config module in this folder as each system is implemented.

return table.freeze({
	GameName = "THE LAST SIGNAL",
	Version = "0.4.0",

	MinPartySize = 1,
	MaxPartySize = 4,

	-- How long a player's session data is kept after they leave, so a reconnect restores it.
	ReconnectGraceSeconds = 120,

	-- Until the menu and lobby exist, the session starts by itself when a player is ready.
	AutoStartSession = true,
	-- Seconds the title card stays up before play begins.
	IntroSeconds = 7,
})
