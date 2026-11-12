--!strict
-- THE COPY's decision making: a small state machine with no Roblox API, so its rules are
-- unit tested (tests/copy.luau). It is fed what the entity perceives and answers with the
-- state it should be in; moving the body and sensing the world happen elsewhere.
--
--   Dormant        not in the world
--   Observing      standing still, watching
--   Investigating  walking to something it heard
--   Searching      checking places near where it last saw or heard something
--   Pursuing       chasing one player (after a short warning)
--   Disappearing   fading out
--
-- Fairness built into the rules: it only appears when a hidden, distant spot exists; it
-- needs continuous sight before reacting; a pursuit needs to be armed by the mission,
-- starts with a warning, ends when sight is lost and is always time limited; and every
-- encounter is followed by a cooldown.

export type State =
	"Dormant"
	| "Observing"
	| "Investigating"
	| "Searching"
	| "Pursuing"
	| "Disappearing"

export type Config = {
	AcquireTime: number,
	PursueStartDistance: number,
	ChaseWarningTime: number,
	LoseSightTime: number,
	MaxPursuitDuration: number,
	ObserveDuration: number,
	ObserveFleeDistance: number,
	SearchDuration: number,
	InvestigateTimeout: number,
	FadeTime: number,
	EncounterCooldown: number,
	CatchCooldown: number,
}

export type Percept = {
	-- At least one living player is in the station and the mission is running.
	playersPresent: boolean,
	-- A spot exists where it can appear unseen and far enough from everyone.
	canAppear: boolean,
	-- It heard something this tick.
	noise: boolean,
	-- The director wants it to come and watch.
	wakeRequested: boolean,
	-- It can see a player right now, and how far that player is.
	seesTarget: boolean,
	targetDistance: number,
	-- Distance to the closest player, seen or not.
	nearestDistance: number,
	-- Its current walk finished, or could not be planned.
	arrived: boolean,
	pathFailed: boolean,
	-- The mission allows pursuits.
	pursuitArmed: boolean,
	-- It has just caught its target.
	caught: boolean,
}

export type Brain = {
	state: State,
	stateTime: number,
	seenTime: number,
	lostTime: number,
	cooldown: number,
	nextCooldown: number,
	observeLimit: number,
	fleeDistance: number,
	config: Config,
	-- The untuned configuration; `tune` always starts from it.
	base: Config,
}

local Brain = {}

function Brain.new(config: Config): Brain
	return {
		state = "Dormant",
		stateTime = 0,
		seenTime = 0,
		lostTime = 0,
		cooldown = 0,
		nextCooldown = config.EncounterCooldown,
		observeLimit = config.ObserveDuration,
		fleeDistance = config.ObserveFleeDistance,
		config = config,
		base = config,
	}
end

local function enter(brain: Brain, state: State)
	brain.state = state
	brain.stateTime = 0
	if state == "Observing" then
		brain.observeLimit = brain.config.ObserveDuration
		brain.fleeDistance = brain.config.ObserveFleeDistance
	elseif state == "Pursuing" then
		brain.lostTime = 0
	end
end

-- Puts it straight into Observing for a scripted sighting with its own timing.
function Brain.stage(brain: Brain, duration: number, fleeDistance: number)
	enter(brain, "Observing")
	brain.observeLimit = duration
	brain.fleeDistance = fleeDistance
	brain.seenTime = 0
end

-- Replaces some timing values (used by the escalation stages). Values not listed go back
-- to the original configuration.
function Brain.tune(brain: Brain, overrides: { [string]: number })
	local tuned = table.clone(brain.base) :: any
	for key, value in overrides do
		tuned[key] = value
	end
	brain.config = tuned
end

function Brain.clearCooldown(brain: Brain)
	brain.cooldown = 0
end

-- True during the stand-still warning at the start of a pursuit.
function Brain.isWarning(brain: Brain): boolean
	return brain.state == "Pursuing" and brain.stateTime < brain.config.ChaseWarningTime
end

function Brain.update(brain: Brain, dt: number, percept: Percept): State
	local config = brain.config
	brain.stateTime += dt
	if percept.seesTarget then
		brain.seenTime += dt
		brain.lostTime = 0
	else
		brain.seenTime = 0
		brain.lostTime += dt
	end

	local state = brain.state
	local acquired = brain.seenTime >= config.AcquireTime
	local canPursue = acquired
		and percept.pursuitArmed
		and percept.targetDistance <= config.PursueStartDistance

	if state == "Dormant" then
		brain.cooldown = math.max(0, brain.cooldown - dt)
		if brain.cooldown <= 0 and percept.playersPresent and percept.canAppear then
			if percept.noise then
				enter(brain, "Investigating")
			elseif percept.wakeRequested then
				enter(brain, "Observing")
			end
		end
	elseif state == "Disappearing" then
		if brain.stateTime >= config.FadeTime then
			enter(brain, "Dormant")
			brain.cooldown = brain.nextCooldown
			brain.nextCooldown = config.EncounterCooldown
		end
	elseif not percept.playersPresent then
		enter(brain, "Disappearing")
	elseif state == "Observing" then
		if canPursue then
			enter(brain, "Pursuing")
		elseif
			percept.nearestDistance < brain.fleeDistance or brain.stateTime > brain.observeLimit
		then
			enter(brain, "Disappearing")
		elseif percept.noise then
			enter(brain, "Investigating")
		end
	elseif state == "Investigating" then
		if canPursue then
			enter(brain, "Pursuing")
		elseif acquired then
			-- Not allowed to chase yet: it stops and stares instead.
			enter(brain, "Observing")
		elseif
			percept.arrived
			or percept.pathFailed
			or brain.stateTime > config.InvestigateTimeout
		then
			enter(brain, "Searching")
		end
	elseif state == "Searching" then
		if canPursue then
			enter(brain, "Pursuing")
		elseif acquired then
			enter(brain, "Observing")
		elseif brain.stateTime > config.SearchDuration then
			enter(brain, "Disappearing")
		end
	elseif state == "Pursuing" then
		if percept.caught then
			brain.nextCooldown = config.CatchCooldown
			enter(brain, "Disappearing")
		elseif brain.stateTime > config.MaxPursuitDuration then
			enter(brain, "Disappearing")
		elseif brain.lostTime > config.LoseSightTime then
			enter(brain, "Searching")
		end
	end

	return brain.state
end

return Brain
