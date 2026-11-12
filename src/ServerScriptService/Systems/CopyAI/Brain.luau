--!strict
-- THE COPY's decision making: a state machine with no Roblox API, so its rules are unit
-- tested (tests/copy.luau). It is fed what the entity perceives and answers with the state
-- it should be in; moving the body and sensing the world happen elsewhere.
--
--   Dormant        not in the world
--   Observing      standing still, watching
--   Patrolling     walking a short route of observation points
--   Investigating  walking to something it heard
--   Searching      checking places near where it last saw or heard something
--   Stalking       following a player it sees from too far to chase, keeping its distance
--   Pursuing       chasing one player (after a stand-still warning)
--   Attacking      standing still for the windup of a lunge; stepping away dodges it
--   LostTarget     going to where it last saw the player it was chasing
--   Returning      giving up: walking away to a distant observation point
--   Disappearing   fading out
--
-- "Escalated" is not a state. How dangerous it is comes from the escalation stage
-- (Escalation.luau: Dormant, Aware, Hunting, Hostile, FinalPursuit), which arms the
-- `pursuitArmed`, `patrolArmed` and `stalkArmed` percepts and tunes the timings.
--
-- Fairness built into the rules: it only appears when a hidden, distant spot exists; it
-- needs continuous sight before reacting; a pursuit needs to be armed by the mission,
-- starts with a warning, ends when sight is lost and is always time limited; a catch is a
-- telegraphed attack that can be dodged; and every encounter is followed by a cooldown.
--
-- Sight regained in LostTarget: within ReacquireGrace seconds the same chase simply goes on
-- (no new warning, same time limit); later than that it is a new chase with the shorter
-- ReacquireWarningTime warning.

export type State =
	"Dormant"
	| "Observing"
	| "Patrolling"
	| "Investigating"
	| "Searching"
	| "Stalking"
	| "Pursuing"
	| "Attacking"
	| "LostTarget"
	| "Returning"
	| "Disappearing"

