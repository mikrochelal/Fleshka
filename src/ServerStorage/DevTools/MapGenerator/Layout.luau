--!nonstrict
-- STATION-09 draft layout: pure data, no Roblox API, so it can be unit tested.
--
-- Coordinates are studs in the station's own space: X grows east, Z grows south, floors sit
-- at Y = 0. `origin` moves the whole station in the world.
--
-- Rules checked by Plan.validate (and by tests/run.luau):
--   * rooms are rectangles that never overlap;
--   * connected rooms share an edge, and the opening fits inside the shared part of it;
--   * every room can be reached from the first one.

local WALL = "wall"
local FURNITURE = "furniture"
local PUZZLE = "puzzle"

return {
	-- Bumped whenever the generated result changes; stored on the generated map.
	version = 1,

	rootName = "Station09",

	-- Below the default Baseplate, so the station is underground and shielded from sunlight.
	origin = { x = 0, y = -60, z = 0 },

	wallThickness = 1,
	slabThickness = 1,
	doorHeight = 8,
	-- Roughly one ceiling light per this many studs, in each direction.
	lightSpacing = 24,

	areas = {
		{ id = "A", folder = "A_Entrance", name = "Entrance" },
		{ id = "B", folder = "B_Corridors", name = "Corridors" },
		{ id = "C", folder = "C_Laboratory", name = "Laboratory" },
		{ id = "D", folder = "D_CommCenter", name = "CommCenter" },
	},

	-- stylua: ignore start
	rooms = {
		-- A. Entrance / Security
		{ name = "A_Elevator", area = "A", x0 = 0, x1 = 16, z0 = 0, z1 = 16, height = 12, style = "metal" },
		{ name = "A_Lobby", area = "A", x0 = 16, x1 = 56, z0 = -8, z1 = 24, height = 12 },
		{ name = "A_SecurityBooth", area = "A", x0 = 56, x1 = 80, z0 = -8, z1 = 8, height = 12 },
		{ name = "A_Checkpoint", area = "A", x0 = 56, x1 = 80, z0 = 8, z1 = 24, height = 12 },
		{ name = "A_Lockers", area = "A", x0 = 16, x1 = 40, z0 = 24, z1 = 44, height = 12 },

		-- B. Research Corridors
		{ name = "B_MainCorridor", area = "B", x0 = 80, x1 = 200, z0 = 10, z1 = 22, height = 12, style = "metal" },
		{ name = "B_Office101", area = "B", x0 = 92, x1 = 116, z0 = -10, z1 = 10, height = 12 },
		{ name = "B_Storage102", area = "B", x0 = 120, x1 = 144, z0 = -10, z1 = 10, height = 12 },
		{ name = "B_MonitorRoom", area = "B", x0 = 150, x1 = 180, z0 = -10, z1 = 10, height = 12 },
		{ name = "B_PowerRoom", area = "B", x0 = 100, x1 = 130, z0 = 22, z1 = 46, height = 12, style = "metal" },
		{ name = "B_Maintenance", area = "B", x0 = 140, x1 = 164, z0 = 22, z1 = 42, height = 12 },
		{ name = "B_EastCorridor", area = "B", x0 = 200, x1 = 212, z0 = -70, z1 = 34, height = 12, style = "metal", emergency = true },
		{ name = "B_ServiceTunnel", area = "B", x0 = 160, x1 = 200, z0 = -18, z1 = -10, height = 10, style = "metal", emergency = true },

		-- C. Experimental Laboratory
		{ name = "C_Airlock", area = "C", x0 = 212, x1 = 228, z0 = -60, z1 = -44, height = 12, style = "metal" },
		{ name = "C_MainLab", area = "C", x0 = 228, x1 = 288, z0 = -80, z1 = -30, height = 16 },
		{ name = "C_SignalChamber", area = "C", x0 = 288, x1 = 312, z0 = -70, z1 = -46, height = 14, style = "metal" },
		{ name = "C_Archive", area = "C", x0 = 240, x1 = 270, z0 = -104, z1 = -80, height = 12 },
		{ name = "C_Observation", area = "C", x0 = 228, x1 = 258, z0 = -30, z1 = -14, height = 12 },

		-- D. Communication Center
		{ name = "D_Antechamber", area = "D", x0 = 212, x1 = 232, z0 = 10, z1 = 30, height = 12 },
		{ name = "D_CommCenter", area = "D", x0 = 232, x1 = 292, z0 = -4, z1 = 44, height = 16 },
		{ name = "D_ServerRoom", area = "D", x0 = 292, x1 = 316, z0 = 4, z1 = 28, height = 12, style = "metal" },
		{ name = "D_RadioMast", area = "D", x0 = 248, x1 = 276, z0 = 44, z1 = 68, height = 16, style = "metal" },
	},
	-- stylua: ignore end

	-- `at` is the centre of the opening along the shared edge (a Z value when the rooms sit
	-- side by side in X, an X value otherwise). `door = false` leaves an open archway.
	connections = {
		{ a = "A_Elevator", b = "A_Lobby", at = 8, width = 8, door = true },
		{ a = "A_Lobby", b = "A_SecurityBooth", at = 0, width = 5, door = true },
		{ a = "A_Lobby", b = "A_Checkpoint", at = 16, width = 8, door = false },
		{ a = "A_SecurityBooth", b = "A_Checkpoint", at = 68, width = 4, door = true },
		{ a = "A_Lobby", b = "A_Lockers", at = 28, width = 5, door = true },
		{
			a = "A_Checkpoint",
			b = "B_MainCorridor",
			at = 16,
			width = 8,
			door = true,
			requiresPower = true,
		},

		{ a = "B_MainCorridor", b = "B_Office101", at = 104, width = 5, door = true },
		{ a = "B_MainCorridor", b = "B_Storage102", at = 132, width = 5, door = true },
		{ a = "B_MainCorridor", b = "B_MonitorRoom", at = 165, width = 5, door = true },
		{ a = "B_MainCorridor", b = "B_PowerRoom", at = 115, width = 6, door = true },
		{ a = "B_MainCorridor", b = "B_Maintenance", at = 152, width = 5, door = true },
		{ a = "B_MainCorridor", b = "B_EastCorridor", at = 16, width = 8, door = false },
		-- Shortcut loop that opens once power is back.
		{
			a = "B_MonitorRoom",
			b = "B_ServiceTunnel",
			at = 170,
			width = 4,
			door = true,
			requiresPower = true,
		},
		{
			a = "B_ServiceTunnel",
			b = "B_EastCorridor",
			at = -14,
			width = 5,
			door = true,
			requiresPower = true,
		},

		{
			a = "B_EastCorridor",
			b = "C_Airlock",
			at = -52,
			width = 6,
			door = true,
			requiresPower = true,
		},
		{ a = "C_Airlock", b = "C_MainLab", at = -52, width = 6, door = true },
		{ a = "C_MainLab", b = "C_SignalChamber", at = -58, width = 6, door = true },
		{ a = "C_MainLab", b = "C_Archive", at = 255, width = 5, door = true },
		{ a = "C_MainLab", b = "C_Observation", at = 243, width = 5, door = true },

		{ a = "B_EastCorridor", b = "D_Antechamber", at = 20, width = 6, door = true },
		-- The security-code door.
		{ a = "D_Antechamber", b = "D_CommCenter", at = 20, width = 6, door = true, locked = true },
		{ a = "D_CommCenter", b = "D_ServerRoom", at = 16, width = 5, door = true },
		{ a = "D_CommCenter", b = "D_RadioMast", at = 262, width = 6, door = true },
	},

	-- Blockout stand-ins for landmarks and puzzle pieces. `x`/`z` is the centre, `y` the
	-- height of the bottom above the floor (default 0). All are plain coloured boxes.
	-- stylua: ignore start
	props = {
		{ name = "Placeholder_CheckpointDesk", room = "A_SecurityBooth", x = 66, z = 3, sx = 8, sy = 3.5, sz = 3, look = FURNITURE },
		{ name = "BreakerPanel_1", room = "A_SecurityBooth", x = 78.6, z = -4, y = 3, sx = 0.6, sy = 4, sz = 3, look = PUZZLE, tag = "TLS_BreakerPanel", panelId = 1 },
		{ name = "Placeholder_Lockers", room = "A_Lockers", x = 28, z = 42, sx = 16, sy = 7, sz = 2, look = FURNITURE },

		{ name = "Placeholder_MonitorWall", room = "B_MonitorRoom", x = 165, z = -8.4, y = 2, sx = 20, sy = 7, sz = 1, look = PUZZLE },
		{ name = "Placeholder_Generator", room = "B_PowerRoom", x = 108, z = 36, sx = 8, sy = 6, sz = 10, look = FURNITURE },
		{ name = "BreakerPanel_2", room = "B_PowerRoom", x = 115, z = 44.6, y = 3, sx = 3, sy = 4, sz = 0.6, look = PUZZLE, tag = "TLS_BreakerPanel", panelId = 2 },
		{ name = "Placeholder_MainLever", room = "B_PowerRoom", x = 128.6, z = 34, y = 3, sx = 0.6, sy = 4, sz = 2, look = PUZZLE },
		{ name = "BreakerPanel_3", room = "B_Maintenance", x = 152, z = 40.6, y = 3, sx = 3, sy = 4, sz = 0.6, look = PUZZLE, tag = "TLS_BreakerPanel", panelId = 3 },

		{ name = "Placeholder_LabBench_1", room = "C_MainLab", x = 250, z = -55, sx = 14, sy = 3.5, sz = 5, look = FURNITURE },
		{ name = "Placeholder_LabBench_2", room = "C_MainLab", x = 270, z = -55, sx = 14, sy = 3.5, sz = 5, look = FURNITURE },
		{ name = "Placeholder_Receiver", room = "C_SignalChamber", x = 306, z = -58, sx = 6, sy = 4, sz = 4, look = PUZZLE },
		{ name = "Placeholder_TapeShelves", room = "C_Archive", x = 255, z = -101.6, sx = 22, sy = 8, sz = 2, look = FURNITURE },

		{ name = "Placeholder_Keypad", room = "D_Antechamber", x = 230.6, z = 15, y = 4, sx = 0.6, sy = 2, sz = 1.5, look = PUZZLE },
		{ name = "Placeholder_CentralComputer", room = "D_CommCenter", x = 262, z = 1, sx = 20, sy = 6, sz = 4, look = PUZZLE },
		{ name = "Placeholder_RadioStation", room = "D_CommCenter", x = 280, z = 38, sx = 10, sy = 5, sz = 4, look = PUZZLE },
		{ name = "Placeholder_ServerRacks", room = "D_ServerRoom", x = 311, z = 16, sx = 3, sy = 9, sz = 18, look = FURNITURE },
		{ name = "Placeholder_MastBase", room = "D_RadioMast", x = 262, z = 58, sx = 8, sy = 15, sz = 8, look = WALL },
	},
	-- stylua: ignore end

	-- Invisible points used by gameplay code (see the world contract in the GDD).
	markers = {
		{
			name = "Spawn_Start",
			room = "A_Elevator",
			x = 8,
			z = 8,
			tag = "TLS_Spawn",
			checkpoint = "Start",
		},
		{ name = "CopyVantage_Lobby", room = "A_Lobby", x = 52, z = -4, tag = "TLS_CopyVantage" },
		{
			name = "CopyVantage_MainCorridorEast",
			room = "B_MainCorridor",
			x = 196,
			z = 16,
			tag = "TLS_CopyVantage",
		},
		{
			name = "CopyVantage_EastCorridorNorth",
			room = "B_EastCorridor",
			x = 206,
			z = -66,
			tag = "TLS_CopyVantage",
		},
		{
			name = "CopyVantage_EastCorridorSouth",
			room = "B_EastCorridor",
			x = 206,
			z = 31,
			tag = "TLS_CopyVantage",
		},
		{
			name = "CopyVantage_MainLab",
			room = "C_MainLab",
			x = 284,
			z = -34,
			tag = "TLS_CopyVantage",
		},
		{
			name = "CopyVantage_CommCenter",
			room = "D_CommCenter",
			x = 288,
			z = 40,
			tag = "TLS_CopyVantage",
		},
	},
}
