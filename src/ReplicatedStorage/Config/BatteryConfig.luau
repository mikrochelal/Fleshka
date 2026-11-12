--!strict
-- Flashlight battery rules. Kept apart from the light's look (Config/FlashlightConfig) so
-- that these numbers have no Roblox types and the regression test can load them.

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
})
