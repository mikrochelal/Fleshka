--!strict
-- Lighting the game applies while it runs. The station is underground, so daylight and sky
-- light are removed and the rooms are lit only by their own lamps and by flashlights; a
-- light haze and a restrained colour grade give the cold, low-saturation look.
--
-- Applied by the server at runtime (Systems/AtmosphereSystem): the place's saved Lighting
-- settings are not modified, and stopping the game restores them. Everything here is a
-- starting value that has not been judged on screen yet - adjust freely.

return table.freeze({
	-- Set to false to keep whatever Lighting the place has.
	Enabled = true,

	-- Same values as the map tool's optional `applyLightingPreset()`.
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

	-- Thin dark haze: distant ends of corridors fade instead of ending in a hard edge.
	-- Kept light so a figure at the far end of the main corridor is still visible.
	Atmosphere = table.freeze({
		Enabled = true,
		Properties = table.freeze({
			Density = 0.22,
			Offset = 0,
			Color = Color3.fromRGB(26, 30, 34),
			Decay = Color3.fromRGB(14, 16, 18),
			Glare = 0,
			Haze = 1.2,
		} :: { [string]: any }),
	}),

	-- Slight desaturation and contrast with a cold tint.
	ColorCorrection = table.freeze({
		Enabled = true,
		Properties = table.freeze({
			Saturation = -0.18,
			Contrast = 0.08,
			Brightness = 0,
			TintColor = Color3.fromRGB(226, 236, 240),
		} :: { [string]: any }),
	}),

	-- Effects from the default Studio template that fight a dark interior. They are
	-- switched off for the play session only.
	DisableEffects = table.freeze({ "DepthOfFieldEffect", "SunRaysEffect" }),
})
