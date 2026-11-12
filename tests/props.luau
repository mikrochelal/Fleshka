--!strict
-- Checks the gameplay data against the map layout: `luau tests/props.luau`
-- Runtime props must sit inside their rooms, clear of doorways, of the map's own
-- placeholder props and of the spawn point; documents and the props objectives need must
-- be complete.

local Layout = require("../src/ServerStorage/DevTools/MapGenerator/Layout")
local Plan = require("../src/ServerStorage/DevTools/MapGenerator/Plan")
local PropList = require("../src/ServerScriptService/Data/PropList")
local Placement = require("../src/ServerScriptService/Systems/WorldProps/Placement")
local Documents = require("../src/ServerScriptService/Data/Documents")
local MissionConfig = require("../src/ReplicatedStorage/Config/MissionConfig")
local ObjectiveConfig = require("../src/ReplicatedStorage/Config/ObjectiveConfig")
local PowerConfig = require("../src/ReplicatedStorage/Config/PowerConfig")
local CopyConfig = require("../src/ReplicatedStorage/Config/CopyConfig")

local EPSILON = 1e-6
local WALL = Layout.wallThickness
-- How far in front of a doorway must stay empty.
local DOOR_CLEARANCE = 5
-- Furthest an interaction can be triggered from (InteractionConfig.MaxDistance).
local REACH = 10

local failures = 0
local total = 0

local function check(name: string, condition: boolean)
	total += 1
	if not condition then
		failures += 1
		print(`FAIL: {name}`)
	end
end

local function overlaps(a: any, b: any): boolean
	return math.abs(a.x - b.x) < (a.sx + b.sx) / 2 - EPSILON
		and math.abs(a.y - b.y) < (a.sy + b.sy) / 2 - EPSILON
		and math.abs(a.z - b.z) < (a.sz + b.sz) / 2 - EPSILON
end

local rooms: { [string]: any } = {}
for _, room in Layout.rooms do
	rooms[room.name] = room
end

-- Map props by room, as boxes.
local mapProps: { [string]: { any } } = {}
for _, prop in Layout.props do
	mapProps[prop.room] = mapProps[prop.room] or {}
	table.insert(mapProps[prop.room], {
		name = prop.name,
		x = prop.x,
		y = (prop.y or 0) + prop.sy / 2,
		z = prop.z,
		sx = prop.sx,
		sy = prop.sy,
		sz = prop.sz,
	})
end

-- The space in front of every doorway, on both sides of the wall.
local doorways: { any } = {}
for _, passage in Plan.build(Layout).passages do
	local header = passage.frame[3]
	local alongZ = header.sz > header.sx
	table.insert(doorways, {
		name = passage.name,
		a = passage.a,
		b = passage.b,
		x = header.x,
		y = 4,
		z = header.z,
		sx = if alongZ then 2 * DOOR_CLEARANCE else header.sx,
		sy = 8,
		sz = if alongZ then header.sz else 2 * DOOR_CLEARANCE,
	})
end

