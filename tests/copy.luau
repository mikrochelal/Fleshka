--!strict
-- Unit tests for THE COPY's decision rules: `luau tests/copy.luau`

local Brain = require("../src/ServerScriptService/Systems/CopyAI/Brain")
local CopyConfig = require("../src/ReplicatedStorage/Config/CopyConfig")
local Escalation = require("../src/ServerScriptService/Systems/CopyAI/Escalation")
local Hearing = require("../src/ServerScriptService/Systems/CopyAI/Hearing")
local Memory = require("../src/ServerScriptService/Systems/CopyAI/Memory")
local Patrol = require("../src/ServerScriptService/Systems/CopyAI/Patrol")
local Targeting = require("../src/ServerScriptService/Systems/CopyAI/Targeting")
local Vision = require("../src/ServerScriptService/Systems/CopyAI/Vision")

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
		patrolArmed = false,
		stalkArmed = false,
		detectionRate = 1,
		inReach = false,
		routeDone = false,
		searchDone = false,
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
local IN_REACH = {
	seesTarget = true,
	targetDistance = 3,
	nearestDistance = 3,
	pursuitArmed = true,
	inReach = true,
}

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
	check(
		"long loss of sight sends it to the last known position",
		run(brain, 1.5, { pursuitArmed = true }) == "LostTarget"
	)
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
	check("no attack during the warning", run(brain, STEP, IN_REACH) == "Pursuing")
	run(brain, CopyConfig.ChaseWarningTime, SEEN_ARMED)
	check("a target in reach starts an attack", run(brain, STEP, IN_REACH) == "Attacking")
	check(
		"the attack has a windup",
		run(brain, CopyConfig.AttackWindup - 0.2, IN_REACH) == "Attacking" and not brain.caught
	)
	local catches = 0
	for _ = 1, 4 do
		Brain.update(brain, STEP, percept(IN_REACH))
		catches += if brain.caught then 1 else 0
	end
	check("a catch ends the pursuit", brain.state == "Disappearing")
	check("the catch is reported for one update only", catches == 1 and not brain.caught)
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

-- Escalation: forward only, one stage at a time.
do
	local escalation = Escalation.new()
	local seen: { string } = {}
	local function record(from: string, to: string)
		table.insert(seen, `{from}>{to}`)
	end
	check("starts dormant", Escalation.stage(escalation) == "Dormant")
	check("one step", Escalation.advanceTo(escalation, "Aware", record) == 1)
	check("asking again does nothing", Escalation.advanceTo(escalation, "Aware", record) == 0)
	check("cannot go back", Escalation.advanceTo(escalation, "Dormant", record) == 0)
	check("unknown stage does nothing", Escalation.advanceTo(escalation, "Furious", record) == 0)
	check(
		"a jump walks through every stage",
		Escalation.advanceTo(escalation, "FinalPursuit", record) == 3
	)
	check(
		"every step was announced in order",
		table.concat(seen, " ")
			== "Dormant>Aware Aware>Hunting Hunting>Hostile Hostile>FinalPursuit"
	)
	check("ends at the last stage", Escalation.stage(escalation) == "FinalPursuit")
end

-- Stage settings: it gets worse step by step, but never unfair.
do
	local previous: any = nil
	for _, name in Escalation.ORDER do
		local stage = CopyConfig.Stages[name]
		check(`stage {name} is configured`, stage ~= nil)
		check(`{name}: slower than a sprint`, stage.PursueSpeed < PlayerSpeeds.sprint)
		check(`{name}: faster than a walk when pursuing`, stage.PursueSpeed > PlayerSpeeds.walk)
		check(`{name}: always leaves some quiet time`, stage.Cooldown >= 5)
		check(
			`{name}: cannot see through the whole station`,
			CopyConfig.DetectionDistanceLit * stage.DetectionScale <= 90
		)
		if previous then
			check(
				`{name}: not slower than the stage before`,
				stage.PursueSpeed >= previous.PursueSpeed
			)
			check(
				`{name}: rests no longer than the stage before`,
				stage.Cooldown <= previous.Cooldown
			)
			check(
				`{name}: sees at least as far as the stage before`,
				stage.DetectionScale >= previous.DetectionScale
			)
			check(
				`{name}: hears at least as well as the stage before`,
				stage.WakeNoiseRadius <= previous.WakeNoiseRadius
			)
		end
		previous = stage
	end
	check("Dormant never visits on its own", CopyConfig.Stages.Dormant.VisitInterval == nil)
	check(
		"Dormant and Aware never chase",
		not CopyConfig.Stages.Dormant.Pursues and not CopyConfig.Stages.Aware.Pursues
	)
	check(
		"Hunting and later chase",
		CopyConfig.Stages.Hunting.Pursues and CopyConfig.Stages.FinalPursuit.Pursues
	)
	check(
		"a rejected breaker (140) wakes it even when dormant",
		CopyConfig.Stages.Dormant.WakeNoiseRadius <= 140
	)
	check(
		"sprinting (34) does not wake it before it is hostile",
		CopyConfig.Stages.Hunting.WakeNoiseRadius > 34
	)
