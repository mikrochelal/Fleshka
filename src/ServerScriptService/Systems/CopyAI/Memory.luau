--!strict
-- What THE COPY remembers: the last position it saw or heard someone at, and how sure it
-- still is (1 = just saw them there, 0 = no idea any more). The certainty fades while it
-- searches, the search widens as it fades, and when it reaches 0 the search is over.
-- No Roblox API (positions are opaque values; the caller supplies distances), unit tested
-- in tests/copy.luau.

export type Memory<T> = {
	position: T?,
	certainty: number,
}

export type Candidate<T> = {
	point: T,
	-- Distance from the remembered position.
	distance: number,
}

local Memory = {}

-- Candidates this close to the remembered position are the same place.
local SAME_PLACE = 6

function Memory.new<T>(): Memory<T>
	return { position = nil, certainty = 0 }
end

-- Records a position with the given certainty (1 for sight, less for a noise).
function Memory.remember<T>(memory: Memory<T>, position: T, certainty: number)
	memory.position = position
	memory.certainty = math.clamp(certainty, 0, 1)
end

function Memory.forget<T>(memory: Memory<T>)
	memory.position = nil
	memory.certainty = 0
end

-- Fades the certainty: from 1 to 0 in `memoryTime` seconds.
function Memory.decay<T>(memory: Memory<T>, dt: number, memoryTime: number)
	if memoryTime <= 0 then
		memory.certainty = 0
	else
		memory.certainty = math.max(0, memory.certainty - dt / memoryTime)
	end
end

-- True when it has nothing left to go on.
function Memory.isSpent<T>(memory: Memory<T>): boolean
	return memory.position == nil or memory.certainty <= 0
end

-- How far from the remembered position it looks: `minRadius` when certain, growing to
-- `maxRadius` as the certainty falls.
function Memory.searchRadius(certainty: number, minRadius: number, maxRadius: number): number
	return maxRadius + (minRadius - maxRadius) * math.clamp(certainty, 0, 1)
end

-- The places to check, in order: the remembered position first, then the nearest
-- candidates (hiding places) within `radius` of it, `count` places in all.
function Memory.plan<T>(origin: T, candidates: { Candidate<T> }, radius: number, count: number): { T }
	local nearby: { Candidate<T> } = {}
	for _, candidate in candidates do
		if candidate.distance > SAME_PLACE and candidate.distance <= radius then
			table.insert(nearby, candidate)
		end
	end
	table.sort(nearby, function(a, b)
		return a.distance < b.distance
	end)
	local plan = { origin }
	for _, candidate in nearby do
		if #plan >= count then
			break
		end
		table.insert(plan, candidate.point)
	end
	return plan
end

return Memory
