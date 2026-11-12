--!strict
-- Plays the sounds named in Config/AudioConfig. A cue whose asset id is empty is skipped
-- without any warning, so the game runs correctly before audio assets have been chosen.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local AudioConfig = require(Config:WaitForChild("AudioConfig"))
local GameState = require(Shared:WaitForChild("GameState"))
local Net = require(Shared:WaitForChild("Net"))
local SessionController = require(script.Parent:WaitForChild("SessionController"))

local AudioController = {}

local ambient: { Sound } = {}

local function newSound(cue: AudioConfig.Cue, parent: Instance): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = cue.id
	sound.Volume = cue.volume
	sound.Looped = cue.looped == true
	if cue.rollOff then
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMaxDistance = cue.rollOff
	end
	sound.Parent = parent
	return sound
end

-- Plays a cue: at a point in the world when a position is given, otherwise everywhere.
function AudioController.play(name: string, position: Vector3?)
	local cue = AudioConfig.Cues[name]
	if not cue or cue.id == "" then
		return
	end

	if position then
		-- A sound needs a part to be positional; the holder removes itself afterwards.
		local holder = Instance.new("Attachment")
		holder.WorldPosition = position
		holder.Parent = Workspace.Terrain
		newSound(cue, holder):Play()
		Debris:AddItem(holder, 20)
	else
		local sound = newSound(cue, SoundService)
		sound.Ended:Once(function()
			sound:Destroy()
		end)
		sound:Play()
	end
end

local function setAmbient(playing: boolean)
	if playing and #ambient == 0 then
		for _, cue in AudioConfig.Ambient do
			if cue.id ~= "" then
				local sound = newSound(cue, SoundService)
				sound:Play()
				table.insert(ambient, sound)
			end
		end
	elseif not playing then
		for _, sound in ambient do
			sound:Destroy()
		end
		table.clear(ambient)
	end
end

function AudioController.Start(_self: any)
	Net.waitForServerEvent("Sound").OnClientEvent:Connect(function(name: any, position: any)
		if type(name) == "string" then
			AudioController.play(name, if typeof(position) == "Vector3" then position else nil)
		end
	end)

	local function onPhase(phase: GameState.Phase)
		setAmbient(phase == GameState.Phase.Playing or phase == GameState.Phase.Finale)
	end
	SessionController.phaseChanged:Connect(onPhase)
	onPhase(SessionController.getPhase())
end

return AudioController
