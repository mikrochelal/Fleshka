--!strict
-- What players see and hear when THE COPY does something: sound cues (through
-- AudioService, played at its position), screen effects, lights and the two notifications.
-- Its looping body sounds are not played here: clients attach them to the model from its
-- "State" attribute. Text is sent as localization references, never as sentences.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CopyConfig = require(ReplicatedStorage.Config.CopyConfig)
local Text = require(ReplicatedStorage.Shared.Text)
local AudioService = require(script.Parent.Parent.Parent.Services.AudioService)
local NetService = require(script.Parent.Parent.Parent.Services.NetService)
local WorldService = require(script.Parent.Parent.Parent.Services.WorldService)
local FacilityLights = require(script.Parent.Parent.FacilityLights)
local SpawnSystem = require(script.Parent.Parent.SpawnSystem)

-- The screen is already black when a caught player is moved.
local BLACKOUT_SECONDS = 3
local CAUGHT_MOVE_DELAY = 0.8

local Reactions = {}

local random = Random.new()

-- It came into the world. An unscripted arrival is sometimes hinted at from afar.
function Reactions.appeared(position: Vector3, scripted: boolean)
	AudioService.play("Whoosh", position)
	if scripted or random:NextNumber() < CopyConfig.DistantCueChance then
		AudioService.play("CopyDistant", position)
	end
end

function Reactions.vanishing(position: Vector3)
	AudioService.play("Whoosh", position)
end

-- Tells one player that it is now after them.
function Reactions.noticed(player: Player)
	NetService.fire("Notify", player, Text.ref("NOTIFY_COPY_SEEN"), "warning")
end

-- The stand-still warning before a chase: everyone gets interference and the alert, the
-- lights of its room flicker, and the player it noticed is told.
function Reactions.pursuitWarning(position: Vector3, player: Player?, seconds: number)
	if player then
		Reactions.noticed(player)
	end
	NetService.fireAll("Effect", "Interference", seconds)
	AudioService.play("CopyAlert", position)
	local room = WorldService.zoneAt(position + Vector3.new(0, 3, 0))
	if room then
		FacilityLights.flickerRooms({ room }, seconds)
	end
end

function Reactions.attack(position: Vector3)
	AudioService.play("CopyAttack", position)
end

function Reactions.lostTarget(position: Vector3)
	AudioService.play("CopyLost", position)
end

-- A search is announced only some of the time, so encounters are not predictable.
function Reactions.searching(position: Vector3)
	if random:NextNumber() < CopyConfig.SearchCueChance then
		AudioService.play("CopySearch", position)
	end
end

function Reactions.finalPursuit()
	AudioService.play("CopyFinal")
end

-- The attack connected: blackout, then the player wakes up at the chapter's checkpoint.
function Reactions.caught(player: Player)
	NetService.fire("Effect", player, "Blackout", BLACKOUT_SECONDS)
	AudioService.playFor(player, "Caught")
	local who: Text.Params = { name = player.DisplayName }
	NetService.fireAll("Notify", Text.ref("NOTIFY_PLAYER_TAKEN", who), "warning")
	task.delay(CAUGHT_MOVE_DELAY, function()
		if player.Parent == Players then
			SpawnSystem.placeAtCheckpoint(player)
		end
	end)
end

return Reactions
