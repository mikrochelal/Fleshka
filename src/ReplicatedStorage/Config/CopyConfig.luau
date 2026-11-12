--!strict
-- THE COPY. Speeds are studs per second, distances studs, times seconds.

-- How it behaves at one escalation stage. The stage is set by mission progress
-- (Systems/SliceDirector); it never changes on its own and never goes backwards.
export type StageSettings = {
	-- Comes to watch on its own this often (nil = never).
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
}

local stages: { [string]: StageSettings } = {
	-- Before power: absent. Only a loud mistake brings it, and it only looks.
	Dormant = {
		VisitInterval = nil,
		Pursues = false,
		PursueSpeed = 15,
		DetectionScale = 1,
		LoseSightTime = 5,
		Cooldown = 35,
		WakeNoiseRadius = 80,
		DisturbanceInterval = nil,
	},
	-- Power is back: it starts coming to watch. Still never chases.
	Aware = {
		VisitInterval = 60,
		Pursues = false,
		PursueSpeed = 15,
		DetectionScale = 1,
		LoseSightTime = 5,
		Cooldown = 35,
		WakeNoiseRadius = 80,
		DisturbanceInterval = 50,
	},
	-- The transmission has been heard: it now gives chase, and the radio-level noises
	-- draw it in.
	Hunting = {
		VisitInterval = 45,
		Pursues = true,
		PursueSpeed = 15,
		DetectionScale = 1.1,
		LoseSightTime = 5,
		Cooldown = 28,
		WakeNoiseRadius = 50,
		DisturbanceInterval = 38,
	},
	-- The signal has been traced: it sees further, holds a chase longer, rests less, and
	-- hears running even when it is away.
	Hostile = {
		VisitInterval = 32,
		Pursues = true,
		PursueSpeed = 16.5,
		DetectionScale = 1.25,
		LoseSightTime = 6.5,
		Cooldown = 18,
		WakeNoiseRadius = 34,
		DisturbanceInterval = 26,
	},
	-- The escape: almost always out, but still slower than a sprint and still blind
	-- around corners.
	FinalPursuit = {
		VisitInterval = 16,
		Pursues = true,
		PursueSpeed = 17.5,
		DetectionScale = 1.35,
		LoseSightTime = 8,
		Cooldown = 8,
		WakeNoiseRadius = 34,
		DisturbanceInterval = 16,
	},
}

return table.freeze({
	Enabled = true,

	-- Slower than a walking player while investigating. Pursuit speed comes from the stage
	-- and always stays between the player's walk (12) and sprint (20).
	WalkSpeed = 9,
	PursueSpeed = 15,

	-- How far it can see a player in the dark, and one whose flashlight is on.
	DetectionDistance = 38,
	DetectionDistanceLit = 60,
	-- Continuous sight needed before it reacts.
	AcquireTime = 1,
	-- A pursuit only starts from within this distance.
	PursueStartDistance = 55,
	-- It stands still for this long after noticing a player, as a warning.
	ChaseWarningTime = 2,
	-- Sight lost for this long ends the pursuit (overridden per stage).
	LoseSightTime = 5,
	MaxPursuitDuration = 25,
	-- A catch needs the player this close, in view, for this long.
	CatchDistance = 4.5,
	CatchTime = 0.8,
	-- Room a caught player wakes up in (falls back to the spawn point).
	CaughtReturnRoom = "D_CommCenter",

	ObserveDuration = 9,
	-- While only observing it vanishes when a player comes this close.
	ObserveFleeDistance = 24,
	SearchDuration = 14,
	InvestigateTimeout = 30,
	FadeTime = 1.2,

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
