--!strict
-- Base lighting the game applies while it runs. The station is underground, so daylight
-- and sky light are removed and the rooms are lit only by their own lamps and by
-- flashlights. Applied by the server at runtime (Systems/AtmosphereSystem): the place's
-- saved Lighting settings are not modified, and stopping the game restores them.
--
-- These are the same values as the map tool's optional `applyLightingPreset()`, so the
-- editor preview and the running game match.

return table.freeze({
	-- Set to false to keep whatever Lighting the place has.
	Enabled = true,

	Properties = table.freeze({
		-- Low, slightly cold fill so unlit corners are dark but not pure black.
		Ambient = Color3.fromRGB(22, 25, 29),
		OutdoorAmbient = Color3.fromRGB(22, 25, 29),
		-- No sunlight underground.
		Brightness = 0,
		-- No sky colour bleeding onto surfaces.
		EnvironmentDiffuseScale = 0,
		EnvironmentSpecularScale = 0,
		ExposureCompensation = 0,
	} :: { [string]: any }),
})
