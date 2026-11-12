--!strict

return table.freeze({
	BatteryMax = 100,
	-- A full battery lasts about five minutes of light.
	DrainPerSecond = 100 / 300,
	-- While the light is off the battery slowly recovers, but only up to RechargeCap, so a
	-- player can never be left permanently in the dark.
	RechargePerSecond = 0.5,
	RechargeCap = 25,
	-- Below this charge the beam flickers.
	LowBattery = 15,

	Range = 60,
	Angle = 62,
	Brightness = 3,
	Color = Color3.fromRGB(226, 232, 236),
	-- Soft glow around the player holding the light.
	FillRange = 9,
	FillBrightness = 0.35,
})
