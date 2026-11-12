--!strict
-- Positional sound sources in the world: the generator, the fans, the receiver's static...
-- The list is data (Config/AudioConfig.Emitters). Each emitter is an invisible part in
-- Workspace.TLS_Runtime tagged `TLS_AudioEmitter`; clients loop its cue while its `Active`
-- attribute is true (Controllers/AmbienceController). No Sound instance exists on the
-- server, and nothing is saved into the place.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioConfig = require(ReplicatedStorage.Config.AudioConfig)
local Logger = require(ReplicatedStorage.Shared.Logger)
local WorldService = require(script.Parent.Parent.Services.WorldService)

local TAG = "TLS_AudioEmitter"

local log = Logger.new("Audio")

local AudioEmitters = {}

local parts: { [string]: BasePart } = {}
-- Requests made before the map was ready.
type Request = { active: boolean?, intensity: number? }
local pending: { [string]: Request } = {}

local function apply(id: string)
	local part = parts[id]
	local state = pending[id]
	if not part or not state then
		return
	end
	if state.active ~= nil then
		part:SetAttribute("Active", state.active)
	end
	if state.intensity ~= nil then
		part:SetAttribute("Intensity", state.intensity)
	end
	pending[id] = nil
end

-- Switches an emitter's loop on or off for everyone.
function AudioEmitters.setActive(id: string, active: boolean)
	local state: Request = pending[id] or {}
	state.active = active
	pending[id] = state
	apply(id)
end

-- Scales an emitter's volume (1 = as configured).
function AudioEmitters.setIntensity(id: string, intensity: number)
	local state: Request = pending[id] or {}
	state.intensity = intensity
	pending[id] = state
	apply(id)
end

function AudioEmitters.Start(_self: any)
	WorldService.onReady(function()
		local count = 0
		for _, emitter in AudioConfig.Emitters do
			local zone = WorldService.getZone(emitter.room)
			if not zone or parts[emitter.id] then
				continue
			end
			local part = Instance.new("Part")
			part.Name = `Emitter_{emitter.id}`
			part.Size = Vector3.new(1, 1, 1)
			part.Transparency = 1
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.CFrame = zone.CFrame
				* CFrame.new(
					(emitter.fx - 0.5) * zone.Size.X,
					-zone.Size.Y / 2 + emitter.y,
					(emitter.fz - 0.5) * zone.Size.Z
				)
			part:SetAttribute("Cue", emitter.cue)
			part:SetAttribute("Active", emitter.active)
			part:SetAttribute("Intensity", 1)
			part:AddTag(TAG)
			part.Parent = WorldService.runtimeFolder()
			parts[emitter.id] = part
			apply(emitter.id)
			count += 1
		end
		log:info(`{count} sound emitter(s) placed`)
	end)
end

return AudioEmitters
