--!strict
-- THE COPY's own sound. The server moves one model (tag `TLS_Copy`) and writes its
-- behaviour state to the model's `State` attribute; this controller gives it a voice on
-- every client:
--
--   presence   a low loop on its body, louder in the more dangerous states;
--   footsteps  a loop whose speed follows how fast it is moving, silent when it stands;
--   heartbeat  not positional: fades in with the player's own dread value.
--
-- So a player can hear roughly where it is and what it is doing, but only within earshot.
-- One-shot stingers (alert, attack, lost...) come from the server through AudioController.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local AudioConfig = require(Config:WaitForChild("AudioConfig"))
local GameState = require(Shared:WaitForChild("GameState"))
local Sounds = require(script.Parent.Parent:WaitForChild("Audio"):WaitForChild("Sounds"))

local COPY_TAG = "TLS_Copy"
local DREAD_ATTRIBUTE = GameState.PlayerAttribute.Dread
local SETTINGS = AudioConfig.Entity

local CopyAudioController = {}

local player = Players.LocalPlayer
local heartbeat: Sound? = nil

-- The loops are created once per model instance and found again by name, so a model that
-- leaves and re-enters the world never collects duplicates.
local function loop(root: Instance, cueName: string): Sound?
	local existing = root:FindFirstChild(cueName)
	if existing and existing:IsA("Sound") then
		return existing
	end
	return Sounds.create(cueName, root)
end

local function apply(model: Instance)
	if not model:IsA("Model") or not model.PrimaryPart then
		return
	end
	local root = model.PrimaryPart
	local state = model:GetAttribute("State")
	local settings = if type(state) == "string" then SETTINGS.States[state] else nil

	local presence = loop(root, SETTINGS.PresenceCue)
	local presenceCue = Sounds.cue(SETTINGS.PresenceCue)
	if presence and presenceCue then
		presence.Volume = presenceCue.volume * (if settings then settings.presence else 0)
		if settings and not presence.IsPlaying then
			presence:Play()
		elseif not settings and presence.IsPlaying then
			presence:Stop()
		end
	end

	local steps = loop(root, SETTINGS.FootstepsCue)
	if steps then
		local speed = if settings then settings.steps else 0
		if speed > 0 then
			steps.PlaybackSpeed = speed
			if not steps.IsPlaying then
				steps:Play()
			end
		elseif steps.IsPlaying then
			steps:Stop()
		end
	end
end

local function bind(model: Instance)
	model:GetAttributeChangedSignal("State"):Connect(function()
		apply(model)
	end)
	apply(model)
end

local function updateHeartbeat(dt: number)
	local sound = heartbeat
	local cue = Sounds.cue(SETTINGS.HeartbeatCue)
	if not sound or not cue then
		return
	end
	local dread = player:GetAttribute(DREAD_ATTRIBUTE)
	local level = if type(dread) == "number" then dread else 0
	local from = SETTINGS.HeartbeatFrom
	local target = cue.volume * math.clamp((level - from) / (1 - from), 0, 1)
	local volume = sound.Volume + math.clamp(target - sound.Volume, -dt * 0.5, dt * 0.5)
	sound.Volume = volume
	sound.PlaybackSpeed = 1 + 0.4 * level
	if volume > 0.01 and not sound.IsPlaying then
		sound:Play()
	elseif volume <= 0.01 and sound.IsPlaying then
		sound:Stop()
	end
end

function CopyAudioController.Start(_self: any)
	CollectionService:GetInstanceAddedSignal(COPY_TAG):Connect(bind)
	for _, model in CollectionService:GetTagged(COPY_TAG) do
		bind(model)
	end

	heartbeat = Sounds.create(SETTINGS.HeartbeatCue, SoundService)
	if heartbeat then
		heartbeat.Volume = 0
	end
	RunService.Heartbeat:Connect(updateHeartbeat)
end

return CopyAudioController
