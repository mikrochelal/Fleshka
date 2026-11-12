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
	local tallest = 0
	for _, room in layout.rooms do
		tallest = math.max(tallest, room.height)
	end
	local slab = layout.slabThickness
	return Shell.build(layout.rooms, layout.shellMargin, -slab, tallest + slab, slab)
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

-- Passages: framed, and really open for a character to walk through.
local frames = {}
for _, passage in plan.passages do
	check(`{passage.name}: frame has jambs, header and threshold`, #passage.frame == 4)
	check(`{passage.name}: only doors have a panel`, (passage.panel ~= nil) == passage.isDoor)
	for _, box in passage.frame do
		check(`{passage.name}/{box.name}: positive size`, box.sx > 0 and box.sy > 0 and box.sz > 0)
		table.insert(frames, box)
		for _, wall in walls do
			if overlaps(wall, box) then
				check(`{passage.name}/{box.name}: does not overlap wall {wall.name}`, false)
			end
		end
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
	for _, list in { walls, frames, shell.rock } do
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

-- Shell: rock fills exactly the space that is not a room, under one roof.
local bounds = shell.bounds
local boundsArea = (bounds.x1 - bounds.x0) * (bounds.z1 - bounds.z0)
local roomArea, rockArea = 0, 0
for _, room in Layout.rooms do
	roomArea += (room.x1 - room.x0) * (room.z1 - room.z0)
end
for i, rock in shell.rock do
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
	for j = i + 1, #shell.rock do
		if overlaps(rock, shell.rock[j]) then
			check(`{rock.name}: does not overlap {shell.rock[j].name}`, false)
		end
	end
end
check(
	"rock and rooms together fill the bounds exactly",
	math.abs(roomArea + rockArea - boundsArea) < 1e-3
)
check("rock is merged into a modest number of blocks", #shell.rock > 0 and #shell.rock <= 120)
check("roof covers the whole station", math.abs(shell.roof.sx * shell.roof.sz - boundsArea) < 1e-3)

local tallest = 0
for _, room in Layout.rooms do
	tallest = math.max(tallest, room.height)
end
check(
	"roof sits above the tallest ceiling",
	shell.roof.y - shell.roof.sy / 2 >= tallest + Layout.slabThickness - EPSILON
)
for _, rock in shell.rock do
	if rock.y + rock.sy / 2 > shell.roof.y - shell.roof.sy / 2 + EPSILON then
		check(`{rock.name}: stays below the roof`, false)
	end
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

local doorCount, lightCount, wallCount = 0, 0, #walls
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
		.. `{#plan.passages - doorCount} archways, {lightCount} lights, {wallCount} wall pieces, `
		.. `{#shell.rock} rock blocks, rooms cover {math.floor(roomArea / boundsArea * 100)}% of the footprint`
)
print(`{total - failures}/{total} checks passed`)
if failures > 0 then
	error("map unit tests failed")
end