end

-- Tuning the brain per stage.
do
	local brain = fresh()
	Brain.tune(brain, { LoseSightTime = 8, EncounterCooldown = 8 })
	check(
		"tune overrides the given values",
		brain.config.LoseSightTime == 8 and brain.config.EncounterCooldown == 8
	)
	check("tune keeps the others", brain.config.AcquireTime == CopyConfig.AcquireTime)
	Brain.tune(brain, { LoseSightTime = 6 })
	check(
		"tune starts from the original each time",
		brain.config.EncounterCooldown == CopyConfig.EncounterCooldown
	)
end

-- Attacking: telegraphed, and stepping away dodges it.
local function attacking(): Brain.Brain
	local brain = pursuing()
	run(brain, CopyConfig.ChaseWarningTime + 0.1, SEEN_ARMED)
	run(brain, STEP, IN_REACH)
	assert(brain.state == "Attacking")
	return brain
end
do
	local brain = attacking()
	run(brain, CopyConfig.AttackWindup - 0.2, IN_REACH)
	local state = run(brain, 0.4, SEEN_ARMED)
	check("stepping out of reach during the windup dodges the attack", state == "Pursuing")
	check("a miss never counts as a catch", not brain.caught)
	check("a miss resumes the chase without a new warning", not Brain.isWarning(brain))
	check(
		"it cannot attack again right after a miss",
		run(brain, CopyConfig.AttackRecovery - 0.6, IN_REACH) == "Pursuing"
	)
	check("it attacks again after recovering", run(brain, 0.5, IN_REACH) == "Attacking")
end
do
	local brain = attacking()
	check(
		"Attacking: leaves when no players remain",
		run(brain, STEP, { playersPresent = false }) == "Disappearing"
	)
end
do
	-- Dodging over and over does not make the chase endless.
	local brain = pursuing()
	local elapsed = 0
	local dodge = false
	while Brain.isChasing(brain) and elapsed < 200 do
		if brain.state == "Attacking" and brain.stateTime > CopyConfig.AttackWindup - 0.25 then
			dodge = true
		elseif brain.state == "Pursuing" then
			dodge = false
		end
		Brain.update(brain, STEP, percept(if dodge then SEEN_ARMED else IN_REACH))
		elapsed += STEP
	end
	check("a chase with attacks is still time limited", brain.state == "Disappearing")
	check("dodging every attack means never being caught", not brain.caught)
	check(
		"the time limit covers the attacks",
		elapsed <= CopyConfig.MaxPursuitDuration + CopyConfig.AcquireTime + 1
	)
end

-- Patrolling.
local ARMED_STAGE = { pursuitArmed = true, patrolArmed = true }
local function patrolling(): Brain.Brain
	local brain = fresh()
	run(brain, STEP, { wakeRequested = true, patrolArmed = true })
	assert(brain.state == "Patrolling")
	return brain
end
do
	local brain = patrolling()
	check("a wake request starts a patrol once patrols are armed", brain.state == "Patrolling")
	check("keeps patrolling", run(brain, 5, ARMED_STAGE) == "Patrolling")
	check(
		"a finished route sends it away",
		run(brain, STEP, { patrolArmed = true, routeDone = true }) == "Returning"
	)
end
do
	local brain = patrolling()
	check(
		"a patrol is time limited",
		run(brain, CopyConfig.PatrolDuration + 0.5, ARMED_STAGE) == "Returning"
	)
end
do
	local brain = patrolling()
	check(
		"noise on patrol sends it to investigate",
		run(brain, STEP, { noise = true }) == "Investigating"
	)
end
do
	local brain = patrolling()
	check(
		"patrol, armed: sustained sight starts a pursuit",
		run(brain, CopyConfig.AcquireTime + 0.2, SEEN_ARMED) == "Pursuing"
			and Brain.isWarning(brain)
	)
