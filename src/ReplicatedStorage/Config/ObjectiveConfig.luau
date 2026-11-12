--!strict
-- The mission: five chapters of objectives, in order, plus optional objectives.
--
-- The server completes objectives by id (Services/ObjectiveService, driven by
-- Systems/SliceDirector); clients only display them. `title` and `hint` are localization
-- keys (Shared/Locale). Nothing here is executed: `completion` documents the condition the
-- mission script implements, and the other fields are data it and the tests read.
--
--   props     objects (Data/PropList ids) the objective cannot be done without. If one is
--             missing from the map, the objective is skipped instead of blocking the game.
--   rooms     rooms a player has to be able to walk to for this objective. tests/mission.luau
--             proves each is reachable with the doors unlocked so far (no softlocks).
--   requires  objectives that must be complete first (always earlier in the list).
--   stage     THE COPY's escalation stage once the objective is complete.
--   steps     number of parts in a multi-step objective (shown as progress on the HUD).

export type Objective = {
	id: string,
	chapter: number,
	title: string,
	hint: string?,
	completion: string,
	props: { string }?,
	rooms: { string },
	requires: { string }?,
	stage: string?,
	steps: number?,
}

export type Chapter = {
	title: string,
	-- Room a player is returned to after being caught or respawning during this chapter.
	-- Always a room that is open by the time the chapter starts.
	checkpoint: string,
}

export type Optional = { id: string, title: string }

local chapters: { Chapter } = {
	{ title = "CHAPTER_1_TITLE", checkpoint = "A_Lobby" },
	{ title = "CHAPTER_2_TITLE", checkpoint = "B_PowerRoom" },
	{ title = "CHAPTER_3_TITLE", checkpoint = "B_Junction" },
	{ title = "CHAPTER_4_TITLE", checkpoint = "B_SouthCorridor" },
	{ title = "CHAPTER_5_TITLE", checkpoint = "G_GeneratorHall" },
}

