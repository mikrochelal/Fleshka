--!strict
-- Unit tests for the map generator's layout and geometry math: `luau tests/map.luau`

local Layout = require("../src/ServerStorage/DevTools/MapGenerator/Layout")
local Plan = require("../src/ServerStorage/DevTools/MapGenerator/Plan")

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

local function overlaps(a: any, b: any): boolean
	local epsilon = 1e-6
	return math.abs(a.x - b.x) < (a.sx + b.sx) / 2 - epsilon
		and math.abs(a.y - b.y) < (a.sy + b.sy) / 2 - epsilon
		and math.abs(a.z - b.z) < (a.sz + b.sz) / 2 - epsilon
end

-- The shipped layout is valid.
local problems = Plan.validate(Layout)
for _, problem in problems do
	print(`layout problem: {problem}`)
end
check("shipped layout has no problems", #problems == 0)

local plan = Plan.build(Layout)

local doorConnections = 0
for _, connection in Layout.connections do
	if connection.door then
		doorConnections += 1
	end
end
check("one room plan per room", #plan.rooms == #Layout.rooms)
check("one door per door connection", #plan.doors == doorConnections)

-- All four required areas contain rooms.
local roomsPerArea = {}
for _, room in Layout.rooms do
	roomsPerArea[room.area] = (roomsPerArea[room.area] or 0) + 1
end
for _, area in Layout.areas do
	check(`area {area.id} has rooms`, (roomsPerArea[area.id] or 0) > 0)
end

-- Geometry of every room.
local allSolid = {}
for _, roomPlan in plan.rooms do
	local room = roomPlan.room
	local name = room.name
	check(`{name}: has lights`, #roomPlan.lights >= 1)

	for _, box in roomPlan.walls do
		check(`{name}/{box.name}: positive size`, box.sx > 0 and box.sy > 0 and box.sz > 0)
		check(
			`{name}/{box.name}: inside the room footprint`,
			box.x - box.sx / 2 >= room.x0 - 1e-6
				and box.x + box.sx / 2 <= room.x1 + 1e-6
				and box.z - box.sz / 2 >= room.z0 - 1e-6
				and box.z + box.sz / 2 <= room.z1 + 1e-6
		)
		check(`{name}/{box.name}: below the ceiling`, box.y + box.sy / 2 <= room.height + 1e-6)
		table.insert(allSolid, box)
	end
	-- Walls of one room must not overlap each other (would z-fight).
	for i = 1, #roomPlan.walls do
		for j = i + 1, #roomPlan.walls do
			check(
				`{name}: {roomPlan.walls[i].name} does not overlap {roomPlan.walls[j].name}`,
				not overlaps(roomPlan.walls[i], roomPlan.walls[j])
			)
		end
	end
	for _, light in roomPlan.lights do
		check(
			`{name}/{light.name}: inside the room`,
			light.x > room.x0 and light.x < room.x1 and light.z > room.z0 and light.z < room.z1
		)
	end
end

-- Every doorway is really open: no wall of any room intersects the door panel.
for _, door in plan.doors do
	local blocked = false
	for _, wall in allSolid do
		if overlaps(wall, door.panel) then
			blocked = true
		end
	end
	check(`{door.name}: doorway is not blocked by a wall`, not blocked)
end

-- A walkable gap also exists for archways (no door): probe the middle of each connection.
local byName = {}
for _, room in Layout.rooms do
	byName[room.name] = room
end
for _, connection in Layout.connections do
	if not connection.door then
		local a, b = byName[connection.a], byName[connection.b]
		local sideBySide = a.x1 == b.x0 or a.x0 == b.x1
		local line = if sideBySide
			then (if a.x1 == b.x0 then a.x1 else a.x0)
			else (if a.z1 == b.z0 then a.z1 else a.z0)
		local probe = {
			x = if sideBySide then line else connection.at,
			y = 3,
			z = if sideBySide then connection.at else line,
			sx = if sideBySide then 2 else connection.width - 1,
			sy = 5,
			sz = if sideBySide then connection.width - 1 else 2,
		}
		local blocked = false
		for _, wall in allSolid do
			if overlaps(wall, probe) then
				blocked = true
			end
		end
		check(`archway {connection.a} <-> {connection.b} is open`, not blocked)
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

print(`{total - failures}/{total} checks passed`)
if failures > 0 then
	error("map unit tests failed")
end
