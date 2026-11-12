--!strict
-- The flashlight: battery rules (from Config/BatteryConfig) and the look of the light.

local BatteryConfig = require(script.Parent.BatteryConfig)

return table.freeze({
	BatteryMax = BatteryConfig.BatteryMax,
	DrainPerSecond = BatteryConfig.DrainPerSecond,
	RechargePerSecond = BatteryConfig.RechargePerSecond,
	RechargeCap = BatteryConfig.RechargeCap,
	LowBattery = BatteryConfig.LowBattery,

	Range = 60,
	Angle = 62,
	Brightness = 3,
	Color = Color3.fromRGB(226, 232, 236),
	-- Soft glow around the player holding the light. It casts no shadows, so it is seen
	-- even if something blocks the beam.
	FillRange = 10,
	FillBrightness = 0.45,

	-- Where the local player's beam starts, relative to the camera: slightly right and
	-- below the eye like a hand-held torch, and far enough forward to be in front of the
	-- face rather than inside the head (which would block a shadow-casting light).
	LocalOffset = Vector3.new(0.45, -0.35, -0.9),
})
