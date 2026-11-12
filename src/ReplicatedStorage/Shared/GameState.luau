--!strict
-- Session phases and the transitions the server is allowed to make between them.
-- The server owns the current phase; clients only ever receive it.

export type Phase = "Lobby" | "Loading" | "Intro" | "Playing" | "Finale" | "Ending"

local GameState = {}

GameState.Phase = table.freeze({
	Lobby = "Lobby" :: Phase,
	Loading = "Loading" :: Phase,
	Intro = "Intro" :: Phase,
	Playing = "Playing" :: Phase,
	Finale = "Finale" :: Phase,
	Ending = "Ending" :: Phase,
})

local TRANSITIONS: { [Phase]: { Phase } } = {
	Lobby = { "Loading" },
	Loading = { "Intro", "Lobby" },
	Intro = { "Playing" },
	Playing = { "Finale", "Lobby" },
	Finale = { "Ending", "Lobby" },
	Ending = { "Lobby" },
}

function GameState.canTransition(from: Phase, to: Phase): boolean
	return table.find(TRANSITIONS[from], to) ~= nil
end

return GameState