end
do
	local brain = patrolling()
	check(
		"patrol, unarmed: sustained sight makes it stop and stare",
		run(brain, CopyConfig.AcquireTime + 0.2, SEEN) == "Observing"
	)
end
do
	local brain = patrolling()
	run(brain, (CopyConfig.MaxPathFailures - 1) * STEP, { pathFailed = true })
	check("a few failed walks do not end a patrol", brain.state == "Patrolling")
	run(brain, STEP, { arrived = true })
	run(brain, (CopyConfig.MaxPathFailures - 1) * STEP, { pathFailed = true })
	check("a walk that worked resets the failure count", brain.state == "Patrolling")
	check(
		"too many failed walks in a row end the patrol",
		run(brain, STEP, { pathFailed = true }) == "Returning"
	)
end

-- Stalking.
local FAR_SEEN = {
	seesTarget = true,
	targetDistance = CopyConfig.PursueStartDistance + 10,
	nearestDistance = CopyConfig.PursueStartDistance + 10,
	pursuitArmed = true,
	stalkArmed = true,
}
local function stalking(): Brain.Brain
	local brain = fresh()
	run(brain, STEP, { noise = true })
	run(brain, CopyConfig.AcquireTime + 0.2, FAR_SEEN)
	assert(brain.state == "Stalking")
	return brain
end
do
	check("armed, too far, stalking allowed: it stalks", stalking().state == "Stalking")
	local searching = fresh()
	run(searching, STEP, { noise = true })
	run(searching, STEP, { arrived = true })
	check(
		"a search can turn into stalking",
		run(searching, CopyConfig.AcquireTime + 0.2, FAR_SEEN) == "Stalking"
	)
	local patrol = patrolling()
	check(
		"a patrol can turn into stalking",
		run(patrol, CopyConfig.AcquireTime + 0.2, FAR_SEEN) == "Stalking"
	)
	local unarmed = fresh()
	run(unarmed, STEP, { noise = true })
	local far = table.clone(FAR_SEEN) :: any
	far.pursuitArmed = false
	check(
		"it never stalks before pursuits are armed",
		run(unarmed, CopyConfig.AcquireTime + 0.2, far) == "Observing"
	)
end
do
	local brain = stalking()
	check("keeps stalking a distant target", run(brain, 5, FAR_SEEN) == "Stalking")
	local close = table.clone(FAR_SEEN) :: any
	close.targetDistance = CopyConfig.PursueStartDistance - 5
	check(
		"stalking turns into a pursuit when close enough",
		run(brain, STEP, close) == "Pursuing" and Brain.isWarning(brain)
	)
end
do
	local brain = stalking()
	local hidden = { pursuitArmed = true, stalkArmed = true }
	check(
		"stalking survives a short loss of sight",
		run(brain, CopyConfig.LoseSightTime - 1, hidden) == "Stalking"
	)
	check("stalking: a long loss of sight", run(brain, 1.5, hidden) == "LostTarget")
end
do
	local brain = stalking()
	check(
		"stalking is time limited",
		run(brain, CopyConfig.StalkDuration + 0.5, FAR_SEEN) == "Returning"
	)
end

-- LostTarget.
local function lostTarget(): Brain.Brain
	local brain = pursuing()
	run(brain, CopyConfig.ChaseWarningTime + 0.1, SEEN_ARMED)
	run(brain, CopyConfig.LoseSightTime + 0.2, { pursuitArmed = true })
	assert(brain.state == "LostTarget")
	return brain
end
do
	local brain = lostTarget()
	check("LostTarget: keeps walking to the last known position", run(brain, 2) == "LostTarget")
	check(
		"LostTarget: arriving starts a search",
		run(brain, STEP, { arrived = true }) == "Searching"
	)
end
do
	local brain = lostTarget()
	check(
		"LostTarget: a failed path starts a search",
		run(brain, STEP, { pathFailed = true }) == "Searching"
	)
end
do
	local brain = lostTarget()
	check(
		"LostTarget: gives up walking after a while",
		run(brain, CopyConfig.LostTargetTimeout + 0.5) == "Searching"
	)
end
do
	local brain = lostTarget()
	check(
		"LostTarget: noise sends it to investigate",
		run(brain, STEP, { noise = true }) == "Investigating"
	)