local seenIds: { [string]: boolean } = {}
local kinds: { [string]: number } = {}
for _, def in PropList :: { any } do
	local id = def.id
	check(`{id}: id is unique`, not seenIds[id])
	seenIds[id] = true
	kinds[def.kind] = (kinds[def.kind] or 0) + 1

	local room = rooms[def.room]
	check(`{id}: room {def.room} exists`, room ~= nil)
	if not room then
		continue
	end

	-- An existing map part is used instead: nothing is created, nothing to place.
	if def.reuse then
		local found = false
		for _, prop in mapProps[def.room] or {} do
			found = found or prop.name == def.reuse
		end
		check(`{id}: map part {def.reuse} exists in {def.room}`, found)
		if found then
			continue
		end
	end

	local sizeX, sizeZ = room.x1 - room.x0, room.z1 - room.z0
	local centreX, centreZ = (room.x0 + room.x1) / 2, (room.z0 + room.z1) / 2
	local placement = Placement.resolve(def, sizeX, sizeZ)

	local boxes: { any } = {}
	for _, box in { placement.stand :: any, placement.item } do
		if box then
			table.insert(boxes, {
				x = centreX + box.ox,
				y = box.oy,
				z = centreZ + box.oz,
				sx = box.sx,
				sy = box.sy,
				sz = box.sz,
			})
		end
	end

	for _, box in boxes do
		check(
			`{id}: inside {def.room}, not in a wall`,
			box.x - box.sx / 2 >= room.x0 + WALL - EPSILON
				and box.x + box.sx / 2 <= room.x1 - WALL + EPSILON
				and box.z - box.sz / 2 >= room.z0 + WALL - EPSILON
				and box.z + box.sz / 2 <= room.z1 - WALL + EPSILON
		)
		check(
			`{id}: on or above the floor, below the ceiling`,
			box.y - box.sy / 2 >= -EPSILON and box.y + box.sy / 2 <= room.height
		)
		for _, prop in mapProps[def.room] or {} do
			check(`{id}: clear of map prop {prop.name}`, not overlaps(box, prop))
		end
		for _, doorway in doorways do
			if doorway.a == def.room or doorway.b == def.room then
				check(`{id}: clear of doorway {doorway.name}`, not overlaps(box, doorway))
			end
		end
		for _, marker in Layout.markers do
			if marker.room == def.room then
				local zone = { x = marker.x, y = 3, z = marker.z, sx = 10, sy = 6, sz = 10 }
				check(`{id}: clear of marker {marker.name}`, not overlaps(box, zone))
			end
		end
	end

	local item = boxes[#boxes]
	check(`{id}: within reach of a standing player`, item.y <= 6)
	if placement.stand then
		check(
			`{id}: item rests on its stand`,
			math.abs((item.y - item.sy / 2) - placement.stand.sy) < EPSILON
				and item.sx <= placement.stand.sx
				and item.sz <= placement.stand.sz
		)
	end
	-- A player standing next to the object must be inside the prompt distance.
	check(`{id}: prompt reachable from beside it`, math.max(item.sx, item.sz) / 2 + 3 <= REACH)
end

-- Everything the mission needs is present, exactly once where it must be unique.
for _, kind in
	{
		"ElevatorPanel",
		"MainLever",
		"Radio",
		"CommConsole",
		"Switchgear",
		"AnalysisConsole",
		"GeneratorPanel",
		"FanControl",
		"ServerRack",
		"MastControl",
		"RadioDesk",
		"EvacConsole",
		"FreightPanel",
	}
do
	check(`exactly one {kind}`, kinds[kind] == 1)
end
check("two channel selectors", kinds.Tuner == 2)
check("two keypads", kinds.Keypad == 2)
check("the feeders of the load puzzle", kinds.Feeder == MissionConfig.LoadPuzzle.Feeders)
check("the fuse and the tape", kinds.Item == 2)
check("battery packs across the station", (kinds.Battery or 0) >= 5)
check("a dozen documents or more", (kinds.Document or 0) >= 12)

-- Documents: every placed document is written, and every written document is placed.
local english = require("../src/ReplicatedStorage/Shared/Locale/en")
local placed: { [string]: boolean } = {}
for _, def in PropList :: { any } do
	if def.kind == "Document" then
		placed[def.id] = true
		local document = (Documents :: { [string]: any })[def.id]
		check(`document {def.id} is written`, document ~= nil)
		if document then
			check(`document {def.id} has a title`, #(english[document.title] or "") > 0)
			check(`document {def.id} has a date`, #(english[document.date] or "") > 0)
			check(`document {def.id} has text`, #(english[document.body] or "") > 80)
		end
	end
end
for id in Documents :: { [string]: any } do
	check(`document {id} is placed in the station`, placed[id] == true)
end

-- Objectives: the props they need exist (the order itself is checked in tests/mission.luau).
for _, objective in ObjectiveConfig.List do
	for _, prop in objective.props or {} do
		check(`objective {objective.id}: prop {prop} exists`, seenIds[prop] == true)
	end
end
for id, lock in MissionConfig.Locks do
	check(`lock {id}: keypad {lock.prop} exists`, seenIds[lock.prop] == true)
end

-- Power puzzle: every panel on the map has a name, and there is more than one order.
local panelCount = 0
for _, prop in Layout.props do
	if prop.tag == "TLS_BreakerPanel" then
		panelCount += 1
		check(`breaker {prop.panelId} has a name`, PowerConfig.BreakerNames[prop.panelId] ~= nil)
		check(
			`breaker {prop.panelId} has a location`,
			PowerConfig.BreakerLocations[prop.panelId] ~= nil
		)
	end
end
check("the puzzle has at least three breakers", panelCount >= 3)
check("the memo has room for every breaker", panelCount <= PowerConfig.MemoSteps)
local circuits: { [string]: boolean } = { Emergency = true }
for _, area in Layout.areas do
	circuits[area.id] = true
end
for _, circuit in PowerConfig.UnpoweredCircuits do
	check(`circuit {circuit} exists on the map`, circuits[circuit] == true)
end
check("the entrance keeps its lights", table.find(PowerConfig.UnpoweredCircuits, "A") == nil)

-- Rooms named in configuration exist.
check(
	`CopyConfig.SightingRoom "{CopyConfig.SightingRoom}" exists`,
	rooms[CopyConfig.SightingRoom] ~= nil
)
local vantages = 0
for _, marker in Layout.markers do
	if marker.tag == "TLS_CopyVantage" then
		vantages += 1
	end
end
check("the map has observation points for THE COPY", vantages >= 4)

print(`{total - failures}/{total} checks passed`)
if failures > 0 then
	error("props unit tests failed")
end
