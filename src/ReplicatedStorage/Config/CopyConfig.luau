--!strict
-- THE COPY. Speeds are studs per second, distances studs, times seconds.

-- How it behaves at one escalation stage. The stage is set by mission progress
-- (Systems/SliceDirector); it never changes on its own and never goes backwards.
export type StageSettings = {
	-- Comes out on its own this often (nil = never).
	VisitInterval: number?,
	-- May give chase. Before this it only watches and leaves.
	Pursues: boolean,
	PursueSpeed: number,
	-- Multiplier on how far it can see.
	DetectionScale: number,
	-- How long it keeps chasing after losing sight.
	LoseSightTime: number,
	-- Quiet time after each encounter.
	Cooldown: number,
	-- While it is away, only noises at least this loud (their radius) bring it out.
	-- Sprinting is 34, the radio 50, a rejected breaker 140, the elevator recall 400.
	WakeNoiseRadius: number,
	-- Seconds between small environmental disturbances near players (nil = none).
	DisturbanceInterval: number?,
	-- A visit is a walk along a route of observation points instead of standing still.
	Patrols: boolean,
	-- Observation points in one patrol route.
	PatrolPoints: number,
	-- Follows a player it sees from too far to chase, keeping its distance, until it is
	-- close enough to start a pursuit.
	Stalks: boolean,
	-- Multiplier on how far a noise carries for it once it is out.
	HearingScale: number,
	-- How wrong its idea of where a noise came from is, as a fraction of the distance.
	HearingError: number,
	-- Places it checks in one search (the last known position plus hiding places).
	SearchPoints: number,
	-- Seconds of searching until it no longer trusts where it last saw or heard someone.
	MemoryTime: number,
}

local stages: { [string]: StageSettings } = {
	-- Before power: absent. Only a loud mistake brings it, it has a poor idea of where the
	-- noise was, and it only looks.
	Dormant = {
		VisitInterval = nil,
		Pursues = false,
		PursueSpeed = 15,
		DetectionScale = 1,
		LoseSightTime = 5,
		Cooldown = 35,
		WakeNoiseRadius = 80,
		DisturbanceInterval = nil,
		Patrols = false,
		PatrolPoints = 0,
		Stalks = false,
		HearingScale = 0.8,
		HearingError = 0.5,
		SearchPoints = 2,
		MemoryTime = 14,
	},
	-- Power is back: it starts coming to watch and investigates a little more. Still never
	-- chases.
	Aware = {
		VisitInterval = 60,
		Pursues = false,
		PursueSpeed = 15,
		DetectionScale = 1,
		LoseSightTime = 5,
		Cooldown = 35,
		WakeNoiseRadius = 80,
		DisturbanceInterval = 50,
		Patrols = false,
		PatrolPoints = 0,
		Stalks = false,
		HearingScale = 0.9,
		HearingError = 0.45,
		SearchPoints = 3,
		MemoryTime = 16,
	},
	-- The transmission has been heard: it now gives chase, the radio-level noises draw it
	-- in, and its visits become patrols.
	Hunting = {
		VisitInterval = 45,
		Pursues = true,
		PursueSpeed = 15,
		DetectionScale = 1.1,
		LoseSightTime = 5,
		Cooldown = 28,
		WakeNoiseRadius = 50,
		DisturbanceInterval = 38,
		Patrols = true,
		PatrolPoints = 3,
		Stalks = false,
		HearingScale = 1,
		HearingError = 0.3,
		SearchPoints = 4,
		MemoryTime = 20,
	},
	-- The signal has been traced: it sees further, holds a chase longer, rests less, hears
	-- running even when it is away, places noises well, stalks, and searches more widely.
	Hostile = {
		VisitInterval = 32,
		Pursues = true,
		PursueSpeed = 16.5,
		DetectionScale = 1.25,
		LoseSightTime = 6.5,
		Cooldown = 18,
		WakeNoiseRadius = 34,
		DisturbanceInterval = 26,
		Patrols = true,
		PatrolPoints = 4,
		Stalks = true,
		HearingScale = 1.15,
		HearingError = 0.15,
		SearchPoints = 5,
		MemoryTime = 26,
	},
	-- The escape: almost always out, knows almost exactly where a noise came from and
	-- searches longest, but is still slower than a sprint and still blind around corners.
	FinalPursuit = {
		VisitInterval = 16,
		Pursues = true,
		PursueSpeed = 17.5,
		DetectionScale = 1.35,
		LoseSightTime = 8,
		Cooldown = 8,
		WakeNoiseRadius = 34,
		DisturbanceInterval = 16,
		Patrols = true,
		PatrolPoints = 5,
		Stalks = true,
		HearingScale = 1.3,
		HearingError = 0.08,
		SearchPoints = 6,
		MemoryTime = 32,
	},
}

