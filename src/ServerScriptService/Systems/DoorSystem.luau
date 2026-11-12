--!strict
-- Doors. Every door of the map (models tagged `TLS_Door`, with `RoomA` / `RoomB`) is open
-- and can be walked through, exactly as the map was built, unless Config/DoorConfig seals
-- it. A sealed door is made solid for the play session and can be tried (it explains why
-- it will not open); `unlock(key)` opens every door sealed with that key, for good.
--
-- Open doors react when a player walks through them: the panel slides out of sight for a
-- moment, the door is heard, and the noise is reported to NoiseService. Nothing here
-- changes the saved place: all of it is runtime state on the map's parts.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local DoorConfig = require(ReplicatedStorage.Config.DoorConfig)
local Logger = require(ReplicatedStorage.Shared.Logger)
local Text = require(ReplicatedStorage.Shared.Text)
local AudioService = require(script.Parent.Parent.Services.AudioService)
local NetService = require(script.Parent.Parent.Services.NetService)
local NoiseService = require(script.Parent.Parent.Services.NoiseService)
local WorldService = require(script.Parent.Parent.Services.WorldService)
local InteractionSystem = require(script.Parent.InteractionSystem)
local WorldProps = require(script.Parent.WorldProps)

type Door = {
	model: Model,
	panel: BasePart,
	roomA: string,
	roomB: string,
	lock: DoorConfig.Lock?,
	sealed: boolean,
	restTransparency: number,
}

local DOOR_TAG = "TLS_Door"
local INTERACTABLE_TAG = "TLS_Interactable"
local COLOR_SEALED = Color3.fromRGB(214, 62, 54)
local OPEN_TRANSPARENCY = 0.92
local PASS_SECONDS = 1.4

local log = Logger.new("Doors")

local DoorSystem = {}

local doors: { Door } = {}
local unlocked: { [string]: boolean } = {}
local lastRoom: { [Player]: string } = setmetatable({} :: any, { __mode = "k" })

local function seal(door: Door)
	door.sealed = true
	door.panel.Transparency = 0
	door.panel.CanCollide = true
	door.panel.CanQuery = true
	door.model:SetAttribute("Kind", "Door")
	door.model:SetAttribute("Id", door.model.Name)
	door.model:SetAttribute("ActionText", "INTERACTION_TRY_DOOR")
	door.model:SetAttribute("ObjectText", "OBJECT_SEALED_DOOR")
	door.model:SetAttribute("InteractEnabled", true)
	door.model:AddTag(INTERACTABLE_TAG)
	WorldProps.setLabel(door.model, Text.ref("LABEL_DOOR_SEALED"), COLOR_SEALED)
end

local function open(door: Door, announce: boolean)
	door.sealed = false
	door.panel.CanCollide = false
	door.panel.CanQuery = false
	door.panel.Transparency = door.restTransparency
	door.model:SetAttribute("InteractEnabled", false)
	WorldProps.clearLabel(door.model)
	if announce then
		local lock = door.lock
		AudioService.play(if lock and lock.heavy then "HeavyDoorOpen" else "DoorOpen", door.panel.Position)
		NoiseService.make("DoorUnlock", door.panel.Position)
		log:info(`Door opened: {door.roomA} <-> {door.roomB}`)
	end
end

-- Opens every door sealed with `key` (an objective id or a free key). Permanent, and safe
-- to call before the map is ready or more than once.
function DoorSystem.unlock(key: string)
	if unlocked[key] then
		return
	end
	unlocked[key] = true
	for _, door in doors do
		if door.sealed and door.lock and door.lock.key == key then
			open(door, true)
		end
	end
end

function DoorSystem.isUnlocked(key: string): boolean
	return unlocked[key] == true
end

local function doorBetween(roomA: string, roomB: string): Door?
	for _, door in doors do
		if
			(door.roomA == roomA and door.roomB == roomB)
			or (door.roomA == roomB and door.roomB == roomA)
		then
			return door
		end
	end
	return nil
end

-- A player walked from one room into another through an open door.
local function onPass(player: Player, door: Door)
	local position = door.panel.Position
	if not NoiseService.make("DoorPass", position, door.model) then
		return
	end
	log:info(`{player.Name} passed the door {door.roomA} <-> {door.roomB}`)
	AudioService.play("DoorOpen", position)
	local info = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(door.panel, info, { Transparency = OPEN_TRANSPARENCY }):Play()
	task.delay(PASS_SECONDS, function()
		if not door.sealed and door.panel.Parent then
			TweenService:Create(door.panel, info, { Transparency = door.restTransparency }):Play()
			AudioService.play("DoorClose", position)
		end
	end)
end

local function collect()
	for _, instance in CollectionService:GetTagged(DOOR_TAG) do
		if not instance:IsA("Model") or not instance:IsDescendantOf(Workspace) then
			continue
		end
		local panel = instance.PrimaryPart
		local roomA = instance:GetAttribute("RoomA")
		local roomB = instance:GetAttribute("RoomB")
		if not panel or type(roomA) ~= "string" or type(roomB) ~= "string" then
			continue
		end
		local door: Door = {
			model = instance,
			panel = panel,
			roomA = roomA,
			roomB = roomB,
			lock = DoorConfig.lockBetween(roomA, roomB),
			sealed = false,
			restTransparency = panel.Transparency,
		}
		table.insert(doors, door)
		if door.lock and not unlocked[door.lock.key] then
			seal(door)
		end
	end
end

function DoorSystem.Start(_self: any)
	InteractionSystem.registerKind("Door", function(player, target, _id)
		for _, door in doors do
			if door.model == target and door.sealed and door.lock then
				NetService.fire("Notify", player, Text.ref(door.lock.reason), "info")
				AudioService.play("DoorLocked", door.panel.Position)
				NoiseService.make("DoorLocked", door.panel.Position, player)
				return
			end
		end
	end)

	WorldService.zoneEntered:Connect(function(player: Player, room: string)
		local previous = lastRoom[player]
		lastRoom[player] = room
		local door = if previous then doorBetween(previous, room) else nil
		if door and not door.sealed then
			onPass(player, door)
		end
	end)

	WorldService.onReady(function()
		collect()
		local sealedCount = 0
		for _, door in doors do
			if door.sealed then
				sealedCount += 1
			end
		end
		log:info(`{#doors} door(s) found, {sealedCount} sealed`)
		if #doors == 0 then
			log:warn(`No {DOOR_TAG} models in the map: every route is open`)
		end
	end)
end

return DoorSystem
