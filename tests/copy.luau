--!strict
-- Unit tests for THE COPY's decision rules: `luau tests/copy.luau`

local Brain = require("../src/ServerScriptService/Systems/CopyAI/Brain")
local CopyConfig = require("../src/ReplicatedStorage/Config/CopyConfig")

local failures = 0
local total = 0

local function check(name: string, condition: boolean)
	total += 1
	if not condition then
		failures += 1
		print(`FAIL: {name}`)
	end
end

local STEP = 0.1

local function percept(overrides: { [string]: any }?): Brain.Percept
	local base: any = {
		playersPresent = true,
		canAppear = true,
		noise = false,
		wakeRequested = false,
		seesTarget = false,
		targetDistance = math.huge,
		nearestDistance = 100,
		arrived = false,
		pathFailed = false,
		pursuitArmed = false,
		caught = false,
	}
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

-- Feeds the same percept for `seconds` and returns the final state.
local function run(brain: Brain.Brain, seconds: number, overrides: { [string]: any }?): Brain.State
	local state = brain.state
	for _ = 1, math.floor(seconds / STEP + 0.5) do
		state = Brain.update(brain, STEP, percept(overrides))
	end
	return state
end

local function fresh(): Brain.Brain
	return Brain.new(CopyConfig)
end

local SEEN = { seesTarget = true, targetDistance = 30, nearestDistance = 30 }
local SEEN_ARMED =
	{ seesTarget = true, targetDistance = 30, nearestDistance = 30, pursuitArmed = true }

-- Waking up.
do
	local brain = fresh()
	check("starts dormant", brain.state == "Dormant")
	check("stays dormant with nothing happening", run(brain, 5) == "Dormant")
	check(
		"noise is ignored when there is no fair place to appear",
		run(brain, 1, { noise = true, canAppear = false }) == "Dormant"
	)
	check(
		"stays dormant without players",
		run(brain, 1, { noise = true, playersPresent = false }) == "Dormant"
	)
	check("noise brings it to investigate", run(brain, STEP, { noise = true }) == "Investigating")
end
do
	local brain = fresh()
	check(
		"a wake request brings it to observe",
		run(brain, STEP, { wakeRequested = true }) == "Observing"
	)
end

-- Observing.
do
	local brain = fresh()
	run(brain, STEP, { wakeRequested = true })
	check(
		"keeps observing a distant player",
		run(brain, 3, { nearestDistance = 60 }) == "Observing"
	)
	check(
		"vanishes when a player comes close",
		run(brain, STEP, { nearestDistance = CopyConfig.ObserveFleeDistance - 1 }) == "Disappearing"
	)
	check(
		"still fading before the fade time",
		run(brain, CopyConfig.FadeTime - 0.3) == "Disappearing"
	)
	check("dormant after the fade", run(brain, 0.5) == "Dormant")
	check("cooldown starts after an encounter", brain.cooldown > CopyConfig.EncounterCooldown - 1)
	check(
		"cooldown blocks waking",
		run(brain, CopyConfig.EncounterCooldown - 5, { wakeRequested = true }) == "Dormant"
	)
	check("wakes again after the cooldown", run(brain, 6, { wakeRequested = true }) == "Observing")
end
do
	local brain = fresh()
	run(brain, STEP, { wakeRequested = true })
	check(
		"observing ends by itself",
		run(brain, CopyConfig.ObserveDuration + 0.5, { nearestDistance = 60 }) == "Disappearing"
	)
end
do
	local brain = fresh()
	run(brain, STEP, { wakeRequested = true })
	check(
		"noise while observing sends it to investigate",
		run(brain, STEP, { noise = true }) == "Investigating"
	)
end

-- Investigating and searching.
do
	local brain = fresh()
	run(brain, STEP, { noise = true })
	check(
		"a glimpse is not enough to react",
		run(brain, CopyConfig.AcquireTime - 0.3, SEEN) == "Investigating"
	)
	run(brain, STEP)
	check(
		"losing sight resets the glimpse",
		run(brain, CopyConfig.AcquireTime - 0.3, SEEN) == "Investigating"
	)
	check("unarmed: sustained sight makes it stop and stare", run(brain, 0.5, SEEN) == "Observing")
end
do
	local brain = fresh()
	run(brain, STEP, { noise = true })
	check(
		"armed: sustained sight starts a pursuit",
		run(brain, CopyConfig.AcquireTime + 0.2, SEEN_ARMED) == "Pursuing"
	)
end
do
	local brain = fresh()
	run(brain, STEP, { noise = true })
	local far = {
		seesTarget = true,
		targetDistance = CopyConfig.PursueStartDistance + 5,
		nearestDistance = CopyConfig.PursueStartDistance + 5,
		pursuitArmed = true,
	}
	check(
		"armed but too far: no pursuit",
		run(brain, CopyConfig.AcquireTime + 0.2, far) == "Observing"
	)
