--!strict
-- The mass the station is carved out of. Pure math, no Roblox API.
--
-- Everything between and around the rooms is solid rock, split into two layers:
--   * rock      - from under the floors up to `cutY` (the lowest ceiling in the station).
--                 Structural: always visible.
--   * rock caps - from `cutY` up to the top of the station. Overhead: hidden with ceilings.
-- Above each room, one roof section fills the space between that room's ceiling and the top.
-- Nothing overlaps: caps cover only rock, roof sections cover only their own room.

export type Footprint = {
	name: string,
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	height: number,
}

export type Box = {
	name: string,
	-- Unused here; kept so shell boxes share the shape of Plan.Box.
	sign: string?,
	face: string?,
	x: number,
	y: number,
	z: number,
	sx: number,
	sy: number,
	sz: number,
}

export type Bounds = { x0: number, x1: number, z0: number, z1: number }

export type Result = {
	bounds: Bounds,
	cutY: number,
	topY: number,
	rock: { Box },
	rockCaps: { Box },
	roofSections: { Box },
}

type Rect = { x0: number, x1: number, z0: number, z1: number }

local Shell = {}

local function sortedUnique(values: { number }): { number }
	table.sort(values)
	local unique: { number } = {}
	for _, value in values do
		if unique[#unique] ~= value then
			table.insert(unique, value)
		end
	end
	return unique
end

local function insideAnyRoom(rooms: { Footprint }, x: number, z: number): boolean
	for _, room in rooms do
		if x > room.x0 and x < room.x1 and z > room.z0 and z < room.z1 then
			return true
		end
	end
	return false
end

-- Rectangles covering everything inside `bounds` that is not a room.
local function rockRects(rooms: { Footprint }, bounds: Bounds): { Rect }
	local xs: { number } = { bounds.x0, bounds.x1 }
	local zs: { number } = { bounds.z0, bounds.z1 }
	for _, room in rooms do
		table.insert(xs, room.x0)
		table.insert(xs, room.x1)
		table.insert(zs, room.z0)
		table.insert(zs, room.z1)
	end
	xs = sortedUnique(xs)
	zs = sortedUnique(zs)

	-- Room edges cut the bounds into a grid in which every cell is entirely room or entirely
	-- rock. Rock cells are merged into runs along X, then equal runs are merged along Z.
	local finished: { Rect } = {}
	local open: { [string]: Rect } = {}
	for zi = 1, #zs - 1 do
		local z0, z1 = zs[zi], zs[zi + 1]
		local midZ = (z0 + z1) / 2

		local runs: { Rect } = {}
		local current: Rect? = nil
		for xi = 1, #xs - 1 do
			local x0, x1 = xs[xi], xs[xi + 1]
			if insideAnyRoom(rooms, (x0 + x1) / 2, midZ) then
				current = nil
			elseif current then
				current.x1 = x1
			else
				local run: Rect = { x0 = x0, x1 = x1, z0 = z0, z1 = z1 }
				table.insert(runs, run)
				current = run
			end
		end

		local stillOpen: { [string]: Rect } = {}
		for _, run in runs do
			local key = `{run.x0}:{run.x1}`
			local above = open[key]
			if above then
				above.z1 = z1
				stillOpen[key] = above
				open[key] = nil
			else
				stillOpen[key] = run
			end
		end
		for _, rect in open do
			table.insert(finished, rect)
		end
		open = stillOpen
	end
	for _, rect in open do
		table.insert(finished, rect)
	end

	-- Stable order so regenerating always produces the same names.
	table.sort(finished, function(a, b)
		if a.z0 ~= b.z0 then
			return a.z0 < b.z0
		end
		return a.x0 < b.x0
	end)
	return finished
end

local function slabBox(name: string, rect: Rect, yLo: number, yHi: number): Box
	return {
		name = name,
		x = (rect.x0 + rect.x1) / 2,
		y = (yLo + yHi) / 2,
		z = (rect.z0 + rect.z1) / 2,
		sx = rect.x1 - rect.x0,
		sy = yHi - yLo,
		sz = rect.z1 - rect.z0,
	}
end

-- rooms:  footprints to keep empty, with their ceiling heights.
-- margin: rock kept around the outermost rooms.
-- slab:   thickness of floors and ceilings.
function Shell.build(rooms: { Footprint }, margin: number, slab: number): Result
	assert(#rooms > 0, "Shell.build needs at least one room")

	local bounds: Bounds = { x0 = math.huge, x1 = -math.huge, z0 = math.huge, z1 = -math.huge }
	local lowest, tallest = math.huge, 0
	for _, room in rooms do
		bounds.x0 = math.min(bounds.x0, room.x0 - margin)
		bounds.x1 = math.max(bounds.x1, room.x1 + margin)
		bounds.z0 = math.min(bounds.z0, room.z0 - margin)
		bounds.z1 = math.max(bounds.z1, room.z1 + margin)
		lowest = math.min(lowest, room.height)
		tallest = math.max(tallest, room.height)
	end

	local bottomY = -slab
	local cutY = lowest
	-- One slab of cover above the tallest room's own ceiling.
	local topY = tallest + 2 * slab

	local rock: { Box } = {}
	local rockCaps: { Box } = {}
	for index, rect in rockRects(rooms, bounds) do
		table.insert(rock, slabBox(`Rock_{index}`, rect, bottomY, cutY))
		table.insert(rockCaps, slabBox(`RockCap_{index}`, rect, cutY, topY))
	end

	local roofSections: { Box } = {}
	for _, room in rooms do
		table.insert(roofSections, slabBox(`Roof_{room.name}`, room, room.height + slab, topY))
	end

	return {
		bounds = bounds,
		cutY = cutY,
		topY = topY,
		rock = rock,
		rockCaps = rockCaps,
		roofSections = roofSections,
	}
end

return Shell
