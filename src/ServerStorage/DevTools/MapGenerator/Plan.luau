--!strict
-- Turns a layout (see Layout.luau) into a list of boxes to build. Pure math, no Roblox API,
-- so the geometry rules are unit tested outside Studio.
--
-- Each room owns the walls on its own side of an edge. Two connected rooms therefore meet
-- as two wall layers back to back, each with the same opening cut out.

export type Area = { id: string, folder: string, name: string }

export type Room = {
	name: string,
	area: string,
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	height: number,
	style: string?,
	emergency: boolean?,
}

export type Connection = {
	a: string,
	b: string,
	at: number,
	width: number,
	door: boolean,
	requiresPower: boolean?,
	locked: boolean?,
}

export type Prop = {
	name: string,
	room: string,
	x: number,
	z: number,
	y: number?,
	sx: number,
	sy: number,
	sz: number,
	look: string,
	tag: string?,
	panelId: number?,
}

export type Marker = {
	name: string,
	room: string,
	x: number,
	z: number,
	tag: string,
	checkpoint: string?,
}

export type Layout = {
	version: number,
	rootName: string,
	origin: { x: number, y: number, z: number },
	wallThickness: number,
	slabThickness: number,
	doorHeight: number,
	lightSpacing: number,
	areas: { Area },
	rooms: { Room },
	connections: { Connection },
	props: { Prop },
	markers: { Marker },
}

-- Centre and size, in layout space.
export type Box = {
	name: string,
	x: number,
	y: number,
	z: number,
	sx: number,
	sy: number,
	sz: number,
}

export type RoomPlan = {
	room: Room,
	floor: Box,
	ceiling: Box,
	zone: Box,
	walls: { Box },
	lights: { Box },
}

export type DoorPlan = {
	name: string,
	panel: Box,
	a: string,
	b: string,
	requiresPower: boolean,
	locked: boolean,
}

export type Result = { rooms: { RoomPlan }, doors: { DoorPlan } }

-- An opening in one side of a room: side is "N" (z0), "S" (z1), "W" (x0) or "E" (x1).
type Opening = { lo: number, hi: number }
type Edge = { axis: string, line: number, lo: number, hi: number, sideA: string, sideB: string }

local DOOR_THICKNESS = 0.4
local LIGHT_SIZE = { x = 4, y = 0.4, z = 1.5 }
-- Clear wall kept between an opening and the end of the shared edge.
local OPENING_MARGIN = 0.5

local Plan = {}

-- The edge two rooms share, or nil when they do not touch along a line.
local function sharedEdge(a: Room, b: Room): Edge?
	if a.x1 == b.x0 or a.x0 == b.x1 then
		local lo, hi = math.max(a.z0, b.z0), math.min(a.z1, b.z1)
		if hi > lo then
			local aIsWest = a.x1 == b.x0
			return {
				axis = "x",
				line = if aIsWest then a.x1 else a.x0,
				lo = lo,
				hi = hi,
				sideA = if aIsWest then "E" else "W",
				sideB = if aIsWest then "W" else "E",
			}
		end
	end
	if a.z1 == b.z0 or a.z0 == b.z1 then
		local lo, hi = math.max(a.x0, b.x0), math.min(a.x1, b.x1)
		if hi > lo then
			local aIsNorth = a.z1 == b.z0
			return {
				axis = "z",
				line = if aIsNorth then a.z1 else a.z0,
				lo = lo,
				hi = hi,
				sideA = if aIsNorth then "S" else "N",
				sideB = if aIsNorth then "N" else "S",
			}
		end
	end
	return nil
end

local function roomsByName(layout: Layout): { [string]: Room }
	local map = {}
	for _, room in layout.rooms do
		map[room.name] = room
	end
	return map
end

local function contains(
	room: Room,
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	inset: number
): boolean
	return x0 >= room.x0 + inset
		and x1 <= room.x1 - inset
		and z0 >= room.z0 + inset
		and z1 <= room.z1 - inset
end