export type Config = {
	AcquireTime: number,
	PursueStartDistance: number,
	ChaseWarningTime: number,
	LoseSightTime: number,
	MaxPursuitDuration: number,
	ReacquireGrace: number,
	ReacquireWarningTime: number,
	LostTargetTimeout: number,
	AttackWindup: number,
	AttackRecovery: number,
	StalkDuration: number,
	PatrolDuration: number,
	MaxPathFailures: number,
	ReturnTimeout: number,
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
	-- The director wants it to come out.
	wakeRequested: boolean,
	-- It can see its target right now, and how far that player is.
	seesTarget: boolean,
	targetDistance: number,
	-- Distance to the closest player, seen or not.
	nearestDistance: number,
	-- Its current walk finished, or could not be planned.
	arrived: boolean,
	pathFailed: boolean,
	-- The mission allows pursuits.
	pursuitArmed: boolean,
	-- Everything below may be left out: absent means false (or 1 for the rate).
	-- The stage makes visits patrols, and allows stalking.
	patrolArmed: boolean?,
	stalkArmed: boolean?,
	-- Multiplier on how fast sight builds toward AcquireTime.
	detectionRate: number?,
	-- The target is in view within catching distance.
	inReach: boolean?,
	-- The patrol route is finished.
	routeDone: boolean?,
	-- Nothing is left to search, or it no longer trusts its memory.
	searchDone: boolean?,
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
	-- Length of the stand-still warning of the current pursuit (0 = none).
	warningTime: number,
	-- Time spent on the current chase, attacks included.
	pursuitTime: number,
	-- Time until it may attack again after a miss.
	attackRecovery: number,
	-- Patrol walks in a row that could not be planned.
	pathFailures: number,
	-- True only for the update in which an attack connected.
	caught: boolean,
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
		warningTime = 0,
		pursuitTime = 0,
		attackRecovery = 0,
		pathFailures = 0,
		caught = false,
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
	elseif state == "Patrolling" then
		brain.pathFailures = 0
	end
end

-- Starts a new chase with a stand-still warning of `warning` seconds.
local function beginPursuit(brain: Brain, warning: number)
	enter(brain, "Pursuing")
	brain.warningTime = warning
	brain.pursuitTime = 0
	brain.attackRecovery = 0
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
	return brain.state == "Pursuing" and brain.stateTime < brain.warningTime
end

-- True while it is committed to one player and must not be distracted.
function Brain.isChasing(brain: Brain): boolean
	return brain.state == "Pursuing" or brain.state == "Attacking"
end

-- What it does about a player it has watched long enough, while walking around. Returns
-- whether it reacted.
local function notice(
	brain: Brain,
	percept: Percept,
	acquired: boolean,
	canPursue: boolean
): boolean
	if canPursue then
		beginPursuit(brain, brain.config.ChaseWarningTime)
	elseif not acquired then
		return false
	elseif percept.pursuitArmed and percept.stalkArmed then
		-- Allowed to chase but too far away: it follows instead.
		enter(brain, "Stalking")
	else
		-- Not allowed to chase (yet): it stops and stares.
		enter(brain, "Observing")
	end
	return true
end

function Brain.update(brain: Brain, dt: number, percept: Percept): State
	local config = brain.config
	brain.stateTime += dt
	brain.caught = false
	brain.attackRecovery = math.max(0, brain.attackRecovery - dt)
	if percept.seesTarget then
		brain.seenTime += dt * (percept.detectionRate or 1)
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
	local walkEnded = percept.arrived or percept.pathFailed

	if state == "Dormant" then
		brain.cooldown = math.max(0, brain.cooldown - dt)
		if brain.cooldown <= 0 and percept.playersPresent and percept.canAppear then
			if percept.noise then
				enter(brain, "Investigating")
			elseif percept.wakeRequested then
				enter(brain, if percept.patrolArmed then "Patrolling" else "Observing")
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
			beginPursuit(brain, config.ChaseWarningTime)
		elseif
			percept.nearestDistance < brain.fleeDistance or brain.stateTime > brain.observeLimit
		then
			enter(brain, "Disappearing")
		elseif percept.noise then
			enter(brain, "Investigating")
		end
	elseif state == "Patrolling" then
		if percept.pathFailed then
			brain.pathFailures += 1
		elseif percept.arrived then
			brain.pathFailures = 0
		end
		if notice(brain, percept, acquired, canPursue) then
			return brain.state
		elseif percept.noise then
			enter(brain, "Investigating")
		elseif
			percept.routeDone
			or brain.stateTime > config.PatrolDuration
			or brain.pathFailures >= config.MaxPathFailures
		then
			enter(brain, "Returning")
		end
	elseif state == "Investigating" then
		if notice(brain, percept, acquired, canPursue) then
			return brain.state
		elseif walkEnded or brain.stateTime > config.InvestigateTimeout then
			enter(brain, "Searching")
		end
	elseif state == "Searching" then
		if notice(brain, percept, acquired, canPursue) then
			return brain.state
		elseif percept.noise then
			enter(brain, "Investigating")
		elseif percept.searchDone or brain.stateTime > config.SearchDuration then
			enter(brain, if percept.patrolArmed then "Returning" else "Disappearing")
		end
	elseif state == "Stalking" then
		if canPursue then
			beginPursuit(brain, config.ChaseWarningTime)
		elseif brain.lostTime > config.LoseSightTime then
			enter(brain, "LostTarget")
		elseif brain.stateTime > config.StalkDuration then
			enter(brain, "Returning")
		end
	elseif state == "Pursuing" then
		brain.pursuitTime += dt
		if brain.pursuitTime > config.MaxPursuitDuration then
			enter(brain, "Disappearing")
		elseif
			percept.inReach
			and brain.stateTime >= brain.warningTime
			and brain.attackRecovery <= 0
		then
			enter(brain, "Attacking")
		elseif brain.lostTime > config.LoseSightTime then
			enter(brain, "LostTarget")
		end
	elseif state == "Attacking" then
		brain.pursuitTime += dt
		if brain.stateTime >= config.AttackWindup then
			if percept.inReach then
				brain.caught = true
				brain.nextCooldown = config.CatchCooldown
				enter(brain, "Disappearing")
			else
				-- Missed: the chase goes on without a new warning.
				enter(brain, "Pursuing")
				brain.warningTime = 0
				brain.attackRecovery = config.AttackRecovery
			end
		end
	elseif state == "LostTarget" then
		if canPursue then
			if brain.stateTime > config.ReacquireGrace then
				beginPursuit(brain, config.ReacquireWarningTime)
			else
				enter(brain, "Pursuing")
				brain.warningTime = 0
			end
		elseif percept.noise then
			enter(brain, "Investigating")
		elseif walkEnded or brain.stateTime > config.LostTargetTimeout then
			enter(brain, "Searching")
		end
	elseif state == "Returning" then
		if canPursue then
			beginPursuit(brain, config.ChaseWarningTime)
		elseif percept.noise then
			enter(brain, "Investigating")
		elseif walkEnded or brain.stateTime > config.ReturnTimeout then
			enter(brain, "Disappearing")
		end
	end

	return brain.state
end

return Brain
