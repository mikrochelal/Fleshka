--!strict
-- Session phases and the transitions the server is allowed to make between them.
-- The server owns the current phase; clients only ever receive it.

export type Phase = "Lobby" | "Loading" | "Intro" | "Playing" | "Finale" | "Ending"

local GameState = {}

-- Attributes on ReplicatedStorage through which the server replicates its state.
GameState.PHASE_ATTRIBUTE = "TLS_Phase"
GameState.MODE_ATTRIBUTE = "TLS_Mode"

GameState.Phase = table.freeze({
	Lobby = "Lobby" :: Phase,
	Loading = "Loading" :: Phase,
	Intro = "Intro" :: Phase,
	Playing = "Playing" :: Phase,
	Finale = "Finale" :: Phase,
	Ending = "Ending" :: Phase,
})

local TRANSITIONS: { [string]: { Phase } } = {
	Lobby = { "Loading" },
	Loading = { "Intro", "Lobby" },
	Intro = { "Playing" },
	Playing = { "Finale", "Lobby" },
	Finale = { "Ending", "Lobby" },
	Ending = { "Lobby" },
}

-- Returns the value as a Phase, or `fallback` when it is not a phase name.
function GameState.parsePhase(value: string, fallback: Phase): Phase
	if TRANSITIONS[value] == nil then
		return fallback
	end
	return (value :: any) :: Phase
end

function GameState.canTransition(from: Phase, to: Phase): boolean
	local allowed = TRANSITIONS[from]
	return allowed ~= nil and table.find(allowed, to) ~= nil
end

return GameState
