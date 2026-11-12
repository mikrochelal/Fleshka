--!strict
-- The mission, in order. The server completes objectives by id (ObjectiveService); clients
-- only display them. `hint` is the one line of practical help shown under the objective.

export type Objective = { id: string, text: string, hint: string? }

local list: { Objective } = {
	{
		id = "EnterStation",
		text = "Investigate the elevator and enter STATION-09.",
		hint = "F switches your flashlight. Hold Shift to run.",
	},
	{
		id = "FindPowerControls",
		text = "Find the emergency power controls.",
		hint = "The Power Room is on the south side of the main corridor.",
	},
	{
		id = "RestorePower",
		text = "Restore the facility power.",
		hint = "Engage the three breakers in the order on the maintenance memo (Security Booth), then throw the main lever.",
	},
	{
		id = "RestoreSystems",
		text = "Bring the communications relay online.",
		hint = "The switchgear is in Electrical Control, behind the Power Room.",
	},
	{
		id = "InvestigateRadio",
		text = "Investigate the anomalous radio transmission.",
		hint = "A receiver is active in the Monitor Room, north of the main corridor.",
	},
	{
		id = "TraceSignal",
		text = "Trace the source of the signal.",
		hint = "Signal Analysis is in the laboratory, past the Signal Chamber.",
	},
	{
		id = "ReachCommCenter",
		text = "Reach the communication center.",
		hint = "South from the junction. Use the central computer to recall the elevator.",
	},
	{
		id = "Escape",
		text = "Find a way to escape.",
		hint = "Get back to the elevator you arrived in.",
	},
}

return table.freeze({ List = table.freeze(list) })