end
do
	local brain = lostTarget()
	local state = run(brain, CopyConfig.AcquireTime + 0.1, SEEN_ARMED)
	check(
		"sight regained at once resumes the chase without a warning",
		state == "Pursuing" and not Brain.isWarning(brain)
	)
end
do
	local brain = lostTarget()
	run(brain, CopyConfig.ReacquireGrace + 0.5)
	local state = run(brain, CopyConfig.AcquireTime + 0.1, SEEN_ARMED)
	check(
		"sight regained later gives a new warning",
		state == "Pursuing" and Brain.isWarning(brain)
	)
	check(
		"the new warning is the short one",
		brain.warningTime == CopyConfig.ReacquireWarningTime
			and CopyConfig.ReacquireWarningTime < CopyConfig.ChaseWarningTime
	)
end

-- Returning, and how a search ends.
do
	local brain = patrolling()
	run(brain, STEP, { patrolArmed = true, routeDone = true })
	check("keeps walking away", run(brain, 3, ARMED_STAGE) == "Returning")
	check("Returning: vanishes on arrival", run(brain, STEP, { arrived = true }) == "Disappearing")
end
do
	local brain = patrolling()
	run(brain, STEP, { patrolArmed = true, routeDone = true })
	check(
		"Returning: vanishes when the way is blocked",
		run(brain, STEP, { pathFailed = true }) == "Disappearing"
	)
end
do
	local brain = patrolling()
	run(brain, STEP, { patrolArmed = true, routeDone = true })
	check(
		"Returning: is time limited",
		run(brain, CopyConfig.ReturnTimeout + 0.5, ARMED_STAGE) == "Disappearing"
	)
end
do
	local brain = patrolling()
	run(brain, STEP, { patrolArmed = true, routeDone = true })
	check("Returning: noise turns it around", run(brain, STEP, { noise = true }) == "Investigating")
end
do
	local brain = patrolling()
	run(brain, STEP, { patrolArmed = true, routeDone = true })
	check(
		"Returning: a player in plain sight is still chased",
		run(brain, CopyConfig.AcquireTime + 0.2, SEEN_ARMED) == "Pursuing"
	)
	check(
		"Returning: leaves when no players remain",
		run(patrolling(), STEP, { playersPresent = false }) == "Disappearing"
	)
end
do
	local brain = fresh()
	run(brain, STEP, { noise = true })
	run(brain, STEP, { arrived = true })
	check(
		"a search that runs out walks away once patrols are armed",
		run(brain, CopyConfig.SearchDuration + 0.5, { patrolArmed = true }) == "Returning"
	)
end
do
	local brain = fresh()
	run(brain, STEP, { noise = true })
	run(brain, STEP, { arrived = true })
	check("a finished search ends early", run(brain, STEP, { searchDone = true }) == "Disappearing")
end
do
	local brain = fresh()
	run(brain, STEP, { noise = true })
	run(brain, STEP, { arrived = true })
	check(
		"noise during a search is investigated",
		run(brain, STEP, { noise = true }) == "Investigating"
	)
end

-- Detection rate: sight builds faster or slower, but a glimpse is never enough.
do
	local slow = fresh()
	run(slow, STEP, { noise = true })
	local seenSlowly = table.clone(SEEN) :: any
	seenSlowly.detectionRate = 0.5
	check(
		"a slow detection rate needs longer sight",
		run(slow, CopyConfig.AcquireTime + 0.3, seenSlowly) == "Investigating"
	)
	check(
		"...but it still gets there",
		run(slow, CopyConfig.AcquireTime, seenSlowly) == "Observing"
	)
	local quick = fresh()
	run(quick, STEP, { noise = true })
	local seenQuickly = table.clone(SEEN) :: any
	seenQuickly.detectionRate = 2
	check(
		"a fast detection rate reacts sooner",
		run(quick, CopyConfig.AcquireTime / 2 + 0.1, seenQuickly) == "Observing"
	)
end

-- New percept fields are optional.
do
	local brain = fresh()
	local bare: any = {
		playersPresent = true,
		canAppear = true,
		noise = false,
		wakeRequested = true,
		seesTarget = false,
		targetDistance = math.huge,
		nearestDistance = 100,
		arrived = false,
		pathFailed = false,
		pursuitArmed = true,
	}
	check(
		"absent stage flags mean an ordinary visit",
		Brain.update(brain, STEP, bare) == "Observing"
	)
	bare.seesTarget = true
	bare.targetDistance = 3
	bare.nearestDistance = 30
	for _ = 1, 40 do
		Brain.update(brain, STEP, bare)
	end
	check("absent inReach never attacks", brain.state == "Pursuing")