end
do
	local brain = fresh()
	run(brain, STEP, { noise = true })
	check(
		"arriving with nothing found starts a search",
		run(brain, STEP, { arrived = true }) == "Searching"
	)
	check("keeps searching", run(brain, CopyConfig.SearchDuration - 1) == "Searching")
	check("search gives up", run(brain, 1.5) == "Disappearing")
end
do
	local brain = fresh()
	run(brain, STEP, { noise = true })
	check("a failed path starts a search", run(brain, STEP, { pathFailed = true }) == "Searching")
	check(
		"search can turn into a pursuit",
		run(brain, CopyConfig.AcquireTime + 0.2, SEEN_ARMED) == "Pursuing"
	)
end
do
	local brain = fresh()
	run(brain, STEP, { noise = true })
	check("investigation times out", run(brain, CopyConfig.InvestigateTimeout + 0.5) == "Searching")
end

-- Pursuing.
local function pursuing(): Brain.Brain
	local brain = fresh()
	run(brain, STEP, { noise = true })
	run(brain, CopyConfig.AcquireTime + 0.2, SEEN_ARMED)
	assert(brain.state == "Pursuing")
	return brain
end
do
	local brain = pursuing()
	check("a pursuit begins with a warning", Brain.isWarning(brain))
	run(brain, CopyConfig.ChaseWarningTime + 0.1, SEEN_ARMED)
	check("the warning ends", not Brain.isWarning(brain) and brain.state == "Pursuing")
	check(
		"short loss of sight keeps the pursuit",
		run(brain, CopyConfig.LoseSightTime - 1, { pursuitArmed = true }) == "Pursuing"
	)
	check("long loss of sight ends it", run(brain, 1.5, { pursuitArmed = true }) == "Searching")
end
do
	local brain = pursuing()
	check(
		"a pursuit is time limited",
		run(brain, CopyConfig.MaxPursuitDuration + 0.5, SEEN_ARMED) == "Disappearing"
	)
end
do
	local brain = pursuing()
	local caught = table.clone(SEEN_ARMED) :: any
	caught.caught = true
	check("a catch ends the pursuit", run(brain, STEP, caught) == "Disappearing")
	run(brain, CopyConfig.FadeTime + 0.2)
	check(
		"a catch gives the longer cooldown",
		brain.state == "Dormant" and brain.cooldown > CopyConfig.EncounterCooldown
	)
	run(brain, CopyConfig.CatchCooldown + 1)
	run(brain, STEP, { wakeRequested = true })
	run(brain, STEP, { nearestDistance = 1 })
	run(brain, CopyConfig.FadeTime + 0.2)
	check(
		"the next encounter uses the normal cooldown again",
		brain.cooldown <= CopyConfig.EncounterCooldown
	)
end

-- Everyone gone.
for _, setup in
	{
		{ name = "Observing", enter = { wakeRequested = true } },
		{ name = "Investigating", enter = { noise = true } },
	}
do
	local brain = fresh()
	run(brain, STEP, setup.enter)
	check(
		`{setup.name}: leaves when no players remain`,
		run(brain, STEP, { playersPresent = false }) == "Disappearing"
	)
end
do
	local brain = pursuing()
	check(
		"Pursuing: leaves when no players remain",
		run(brain, STEP, { playersPresent = false }) == "Disappearing"
	)
end

-- Scripted sighting.
do
	local brain = fresh()
	Brain.stage(brain, 4, 12)
	check("staging puts it straight into observing", brain.state == "Observing")
	check(
		"staged: uses its own flee distance",
		run(brain, 2, { nearestDistance = 15 }) == "Observing"
	)
	check(
		"staged: uses its own duration",
		run(brain, 2.5, { nearestDistance = 15 }) == "Disappearing"
	)
end
do
	local brain = fresh()
	Brain.stage(brain, 10, 12)
	check(
		"staged: vanishes when approached",
		run(brain, STEP, { nearestDistance = 10 }) == "Disappearing"
	)
end

-- Balance: sprinting must outrun it, walking must not.
local PlayerSpeeds = { walk = 12, sprint = 20 }
check("slower than a sprinting player", CopyConfig.PursueSpeed < PlayerSpeeds.sprint)
check("faster than a walking player while pursuing", CopyConfig.PursueSpeed > PlayerSpeeds.walk)
check("slower than a walking player otherwise", CopyConfig.WalkSpeed < PlayerSpeeds.walk)
check(
	"never appears inside its own flee distance",
	CopyConfig.MinAppearDistance > CopyConfig.ObserveFleeDistance
)

print(`{total - failures}/{total} checks passed`)
if failures > 0 then
	error("copy unit tests failed")
end
