--!strict
-- THE COPY. Speeds are studs per second, distances studs, times seconds.

return table.freeze({
	Enabled = true,

	-- Slower than a walking player while investigating; between walking and sprinting while
	-- pursuing, so sprinting and breaking line of sight always works.
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
	-- Sight lost for this long ends the pursuit.
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
	-- Quiet time after an encounter, and after a catch.
	EncounterCooldown = 35,
	CatchCooldown = 60,
	-- Once active, it comes to watch after this long without an encounter.
	AmbientInterval = 55,

	-- While it is dormant, only noises at least this loud (their radius) bring it out.
	-- Sprinting (34) and the radio (50) are quieter; a failed power start-up is louder.
	WakeNoiseRadius = 80,

	-- Distance at which the screen interference starts to build.
	DreadDistance = 70,

	-- Scripted first sighting.
	SightingRoom = "B_MainCorridor",
	SightingDuration = 7,
	SightingFleeDistance = 28,
	-- If nobody walks into the corridor, the sighting plays anyway after this long.
	SightingFallbackSeconds = 25,
})
