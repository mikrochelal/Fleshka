--!strict
-- Creates Sound instances from Config/AudioConfig. The one place on the client that knows
-- how a cue becomes a Sound: asset id, volume, speed, roll-off and mixer group. A cue with
-- no asset id returns nil, so callers skip it without any special case.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = ReplicatedStorage:WaitForChild("Config")
local AudioConfig = require(Config:WaitForChild("AudioConfig"))

local GROUP_PREFIX = "TLS_"

local Sounds = {}

local groups: { [string]: SoundGroup } = {}

-- The mixer group for a cue group name, created once under SoundService.
function Sounds.group(name: string): SoundGroup
	local known = groups[name]
	if known then
		return known
	end
	local existing = SoundService:FindFirstChild(GROUP_PREFIX .. name)
	local group: SoundGroup
	if existing and existing:IsA("SoundGroup") then
		group = existing
	else
		group = Instance.new("SoundGroup")
		group.Name = GROUP_PREFIX .. name
		group.Parent = SoundService
	end
	group.Volume = AudioConfig.Groups[name] or 1
	groups[name] = group
	return group
end

function Sounds.cue(name: string): AudioConfig.Cue?
	return AudioConfig.Cues[name]
end

-- True when the cue exists and has an asset.
function Sounds.available(name: string): boolean
	local cue = AudioConfig.Cues[name]
	return cue ~= nil and cue.id ~= ""
end

-- A configured, unparented-safe Sound for the cue under `parent`; nil when the cue is
-- unknown or has no asset yet. Positional settings apply when the parent is a part or an
-- attachment and the cue defines `max`.
function Sounds.create(name: string, parent: Instance): Sound?
	local cue = AudioConfig.Cues[name]
	if not cue or cue.id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = cue.id
	sound.Volume = cue.volume
	sound.PlaybackSpeed = cue.speed or 1
	sound.Looped = cue.looped == true
	sound.SoundGroup = Sounds.group(cue.group)
	if cue.max then
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = cue.min or 10
		sound.RollOffMaxDistance = cue.max
	end
	sound.Parent = parent
	return sound
end

return Sounds
