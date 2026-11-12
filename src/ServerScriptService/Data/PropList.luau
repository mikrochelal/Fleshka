--!nonstrict
-- Gameplay objects the game places in the station while it runs. Pure data.
--
-- The generated map is architecture only, so documents, consoles, pickups and switches
-- are created at runtime (Systems/WorldProps) and exist only during play.
-- Positions are fractions of the room's footprint (fx along X, fz along Z, 0..1), measured
-- from the room's zone, so they follow the room if the layout ever changes.
--
--   reuse   name of an existing map part in that room to use instead of creating one
--   stand   size {x, y, z} of a plinth the item sits on (omit for wall-mounted items)
--   y       height of the item's underside above the floor when there is no stand
--   action  localization key of the prompt's action text
--   object  localization key of the prompt's object text
--
-- tests/props.luau checks every entry against the map layout: inside its room, clear of
-- doorways and of the map's own placeholder props.

local PAPER = { 2.2, 0.15, 1.6 }
local DESK = { 3, 3, 2 }
local PLINTH = { 2.5, 2.5, 2.5 }
local PACK = { 0.8, 0.6, 1.4 }
local POST = { 2, 3, 2 }
local BOX = { 1.4, 1.6, 1 }

local function document(id, room, fx, fz, object)
	return {
		id = id,
		kind = "Document",
		room = room,
		fx = fx,
		fz = fz,
		stand = DESK,
		size = PAPER,
		look = "paper",
		action = "INTERACTION_READ",
		object = object,
	}
end

local function battery(id, room, fx, fz)
	return {
		id = id,
		kind = "Battery",
		room = room,
		fx = fx,
		fz = fz,
		stand = PLINTH,
		size = PACK,
		look = "battery",
		action = "INTERACTION_TAKE",
		object = "OBJECT_BATTERY_PACK",
	}
end

-- A control on a short post: a switch box, a console, a keypad.
local function control(id, kind, room, fx, fz, look, action, object, enabled)
	return {
		id = id,
		kind = kind,
		room = room,
		fx = fx,
		fz = fz,
		stand = POST,
		size = BOX,
		look = look,
		action = action,
		object = object,
		enabled = enabled,
	}
end

