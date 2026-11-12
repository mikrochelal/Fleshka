--!strict
-- Unit tests for pure-logic modules, run with the standalone Luau CLI: `luau tests/run.luau`
-- Only modules without Roblox API calls can be tested here.

local GameState = require("../src/ReplicatedStorage/Shared/GameState")
local RateLimiter = require("../src/ReplicatedStorage/Shared/RateLimiter")

local failures = 0
local total = 0

local function check(name: string, condition: boolean)
	total += 1
	if not condition then
		failures += 1
		print(`FAIL: {name}`)
	end
end

-- GameState
check("Lobby -> Loading allowed", GameState.canTransition("Lobby", "Loading"))
check("Lobby -> Playing refused", not GameState.canTransition("Lobby", "Playing"))
check("Intro -> Lobby refused", not GameState.canTransition("Intro", "Lobby"))
check("Playing -> Lobby allowed", GameState.canTransition("Playing", "Lobby"))
check("Ending -> Lobby allowed", GameState.canTransition("Ending", "Lobby"))
check("same phase refused", not GameState.canTransition("Playing", "Playing"))
check("parsePhase accepts a phase", GameState.parsePhase("Finale", "Lobby") == "Finale")
check("parsePhase falls back on junk", GameState.parsePhase("Nope", "Lobby") == "Lobby")

-- The full story order must be walkable.
local order: { GameState.Phase } =
	{ "Lobby", "Loading", "Intro", "Playing", "Finale", "Ending", "Lobby" }
for index = 1, #order - 1 do
	check(
		`story step {order[index]} -> {order[index + 1]}`,
		GameState.canTransition(order[index], order[index + 1])
	)
end

-- RateLimiter: burst of 3, refilling one token every 2 seconds.
local limiter = RateLimiter.new(3, 0.5)
check("burst call 1", limiter:allow("a", 0))
check("burst call 2", limiter:allow("a", 0))
check("burst call 3", limiter:allow("a", 0))
check("burst exhausted", not limiter:allow("a", 0))
check("other key unaffected", limiter:allow("b", 0))
check("not refilled after 1s", not limiter:allow("a", 1))
check("refilled after 2s", limiter:allow("a", 2))
check("only one token refilled", not limiter:allow("a", 2))
check("clock going backwards is safe", not limiter:allow("a", 1))

-- Refill never exceeds the burst size.
local capped = RateLimiter.new(2, 10)
check("cap call 1", capped:allow("k", 0))
check("cap call 2 after long idle", capped:allow("k", 1000))
check("cap call 3", capped:allow("k", 1000))
check("cap holds at burst", not capped:allow("k", 1000))

capped:forget("k")
check("forget resets the bucket", capped:allow("k", 1000))

print(`{total - failures}/{total} checks passed`)
if failures > 0 then
	error("unit tests failed")
end
