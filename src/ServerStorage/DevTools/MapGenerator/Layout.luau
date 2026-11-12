--!nonstrict
-- STATION-09 draft layout: pure data, no Roblox API, so it can be unit tested.
--
-- Coordinates are studs in the station's own space: X grows east, Z grows south, floors sit
-- at Y = 0. `origin` moves the whole station in the world.
--
-- The plan is one building: an east-west spine corridor with rooms wall to wall on both
-- sides, ending in a junction hall from which one wing runs north to the laboratory and one
-- south to the communication center. Everything between and around the rooms is filled
-- with solid rock by the generator, under a single roof.
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
	version = 3,

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
	},
}
