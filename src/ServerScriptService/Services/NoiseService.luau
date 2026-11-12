--!strict
-- Decouples things that make noise (sprinting, doors, machinery, the radio) from things
-- that listen (THE COPY). Emitters name a noise from Config/NoiseConfig; they do not need
-- to know who is listening, and actions that are not listed there make no noise at all.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NoiseConfig = require(ReplicatedStorage.Config.NoiseConfig)
local Logger = require(ReplicatedStorage.Shared.Logger)
local Signal = require(ReplicatedStorage.Shared.Signal)

local log = Logger.new("Noise")

local NoiseService = {}

-- Fired with (position: Vector3, radius: number, name: string): the noise can be heard
-- within `radius` studs of `position`.
NoiseService.heard = Signal.new()

local lastMade: { [any]: { [string]: number } } = setmetatable({} :: any, { __mode = "k" })
local unknown: { [string]: boolean } = {}

-- Makes the named noise at a position. `source` (a player or an object) is used only to
-- apply the noise's minimum interval. Returns whether the noise was made.
function NoiseService.make(name: string, position: Vector3, source: any?): boolean
	local noise = NoiseConfig.Events[name]
	if not noise then
		if not unknown[name] then
			unknown[name] = true
			log:warn(`Unknown noise "{name}" (add it to Config/NoiseConfig)`)
		end
		return false
	end
	if noise.interval and source ~= nil then
		local now = os.clock()
		local made = lastMade[source]
		if not made then
			made = {}
			lastMade[source] = made
		end
		if now - (made[name] or -math.huge) < noise.interval then
			return false
		end
		made[name] = now
	end
	NoiseService.heard:Fire(position, noise.radius, name)
	return true
end

return NoiseService