-- Returns every problem found in the layout; an empty list means it can be built.
function Plan.validate(layout: Layout): { string }
	local problems: { string } = {}
	local function problem(message: string)
		table.insert(problems, message)
	end

	local areaIds = {}
	for _, area in layout.areas do
		areaIds[area.id] = true
	end

	local byName: { [string]: Room } = {}
	for _, room in layout.rooms do
		if byName[room.name] then
			problem(`duplicate room name {room.name}`)
		end
		byName[room.name] = room
		if not areaIds[room.area] then
			problem(`{room.name}: unknown area {room.area}`)
		end
		if room.x1 - room.x0 < 6 or room.z1 - room.z0 < 6 then
			problem(`{room.name}: must be at least 6 studs in each direction`)
		end
		if room.height < layout.doorHeight + 1 then
			problem(`{room.name}: ceiling too low for a door`)
		end
	end

	for i = 1, #layout.rooms do
		for j = i + 1, #layout.rooms do
			local a, b = layout.rooms[i], layout.rooms[j]
			if a.x0 < b.x1 and b.x0 < a.x1 and a.z0 < b.z1 and b.z0 < a.z1 then
				problem(`{a.name} overlaps {b.name}`)
			end
		end
	end

	local neighbours: { [string]: { string } } = {}
	local openings: { [string]: { Opening } } = {}
	for _, connection in layout.connections do
		local label = `{connection.a} <-> {connection.b}`
		local a, b = byName[connection.a], byName[connection.b]
		if not a or not b then
			problem(`{label}: unknown room`)
			continue
		end
		local edge = sharedEdge(a, b)
		if not edge then
			problem(`{label}: rooms do not share an edge`)
			continue
		end

		local lo, hi = connection.at - connection.width / 2, connection.at + connection.width / 2
		local margin = layout.wallThickness + OPENING_MARGIN
		if connection.width < 3 or lo < edge.lo + margin or hi > edge.hi - margin then
			problem(`{label}: opening does not fit the shared edge`)
		end

		for _, key in { `{a.name}/{edge.sideA}`, `{b.name}/{edge.sideB}` } do
			local list: { Opening } = openings[key] or {}
			openings[key] = list
			for _, other in list do
				if lo < other.hi and other.lo < hi then
					problem(`{label}: opening overlaps another opening on {key}`)
				end
			end
			table.insert(list, { lo = lo, hi = hi })
		end

		neighbours[a.name] = neighbours[a.name] or {}
		neighbours[b.name] = neighbours[b.name] or {}
		table.insert(neighbours[a.name], b.name)
		table.insert(neighbours[b.name], a.name)
	end

	-- Every room must be reachable on foot from the first one.
	local first = layout.rooms[1]
	if first then
		local seen = { [first.name] = true }
		local queue = { first.name }
		while #queue > 0 do
			local current = table.remove(queue) :: string
			local nextNames: { string } = neighbours[current] or {}
			for _, nextName in nextNames do
				if not seen[nextName] then
					seen[nextName] = true
					table.insert(queue, nextName)
				end
			end
		end
		for _, room in layout.rooms do
			if not seen[room.name] then
				problem(`{room.name}: not reachable from {first.name}`)
			end
		end
	end

	local inset = layout.wallThickness
	for _, prop in layout.props do
		local room = byName[prop.room]
		if not room then
			problem(`{prop.name}: unknown room {prop.room}`)
		elseif
			not contains(
				room,
				prop.x - prop.sx / 2,
				prop.x + prop.sx / 2,
				prop.z - prop.sz / 2,
				prop.z + prop.sz / 2,
				inset
			)
		then
			problem(`{prop.name}: does not fit inside {prop.room}`)
		elseif (prop.y or 0) + prop.sy > room.height then
			problem(`{prop.name}: taller than {prop.room}`)
		end
	end
	for _, marker in layout.markers do
		local room = byName[marker.room]
		if not room then
			problem(`{marker.name}: unknown room {marker.room}`)
		elseif not contains(room, marker.x, marker.x, marker.z, marker.z, inset + 1) then
			problem(`{marker.name}: not inside {marker.room}`)
		end
	end

	return problems
end

-- Splits one wall into solid pieces around its openings, plus a lintel above each opening.
local function wallBoxes(layout: Layout, room: Room, side: string, openings: { Opening }): { Box }
	local t = layout.wallThickness
	local alongX = side == "N" or side == "S"
	-- North/south walls run the full width; east/west walls fit between them.
	local spanLo = if alongX then room.x0 else room.z0 + t
	local spanHi = if alongX then room.x1 else room.z1 - t
	local across: number
	if side == "N" then
		across = room.z0 + t / 2
	elseif side == "S" then
		across = room.z1 - t / 2
	elseif side == "W" then
		across = room.x0 + t / 2
	else
		across = room.x1 - t / 2
	end

	local boxes: { Box } = {}
	local function add(prefix: string, lo: number, hi: number, yLo: number, yHi: number)
		if hi - lo <= 0 or yHi - yLo <= 0 then
			return
		end
		local mid, length = (lo + hi) / 2, hi - lo
		table.insert(boxes, {
			name = `{prefix}_{side}_{#boxes + 1}`,
			x = if alongX then mid else across,
			y = (yLo + yHi) / 2,
			z = if alongX then across else mid,
			sx = if alongX then length else t,
			sy = yHi - yLo,
			sz = if alongX then t else length,
		})
	end

	local sorted = table.clone(openings)
	table.sort(sorted, function(a, b)
		return a.lo < b.lo
	end)

	local cursor = spanLo
	for _, opening in sorted do
		add("Wall", cursor, opening.lo, 0, room.height)
		add("Lintel", opening.lo, opening.hi, layout.doorHeight, room.height)
		cursor = opening.hi
	end
	add("Wall", cursor, spanHi, 0, room.height)
	return boxes
