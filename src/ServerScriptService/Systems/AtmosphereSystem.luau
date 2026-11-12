--!strict
-- Applies the dark base lighting from Config/AtmosphereConfig when the game starts.
-- Runtime only: nothing is saved into the place, and the Lighting settings the owner chose
-- in Studio come back when the game stops.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AtmosphereConfig = require(ReplicatedStorage.Config.AtmosphereConfig)
local Logger = require(ReplicatedStorage.Shared.Logger)

local log = Logger.new("Atmosphere")

local AtmosphereSystem = {}

function AtmosphereSystem.Start(_self: any)
	if not AtmosphereConfig.Enabled then
		return
	end
	local lighting = Lighting :: any
	for property, value in AtmosphereConfig.Properties do
		local ok, err = pcall(function()
			lighting[property] = value
		end)
		if not ok then
			log:warn(`Could not set Lighting.{property}: {err}`)
		end
	end
	log:info("Underground base lighting applied for this play session")
end

return AtmosphereSystem
