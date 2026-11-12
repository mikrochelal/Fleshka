--!nonstrict
-- STATION-09 draft layout: pure data, no Roblox API, so it can be unit tested.
--
-- Coordinates are studs in the station's own space: X grows east, Z grows south, floors sit
-- at Y = 0. `origin` moves the whole station in the world.
--
-- The plan is one building: an east-west spine corridor with rooms wall to wall on both
-- sides, ending in a junction hall. From there wings run north (laboratory, archives),
-- south (communication center), and east (medical and quarantine). The power and
-- maintenance wing lies south of the spine and leads west to the freight and containment
-- wing, which loops back to the entrance. Everything between and around the rooms is
-- filled with solid rock by the generator.
--
-- The first 29 rooms and 30 connections are the original station (layout v3) and are
-- pinned by tests/map.luau: new rooms are only ever appended after them.
--
-- Rules checked by Plan.validate (and by tests/map.luau):
--   * rooms are rectangles that never overlap;
--   * connected rooms share an edge, and the opening fits inside the shared part of it;
--   * every room can be reached from the first one.

local WALL = "wall"
local FURNITURE = "furniture"
local PUZZLE = "puzzle"

return {
	-- Bumped whenever the generated result changes; stored on the generated map.
	version = 4,

	rootName = "Station09",

	-- Below the default Baseplate, so the station is underground and shielded from sunlight.
	origin = { x = 0, y = -60, z = 0 },

	wallThickness = 1,
	slabThickness = 1,
	doorHeight = 8,
	-- Roughly one ceiling light per this many studs, in each direction.
	lightSpacing = 24,
	-- Solid rock kept around the outermost rooms.
	shellMargin = 6,

	areas = {
		{ id = "A", folder = "A_Entrance", name = "Entrance" },
		{ id = "B", folder = "B_Corridors", name = "Corridors" },
		{ id = "C", folder = "C_Laboratory", name = "Laboratory" },
		{ id = "D", folder = "D_CommCenter", name = "CommCenter" },
		{ id = "E", folder = "E_Medical", name = "Medical" },
		{ id = "F", folder = "F_Archives", name = "Archives" },
		{ id = "G", folder = "G_Power", name = "Power" },
		{ id = "H", folder = "H_Containment", name = "Containment" },
	},

	-- stylua: ignore start
	rooms = {
		-- A. Entrance / Security: elevator -> lobby -> checkpoint, which lines up with the spine.
		{ name = "A_Elevator", area = "A", x0 = 0, x1 = 16, z0 = 0, z1 = 20, height = 12, style = "metal" },
		{ name = "A_Lobby", area = "A", x0 = 16, x1 = 52, z0 = -10, z1 = 30, height = 14 },
		{ name = "A_SecurityBooth", area = "A", x0 = 52, x1 = 76, z0 = -10, z1 = 4, height = 12 },
		{ name = "A_Checkpoint", area = "A", x0 = 52, x1 = 76, z0 = 4, z1 = 16, height = 12, style = "metal" },
		{ name = "A_Lockers", area = "A", x0 = 52, x1 = 76, z0 = 16, z1 = 30, height = 12 },

		-- B. Research Corridors: the spine, the rooms along it, the junction and both wings.
		{ name = "B_MainCorridor", area = "B", x0 = 76, x1 = 196, z0 = 4, z1 = 16, height = 12, style = "metal" },
		{ name = "B_Office101", area = "B", x0 = 76, x1 = 104, z0 = -16, z1 = 4, height = 12 },
		{ name = "B_Storage102", area = "B", x0 = 104, x1 = 128, z0 = -16, z1 = 4, height = 12 },
		{ name = "B_MonitorRoom", area = "B", x0 = 128, x1 = 164, z0 = -16, z1 = 4, height = 12 },
		{ name = "B_Records104", area = "B", x0 = 164, x1 = 196, z0 = -16, z1 = 4, height = 12 },
		{ name = "B_PowerRoom", area = "B", x0 = 76, x1 = 112, z0 = 16, z1 = 40, height = 12, style = "metal" },
		{ name = "B_Maintenance", area = "B", x0 = 112, x1 = 140, z0 = 16, z1 = 40, height = 12 },
		{ name = "B_BreakRoom", area = "B", x0 = 140, x1 = 172, z0 = 16, z1 = 40, height = 12 },
		{ name = "B_Infirmary", area = "B", x0 = 172, x1 = 196, z0 = 16, z1 = 40, height = 12, style = "lab" },
		{ name = "B_Junction", area = "B", x0 = 196, x1 = 224, z0 = -2, z1 = 22, height = 14, style = "metal" },
		{ name = "B_NorthCorridor", area = "B", x0 = 204, x1 = 216, z0 = -50, z1 = -2, height = 12, style = "metal" },
		{ name = "B_SouthCorridor", area = "B", x0 = 204, x1 = 216, z0 = 22, z1 = 62, height = 12, style = "metal" },
		{ name = "B_ServiceTunnel", area = "B", x0 = 140, x1 = 204, z0 = -24, z1 = -16, height = 10, style = "metal", emergency = true },

		-- C. Experimental Laboratory: north wing, entered through the airlock.
		{ name = "C_Airlock", area = "C", x0 = 200, x1 = 216, z0 = -66, z1 = -50, height = 12, style = "metal", emergency = true },
		{ name = "C_MainLab", area = "C", x0 = 216, x1 = 276, z0 = -92, z1 = -44, height = 16, style = "lab" },
		{ name = "C_SignalChamber", area = "C", x0 = 276, x1 = 304, z0 = -82, z1 = -54, height = 14, style = "metal" },
		{ name = "C_Archive", area = "C", x0 = 228, x1 = 264, z0 = -116, z1 = -92, height = 12 },
		{ name = "C_Observation", area = "C", x0 = 216, x1 = 246, z0 = -44, z1 = -20, height = 12, style = "lab" },
		{ name = "C_ColdStorage", area = "C", x0 = 246, x1 = 276, z0 = -44, z1 = -24, height = 12, style = "lab" },

		-- D. Communication Center: south wing, behind the security-code door.
		{ name = "D_OperatorOffice", area = "D", x0 = 216, x1 = 246, z0 = 22, z1 = 44, height = 12 },
		{ name = "D_Antechamber", area = "D", x0 = 196, x1 = 216, z0 = 62, z1 = 80, height = 12, style = "metal" },
		{ name = "D_CommCenter", area = "D", x0 = 216, x1 = 280, z0 = 44, z1 = 100, height = 16 },
		{ name = "D_ServerRoom", area = "D", x0 = 280, x1 = 308, z0 = 52, z1 = 80, height = 12, style = "metal" },
		{ name = "D_RadioMast", area = "D", x0 = 234, x1 = 262, z0 = 100, z1 = 128, height = 16, style = "metal" },
		-- ---- Expansion (layout v4). Appended only; the rooms above never move. ----

		-- A. Administration and access control.
		{ name = "A_AdminOffice", area = "A", x0 = 16, x1 = 44, z0 = -34, z1 = -10, height = 12 },
		{ name = "A_AccessControl", area = "A", x0 = 24, x1 = 40, z0 = 30, z1 = 40, height = 12, style = "metal" },

		-- C. Laboratory: analysis and containment behind the signal chamber.
		{ name = "C_SignalAnalysis", area = "C", x0 = 276, x1 = 304, z0 = -54, z1 = -30, height = 12, style = "lab" },
		{ name = "C_Containment", area = "C", x0 = 304, x1 = 328, z0 = -80, z1 = -56, height = 12, style = "metal", emergency = true },

		-- D. Radio control beside the communication center.
		{ name = "D_RadioControl", area = "D", x0 = 192, x1 = 216, z0 = 80, z1 = 104, height = 12 },

		-- E. Medical and quarantine: east of the junction.
		{ name = "E_MedCorridor", area = "E", x0 = 224, x1 = 284, z0 = 4, z1 = 16, height = 12, style = "lab" },
		{ name = "E_MedReception", area = "E", x0 = 224, x1 = 252, z0 = -18, z1 = 4, height = 12, style = "lab" },
		{ name = "E_Examination", area = "E", x0 = 252, x1 = 284, z0 = -18, z1 = 4, height = 12, style = "lab" },
		{ name = "E_QuarantineCorridor", area = "E", x0 = 284, x1 = 324, z0 = 4, z1 = 16, height = 12, style = "lab", emergency = true },
		{ name = "E_PatientRoom", area = "E", x0 = 284, x1 = 312, z0 = -18, z1 = 4, height = 12, style = "lab" },
		{ name = "E_IsolationChamber", area = "E", x0 = 324, x1 = 352, z0 = -4, z1 = 24, height = 14, style = "metal", emergency = true },

		-- F. Archives: north-west, off the north corridor.
		{ name = "F_ArchiveCorridor", area = "F", x0 = 120, x1 = 204, z0 = -40, z1 = -30, height = 12 },
		{ name = "F_DocumentArchive", area = "F", x0 = 120, x1 = 152, z0 = -66, z1 = -40, height = 12 },
		{ name = "F_TapeStorage", area = "F", x0 = 152, x1 = 184, z0 = -66, z1 = -40, height = 12 },
		{ name = "F_PersonnelRecords", area = "F", x0 = 92, x1 = 120, z0 = -52, z1 = -24, height = 12 },
		{ name = "F_RestrictedArchive", area = "F", x0 = 120, x1 = 152, z0 = -92, z1 = -66, height = 12, style = "metal" },

		-- G. Power and maintenance: south of the spine, behind the emergency power room.
		{ name = "G_ServiceCorridor", area = "G", x0 = 76, x1 = 204, z0 = 40, z1 = 50, height = 12, style = "metal" },
		{ name = "G_GeneratorHall", area = "G", x0 = 76, x1 = 124, z0 = 50, z1 = 86, height = 16, style = "metal" },
		{ name = "G_ElectricalControl", area = "G", x0 = 124, x1 = 156, z0 = 50, z1 = 76, height = 12, style = "metal" },
		{ name = "G_Ventilation", area = "G", x0 = 164, x1 = 196, z0 = 50, z1 = 78, height = 14, style = "metal" },
		{ name = "G_PipeTunnel", area = "G", x0 = 40, x1 = 76, z0 = 58, z1 = 68, height = 10, style = "metal", emergency = true },

		-- H. Freight and containment: the deepest part of the station.
		{ name = "H_CargoCorridor", area = "H", x0 = 24, x1 = 40, z0 = 40, z1 = 120, height = 14, style = "metal" },
		{ name = "H_FreightElevator", area = "H", x0 = 4, x1 = 24, z0 = 44, z1 = 64, height = 14, style = "metal" },
		{ name = "H_Checkpoint", area = "H", x0 = 20, x1 = 44, z0 = 120, z1 = 140, height = 12, style = "metal", emergency = true },
		{ name = "H_ObservationChamber", area = "H", x0 = 44, x1 = 80, z0 = 116, z1 = 144, height = 12, style = "metal" },
		{ name = "H_SignalSource", area = "H", x0 = 80, x1 = 132, z0 = 104, z1 = 156, height = 20, style = "metal", emergency = true },
	},
	-- stylua: ignore end

	-- `at` is the centre of the opening along the shared edge (a Z value when the rooms sit
	-- side by side in X, an X value otherwise). `door = false` leaves a framed archway.
	connections = {
		{ a = "A_Elevator", b = "A_Lobby", at = 10, width = 8, door = true },
		{ a = "A_Lobby", b = "A_SecurityBooth", at = -3, width = 5, door = true },
		{ a = "A_Lobby", b = "A_Checkpoint", at = 10, width = 8, door = false },
		{ a = "A_Lobby", b = "A_Lockers", at = 23, width = 5, door = true },
		{ a = "A_SecurityBooth", b = "A_Checkpoint", at = 64, width = 4, door = true },
		-- Bulkhead between the entrance and the facility proper.
		{
			a = "A_Checkpoint",
			b = "B_MainCorridor",
			at = 10,
			width = 8,
			door = true,
			requiresPower = true,
		},

		{ a = "B_MainCorridor", b = "B_Office101", at = 90, width = 5, door = true },
		{ a = "B_MainCorridor", b = "B_Storage102", at = 116, width = 5, door = true },
		{ a = "B_MainCorridor", b = "B_MonitorRoom", at = 146, width = 5, door = true },
		{ a = "B_MainCorridor", b = "B_Records104", at = 180, width = 5, door = true },
		{ a = "B_MainCorridor", b = "B_PowerRoom", at = 94, width = 6, door = true },
		{ a = "B_MainCorridor", b = "B_Maintenance", at = 126, width = 5, door = true },
		{ a = "B_MainCorridor", b = "B_BreakRoom", at = 156, width = 5, door = true },
		{ a = "B_MainCorridor", b = "B_Infirmary", at = 184, width = 5, door = true },
		{ a = "B_MainCorridor", b = "B_Junction", at = 10, width = 8, door = false },
		{ a = "B_Junction", b = "B_NorthCorridor", at = 210, width = 8, door = false },
		{ a = "B_Junction", b = "B_SouthCorridor", at = 210, width = 8, door = false },
		-- Shortcut loop that opens once power is back.
		{
			a = "B_MonitorRoom",
			b = "B_ServiceTunnel",
			at = 152,
			width = 4,
			door = true,
			requiresPower = true,
		},
		{
			a = "B_ServiceTunnel",
			b = "B_NorthCorridor",
			at = -20,
			width = 5,
			door = true,
			requiresPower = true,
		},

		{
			a = "B_NorthCorridor",
			b = "C_Airlock",
			at = 210,
			width = 6,
			door = true,
			requiresPower = true,
		},
		{ a = "C_Airlock", b = "C_MainLab", at = -58, width = 6, door = true },
		{ a = "C_MainLab", b = "C_SignalChamber", at = -68, width = 6, door = true },
		{ a = "C_MainLab", b = "C_Archive", at = 246, width = 5, door = true },
		{ a = "C_MainLab", b = "C_Observation", at = 231, width = 5, door = true },
		{ a = "C_MainLab", b = "C_ColdStorage", at = 261, width = 5, door = true },

		{ a = "B_SouthCorridor", b = "D_OperatorOffice", at = 33, width = 5, door = true },
		{ a = "B_SouthCorridor", b = "D_Antechamber", at = 210, width = 6, door = true },
		-- The security-code door.
		{ a = "D_Antechamber", b = "D_CommCenter", at = 71, width = 6, door = true, locked = true },
		{ a = "D_CommCenter", b = "D_ServerRoom", at = 66, width = 5, door = true },
		{ a = "D_CommCenter", b = "D_RadioMast", at = 248, width = 6, door = true },
		-- ---- Expansion (layout v4) ----
		{ a = "A_Lobby", b = "A_AdminOffice", at = 30, width = 5, door = true },
		{ a = "A_Lobby", b = "A_AccessControl", at = 32, width = 6, door = true },
		-- Restricted link between the entrance and the freight wing.
		{
			a = "A_AccessControl",
			b = "H_CargoCorridor",
			at = 32,
			width = 6,
			door = true,
			locked = true,
		},

		{ a = "C_SignalChamber", b = "C_SignalAnalysis", at = 290, width = 5, door = true },
		{
			a = "C_SignalChamber",
			b = "C_Containment",
			at = -62,
			width = 5,
			door = true,
			requiresPower = true,
		},

		{ a = "D_CommCenter", b = "D_RadioControl", at = 90, width = 5, door = true },

		{ a = "B_Junction", b = "E_MedCorridor", at = 10, width = 8, door = true },
		{ a = "E_MedCorridor", b = "E_MedReception", at = 238, width = 5, door = true },
		{ a = "E_MedCorridor", b = "E_Examination", at = 268, width = 5, door = true },
		-- Quarantine seal.
		{
			a = "E_MedCorridor",
			b = "E_QuarantineCorridor",
			at = 10,
			width = 6,
			door = true,
			requiresPower = true,
		},
		{ a = "E_QuarantineCorridor", b = "E_PatientRoom", at = 298, width = 5, door = true },
		{ a = "E_QuarantineCorridor", b = "E_IsolationChamber", at = 10, width = 6, door = true },

		{ a = "B_NorthCorridor", b = "F_ArchiveCorridor", at = -35, width = 6, door = true },
		{ a = "F_ArchiveCorridor", b = "F_DocumentArchive", at = 136, width = 5, door = true },
		{ a = "F_ArchiveCorridor", b = "F_TapeStorage", at = 168, width = 5, door = true },
		{ a = "F_ArchiveCorridor", b = "F_PersonnelRecords", at = -35, width = 5, door = true },
		{
			a = "F_DocumentArchive",
			b = "F_RestrictedArchive",
			at = 136,
			width = 5,
			door = true,
			locked = true,
		},

		{ a = "B_PowerRoom", b = "G_ServiceCorridor", at = 93, width = 6, door = true },
		{ a = "B_Maintenance", b = "G_ServiceCorridor", at = 134, width = 5, door = true },
		-- Shortcut from the power wing to the south corridor, open once power is back.
		{
			a = "G_ServiceCorridor",
			b = "B_SouthCorridor",
			at = 45,
			width = 6,
			door = true,
			requiresPower = true,
		},
		{ a = "G_ServiceCorridor", b = "G_GeneratorHall", at = 100, width = 8, door = false },
		{ a = "G_ServiceCorridor", b = "G_ElectricalControl", at = 140, width = 5, door = true },
		{ a = "G_ServiceCorridor", b = "G_Ventilation", at = 180, width = 5, door = true },
		{ a = "G_GeneratorHall", b = "G_PipeTunnel", at = 63, width = 5, door = true },

		{
			a = "G_PipeTunnel",
			b = "H_CargoCorridor",
			at = 63,
			width = 5,
			door = true,
			requiresPower = true,
		},
		{
			a = "H_CargoCorridor",
			b = "H_FreightElevator",
			at = 54,
			width = 8,
			door = true,
			requiresPower = true,
		},
		{ a = "H_CargoCorridor", b = "H_Checkpoint", at = 32, width = 8, door = false },
		{
			a = "H_Checkpoint",
			b = "H_ObservationChamber",
			at = 130,
			width = 6,
			door = true,
			locked = true,
		},
		{ a = "H_ObservationChamber", b = "H_SignalSource", at = 130, width = 8, door = true },
	},

	-- Blockout stand-ins for landmarks and puzzle pieces. `x`/`z` is the centre, `y` the
	-- height of the bottom above the floor (default 0). All are plain coloured boxes.
	-- stylua: ignore start
	props = {
		{ name = "Placeholder_CheckpointDesk", room = "A_SecurityBooth", x = 64, z = -1, sx = 10, sy = 3.5, sz = 3, look = FURNITURE },
		{ name = "BreakerPanel_1", room = "A_SecurityBooth", x = 74.6, z = -6, y = 3, sx = 0.6, sy = 4, sz = 3, look = PUZZLE, tag = "TLS_BreakerPanel", panelId = 1 },
		{ name = "Placeholder_Lockers", room = "A_Lockers", x = 64, z = 28, sx = 16, sy = 7, sz = 2, look = FURNITURE },

		{ name = "Placeholder_MonitorWall", room = "B_MonitorRoom", x = 138, z = -14.4, y = 2, sx = 14, sy = 7, sz = 1, look = PUZZLE },
		{ name = "Placeholder_Generator", room = "B_PowerRoom", x = 86, z = 30, sx = 8, sy = 6, sz = 10, look = FURNITURE },
		{ name = "BreakerPanel_2", room = "B_PowerRoom", x = 100, z = 38.6, y = 3, sx = 3, sy = 4, sz = 0.6, look = PUZZLE, tag = "TLS_BreakerPanel", panelId = 2 },
		{ name = "Placeholder_MainLever", room = "B_PowerRoom", x = 110.6, z = 30, y = 3, sx = 0.6, sy = 4, sz = 2, look = PUZZLE },
		{ name = "BreakerPanel_3", room = "B_Maintenance", x = 126, z = 38.6, y = 3, sx = 3, sy = 4, sz = 0.6, look = PUZZLE, tag = "TLS_BreakerPanel", panelId = 3 },

		{ name = "Placeholder_LabBench_1", room = "C_MainLab", x = 236, z = -68, sx = 14, sy = 3.5, sz = 5, look = FURNITURE },
		{ name = "Placeholder_LabBench_2", room = "C_MainLab", x = 256, z = -68, sx = 14, sy = 3.5, sz = 5, look = FURNITURE },
		{ name = "Placeholder_Receiver", room = "C_SignalChamber", x = 298, z = -68, sx = 6, sy = 4, sz = 4, look = PUZZLE },
		{ name = "Placeholder_TapeShelves", room = "C_Archive", x = 246, z = -113.6, sx = 24, sy = 8, sz = 2, look = FURNITURE },

		{ name = "Placeholder_Keypad", room = "D_Antechamber", x = 214.6, z = 66, y = 4, sx = 0.6, sy = 2, sz = 1.5, look = PUZZLE },
		{ name = "Placeholder_CentralComputer", room = "D_CommCenter", x = 248, z = 48, sx = 20, sy = 6, sz = 4, look = PUZZLE },
		{ name = "Placeholder_RadioStation", room = "D_CommCenter", x = 270, z = 94, sx = 10, sy = 5, sz = 4, look = PUZZLE },
		{ name = "Placeholder_ServerRacks", room = "D_ServerRoom", x = 305, z = 66, sx = 3, sy = 9, sz = 18, look = FURNITURE },
		{ name = "Placeholder_MastBase", room = "D_RadioMast", x = 248, z = 118, sx = 8, sy = 15, sz = 8, look = WALL },
		-- ---- Expansion (layout v4) ----
		{ name = "Placeholder_AdminDesk", room = "A_AdminOffice", x = 30, z = -28, sx = 10, sy = 3.5, sz = 3, look = FURNITURE },
		{ name = "Placeholder_AccessTerminal", room = "A_AccessControl", x = 38.6, z = 35, y = 3, sx = 0.6, sy = 3, sz = 2, look = PUZZLE },

		{ name = "Placeholder_AnalysisConsole", room = "C_SignalAnalysis", x = 290, z = -33, sx = 14, sy = 4, sz = 2, look = PUZZLE },
		{ name = "Placeholder_ContainmentCell", room = "C_Containment", x = 320, z = -68, sx = 8, sy = 8, sz = 8, look = WALL },

		{ name = "Placeholder_RadioDesk", room = "D_RadioControl", x = 204, z = 100, sx = 12, sy = 4, sz = 3, look = PUZZLE },

		{ name = "Placeholder_MedDesk", room = "E_MedReception", x = 238, z = -12, sx = 10, sy = 3.5, sz = 3, look = FURNITURE },
		{ name = "Placeholder_ExamTable", room = "E_Examination", x = 268, z = -10, sx = 4, sy = 3, sz = 8, look = FURNITURE },
		{ name = "Placeholder_PatientBed", room = "E_PatientRoom", x = 306, z = -12, sx = 5, sy = 2.5, sz = 9, look = FURNITURE },
		{ name = "Placeholder_IsolationCell", room = "E_IsolationChamber", x = 342, z = 10, sx = 8, sy = 9, sz = 8, look = WALL },

		{ name = "Placeholder_Shelves_1", room = "F_DocumentArchive", x = 128, z = -56, sx = 3, sy = 8, sz = 14, look = FURNITURE },
		{ name = "Placeholder_Shelves_2", room = "F_DocumentArchive", x = 144, z = -56, sx = 3, sy = 8, sz = 14, look = FURNITURE },
		{ name = "Placeholder_TapeRacks", room = "F_TapeStorage", x = 168, z = -63.6, sx = 22, sy = 8, sz = 2, look = FURNITURE },
		{ name = "Placeholder_FileCabinets", room = "F_PersonnelRecords", x = 95, z = -40, sx = 2, sy = 6, sz = 16, look = FURNITURE },
		{ name = "Placeholder_ArchiveTerminal", room = "F_RestrictedArchive", x = 136, z = -89, sx = 8, sy = 4, sz = 3, look = PUZZLE },

		{ name = "Placeholder_MainGenerator", room = "G_GeneratorHall", x = 100, z = 72, sx = 20, sy = 10, sz = 14, look = WALL },
		{ name = "Placeholder_SwitchGear", room = "G_ElectricalControl", x = 140, z = 73.6, sx = 20, sy = 7, sz = 2, look = PUZZLE },
		{ name = "Placeholder_FanHousing", room = "G_Ventilation", x = 180, z = 70, sx = 12, sy = 8, sz = 8, look = WALL },

		{ name = "Placeholder_CargoCrates", room = "H_CargoCorridor", x = 37, z = 100, sx = 4, sy = 5, sz = 8, look = FURNITURE },
		{ name = "Placeholder_FreightPlatform", room = "H_FreightElevator", x = 13, z = 54, sx = 14, sy = 0.2, sz = 16, look = WALL },
		{ name = "Placeholder_CheckpointDesk_H", room = "H_Checkpoint", x = 24, z = 130, sx = 4, sy = 4, sz = 8, look = FURNITURE },
		{ name = "Placeholder_ObservationWindow", room = "H_ObservationChamber", x = 78.6, z = 121, y = 2, sx = 0.6, sy = 6, sz = 8, look = PUZZLE },
		{ name = "Placeholder_SignalCore", room = "H_SignalSource", x = 110, z = 130, sx = 10, sy = 16, sz = 10, look = PUZZLE },
	},
	-- stylua: ignore end

	-- Invisible points used by gameplay code (see the world contract in the GDD).
	markers = {
		{
			name = "Spawn_Start",
			room = "A_Elevator",
			x = 8,
			z = 10,
			tag = "TLS_Spawn",
			checkpoint = "Start",
		},
		{ name = "CopyVantage_Lobby", room = "A_Lobby", x = 48, z = -6, tag = "TLS_CopyVantage" },
		{
			name = "CopyVantage_MainCorridorEast",
			room = "B_MainCorridor",
			x = 192,
			z = 10,
			tag = "TLS_CopyVantage",
		},
		{
			name = "CopyVantage_Junction",
			room = "B_Junction",
			x = 220,
			z = 18,
			tag = "TLS_CopyVantage",
		},
		{
			name = "CopyVantage_NorthCorridor",
			room = "B_NorthCorridor",
			x = 210,
			z = -46,
			tag = "TLS_CopyVantage",
		},
		{
			name = "CopyVantage_SouthCorridor",
			room = "B_SouthCorridor",
			x = 210,
			z = 58,
			tag = "TLS_CopyVantage",
		},
		{
			name = "CopyVantage_MainLab",
			room = "C_MainLab",
			x = 272,
			z = -48,
			tag = "TLS_CopyVantage",
		},
		{
			name = "CopyVantage_CommCenter",
			room = "D_CommCenter",
			x = 276,
			z = 96,
			tag = "TLS_CopyVantage",
		},
		-- ---- Expansion (layout v4) ----
		{
			name = "CopyVantage_MedCorridor",
			room = "E_MedCorridor",
			x = 280,
			z = 10,
			tag = "TLS_CopyVantage",
		},
		{
			name = "CopyVantage_Quarantine",
			room = "E_QuarantineCorridor",
			x = 320,
			z = 10,
			tag = "TLS_CopyVantage",
		},
		{
			name = "CopyVantage_ArchiveCorridor",
			room = "F_ArchiveCorridor",
			x = 124,
			z = -35,
			tag = "TLS_CopyVantage",
		},
		{
			name = "CopyVantage_ServiceCorridor",
			room = "G_ServiceCorridor",
			x = 80,
			z = 45,
			tag = "TLS_CopyVantage",
		},
		{
			name = "CopyVantage_GeneratorHall",
			room = "G_GeneratorHall",
			x = 120,
			z = 82,
			tag = "TLS_CopyVantage",
		},
		{
			name = "CopyVantage_CargoCorridor",
			room = "H_CargoCorridor",
			x = 32,
			z = 116,
			tag = "TLS_CopyVantage",
		},
		{
			name = "CopyVantage_SignalSource",
			room = "H_SignalSource",
			x = 128,
			z = 152,
			tag = "TLS_CopyVantage",
		},
	},

	-- What each room is for: shown by the developer overlay and in docs/ROOM_DIRECTORY.md.
	purposes = {
		A_Elevator = "Arrival point and exit. Spawn.",
		A_Lobby = "Reception hall; first document; hub of the entrance.",
		A_SecurityBooth = "Security desk; breaker 1; start-up memo.",
		A_Checkpoint = "Bulkhead between the entrance and the facility.",
		A_Lockers = "Staff lockers; battery pack.",
		A_AdminOffice = "Administration; director's paperwork and personnel decisions.",
		A_AccessControl = "Restricted gate from the lobby to the freight wing.",
		B_MainCorridor = "The spine of the station; main landmark; first sighting.",
		B_Office101 = "Research office; Dr. Hale's note.",
		B_Storage102 = "General storage.",
		B_MonitorRoom = "Camera monitors; the radio receiver.",
		B_Records104 = "Day-to-day research records.",
		B_PowerRoom = "Emergency power: breaker 2 and the main lever.",
		B_Maintenance = "Maintenance shop; breaker 3; battery pack.",
		B_BreakRoom = "Staff break room; abandoned personal belongings.",
		B_Infirmary = "First-aid room on the main corridor.",
		B_Junction = "Crossing hall: north to the lab, south to comms, east to medical.",
		B_NorthCorridor = "Route to the laboratory and the archives.",
		B_SouthCorridor = "Route to the communication center.",
		B_ServiceTunnel = "Shortcut loop behind the north rooms, opens with power.",
		C_Airlock = "Decontamination lock into the laboratory.",
		C_MainLab = "Main laboratory.",
		C_SignalChamber = "Shielded chamber where the signal was received.",
		C_Archive = "Laboratory tape archive.",
		C_Observation = "Observation room over the laboratory.",
		C_ColdStorage = "Sample cold storage.",
		C_SignalAnalysis = "Signal analysis; frequency clues.",
		C_Containment = "Isolated containment room behind the signal chamber.",
		D_OperatorOffice = "Radio operator's office; battery pack.",
		D_Antechamber = "Security-code door into the communication center.",
		D_CommCenter = "Main communication room; central computer.",
		D_ServerRoom = "Signal recording servers.",
		D_RadioMast = "Base of the antenna mast.",
		D_RadioControl = "Radio control room; frequency calibration.",
		E_MedCorridor = "Medical wing corridor.",
		E_MedReception = "Medical reception; staff examination logs.",
		E_Examination = "Examination room for staff exposed to the signal.",
		E_QuarantineCorridor = "Sealed quarantine corridor.",
		E_PatientRoom = "Patient room under observation.",
		E_IsolationChamber = "Isolation chamber at the end of quarantine.",
		F_ArchiveCorridor = "Archive wing corridor.",
		F_DocumentArchive = "Paper archive.",
		F_TapeStorage = "Audio tape storage; recordings.",
		F_PersonnelRecords = "Personnel files.",
		F_RestrictedArchive = "Restricted archive behind a code lock.",
		G_ServiceCorridor = "Service corridor of the power wing; shortcut to the south corridor.",
		G_GeneratorHall = "Main generator hall.",
		G_ElectricalControl = "Electrical control room; subsystem switchgear.",
		G_Ventilation = "Ventilation plant.",
		G_PipeTunnel = "Pipe tunnel to the freight wing.",
		H_CargoCorridor = "Cargo corridor of the freight wing.",
		H_FreightElevator = "Freight elevator; final extraction route.",
		H_Checkpoint = "Restricted-access checkpoint before containment.",
		H_ObservationChamber = "Observation chamber facing the signal source.",
		H_SignalSource = "The signal source.",
	},
}
