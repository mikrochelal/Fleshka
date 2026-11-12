--!strict
-- The one way server code asks for a sound. Sounds are never created on the server: a cue
-- name from Config/AudioConfig is sent to clients, which play it locally (positional when
-- a position is given). Unknown cue names are reported once, and a cue's cooldown is
-- applied here too so a burst of events cannot flood the network.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioConfig = require(ReplicatedStorage.Config.AudioConfig)
local Logger = require(ReplicatedStorage.Shared.Logger)
local NetService = require(script.Parent.NetService)

local log = Logger.new("Audio")

local AudioService = {}

local lastBroadcast: { [string]: number } = {}
local unknown: { [string]: boolean } = {}

local function known(cue: string): boolean
	if AudioConfig.Cues[cue] then
		return true
	end
	if not unknown[cue] then
		unknown[cue] = true
		log:warn(`Unknown cue "{cue}" (add it to Config/AudioConfig)`)
	end
	return false
end

-- Plays a cue for every player: at `position` in the world, or everywhere when nil.
function AudioService.play(cue: string, position: Vector3?)
	if not known(cue) then
		return
	end
	local cooldown = AudioConfig.Cues[cue].cooldown
	local now = os.clock()
	if cooldown and now - (lastBroadcast[cue] or -math.huge) < cooldown then
		return
	end
	lastBroadcast[cue] = now
	NetService.fireAll("Sound", cue, position)
end

-- Plays a cue for one player only.
function AudioService.playFor(player: Player, cue: string, position: Vector3?)
	if known(cue) then
		NetService.fire("Sound", player, cue, position)
	end
end

return AudioService