end

local function lightBoxes(layout: Layout, room: Room): { Box }
	local width, depth = room.x1 - room.x0, room.z1 - room.z0
	local countX = math.max(1, math.floor(width / layout.lightSpacing + 0.5))
	local countZ = math.max(1, math.floor(depth / layout.lightSpacing + 0.5))
	-- Run the fixture along the longer direction of the room.
	local turned = depth > width

	local boxes: { Box } = {}
	for ix = 1, countX do
		for iz = 1, countZ do
			table.insert(boxes, {
				name = `Light_{#boxes + 1}`,
				x = room.x0 + (ix - 0.5) * width / countX,
				y = room.height - LIGHT_SIZE.y / 2,
				z = room.z0 + (iz - 0.5) * depth / countZ,
				sx = if turned then LIGHT_SIZE.z else LIGHT_SIZE.x,
				sy = LIGHT_SIZE.y,
				sz = if turned then LIGHT_SIZE.x else LIGHT_SIZE.z,
			})
		end
	end
	return boxes
end

-- Builds the full plan. Errors when the layout is invalid; call Plan.validate first to
-- report problems nicely.
function Plan.build(layout: Layout): Result
	local problems = Plan.validate(layout)
	if #problems > 0 then
		error(`invalid layout: {table.concat(problems, "; ")}`)
	end

	local byName = roomsByName(layout)
	local openings: { [string]: { Opening } } = {}
	local doors: { DoorPlan } = {}

	for _, connection in layout.connections do
		local a, b = byName[connection.a], byName[connection.b]
		local edge = sharedEdge(a, b) :: Edge
		local lo, hi = connection.at - connection.width / 2, connection.at + connection.width / 2
		for _, key in { `{a.name}/{edge.sideA}`, `{b.name}/{edge.sideB}` } do
			openings[key] = openings[key] or {}
			table.insert(openings[key], { lo = lo, hi = hi })
		end

		if connection.door then
			local alongZ = edge.axis == "x"
			table.insert(doors, {
				name = `Door_{a.name}_{b.name}`,
				panel = {
					name = "Panel",
					x = if alongZ then edge.line else connection.at,
					y = layout.doorHeight / 2,
					z = if alongZ then connection.at else edge.line,
					sx = if alongZ then DOOR_THICKNESS else connection.width,
					sy = layout.doorHeight,
					sz = if alongZ then connection.width else DOOR_THICKNESS,
				},
				a = a.name,
				b = b.name,
				requiresPower = connection.requiresPower == true,
				locked = connection.locked == true,
			})
		end
	end

	local rooms: { RoomPlan } = {}
	for _, room in layout.rooms do
		local width, depth = room.x1 - room.x0, room.z1 - room.z0
		local cx, cz = (room.x0 + room.x1) / 2, (room.z0 + room.z1) / 2
		local slab = layout.slabThickness

		local walls: { Box } = {}
		for _, side in { "N", "S", "W", "E" } do
			for _, box in wallBoxes(layout, room, side, openings[`{room.name}/{side}`] or {}) do
				table.insert(walls, box)
			end
		end

		table.insert(rooms, {
			room = room,
			floor = {
				name = "Floor",
				x = cx,
				y = -slab / 2,
				z = cz,
				sx = width,
				sy = slab,
				sz = depth,
			},
			ceiling = {
				name = "Ceiling",
				x = cx,
				y = room.height + slab / 2,
				z = cz,
				sx = width,
				sy = slab,
				sz = depth,
			},
			zone = {
				name = "Zone",
				x = cx,
				y = room.height / 2,
				z = cz,
				sx = width,
				sy = room.height,
				sz = depth,
			},
			walls = walls,
			lights = lightBoxes(layout, room),
		})
	end

	return { rooms = rooms, doors = doors }
end

return Plan
