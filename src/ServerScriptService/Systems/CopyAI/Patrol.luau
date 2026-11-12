--!strict
-- Patrol routes: which observation points THE COPY walks through on a visit, and where it
-- goes when it gives up. No Roblox API (points are opaque values and the caller supplies
-- the distance function), unit tested in tests/copy.luau.

local Patrol = {}

-- Points closer than this to where it stands are skipped: there is nothing to walk to.
local MIN_STEP = 8

-- A route of up to `count` points starting from `start`: always the nearest point not
-- visited yet, so it never doubles back through the same point.
function Patrol.route<T>(
	points: { T },
	start: T,
	count: number,
	distance: (a: T, b: T) -> number
): { T }
	local route: { T } = {}
	local used: { [number]: boolean } = {}
	local current = start
	while #route < count do
		local bestIndex: number? = nil
		local bestDistance = math.huge
		for index, point in points do
			if not used[index] then
				local d = distance(current, point)
				if d < MIN_STEP then
					used[index] = true
				elseif d < bestDistance then
					bestIndex = index
					bestDistance = d
				end
			end
		end
		if not bestIndex then
			break
		end
		used[bestIndex] = true
		current = points[bestIndex]
		table.insert(route, current)
	end
	return route
end

-- Where to walk away to: among points within `maxWalk` of it, the one furthest from the
-- nearest player. `threat(point)` is the distance from a point to the nearest player.
function Patrol.retreat<T>(
	points: { T },
	from: T,
	maxWalk: number,
	distance: (a: T, b: T) -> number,
	threat: (point: T) -> number
): T?
	local best: T? = nil
	local bestThreat = -math.huge
	for _, point in points do
		local walk = distance(from, point)
		if walk >= MIN_STEP and walk <= maxWalk then
			local value = threat(point)
			if value > bestThreat then
				best = point
				bestThreat = value
			end
		end
	end
	return best
end

return Patrol