return {
	-- ---- A. Entrance ----
	{
		id = "ElevatorPanel",
		kind = "ElevatorPanel",
		room = "A_Elevator",
		fx = 0.5,
		fz = 0.065,
		y = 3,
		size = { 3, 4, 0.6 },
		look = "panel",
		action = "INTERACTION_CALL_ELEVATOR",
		object = "OBJECT_ELEVATOR_CONTROL",
	},
	document("IncidentLog", "A_Lobby", 0.6, 0.12, "OBJECT_INCIDENT_LOG"),
	document("StartupMemo", "A_SecurityBooth", 0.25, 0.15, "OBJECT_MAINTENANCE_MEMO"),
	document("DirectorMemo", "A_AdminOffice", 0.75, 0.6, "OBJECT_DIRECTOR_MEMO"),
	battery("Battery_Lockers", "A_Lockers", 0.5, 0.3),

	-- ---- B. Research corridors ----
	document("ResearchNote", "B_Office101", 0.25, 0.3, "OBJECT_RESEARCH_NOTE"),
	document("MaintenanceReport", "B_Maintenance", 0.8, 0.45, "OBJECT_MAINTENANCE_REPORT"),
	document("BreakRoomNote", "B_BreakRoom", 0.7, 0.6, "OBJECT_BREAK_ROOM_NOTE"),
	{
		id = "MainLever",
		kind = "MainLever",
		room = "B_PowerRoom",
		reuse = "Placeholder_MainLever",
		fx = 0.961,
		fz = 0.583,
		y = 3,
		size = { 0.6, 4, 2 },
		look = "panel",
		action = "INTERACTION_THROW_LEVER",
		object = "OBJECT_EMERGENCY_POWER",
	},
	{
		id = "Radio",
		kind = "Radio",
		room = "B_MonitorRoom",
		fx = 0.85,
		fz = 0.5,
		stand = { 4, 3, 3 },
		size = { 2, 1.4, 1.2 },
		look = "radio",
		action = "INTERACTION_LISTEN",
		object = "OBJECT_RADIO_RECEIVER",
		enabled = false,
	},
	{
		id = "RelayFuse",
		kind = "Item",
		room = "B_Storage102",
		fx = 0.75,
		fz = 0.25,
		stand = PLINTH,
		size = { 0.6, 0.6, 1.6 },
		look = "item",
		action = "INTERACTION_TAKE",
		object = "OBJECT_RELAY_FUSE",
	},
	battery("Battery_Maintenance", "B_Maintenance", 0.25, 0.6),
	battery("Battery_Infirmary", "B_Infirmary", 0.5, 0.6),

	-- ---- C. Laboratory ----
	{
		id = "AnalysisConsole",
		kind = "AnalysisConsole",
		room = "C_SignalAnalysis",
		reuse = "Placeholder_AnalysisConsole",
		fx = 0.5,
		fz = 0.87,
		y = 0,
		size = { 14, 4, 2 },
		look = "panel",
		action = "INTERACTION_RUN_TRACE",
		object = "OBJECT_ANALYSIS_CONSOLE",
	},
	{
		id = "SignalTape",
		kind = "Item",
		room = "C_Archive",
		fx = 0.85,
		fz = 0.5,
		stand = PLINTH,
		size = { 1.2, 0.4, 0.9 },
		look = "item",
		action = "INTERACTION_TAKE",
		object = "OBJECT_SIGNAL_TAPE",
	},
	document("ContainmentReport", "C_Containment", 0.25, 0.25, "OBJECT_CONTAINMENT_REPORT"),
	battery("Battery_Observation", "C_Observation", 0.5, 0.5),

	-- ---- D. Communication center ----
	{
		id = "CommKeypad",
		kind = "Keypad",
		room = "D_Antechamber",
		reuse = "Placeholder_Keypad",
		fx = 0.5,
		fz = 0.5,
		y = 4,
		size = { 0.6, 2, 1.5 },
		look = "panel",
		action = "INTERACTION_ENTER_CODE",
		object = "OBJECT_COMM_KEYPAD",
	},
	{
		id = "CommConsole",
		kind = "CommConsole",
		room = "D_CommCenter",
		reuse = "Placeholder_CentralComputer",
		fx = 0.5,
		fz = 0.1,
		stand = { 8, 2, 3 },
		size = { 6, 3, 2 },
		look = "panel",
		action = "INTERACTION_SEND_DISTRESS",
		object = "OBJECT_CENTRAL_COMPUTER",
	},
	{
		id = "ServerRack",
		kind = "ServerRack",
		room = "D_ServerRoom",
		reuse = "Placeholder_ServerRacks",
		fx = 0.5,
		fz = 0.5,
		y = 0,
		size = { 3, 9, 18 },
		look = "panel",
		action = "INTERACTION_RESTART_SERVERS",
		object = "OBJECT_SERVER_RACK",
	},
	control("MastControl", "MastControl", "D_RadioMast", 0.2, 0.5, "panel", "INTERACTION_RAISE_MAST", "OBJECT_MAST_CONTROL"),
	{
		id = "RadioDesk",
		kind = "RadioDesk",
		room = "D_RadioControl",
		reuse = "Placeholder_RadioDesk",
		fx = 0.5,
		fz = 0.5,
		y = 0,
		size = { 12, 4, 3 },
		look = "panel",
		action = "INTERACTION_LOCK_CHANNEL",
		object = "OBJECT_RADIO_DESK",
	},
	control("TunerDown", "Tuner", "D_RadioControl", 0.25, 0.8, "switch", "INTERACTION_TUNE_DOWN", "OBJECT_TUNER"),
	control("TunerUp", "Tuner", "D_RadioControl", 0.75, 0.8, "switch", "INTERACTION_TUNE_UP", "OBJECT_TUNER"),
	document("OperatorNote", "D_OperatorOffice", 0.5, 0.2, "OBJECT_OPERATOR_NOTE"),
	document("ServerLog", "D_ServerRoom", 0.3, 0.3, "OBJECT_SERVER_LOG"),
	battery("Battery_Operator", "D_OperatorOffice", 0.6, 0.75),

	-- ---- E. Medical ----
	document("ExaminationLog", "E_MedReception", 0.8, 0.5, "OBJECT_EXAMINATION_LOG"),
	document("QuarantineOrder", "E_Examination", 0.2, 0.5, "OBJECT_QUARANTINE_ORDER"),
	document("PatientChart", "E_PatientRoom", 0.2, 0.45, "OBJECT_PATIENT_CHART"),

	-- ---- F. Archives ----
	document("TapeTranscript", "F_TapeStorage", 0.25, 0.5, "OBJECT_TAPE_TRANSCRIPT"),
	document("PersonnelFile", "F_PersonnelRecords", 0.6, 0.3, "OBJECT_PERSONNEL_FILE"),
	document("RestrictedFile", "F_RestrictedArchive", 0.25, 0.6, "OBJECT_RESTRICTED_FILE"),
	control("ArchiveKeypad", "Keypad", "F_DocumentArchive", 0.72, 0.12, "panel", "INTERACTION_ENTER_CODE", "OBJECT_ARCHIVE_KEYPAD"),

	-- ---- G. Power and maintenance ----
	{
		id = "Switchgear",
		kind = "Switchgear",
		room = "G_ElectricalControl",
		reuse = "Placeholder_SwitchGear",
		fx = 0.5,
		fz = 0.9,
		y = 0,
		size = { 20, 7, 2 },
		look = "panel",
		action = "INTERACTION_INSPECT",
		object = "OBJECT_SWITCHGEAR",
	},
	control("Feeder_1", "Feeder", "G_ElectricalControl", 0.1, 0.55, "switch", "INTERACTION_SWITCH_FEEDER", "OBJECT_FEEDER_1"),
	control("Feeder_2", "Feeder", "G_ElectricalControl", 0.1, 0.8, "switch", "INTERACTION_SWITCH_FEEDER", "OBJECT_FEEDER_2"),
	control("Feeder_3", "Feeder", "G_ElectricalControl", 0.9, 0.55, "switch", "INTERACTION_SWITCH_FEEDER", "OBJECT_FEEDER_3"),
	control("Feeder_4", "Feeder", "G_ElectricalControl", 0.9, 0.8, "switch", "INTERACTION_SWITCH_FEEDER", "OBJECT_FEEDER_4"),
	document("FeederNote", "G_ElectricalControl", 0.2, 0.3, "OBJECT_SHIFT_HANDOVER"),
	control("GeneratorPanel", "GeneratorPanel", "G_GeneratorHall", 0.2, 0.3, "panel", "INTERACTION_INSPECT", "OBJECT_GENERATOR_PANEL"),
	control("FanControl", "FanControl", "G_Ventilation", 0.2, 0.3, "panel", "INTERACTION_START_FANS", "OBJECT_FAN_CONTROL"),

	-- ---- H. Freight and containment ----
	document("EvacuationNotice", "H_Checkpoint", 0.2, 0.75, "OBJECT_EVACUATION_NOTICE"),
	document("SourceLog", "H_ObservationChamber", 0.3, 0.75, "OBJECT_SOURCE_LOG"),
	control("EvacConsole", "EvacConsole", "H_ObservationChamber", 0.75, 0.25, "panel", "INTERACTION_AUTHORISE_EVACUATION", "OBJECT_EVAC_CONSOLE"),
	{
		id = "FreightPanel",
		kind = "FreightPanel",
		room = "H_FreightElevator",
		fx = 0.07,
		fz = 0.5,
		y = 3,
		size = { 0.6, 4, 3 },
		look = "panel",
		action = "INTERACTION_START_LIFT",
		object = "OBJECT_FREIGHT_PANEL",
	},
	battery("Battery_Checkpoint", "H_Checkpoint", 0.75, 0.25),
}
