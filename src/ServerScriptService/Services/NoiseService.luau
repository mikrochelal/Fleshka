--!strict
-- Decouples things that make noise (sprinting, the power puzzle, the radio) from things
-- that listen (THE COPY). Emitters do not need to know who is listening.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)

local NoiseService = {}

-- Fired with (position: Vector3, radius: number): the noise can be heard within `radius`.
NoiseService.heard = Signal.new()

function NoiseService.emit(position: Vector3, radius: number)
	NoiseService.heard:Fire(position, radius)
end

return NoiseService