local list: { Objective } = {
	-- ---- Chapter 1: THE FACILITY WAKES UP ----
	{
		id = "EnterStation",
		chapter = 1,
		title = "OBJECTIVE_ENTER_STATION",
		hint = "OBJECTIVE_ENTER_STATION_HINT",
		completion = "A player leaves the arrival elevator.",
		rooms = { "A_Lobby" },
	},
	{
		id = "ReadIncidentLog",
		chapter = 1,
		title = "OBJECTIVE_READ_INCIDENT_LOG",
		hint = "OBJECTIVE_READ_INCIDENT_LOG_HINT",
		completion = "A player reads the incident log at the reception desk.",
		props = { "IncidentLog" },
		rooms = { "A_Lobby" },
		requires = { "EnterStation" },
	},
	{
		id = "FindPowerControls",
		chapter = 1,
		title = "OBJECTIVE_FIND_POWER_CONTROLS",
		hint = "OBJECTIVE_FIND_POWER_CONTROLS_HINT",
		completion = "A player reaches the Power Room or operates a breaker or the lever.",
		rooms = { "B_PowerRoom" },
		requires = { "EnterStation" },
	},
	{
		id = "RestorePower",
		chapter = 1,
		title = "OBJECTIVE_RESTORE_POWER",
		hint = "OBJECTIVE_RESTORE_POWER_HINT",
		completion = "The three breakers are engaged in the memo's order and the lever is thrown.",
		props = { "MainLever", "StartupMemo" },
		rooms = { "A_SecurityBooth", "B_PowerRoom", "B_Maintenance" },
		requires = { "FindPowerControls" },
		stage = "Aware",
	},
	{
		id = "InspectGenerator",
		chapter = 1,
		title = "OBJECTIVE_INSPECT_GENERATOR",
		hint = "OBJECTIVE_INSPECT_GENERATOR_HINT",
		completion = "A player reads the status panel of the main generator, which power woke up.",
		props = { "GeneratorPanel" },
		rooms = { "G_GeneratorHall" },
		requires = { "RestorePower" },
	},

	-- ---- Chapter 2: SYSTEM FAILURE ----
	{
		id = "InspectSwitchgear",
		chapter = 2,
		title = "OBJECTIVE_INSPECT_SWITCHGEAR",
		hint = "OBJECTIVE_INSPECT_SWITCHGEAR_HINT",
		completion = "A player examines the relay cabinet in Electrical Control (its fuse is missing).",
		props = { "Switchgear" },
		rooms = { "G_ElectricalControl" },
		requires = { "InspectGenerator" },
	},
	{
		id = "FindRelayFuse",
		chapter = 2,
		title = "OBJECTIVE_FIND_RELAY_FUSE",
		hint = "OBJECTIVE_FIND_RELAY_FUSE_HINT",
		completion = "A player picks up the relay fuse (the maintenance report says where it is).",
		props = { "RelayFuse", "MaintenanceReport" },
		rooms = { "B_Maintenance", "B_Storage102" },
		requires = { "InspectSwitchgear" },
	},
	{
		id = "RouteRelayPower",
		chapter = 2,
		title = "OBJECTIVE_ROUTE_RELAY_POWER",
		hint = "OBJECTIVE_ROUTE_RELAY_POWER_HINT",
		completion = "The fuse is fitted and the feeder switches are set so the load matches the "
			.. "relay's demand exactly; the relay closes and the sealed bulkheads open.",
		props = { "Switchgear", "Feeder_1", "Feeder_2", "Feeder_3", "Feeder_4" },
		rooms = { "G_ElectricalControl" },
		requires = { "FindRelayFuse" },
		steps = 2,
	},

	-- ---- Chapter 3: THE SIGNAL ----
	{
		id = "InvestigateRadio",
		chapter = 3,
		title = "OBJECTIVE_INVESTIGATE_RADIO",
		hint = "OBJECTIVE_INVESTIGATE_RADIO_HINT",
		completion = "The receiver's transmission has been heard to the end.",
		props = { "Radio" },
		rooms = { "B_MonitorRoom" },
		requires = { "RouteRelayPower" },
		stage = "Hunting",
	},
	{
		id = "FindSignalTape",
		chapter = 3,
		title = "OBJECTIVE_FIND_SIGNAL_TAPE",
		hint = "OBJECTIVE_FIND_SIGNAL_TAPE_HINT",
		completion = "A player takes tape 9-114 from the laboratory archive.",
		props = { "SignalTape" },
		rooms = { "C_Archive" },
		requires = { "InvestigateRadio" },
	},
	{
		id = "TraceSignal",
		chapter = 3,
		title = "OBJECTIVE_TRACE_SIGNAL",
		hint = "OBJECTIVE_TRACE_SIGNAL_HINT",
		completion = "The tape is played on the analysis console and the trace runs to the end.",
		props = { "AnalysisConsole" },
		rooms = { "C_SignalAnalysis" },
		requires = { "FindSignalTape" },
		stage = "Hostile",
	},
	{
		id = "EscapeLaboratory",
		chapter = 3,
		title = "OBJECTIVE_ESCAPE_LABORATORY",
		hint = "OBJECTIVE_ESCAPE_LABORATORY_HINT",
		completion = "After the trace, a player gets back out of the laboratory wing.",
		rooms = { "B_NorthCorridor" },
		requires = { "TraceSignal" },
	},

	-- ---- Chapter 4: RESTRICTED AREA ----
	{
		id = "FindCommCode",
		chapter = 4,
		title = "OBJECTIVE_FIND_COMM_CODE",
		hint = "OBJECTIVE_FIND_COMM_CODE_HINT",
		completion = "Both halves of the door code have been read (operator's note, patient chart).",
		props = { "OperatorNote", "PatientChart" },
		rooms = { "D_OperatorOffice", "E_PatientRoom" },
		requires = { "EscapeLaboratory" },
		steps = 2,
	},
	{
		id = "EnterCommCenter",
		chapter = 4,
		title = "OBJECTIVE_ENTER_COMM_CENTER",
		hint = "OBJECTIVE_ENTER_COMM_CENTER_HINT",
		completion = "The correct code is entered on the antechamber keypad.",
		props = { "CommKeypad" },
		rooms = { "D_Antechamber" },
		requires = { "TraceSignal" },
	},
	{
		id = "RestoreTransmitter",
		chapter = 4,
		title = "OBJECTIVE_RESTORE_TRANSMITTER",
		hint = "OBJECTIVE_RESTORE_TRANSMITTER_HINT",
		completion = "The recording servers are restarted, the mast is raised and the radio desk is "
			.. "locked onto the carrier channel found by the trace.",
		props = { "ServerRack", "MastControl", "RadioDesk", "TunerUp", "TunerDown" },
		rooms = { "D_ServerRoom", "D_RadioMast", "D_RadioControl" },
		requires = { "EnterCommCenter" },
		steps = 3,
	},
	{
		id = "SendDistress",
		chapter = 4,
		title = "OBJECTIVE_SEND_DISTRESS",
		hint = "OBJECTIVE_SEND_DISTRESS_HINT",
		completion = "The central computer sends the distress call and the answer has been heard.",
		props = { "CommConsole" },
		rooms = { "D_CommCenter" },
		requires = { "RestoreTransmitter" },
	},
	{
		id = "EscapeCommCenter",
		chapter = 4,
		title = "OBJECTIVE_ESCAPE_COMM_CENTER",
		hint = "OBJECTIVE_ESCAPE_COMM_CENTER_HINT",
		completion = "After the answer, a player gets out of the communication wing.",
		rooms = { "B_SouthCorridor" },
		requires = { "SendDistress" },
	},

	-- ---- Chapter 5: NO WAY BACK ----
	{
		id = "RestoreFreightCircuit",
		chapter = 5,
		title = "OBJECTIVE_RESTORE_FREIGHT_CIRCUIT",
		hint = "OBJECTIVE_RESTORE_FREIGHT_CIRCUIT_HINT",
		completion = "The ventilation plant is started and the main generator is switched to full "
			.. "load; the freight wing bulkheads open.",
		props = { "FanControl", "GeneratorPanel" },
		rooms = { "G_Ventilation", "G_GeneratorHall" },
		requires = { "SendDistress" },
		steps = 2,
	},
	{
		id = "ReachObservation",
		chapter = 5,
		title = "OBJECTIVE_REACH_OBSERVATION",
		hint = "OBJECTIVE_REACH_OBSERVATION_HINT",
		completion = "A player reaches the observation chamber in the freight wing.",
		rooms = { "H_ObservationChamber" },
		requires = { "RestoreFreightCircuit" },
	},
	{
		id = "ActivateEvacuation",
		chapter = 5,
		title = "OBJECTIVE_ACTIVATE_EVACUATION",
		hint = "OBJECTIVE_ACTIVATE_EVACUATION_HINT",
		completion = "The evacuation override in the observation chamber is used.",
		props = { "EvacConsole" },
		rooms = { "H_ObservationChamber" },
		requires = { "ReachObservation" },
		stage = "FinalPursuit",
	},
	{
		id = "Escape",
		chapter = 5,
		title = "OBJECTIVE_ESCAPE",
		hint = "OBJECTIVE_ESCAPE_HINT",
		completion = "The freight elevator is started with the team aboard.",
		props = { "FreightPanel" },
		rooms = { "H_FreightElevator" },
		requires = { "ActivateEvacuation" },
	},
}

-- Never required, never block anything; shown under the main objective once started.
local optional: { Optional } = {
	{ id = "ReadDocuments", title = "OPTIONAL_READ_DOCUMENTS" },
	{ id = "RestrictedArchive", title = "OPTIONAL_RESTRICTED_ARCHIVE" },
}

return table.freeze({
	List = table.freeze(list),
	Chapters = table.freeze(chapters),
	Optional = table.freeze(optional),
})