return table.freeze({
	Enabled = true,

	-- Slower than a walking player while investigating. Pursuit speed comes from the stage
	-- and always stays between the player's walk (12) and sprint (20).
	WalkSpeed = 9,
	PursueSpeed = 15,

	-- How far it can see a player: in a lit room, with their flashlight on, and in a dark
	-- room with the flashlight off. Walls always block its sight.
	DetectionDistance = 38,
	DetectionDistanceLit = 60,
	DetectionDistanceDark = 26,
	-- Total width of its field of view in degrees, measured from where it faces. Within
	-- CloseAwareness studs it notices a player whichever way it faces.
	VisionAngle = 150,
	CloseAwareness = 14,
	-- Continuous sight needed before it reacts, at detection rate 1.
	AcquireTime = 1,
	-- How fast sight builds toward AcquireTime: from RateNear right next to it down to
	-- RateFar at the edge of its range, times a factor for how easy the player is to see.
	DetectionRateNear = 1.6,
	DetectionRateFar = 0.6,
	DetectionRateLit = 1.25,
	DetectionRateDark = 0.7,
	DetectionRateSprint = 1.3,
	DetectionRateMin = 0.4,
	DetectionRateMax = 2.5,

	-- A pursuit only starts from within this distance.
	PursueStartDistance = 55,
	-- It stands still for this long after noticing a player, as a warning.
	ChaseWarningTime = 2,
	-- Sight lost for this long ends the pursuit (overridden per stage).
	LoseSightTime = 5,
	MaxPursuitDuration = 25,
	-- Sight regained within this long of giving up a chase resumes it at once; later than
	-- that it gives the shorter warning below first.
	ReacquireGrace = 3,
	ReacquireWarningTime = 1,
	-- It walks to where it last saw its target for at most this long before searching.
	LostTargetTimeout = 12,
	-- An attack starts when the target is this close and in view. It then stands still for
	-- the windup; the catch happens only if the target is still that close when it ends.
	-- After a miss it cannot attack again for the recovery time.
	CatchDistance = 4.5,
	AttackWindup = 0.7,
	AttackRecovery = 2.5,

	-- Stalking: it follows at StalkSpeed and stops when closer than StalkDistance.
	StalkDistance = 30,
	StalkDuration = 25,
	StalkSpeed = 11,

	-- Patrolling: a patrol ends after this long even if the route is not finished, and
	-- after this many walks in a row that could not be planned.
	PatrolDuration = 45,
	MaxPathFailures = 3,
	-- Leaving: it walks to an observation point at most this far away before vanishing.
	ReturnTimeout = 20,
	ReturnMaxDistance = 120,

	ObserveDuration = 9,
	-- While only observing it vanishes when a player comes this close.
	ObserveFleeDistance = 24,
	-- Longest search (overridden per stage by MemoryTime).
	SearchDuration = 14,
	InvestigateTimeout = 30,
	FadeTime = 1.2,

	-- Hearing. Its idea of where a noise came from is off by `distance * stage
	-- HearingError`, kept between these limits (studs).
	HearingMinError = 3,
	HearingMaxError = 40,
	-- While it is away it is treated as being this far from every noise.
	HearingDormantDistance = 70,
	-- After turning toward a noise it ignores weaker ones for this long.
	HearingFocusTime = 6,
	-- A scripted summon counts as a noise this loud.
	SummonNoiseRadius = 400,
	-- A summon that finds no fair place to appear is dropped after this long.
	SummonPatience = 30,

	-- Memory. How sure it is of a position it saw (1) or only heard, and how far from
	-- that position it searches: the less sure, the wider.
	NoiseCertainty = 0.6,
	SearchRadiusMin = 35,
	SearchRadiusMax = 80,
	-- Chance that entering a search is announced by a sound, so it is not predictable.
	SearchCueChance = 0.6,
	-- Chance that an unscripted appearance is hinted at by a distant sound.
	DistantCueChance = 0.5,

	-- Choosing between players. A new target must score this much better, and the
	-- current one must have been held this long, before it switches.
	TargetSwitchMargin = 0.25,
	TargetCommitTime = 4,
	-- A caught player is ignored for this long.
	CaughtGraceTime = 20,
	-- Score parts: being in view, closeness (within TargetRange), a recent noise (within
	-- TargetNoiseMemory seconds), and a penalty that builds over TargetAttentionTime
	-- seconds of being its target, so it does not hound one player forever.
	TargetVisibleScore = 1,
	TargetDistanceScore = 1,
	TargetRange = 80,
	TargetNoiseScore = 0.4,
	TargetNoiseMemory = 6,
	TargetAttentionPenalty = 0.6,
	TargetAttentionTime = 40,

	-- Pathfinding: minimum time between two path requests, and how long a request may
	-- take before the walk is reported as failed.
	RepathInterval = 0.6,
	PathTimeout = 4,

	-- It never appears closer than this to any player, or in any player's view.
	MinAppearDistance = 40,
	-- Quiet time after an encounter (overridden per stage), and after a catch.
	EncounterCooldown = 35,
	CatchCooldown = 60,

	-- Distance at which the screen interference starts to build.
	DreadDistance = 70,

	-- Scripted first sighting.
	SightingRoom = "B_MainCorridor",
	SightingDuration = 7,
	SightingFleeDistance = 28,
	-- If nobody walks into the corridor, the sighting plays anyway after this long.
	SightingFallbackSeconds = 25,

	Stages = table.freeze(stages),
})
