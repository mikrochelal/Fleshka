--!strict
-- Optional dark base lighting for working on the underground station. Never applied
-- automatically: it changes properties of the place's Lighting service, which the owner
-- controls. Previous values are remembered on the Lighting instance and can be restored.
--
-- It only removes daylight and sets a low cold ambient, so the station's own lamps define
-- the look. Fog, post-processing and the final mood are deliberately left for later.

local Lighting = game:GetService("Lighting")

local PREVIOUS_PREFIX = "TLS_Prev_"
local APPLIED_ATTRIBUTE = "TLS_LightingPreset"

local PRESET: { [string]: any } = {
	-- Low, slightly cold fill so unlit corners are dark but not pure black.
	Ambient = Color3.fromRGB(22, 25, 29),
	OutdoorAmbient = Color3.fromRGB(22, 25, 29),
	-- No sunlight underground.
	Brightness = 0,
	-- No sky colour bleeding onto surfaces.
	EnvironmentDiffuseScale = 0,
	EnvironmentSpecularScale = 0,
	ExposureCompensation = 0,
}

local LightingPreset = {}

function LightingPreset.isApplied(): boolean
	return Lighting:GetAttribute(APPLIED_ATTRIBUTE) == true
end

-- Returns false when the preset was already applied (nothing changes).
function LightingPreset.apply(): boolean
	if LightingPreset.isApplied() then
		return false
	end
	local lighting = Lighting :: any
	for property, value in PRESET do
		Lighting:SetAttribute(PREVIOUS_PREFIX .. property, lighting[property])
		lighting[property] = value
	end
	Lighting:SetAttribute(APPLIED_ATTRIBUTE, true)
	return true
end

-- Puts back the values that were in place before apply(). Returns false if not applied.
function LightingPreset.restore(): boolean
	if not LightingPreset.isApplied() then
		return false
	end
	local lighting = Lighting :: any
	for property in PRESET do
		local previous = Lighting:GetAttribute(PREVIOUS_PREFIX .. property)
		if previous ~= nil then
			lighting[property] = previous
		end
		Lighting:SetAttribute(PREVIOUS_PREFIX .. property, nil)
	end
	Lighting:SetAttribute(APPLIED_ATTRIBUTE, nil)
	return true
end

return LightingPreset