end

-- Vision: range by light, field of view, detection rate.
do
	local lit = Vision.range(CopyConfig, false, true, 1)
	local torch = Vision.range(CopyConfig, true, false, 1)
	local dark = Vision.range(CopyConfig, false, false, 1)
	check("a dark room hides a player best", dark < lit and lit < torch)
	check(
		"a flashlight gives a player away even in a lit room",
		Vision.range(CopyConfig, true, true, 1) == torch
	)
	check(
		"the stage scale stretches the range",
		Vision.range(CopyConfig, false, true, 1.25) == lit * 1.25
	)
	check("sees straight ahead", Vision.inView(CopyConfig, 0, -1, 0, -30, 30))
	check("does not see behind it", not Vision.inView(CopyConfig, 0, -1, 0, 30, 30))
	check("does not see far to the side", not Vision.inView(CopyConfig, 0, -1, 30, 2, 30))
	check("sees inside the cone", Vision.inView(CopyConfig, 0, -1, 20, -20, 28.3))
	check(
		"notices a very close player behind it",
		Vision.inView(
			CopyConfig,
			0,
			-1,
			0,
			CopyConfig.CloseAwareness - 1,
			CopyConfig.CloseAwareness - 1
		)
	)
	check("the field of view is narrower than a full circle", CopyConfig.VisionAngle < 360)
	local near = Vision.rate(CopyConfig, 5, lit, false, true, false)
	local far = Vision.rate(CopyConfig, lit, lit, false, true, false)
	check("close players are noticed faster", near > far)
	check(
		"sprinting is noticed faster",
		Vision.rate(CopyConfig, 20, lit, false, true, true)
			> Vision.rate(CopyConfig, 20, lit, false, true, false)
	)
	check(
		"darkness slows detection",
		Vision.rate(CopyConfig, 20, dark, false, false, false)
			< Vision.rate(CopyConfig, 20, lit, false, true, false)
	)
	local slowest = Vision.rate(CopyConfig, dark, dark, false, false, false)
	local fastest = Vision.rate(CopyConfig, 0, torch, true, true, true)
	check(
		"the rate stays inside its limits",
		slowest >= CopyConfig.DetectionRateMin and fastest <= CopyConfig.DetectionRateMax
	)
	check("the slowest detection still takes under 3 seconds", CopyConfig.AcquireTime / slowest < 3)
	check("the fastest detection is not instant", CopyConfig.AcquireTime / fastest >= 0.3)
end

-- Hearing.
local function hearingContext(overrides: { [string]: any }?): Hearing.Context
	local base: any = {
		out = true,
		busy = false,
		distance = 40,
		wakeRadius = 80,
		scale = 1,
		errorFactor = 0.3,
		minError = CopyConfig.HearingMinError,
		maxError = CopyConfig.HearingMaxError,
		focusTime = CopyConfig.HearingFocusTime,
	}
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end
local function fixed(value: number): () -> number
	return function()
		return value
	end
end
do
	check("out: hears a noise that reaches it", Hearing.audible(hearingContext(), 50))
	check("out: does not hear one that does not", not Hearing.audible(hearingContext(), 30))
	check(
		"out: better hearing reaches further",
		Hearing.audible(hearingContext({ scale = 1.4 }), 30)
	)
	check(
		"away: quiet noises are ignored",
		not Hearing.audible(hearingContext({ out = false }), 50)
	)
	check("away: loud noises bring it", Hearing.audible(hearingContext({ out = false }), 140))
	check(
		"a chase is never interrupted by noise",
		not Hearing.audible(hearingContext({ busy = true }), 400)
	)

	local poor = hearingContext({ errorFactor = 0.5 })
	local sharp = hearingContext({ errorFactor = 0.08 })
	check("the guess is never exact", Hearing.errorFor(sharp, 0) > 0)
	check("poor hearing guesses worse", Hearing.errorFor(poor, 0.5) > Hearing.errorFor(sharp, 0.5))
	check(
		"a distant noise is placed worse than a close one",
		Hearing.errorFor(hearingContext({ distance = 80 }), 0.5)
			> Hearing.errorFor(hearingContext({ distance = 20 }), 0.5)
	)
	check(
		"the error never exceeds the maximum",
		Hearing.errorFor(hearingContext({ distance = 1000, errorFactor = 1 }), 1)
			<= CopyConfig.HearingMaxError
	)
	check(
		"the error has a floor",
		Hearing.errorFor(hearingContext({ distance = 1 }), 1) >= CopyConfig.HearingMinError / 2
	)
