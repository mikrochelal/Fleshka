--!strict
-- One-shot sounds: the cues the server asks for through the `Sound` event, and the ones
-- other controllers play locally. Everything is defined in Config/AudioConfig; a cue with
-- no asset is skipped silently.
--
-- Guards against sound bugs: each cue has a cooldown, the same cue is never stacked more
-- than a few times, and the total number of one-shots playing at once is capped.
-- Ambience, emitters and THE COPY's loops live in AmbienceController and
-- CopyAudioController.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared:WaitForChild("Logger"))
local Net = require(Shared:WaitForChild("Net"))
local Sounds = require(script.Parent.Parent:WaitForChild("Audio"):WaitForChild("Sounds"))

local MAX_ONE_SHOTS = 14
local MAX_SAME_CUE = 3
-- A sound that never reports Ended (failed to load) is cleaned up after this long.
local MAX_LIFETIME = 30

local log = Logger.new("Audio")

local AudioController = {}

local lastPlayed: { [string]: number } = {}
local playing: { [string]: number } = {}
local total = 0
local reportedMissing: { [string]: boolean } = {}

-- Plays a cue: at a point in the world when a position is given, otherwise everywhere.
-- Returns whether a sound was started.
function AudioController.play(name: string, position: Vector3?): boolean
	local cue = Sounds.cue(name)
	if not cue then
		if not reportedMissing[name] then
			reportedMissing[name] = true
			log:warn(`Unknown cue "{name}"`)
		end
		return false
	end
	if cue.id == "" then
		if not reportedMissing[name] then
			reportedMissing[name] = true
			log:info(`Cue "{name}" has no audio asset yet (see ASSET_MANIFEST.md); skipped`)
		end
		return false
	end

	local now = os.clock()
	if cue.cooldown and now - (lastPlayed[name] or -math.huge) < cue.cooldown then
		return false
	end
	if total >= MAX_ONE_SHOTS or (playing[name] or 0) >= MAX_SAME_CUE then
		return false
	end

	-- A positional sound needs something in the world to sit on; the holder goes with it.
	local holder: Instance? = nil
	local parent: Instance = SoundService
	if position and cue.max then
		local attachment = Instance.new("Attachment")
		attachment.Name = "TLS_Sound"
		attachment.WorldPosition = position
		attachment.Parent = Workspace.Terrain
		holder, parent = attachment, attachment
	end
	local sound = Sounds.create(name, parent)
	if not sound then
		if holder then
			holder:Destroy()
		end
		return false
	end

	lastPlayed[name] = now
	playing[name] = (playing[name] or 0) + 1
	total += 1
	local finished = false
	local function cleanup()
		if finished then
			return
		end
		finished = true
		playing[name] = math.max(0, (playing[name] or 1) - 1)
		total = math.max(0, total - 1)
		sound:Destroy()
		if holder then
			holder:Destroy()
		end
	end
	sound.Ended:Once(cleanup)
	task.delay(MAX_LIFETIME, cleanup)
	sound:Play()
	return true
end

function AudioController.Start(_self: any)
	Net.waitForServerEvent("Sound").OnClientEvent:Connect(function(name: any, position: any)
		if type(name) == "string" then
			AudioController.play(name, if typeof(position) == "Vector3" then position else nil)
		end
	end)
end

return AudioController
