--!strict
-- The relay load puzzle. Pure logic, unit tested (tests/mission.luau).
--
-- Each feeder switch carries a fixed load. The closed feeders must add up to the relay's
-- demand exactly. Closing a feeder that would exceed the demand overloads the bus: that
-- feeder trips straight back open (and is loud) - nothing already closed is lost.

export type State = {
	values: { number },
	closed: { boolean },
	target: number,
}

export type Result = "closed" | "opened" | "overload" | "solved"

local LoadBalance = {}

-- `random(min, max)` returns an integer in [min, max]. `pool` needs at least `feeders`
-- different values. The demand is the sum of two or three of the chosen feeders, so the
-- puzzle always has a solution and never needs every feeder.
function LoadBalance.generate(
	pool: { number },
	feeders: number,
	random: (min: number, max: number) -> number
): State
	assert(#pool >= feeders and feeders >= 3, "LoadBalance needs at least three feeders")
	local remaining = table.clone(pool)
	local values: { number } = {}
	local closed: { boolean } = {}
	for index = 1, feeders do
		values[index] = table.remove(remaining, random(1, #remaining)) :: number
		closed[index] = false
	end

	local picks = random(2, math.min(3, feeders - 1))
	local order: { number } = {}
	for index = 1, feeders do
		table.insert(order, random(1, #order + 1), index)
	end
	local target = 0
	for pick = 1, picks do
		target += values[order[pick]]
	end
	return { values = values, closed = closed, target = target }
end

function LoadBalance.load(state: State): number
	local total = 0
	for index, value in state.values do
		if state.closed[index] then
			total += value
		end
	end
	return total
end

function LoadBalance.isSolved(state: State): boolean
	return LoadBalance.load(state) == state.target
end

-- Operates feeder `index`. Returns nil for a feeder that does not exist.
function LoadBalance.toggle(state: State, index: number): Result?
	local value = state.values[index]
	if not value then
		return nil
	end
	if state.closed[index] then
		state.closed[index] = false
		return if LoadBalance.isSolved(state) then "solved" else "opened"
	end
	if LoadBalance.load(state) + value > state.target then
		return "overload"
	end
	state.closed[index] = true
	return if LoadBalance.isSolved(state) then "solved" else "closed"
end

return LoadBalance