end
do
	local ear: Hearing.Ear<string> = Hearing.new()
	check("nothing heard yet", Hearing.take(ear, 0) == nil)
	check(
		"an inaudible noise is not kept",
		Hearing.offer(ear, 0, "far", 30, "Sprint", hearingContext(), fixed(0.5)) == nil
	)
	local door = Hearing.offer(ear, 0, "door", 60, "DoorPass", hearingContext(), fixed(0.5))
	check("an audible noise is kept", door ~= nil and door.source == "door")
	check(
		"the estimate is off by the reported error",
		door ~= nil
			and math.abs(math.sqrt(door.offsetX ^ 2 + door.offsetZ ^ 2) - door.error) < 1e-6
			and door.error > 0
	)
	check(
		"a weaker noise does not replace a waiting one",
		Hearing.offer(ear, 0, "weak", 50, "Terminal", hearingContext(), fixed(0.5)) == nil
	)
	check(
		"a louder noise replaces a waiting one",
		Hearing.offer(ear, 0, "loud", 140, "BreakerTrip", hearingContext(), fixed(0.5)) ~= nil
	)
	local taken = Hearing.take(ear, 0)
	check("the loudest noise is the one it reacts to", taken ~= nil and taken.source == "loud")
	check("a noise is reacted to once", Hearing.take(ear, 0) == nil)
	check(
		"a weaker noise soon after is shut out",
		Hearing.offer(ear, 1, "door", 60, "DoorPass", hearingContext(), fixed(0.5)) == nil
	)
	check(
		"...but is heard once its attention is free again",
		Hearing.offer(
			ear,
			CopyConfig.HearingFocusTime + 1,
			"door",
			60,
			"DoorPass",
			hearingContext(),
			fixed(0.5)
		) ~= nil
	)
	Hearing.reset(ear)
	check("reset forgets everything", Hearing.take(ear, 0) == nil and ear.focus == 0)
end

-- Memory.
do
	local memory: Memory.Memory<string> = Memory.new()
	check("starts with nothing", Memory.isSpent(memory))
	Memory.remember(memory, "lab", 1)
	check("remembers a position", memory.position == "lab" and not Memory.isSpent(memory))
	Memory.decay(memory, 5, 20)
	check("certainty fades with time", math.abs(memory.certainty - 0.75) < 1e-6)
	Memory.decay(memory, 20, 20)
	check(
		"certainty reaches zero and stays there",
		memory.certainty == 0 and Memory.isSpent(memory)
	)
	Memory.remember(memory, "hall", 0.6)
	check("a noise is remembered with less certainty", memory.certainty == 0.6)
	Memory.forget(memory)
	check("forgetting clears the position", memory.position == nil)

	local sure = Memory.searchRadius(1, CopyConfig.SearchRadiusMin, CopyConfig.SearchRadiusMax)
	local unsure = Memory.searchRadius(0.2, CopyConfig.SearchRadiusMin, CopyConfig.SearchRadiusMax)
	check("the search widens as certainty falls", unsure > sure)
	check(
		"the search radius stays inside its limits",
		sure == CopyConfig.SearchRadiusMin
			and Memory.searchRadius(0, CopyConfig.SearchRadiusMin, CopyConfig.SearchRadiusMax)
				== CopyConfig.SearchRadiusMax
	)

	local candidates: { Memory.Candidate<string> } = {
		{ point = "far", distance = 90 },
		{ point = "closet", distance = 20 },
		{ point = "same", distance = 2 },
		{ point = "office", distance = 34 },
		{ point = "store", distance = 50 },
	}
	local plan = Memory.plan("origin", candidates, 60, 3)
	check(
		"the plan starts at the last known position, then the nearest hiding places",
		table.concat(plan, ",") == "origin,closet,office"
	)
	check(
		"a wider search with more points reaches further",
		table.concat(Memory.plan("origin", candidates, 60, 6), ",") == "origin,closet,office,store"
	)
	check(
		"places outside the radius are never checked",
		table.concat(Memory.plan("origin", candidates, 25, 6), ",") == "origin,closet"
	)
end

