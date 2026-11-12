--!strict

return table.freeze({
	-- Studs from the character to the object at which the prompt appears.
	MaxDistance = 10,
	-- Extra studs the server accepts on top of MaxDistance to absorb network latency.
	DistanceTolerance = 3,
	-- Minimum seconds between two interactions by the same player.
	Cooldown = 0.25,
	-- Server-side check that no wall stands between the character and the object.
	RequireLineOfSight = true,
})
