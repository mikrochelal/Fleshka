--!strict
-- Session phases and the transitions the server is allowed to make between them.
-- The server owns the current phase; clients only ever receive it.

export type Phase = "Lobby" | "Loading" | "Intro" | "Playing" | "Finale" | "Ending"

local GameState = {}

-- Attributes on ReplicatedStorage through which the server replicates shared state.
GameState.PHASE_ATTRIBUTE = "TLS_Phase"
GameState.MODE_ATTRIBUTE = "TLS_Mode"
-- Index (1-based) of the current objective in Config/ObjectiveConfig; one past the end when
-- every objective is complete.
GameState.OBJECTIVE_ATTRIBUTE = "TLS_Objective"
GameState.POWER_ATTRIBUTE = "TLS_PowerOn"
-- Seconds the session took, set when it ends.
GameState.DURATION_ATTRIBUTE = "TLS_SessionSeconds"

-- Attributes on each Player through which the server replicates that player's state.
GameState.PlayerAttribute = table.freeze({
	Stamina = "TLS_Stamina", -- 0..100
	Exhausted = "TLS_Exhausted", -- boolean
	Battery = "TLS_Battery", -- 0..100
	FlashlightOn = "TLS_FlashlightOn", -- boolean
	Dread = "TLS_Dread", -- 0..1, how close THE COPY is
})

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
