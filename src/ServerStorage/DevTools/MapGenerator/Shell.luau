--!strict
-- The mass the station is carved out of: solid rock filling every gap between and around
-- the rooms, and one roof slab over everything. This is what makes the station read as a
-- single underground structure instead of separate boxes. Pure math, no Roblox API.

export type Rect = { x0: number, x1: number, z0: number, z1: number }

export type Box = {
	name: string,
	x: number,
	y: number,
	z: number,
	sx: number,
	sy: number,
	sz: number,
}

export type Result = { bounds: Rect, rock: { Box }, roof: Box }

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

local function insideAnyRoom(rooms: { Rect }, x: number, z: number): boolean
	for _, room in rooms do
		if x > room.x0 and x < room.x1 and z > room.z0 and z < room.z1 then
			return true
		end
	end
	return false
end

-- rooms:     footprints to keep empty.
-- margin:    rock kept around the outermost rooms.
-- bottomY/topY: vertical extent of the rock; the roof slab sits on top of it.
function Shell.build(
	rooms: { Rect },
	margin: number,
	bottomY: number,
	topY: number,
	roofThickness: number
): Result
	assert(#rooms > 0, "Shell.build needs at least one room")

	local bounds: Rect = { x0 = math.huge, x1 = -math.huge, z0 = math.huge, z1 = -math.huge }
	local xs: { number } = {}
	local zs: { number } = {}
	for _, room in rooms do
		bounds.x0 = math.min(bounds.x0, room.x0 - margin)
		bounds.x1 = math.max(bounds.x1, room.x1 + margin)
		bounds.z0 = math.min(bounds.z0, room.z0 - margin)
		bounds.z1 = math.max(bounds.z1, room.z1 + margin)
		table.insert(xs, room.x0)
		table.insert(xs, room.x1)
		table.insert(zs, room.z0)
		table.insert(zs, room.z1)
	end
	table.insert(xs, bounds.x0)
	table.insert(xs, bounds.x1)
	table.insert(zs, bounds.z0)
	table.insert(zs, bounds.z1)
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

	local rock: { Box } = {}
	for index, rect in finished do
		table.insert(rock, {
			name = `Rock_{index}`,
			x = (rect.x0 + rect.x1) / 2,
			y = (bottomY + topY) / 2,
			z = (rect.z0 + rect.z1) / 2,
			sx = rect.x1 - rect.x0,
			sy = topY - bottomY,
			sz = rect.z1 - rect.z0,
		})
	end

	return {
		bounds = bounds,
		rock = rock,
		roof = {
			name = "Roof",
			x = (bounds.x0 + bounds.x1) / 2,
			y = topY + roofThickness / 2,
			z = (bounds.z0 + bounds.z1) / 2,
			sx = bounds.x1 - bounds.x0,
			sy = roofThickness,
			sz = bounds.z1 - bounds.z0,
		},
	}
end

return Shell
