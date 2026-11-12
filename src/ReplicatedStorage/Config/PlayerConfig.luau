--!strict

return table.freeze({
	WalkSpeed = 12,
	SprintSpeed = 20,

	StaminaMax = 100,
	-- A full bar lasts about seven seconds of sprinting.
	StaminaDrainPerSecond = 14,
	StaminaRegenPerSecond = 11,
	-- Seconds after sprinting stops before stamina starts to return.
	StaminaRegenDelay = 1.2,
	-- After running dry, sprinting is locked until stamina is back to this value.
	ExhaustedRecoverAt = 25,
	-- Horizontal studs per second below which the character counts as standing still.
	MovingSpeedThreshold = 2,

	-- Studs above the floor at which characters are placed when spawning.
	SpawnDropHeight = 4,
	-- Horizontal offsets from the spawn marker, one per player slot.
	SpawnSlots = table.freeze({
		Vector3.new(0, 0, 0),
		Vector3.new(3, 0, 0),
		Vector3.new(-3, 0, 0),
		Vector3.new(0, 0, 3),
	}),
	-- Characters are turned to face this room when they spawn.
	SpawnFacingRoom = "A_Lobby",
})
