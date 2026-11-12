--!strict
-- The sound of the station itself. Everything is described in Config/AudioConfig.
--
--   Layers     non-positional loops mixed by where the player is and what state the
--              station is in: a base room tone, the layers that come alive when emergency
--              power returns (a facility-wide transition), and one room layer chosen from
--              the room the player stands in. Layers cross-fade; none restarts.
--   Emitters   positional loops at the parts the server tags `TLS_AudioEmitter`
--              (generator, fans, the receiver's static...). A loop exists only while its
--              emitter is active and near enough to be heard.
--   Random     occasional distant noises from a random direction.
--
-- Runs entirely on this client, so each player hears their own position and nothing is
-- replicated. Layers without an audio asset are skipped silently.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local AudioConfig = require(Config:WaitForChild("AudioConfig"))
local GameState = require(Shared:WaitForChild("GameState"))
local Logger = require(Shared:WaitForChild("Logger"))
local Sounds = require(script.Parent.Parent:WaitForChild("Audio"):WaitForChild("Sounds"))
local AudioController = require(script.Parent:WaitForChild("AudioController"))
local SessionController = require(script.Parent:WaitForChild("SessionController"))

type Layer = { sound: Sound, base: number, target: number }

local EMITTER_TAG = "TLS_AudioEmitter"
local EMITTER_CHECK = 0.5
local ROOM_ATTRIBUTE = GameState.PlayerAttribute.Room

local log = Logger.new("Audio")

local AmbienceController = {}

local player = Players.LocalPlayer
local random = Random.new()
local layers: { [string]: Layer } = {}
local emitterSounds: { [Instance]: Sound } = {}
local active = false

local function layer(name: string): Layer?
	local existing = layers[name]
	if existing then
		return existing
	end
	local sound = Sounds.create(name, SoundService)
	if not sound then
		return nil
	end
	local created: Layer = { sound = sound, base = sound.Volume, target = 0 }
	sound.Volume = 0
	layers[name] = created
	return created
end

local function powered(): boolean
	return ReplicatedStorage:GetAttribute(GameState.POWER_ATTRIBUTE) == true
end

-- Decides how loud every layer should be right now.
local function retarget()
	for _, entry in layers do
		entry.target = 0
	end
	if not active then
		return
	end
	local function want(name: string, scale: number)
		local entry = layer(name)
		if entry then
			entry.target = math.max(entry.target, entry.base * scale)
		end
	end

	for _, name in AudioConfig.Ambient.Base do
		want(name, 1)
	end
	if powered() then
		for _, name in AudioConfig.Ambient.Powered do
			want(name, 1)
		end
	end

	local room = player:GetAttribute(ROOM_ATTRIBUTE)
	if type(room) == "string" and room ~= "" then
		local ambience = AudioConfig.Ambient.Rooms[room]
			or AudioConfig.Ambient.Areas[string.sub(room, 1, 1)]
		if ambience and (not ambience.needsPower or powered()) then
			want(ambience.cue, ambience.volume)
		end
	end
end

local function fade(dt: number)
	local step = dt / AudioConfig.Ambient.FadeSeconds
	for _, entry in layers do
		local sound = entry.sound
		local volume = sound.Volume
		if volume ~= entry.target then
			local change = math.max(entry.base, 0.05) * step
			volume = if volume < entry.target
				then math.min(entry.target, volume + change)
				else math.max(entry.target, volume - change)
			sound.Volume = volume
		end
		-- A silent layer is paused rather than left running.
		if volume > 0 and not sound.IsPlaying then
			sound:Play()
		elseif volume <= 0 and sound.IsPlaying then
			sound:Stop()
		end
	end
end

local function listenerPosition(): Vector3?
	local camera = Workspace.CurrentCamera
	return if camera then camera.CFrame.Position else nil
end

local function updateEmitters()
	local position = listenerPosition()
	for _, emitter in CollectionService:GetTagged(EMITTER_TAG) do
		if not emitter:IsA("BasePart") then
			continue
		end
		local cueName = emitter:GetAttribute("Cue")
		local cue = if type(cueName) == "string" then Sounds.cue(cueName) else nil
		local wanted = active
			and cue ~= nil
			and position ~= nil
			and emitter:GetAttribute("Active") == true
			and (emitter.Position - position).Magnitude <= (cue.max or 100) * 1.15
		local sound = emitterSounds[emitter]

		if wanted and cue and type(cueName) == "string" then
			if not sound then
				local created = Sounds.create(cueName, emitter)
				if created then
					created:Play()
					emitterSounds[emitter] = created
					sound = created
				end
			end
			if sound then
				local intensity = emitter:GetAttribute("Intensity")
				sound.Volume = cue.volume * (if type(intensity) == "number" then intensity else 1)
			end
		elseif sound then
			sound:Destroy()
			emitterSounds[emitter] = nil
		end
	end
	-- Emitters that left the world take their sounds with them.
	for emitter in emitterSounds do
		if not emitter:IsDescendantOf(Workspace) then
			emitterSounds[emitter] = nil
		end
	end
end

local function randomNoises()
	local settings = AudioConfig.Ambient.Random
	while true do
		task.wait(random:NextNumber(settings.MinInterval, settings.MaxInterval))
		local position = listenerPosition()
		if active and position and #settings.Cues > 0 then
			local angle = random:NextNumber(0, math.pi * 2)
			local distance = random:NextNumber(settings.MinDistance, settings.MaxDistance)
			AudioController.play(
				settings.Cues[random:NextInteger(1, #settings.Cues)],
				position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance
			)
		end
	end
end

function AmbienceController.Start(_self: any)
	local function onPhase(phase: GameState.Phase)
		-- The finale keeps only what the ending itself plays.
		active = phase == GameState.Phase.Playing
		retarget()
	end
	SessionController.phaseChanged:Connect(onPhase)
	onPhase(SessionController.getPhase())

	player:GetAttributeChangedSignal(ROOM_ATTRIBUTE):Connect(retarget)
	ReplicatedStorage:GetAttributeChangedSignal(GameState.POWER_ATTRIBUTE):Connect(function()
		if powered() then
			log:info("Emergency power: station ambience fading in")
		end
		retarget()
	end)

	local sinceCheck = 0
	RunService.Heartbeat:Connect(function(dt)
		fade(dt)
		sinceCheck += dt
		if sinceCheck >= EMITTER_CHECK then
			sinceCheck = 0
			updateEmitters()
		end
	end)
	task.spawn(randomNoises)

	local available, missing = 0, 0
	for name in AudioConfig.Cues do
		if Sounds.available(name) then
			available += 1
		else
			missing += 1
		end
	end
	log:info(`Audio ready: {available} cue(s) with assets, {missing} placeholder(s) without`)
end

return AmbienceController
