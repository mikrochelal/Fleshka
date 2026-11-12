--!strict
-- The mission, in order. The server completes objectives by id (ObjectiveService); clients
-- only display them.

export type Objective = { id: string, text: string }

local list: { Objective } = {
	{ id = "EnterStation", text = "Investigate the elevator and enter STATION-09." },
	{ id = "FindPowerControls", text = "Find the emergency power controls." },
	{ id = "RestorePower", text = "Restore the facility power." },
	{ id = "InvestigateRadio", text = "Investigate the anomalous radio transmission." },
	{ id = "ReachCommCenter", text = "Reach the communication center." },
	{ id = "Escape", text = "Find a way to escape." },
}

return table.freeze({ List = table.freeze(list) })
