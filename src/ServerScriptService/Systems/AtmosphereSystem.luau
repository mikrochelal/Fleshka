--!strict
-- Applies the look from Config/AtmosphereConfig when the game starts: dark base lighting,
-- a thin haze and a restrained colour grade. Runtime only: nothing is saved into the
-- place, and the Lighting the owner set up in Studio comes back when the game stops.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AtmosphereConfig = require(ReplicatedStorage.Config.AtmosphereConfig)
local Logger = require(ReplicatedStorage.Shared.Logger)

local COLOR_CORRECTION_NAME = "TLS_ColorCorrection"

local log = Logger.new("Atmosphere")

local AtmosphereSystem = {}

local function setProperties(instance: Instance, properties: { [string]: any })
	local target = instance :: any
	for property, value in properties do
		local ok, err = pcall(function()
			target[property] = value
		end)
		if not ok then
			log:warn(`Could not set {instance.ClassName}.{property}: {err}`)
		end
	end
end

function AtmosphereSystem.Start(_self: any)
	if not AtmosphereConfig.Enabled then
		return
	end
	setProperties(Lighting, AtmosphereConfig.Properties)

	if AtmosphereConfig.Atmosphere.Enabled then
		-- Lighting uses one Atmosphere; reuse the place's own if it has one.
		local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
		if not atmosphere then
			atmosphere = Instance.new("Atmosphere")
			atmosphere.Parent = Lighting
		end
		setProperties(atmosphere :: Instance, AtmosphereConfig.Atmosphere.Properties)
	end

	if AtmosphereConfig.ColorCorrection.Enabled then
		local existing = Lighting:FindFirstChild(COLOR_CORRECTION_NAME)
		local grade = if existing and existing:IsA("ColorCorrectionEffect")
			then existing
			else Instance.new("ColorCorrectionEffect")
		grade.Name = COLOR_CORRECTION_NAME
		setProperties(grade, AtmosphereConfig.ColorCorrection.Properties)
		grade.Parent = Lighting
	end

	for _, child in Lighting:GetChildren() do
		if
			child:IsA("PostEffect") and table.find(AtmosphereConfig.DisableEffects, child.ClassName)
		then
			child.Enabled = false
		end
	end

	log:info("Underground lighting, haze and colour grade applied for this play session")
end

return AtmosphereSystem