-- Targeting.
do
	local function candidate(id: string, visible: boolean, distance: number, noiseAge: number?)
		return { id = id, visible = visible, distance = distance, noiseAge = noiseAge }
	end
	local state: Targeting.Targeting<string> = Targeting.new()
	check("no candidates, no target", Targeting.choose(state, {}, CopyConfig) == nil)
	local first, why = Targeting.choose(state, { candidate("A", true, 30) }, CopyConfig)
	check("the only player becomes the target", first == "A" and why ~= nil)
	local both = { candidate("A", true, 30), candidate("B", true, 10) }
	local kept, keptWhy = Targeting.choose(state, both, CopyConfig)
	check("no switch before the commit time", kept == "A" and keptWhy == nil)
	Targeting.tick(state, CopyConfig.TargetCommitTime + 0.1)
	local slightly = { candidate("A", true, 30), candidate("B", true, 25) }
	check(
		"no switch for a slightly better candidate",
		Targeting.choose(state, slightly, CopyConfig) == "A"
	)
	local switched, switchWhy = Targeting.choose(state, both, CopyConfig)
	check("switches to a clearly better candidate", switched == "B" and switchWhy ~= nil)
	check(
		"no switching straight back",
		Targeting.choose(state, { candidate("A", true, 5), candidate("B", true, 30) }, CopyConfig)
			== "B"
	)

	local hidden = { candidate("B", false, 20), candidate("A", true, 30) }
	local turned = Targeting.choose(state, hidden, CopyConfig)
	check("turns at once on a visible player when its target is out of sight", turned == "A")

	check(
		"a recent noise raises the score",
		Targeting.score(candidate("A", true, 30, 1), 0, CopyConfig)
			> Targeting.score(candidate("A", true, 30), 0, CopyConfig)
	)
	check(
		"an old noise does not",
		Targeting.score(candidate("A", true, 30, CopyConfig.TargetNoiseMemory + 1), 0, CopyConfig)
			== Targeting.score(candidate("A", true, 30), 0, CopyConfig)
	)
	check(
		"long attention lowers the score",
		Targeting.score(candidate("A", true, 30), CopyConfig.TargetAttentionTime, CopyConfig)
			< Targeting.score(candidate("A", true, 30), 0, CopyConfig)
	)
end
do
	-- Two players at the same distance: it does not stay on one of them forever.
	local state: Targeting.Targeting<string> = Targeting.new()
	local pair = {
		{ id = "A", visible = true, distance = 30 },
		{ id = "B", visible = true, distance = 30 },
	}
	local firstTarget = Targeting.choose(state, pair, CopyConfig)
	local switches = 0
	local current = firstTarget
	for _ = 1, 1200 do
		Targeting.tick(state, STEP)
		local chosen = Targeting.choose(state, pair, CopyConfig)
		if chosen ~= current then
			switches += 1
			current = chosen
		end
	end
	check("attention eventually moves to the other player", switches >= 1)
	check("...without rapid switching", switches <= 120 / CopyConfig.TargetCommitTime)
end
do
	local state: Targeting.Targeting<string> = Targeting.new()
	local both = {
		{ id = "A", visible = true, distance = 10 },
		{ id = "B", visible = true, distance = 40 },
	}
	check(
		"the closest visible player is chosen first",
		Targeting.choose(state, both, CopyConfig) == "A"
	)
	Targeting.markCaught(state, "A", CopyConfig)
	check("a caught player is dropped", state.current == nil and Targeting.isIgnored(state, "A"))
	check("a caught player is ignored", Targeting.choose(state, both, CopyConfig) == "B")
	local alone = { { id = "A", visible = true, distance = 5 } }
	Targeting.release(state)
	check(
		"...even when they are the only one in view",
		Targeting.choose(state, alone, CopyConfig) == nil
	)
	Targeting.tick(state, CopyConfig.CaughtGraceTime + 0.1)
	check(
		"the grace period ends",
		not Targeting.isIgnored(state, "A") and Targeting.choose(state, alone, CopyConfig) == "A"
	)
	Targeting.forget(state, "A")
	check("a player who left is forgotten", state.current == nil and state.attention["A"] == nil)
end

