--!strict
-- Unit tests for the map generator's layout and geometry math: `luau tests/map.luau`

local Layout = require("../src/ServerStorage/DevTools/MapGenerator/Layout")
local Plan = require("../src/ServerStorage/DevTools/MapGenerator/Plan")
local Shell = require("../src/ServerStorage/DevTools/MapGenerator/Shell")

local EPSILON = 1e-6

local failures = 0
local total = 0

local function check(name: string, condition: boolean)
	total += 1
	if not condition then
		failures += 1
		print(`FAIL: {name}`)
	end
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in value do
		copy[key] = deepCopy(item)
	end
	return copy
end

local function deepEqual(a: any, b: any): boolean
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for key, item in a do
		if not deepEqual(item, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

-- True when two boxes share volume; touching faces do not count.
local function overlaps(a: any, b: any): boolean
	return math.abs(a.x - b.x) < (a.sx + b.sx) / 2 - EPSILON
		and math.abs(a.y - b.y) < (a.sy + b.sy) / 2 - EPSILON
		and math.abs(a.z - b.z) < (a.sz + b.sz) / 2 - EPSILON
end

local function buildShell(layout: any)
	return Shell.build(layout.rooms, layout.shellMargin, layout.slabThickness)
end

-- The shipped layout is valid.
local problems = Plan.validate(Layout)
for _, problem in problems do
	print(`layout problem: {problem}`)
end
check("shipped layout has no problems", #problems == 0)

local plan = Plan.build(Layout)
local shell = buildShell(Layout)

check("one room plan per room", #plan.rooms == #Layout.rooms)
check("one passage per connection", #plan.passages == #Layout.connections)

-- All four required areas contain rooms.
local roomsPerArea = {}
for _, room in Layout.rooms do
	roomsPerArea[room.area] = (roomsPerArea[room.area] or 0) + 1
end
for _, area in Layout.areas do
	check(`area {area.id} has rooms`, (roomsPerArea[area.id] or 0) > 0)
end

-- The reference floor plan must not drift: room footprints and connections are pinned.
-- The original station (layout v3) is the first 29 rooms and 30 connections.
local ORIGINAL_ROOMS, ORIGINAL_CONNECTIONS = 29, 30
local footprintSum, connectionSum = 0, 0
for index = 1, ORIGINAL_ROOMS do
	local room = Layout.rooms[index]
	footprintSum += index * (room.x0 + 2 * room.x1 + 3 * room.z0 + 5 * room.z1 + 7 * room.height)
end
for index = 1, ORIGINAL_CONNECTIONS do
	local connection = Layout.connections[index]
	connectionSum += index * (connection.at + 3 * connection.width)
end
check(
	"expanded station: 55 rooms, 59 connections",
	#Layout.rooms == 55 and #Layout.connections == 59
)
check(`reference floor plan: room footprints unchanged ({footprintSum})`, footprintSum == 361936)
check(`reference floor plan: connections unchanged ({connectionSum})`, connectionSum == 66752)

check("eight areas", #Layout.areas == 8)
local originalNames =
	{ "A_Elevator", "A_Lobby", "B_MainCorridor", "C_MainLab", "D_CommCenter", "D_RadioMast" }
for _, name in originalNames do
	local found = false
	for index = 1, ORIGINAL_ROOMS do
		found = found or Layout.rooms[index].name == name
	end
	check(`original room {name} is still among the first {ORIGINAL_ROOMS}`, found)
end
for _, room in Layout.rooms do
	local purpose = Layout.purposes[room.name]
	check(`{room.name}: has a documented purpose`, type(purpose) == "string" and #purpose > 10)
end

-- Door signs: every doorway is labelled on both sides with the room beyond it.
local signCount = 0
for _, roomPlan in plan.rooms do
	for _, box in roomPlan.walls do
		if box.sign then
			signCount += 1
			check(
				`{roomPlan.room.name}/{box.name}: sign names another room`,
				box.sign ~= roomPlan.room.name and Layout.purposes[box.sign] ~= nil
			)
			check(`{roomPlan.room.name}/{box.name}: sign has a face`, box.face ~= nil)
		end
	end
end
check(`two signs per connection ({signCount})`, signCount == 2 * #Layout.connections)

-- Geometry of every room.
local walls = {}
for _, roomPlan in plan.rooms do
	local room = roomPlan.room
	local name = room.name
	check(`{name}: has lights`, #roomPlan.lights >= 1)

	for _, box in roomPlan.walls do
		check(`{name}/{box.name}: positive size`, box.sx > 0 and box.sy > 0 and box.sz > 0)
		check(
			`{name}/{box.name}: inside the room footprint`,
			box.x - box.sx / 2 >= room.x0 - EPSILON
				and box.x + box.sx / 2 <= room.x1 + EPSILON
				and box.z - box.sz / 2 >= room.z0 - EPSILON
				and box.z + box.sz / 2 <= room.z1 + EPSILON
		)
		check(`{name}/{box.name}: below the ceiling`, box.y + box.sy / 2 <= room.height + EPSILON)
		table.insert(walls, box)
	end
	for _, light in roomPlan.lights do
		check(
			`{name}/{light.name}: inside the room`,
			light.x > room.x0 and light.x < room.x1 and light.z > room.z0 and light.z < room.z1
		)
	end
end

-- Passages: framed, and really open for a character to walk through.
local frames = {}
for _, passage in plan.passages do
	check(`{passage.name}: frame has jambs, header and threshold`, #passage.frame == 4)
	check(`{passage.name}: only doors have a panel`, (passage.panel ~= nil) == passage.isDoor)
	for _, box in passage.frame do
		check(`{passage.name}/{box.name}: positive size`, box.sx > 0 and box.sy > 0 and box.sz > 0)
		table.insert(frames, box)
	end
end

for _, passage in plan.passages do
	local header, threshold = passage.frame[3], passage.frame[4]
	local alongZ = header.sz > header.sx
	-- The volume a character needs: between the jambs, above the threshold, below the header,
	-- reaching 3 studs into both rooms.
	local probe = {
		x = header.x,
		y = (threshold.y + threshold.sy / 2 + header.y - header.sy / 2) / 2,
		z = header.z,
		sx = if alongZ then 6 else threshold.sx - 0.1,
		sy = (header.y - header.sy / 2) - (threshold.y + threshold.sy / 2) - 0.1,
		sz = if alongZ then threshold.sz - 0.1 else 6,
	}
	check(`{passage.name}: at least 7 studs of headroom`, probe.sy >= 7)

	local blocked = false
	for _, list in { walls, frames, shell.rock, shell.rockCaps } do
		for _, box in list do
			if overlaps(box, probe) then
				blocked = true
			end
		end
	end
	check(`{passage.name}: passage is clear`, not blocked)

	if passage.panel then
		for _, box in passage.frame do
			check(`{passage.name}: panel fits inside {box.name}`, not overlaps(box, passage.panel))
		end
	end
end

-- A wall without openings is one full piece; with one opening it is wall, lintel, wall.
local elevator = plan.rooms[1]
local eastPieces, westPieces = 0, 0
for _, box in elevator.walls do
	if string.find(box.name, "_E_", 1, true) then
		eastPieces += 1
	elseif string.find(box.name, "_W_", 1, true) then
		westPieces += 1
	end
end
check("elevator east wall is split around its door", eastPieces == 3)
check("elevator west wall is one piece", westPieces == 1)

-- Shell: rock fills exactly the space that is not a room.
local bounds = shell.bounds
local boundsArea = (bounds.x1 - bounds.x0) * (bounds.z1 - bounds.z0)
local roomArea, rockArea, roofArea = 0, 0, 0
local tallest, lowest = 0, math.huge
for _, room in Layout.rooms do
	roomArea += (room.x1 - room.x0) * (room.z1 - room.z0)
	tallest = math.max(tallest, room.height)
	lowest = math.min(lowest, room.height)
end
for _, rock in shell.rock do
	rockArea += rock.sx * rock.sz
	check(`{rock.name}: positive size`, rock.sx > 0 and rock.sy > 0 and rock.sz > 0)
	for _, room in Layout.rooms do
		local intrudes = rock.x - rock.sx / 2 < room.x1 - EPSILON
			and rock.x + rock.sx / 2 > room.x0 + EPSILON
			and rock.z - rock.sz / 2 < room.z1 - EPSILON
			and rock.z + rock.sz / 2 > room.z0 + EPSILON
		if intrudes then
			check(`{rock.name}: stays out of {room.name}`, false)
		end
	end
end
check(
	"rock and rooms together fill the bounds exactly",
	math.abs(roomArea + rockArea - boundsArea) < 1e-3
)
check("rock is merged into a modest number of blocks", #shell.rock > 0 and #shell.rock <= 300)

-- Ceiling system: structural rock stops at the lowest ceiling, so with the overhead parts
-- hidden nothing stands above any room's walls; the overhead parts are per-section.
check("structural rock stops at the lowest ceiling", shell.cutY == lowest)
for _, rock in shell.rock do
	if rock.y + rock.sy / 2 > lowest + EPSILON then
		check(`{rock.name}: does not rise above the lowest ceiling`, false)
	end
end
check("one rock cap per rock block", #shell.rockCaps == #shell.rock)
for index, cap in shell.rockCaps do
	local rock = shell.rock[index]
	check(
		`{cap.name}: sits exactly on its rock block`,
		cap.x == rock.x
			and cap.z == rock.z
			and cap.sx == rock.sx
			and cap.sz == rock.sz
			and math.abs((cap.y - cap.sy / 2) - (rock.y + rock.sy / 2)) < EPSILON
			and math.abs(cap.y + cap.sy / 2 - shell.topY) < EPSILON
	)
end
check("one roof section per room", #shell.roofSections == #Layout.rooms)
for index, section in shell.roofSections do
	local room = Layout.rooms[index]
	roofArea += section.sx * section.sz
	check(
		`{section.name}: covers exactly its room, from its ceiling to the top`,
		section.sx == room.x1 - room.x0
			and section.sz == room.z1 - room.z0
			and section.sy > 0
			and math.abs((section.y - section.sy / 2) - (room.height + Layout.slabThickness)) < EPSILON
			and math.abs(section.y + section.sy / 2 - shell.topY) < EPSILON
	)
	check(
		`{section.name}: is a section, not a station-wide slab`,
		section.sx * section.sz < boundsArea / 10
	)
end
check("roof sections cover exactly the rooms", math.abs(roofArea - roomArea) < 1e-3)

-- No overlapping geometry anywhere: every solid part against every other.
local solids: { { owner: string, box: any } } = {}
local function addSolid(owner: string, box: any)
	table.insert(solids, { owner = owner, box = box })
end
for _, roomPlan in plan.rooms do
	local name = roomPlan.room.name
	addSolid(name, roomPlan.floor)
	addSolid(name, roomPlan.ceiling)
	for _, box in roomPlan.walls do
		addSolid(name, box)
	end
end
for _, passage in plan.passages do
	for _, box in passage.frame do
		addSolid(passage.name, box)
	end
end
for _, list in { shell.rock, shell.rockCaps, shell.roofSections } do
	for _, box in list do
		addSolid("Shell", box)
	end
end
for _, prop in Layout.props do
	addSolid("Props", {
		name = prop.name,
		x = prop.x,
		y = (prop.y or 0) + prop.sy / 2,
		z = prop.z,
		sx = prop.sx,
		sy = prop.sy,
		sz = prop.sz,
	})
end
local overlapCount = 0
for i = 1, #solids do
	for j = i + 1, #solids do
		if overlaps(solids[i].box, solids[j].box) then
			overlapCount += 1
			print(
				`overlap: {solids[i].owner}/{solids[i].box.name} with {solids[j].owner}/{solids[j].box.name}`
			)
		end
	end
end
check(`no overlapping geometry among {#solids} solid parts`, overlapCount == 0)

-- Walkability: flood fill at character size from the spawn point over a 1-stud grid.
-- Anything between ankle and head height blocks; thresholds are low enough to step over.
local CHARACTER_RADIUS = 0.9
local STEP_HEIGHT, HEAD_HEIGHT = 0.3, 5.5
local gridW = math.floor(bounds.x1 - bounds.x0)
local gridH = math.floor(bounds.z1 - bounds.z0)
local blocked = table.create(gridW * gridH, false)
for _, solid in solids do
	local box = solid.box
	if box.y + box.sy / 2 > STEP_HEIGHT and box.y - box.sy / 2 < HEAD_HEIGHT then
		local i0 =
			math.max(0, math.floor(box.x - box.sx / 2 - CHARACTER_RADIUS - bounds.x0 - 0.5) + 1)
		local i1 = math.min(
			gridW - 1,
			math.ceil(box.x + box.sx / 2 + CHARACTER_RADIUS - bounds.x0 - 0.5) - 1
		)
		local j0 =
			math.max(0, math.floor(box.z - box.sz / 2 - CHARACTER_RADIUS - bounds.z0 - 0.5) + 1)
		local j1 = math.min(
			gridH - 1,
			math.ceil(box.z + box.sz / 2 + CHARACTER_RADIUS - bounds.z0 - 0.5) - 1
		)
		for i = i0, i1 do
			for j = j0, j1 do
				blocked[j * gridW + i + 1] = true
			end
		end
	end
end
local function cellOf(x: number, z: number): number
	return math.floor(z - bounds.z0) * gridW + math.floor(x - bounds.x0) + 1
end

local spawn = Layout.markers[1]
local reached = table.create(gridW * gridH, false)
local queue = { cellOf(spawn.x, spawn.z) }
check("spawn point is on free floor", not blocked[queue[1]])
reached[queue[1]] = true
local head = 1
while head <= #queue do
	local cell = queue[head]
	head += 1
	local i = (cell - 1) % gridW
	local j = (cell - 1) // gridW
	for _, step in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local ni, nj = i + step[1], j + step[2]
		if ni >= 0 and ni < gridW and nj >= 0 and nj < gridH then
			local nextCell = nj * gridW + ni + 1
			if not blocked[nextCell] and not reached[nextCell] then
				reached[nextCell] = true
				table.insert(queue, nextCell)
			end
		end
	end
end

local freeCells, unreachedCells = 0, 0
for _, room in Layout.rooms do
	local roomReached = 0
	for x = room.x0, room.x1 - 1 do
		for z = room.z0, room.z1 - 1 do
			local cell = cellOf(x + 0.5, z + 0.5)
			if not blocked[cell] then
				freeCells += 1
				if reached[cell] then
					roomReached += 1
				else
					unreachedCells += 1
				end
			end
		end
	end
	check(`{room.name}: can be walked into from the spawn point`, roomReached > 0)
end
check(`no walled-off floor inside rooms ({unreachedCells} cells)`, unreachedCells == 0)
for _, marker in Layout.markers do
	check(`{marker.name}: reachable on foot`, reached[cellOf(marker.x, marker.z)] == true)
end
for _, passage in plan.passages do
	local header = passage.frame[3]
	check(`{passage.name}: can be walked through`, reached[cellOf(header.x, header.z)] == true)
end

-- Regeneration is predictable: the same layout always gives the same plan.
check("plan is deterministic", deepEqual(plan, Plan.build(Layout)))
check("shell is deterministic", deepEqual(shell, buildShell(Layout)))

-- Broken layouts are reported.
local function problemsAfter(mutate: (any) -> ()): number
	local copy = deepCopy(Layout)
	mutate(copy)
	return #Plan.validate(copy)
end

check("overlapping rooms are reported", problemsAfter(function(layout)
	layout.rooms[2].x0 = 8
end) > 0)
check("connection between distant rooms is reported", problemsAfter(function(layout)
	table.insert(
		layout.connections,
		{ a = "A_Elevator", b = "D_RadioMast", at = 8, width = 5, door = true }
	)
end) > 0)
check("unreachable room is reported", problemsAfter(function(layout)
	table.insert(layout.rooms, {
		name = "X_Island",
		area = "A",
		x0 = 500,
		x1 = 520,
		z0 = 500,
		z1 = 520,
		height = 12,
	})
end) > 0)
check("opening wider than the shared edge is reported", problemsAfter(function(layout)
	layout.connections[1].width = 40
end) > 0)
check("prop outside its room is reported", problemsAfter(function(layout)
	layout.props[1].x = 0
end) > 0)
check("build refuses an invalid layout", not pcall(function()
	local copy = deepCopy(Layout)
	copy.rooms[2].x0 = 8
	Plan.build(copy)
end))

local doorCount, lightCount = 0, 0
for _, passage in plan.passages do
	if passage.isDoor then
		doorCount += 1
	end
end
for _, roomPlan in plan.rooms do
	lightCount += #roomPlan.lights
end
print(
	`layout v{Layout.version}: {#plan.rooms} rooms, {doorCount} doors, `
		.. `{#plan.passages - doorCount} archways, {lightCount} lights, {#walls} wall pieces, `
		.. `{#shell.rock} rock blocks, {#shell.rockCaps + #shell.roofSections + #plan.rooms} overhead parts, `
		.. `{freeCells} walkable cells all reached from spawn`
)
print(`{total - failures}/{total} checks passed`)
if failures > 0 then
	error("map unit tests failed")
end