-- Patrol routes.
do
	local points = { 0, 100, 30, 12, 60, 3 }
	local function distance(a: number, b: number): number
		return math.abs(a - b)
	end
	local route = Patrol.route(points, 0, 3, distance)
	check("a route visits the nearest points first", table.concat(route, ",") == "12,30,60")
	check("a route skips the point it is standing on", table.find(route, 0) == nil)
	local all = Patrol.route(points, 0, 10, distance)
	local unique: { [number]: boolean } = {}
	local repeated = false
	for _, point in all do
		repeated = repeated or unique[point] == true
		unique[point] = true
	end
	check("a route never repeats a point", not repeated)
	check("a route is no longer than the points there are", #all == 4)
	check("no points, no route", #Patrol.route({}, 0, 3, distance) == 0)
	check("a zero-length route is empty", #Patrol.route(points, 0, 0, distance) == 0)

	local players = { 20 }
	local function threat(point: number): number
		return math.abs(point - players[1])
	end
	check(
		"it leaves toward the point furthest from players",
		Patrol.retreat(points, 30, 80, distance, threat) == 100
	)
	check(
		"...but not further than it is willing to walk",
		Patrol.retreat(points, 30, 40, distance, threat) == 60
	)
	check("nowhere to go", Patrol.retreat({}, 30, 40, distance, threat) == nil)
end

-- New stage settings: smarter step by step, never unfair.
do
	local previous: any = nil
	for _, name in Escalation.ORDER do
		local stage = CopyConfig.Stages[name]
		check(`{name}: hearing never reaches the whole station`, stage.HearingScale <= 1.5)
		check(`{name}: its guess is never exact`, stage.HearingError > 0)
		check(`{name}: searches at least the last known position`, stage.SearchPoints >= 1)
		check(`{name}: gives up a search eventually`, stage.MemoryTime <= 40)
		check(`{name}: only stalks once it may chase`, stage.Pursues or not stage.Stalks)
		check(`{name}: a patrol has a route`, not stage.Patrols or stage.PatrolPoints >= 2)
		if previous then
			check(
				`{name}: places noises no worse than the stage before`,
				stage.HearingError <= previous.HearingError
			)
			check(
				`{name}: hears no worse than the stage before`,
				stage.HearingScale >= previous.HearingScale
			)
			check(
				`{name}: searches no fewer places than the stage before`,
				stage.SearchPoints >= previous.SearchPoints
			)
			check(
				`{name}: remembers no shorter than the stage before`,
				stage.MemoryTime >= previous.MemoryTime
			)
			check(
				`{name}: patrols no shorter than the stage before`,
				stage.PatrolPoints >= previous.PatrolPoints
			)
			check(
				`{name}: keeps patrolling once it has started`,
				stage.Patrols or not previous.Patrols
			)
			check(`{name}: keeps stalking once it has started`, stage.Stalks or not previous.Stalks)
		end
		previous = stage
	end
	check(
		"Dormant and Aware only come to look",
		not CopyConfig.Stages.Dormant.Patrols and not CopyConfig.Stages.Aware.Patrols
	)
	check("Hunting patrols", CopyConfig.Stages.Hunting.Patrols)
	check(
		"only Hostile and later stalk",
		not CopyConfig.Stages.Hunting.Stalks
			and CopyConfig.Stages.Hostile.Stalks
			and CopyConfig.Stages.FinalPursuit.Stalks
	)
	check(
		"escalation is not just speed: the top speed gains less than 20% over the first chase",
		CopyConfig.Stages.FinalPursuit.PursueSpeed / CopyConfig.Stages.Hunting.PursueSpeed < 1.2
	)
end

-- Fairness numbers.
check("an attack is telegraphed", CopyConfig.AttackWindup >= 0.5)
check("it cannot attack again at once after a miss", CopyConfig.AttackRecovery >= 1)
check("stalking is slower than a walking player", CopyConfig.StalkSpeed < PlayerSpeeds.walk)
check(
	"it stalks from outside catching distance",
	CopyConfig.StalkDistance > CopyConfig.CatchDistance * 3
)
check(
	"a dark room hides a player better than a lit one",
	CopyConfig.DetectionDistanceDark < CopyConfig.DetectionDistance
		and CopyConfig.DetectionDistance < CopyConfig.DetectionDistanceLit
)
check("a caught player gets a breather", CopyConfig.CaughtGraceTime >= 10)
check(
	"search cues are not certain",
	CopyConfig.SearchCueChance > 0 and CopyConfig.SearchCueChance < 1
)
check("path requests are throttled", CopyConfig.RepathInterval >= 0.5)
check("the sighting room is unchanged", CopyConfig.SightingRoom == "B_MainCorridor")

print(`{total - failures}/{total} checks passed`)
if failures > 0 then
	error("copy unit tests failed")
end
