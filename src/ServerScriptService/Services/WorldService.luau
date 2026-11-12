--!strict
-- The game's only view of the Studio-built map. Everything is found through
-- CollectionService tags, never through fixed Workspace paths, so the map can be
-- regenerated or rearranged without touching game code.
--
--   TLS_Zone   invisible box around a room; attribute `ZoneId` is the room name. Its parent
--              is the room folder (Floor, Walls, Lights, Props...).
--   TLS_Spawn  spawn marker.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Logger = require(ReplicatedStorage.Shared.Logger)
local Signal = require(ReplicatedStorage.Shared.Signal)

local ZONE_TAG = "TLS_Zone"
local SPAWN_TAG = "TLS_Spawn"
local RUNTIME_FOLDER = "TLS_Runtime"
local TRACK_INTERVAL = 0.25

local log = Logger.new("WorldService")

local WorldService = {}

-- Fired with (player: Player, roomName: string) when a living player walks into a room.
WorldService.zoneEntered = Signal.new()

local zones: { [string]: BasePart } = {}
local ready = false
local waiting: { () -> () } = {}
local playerZone: { [Player]: string } = setmetatable({} :: any, { __mode = "k" })

-- Tagged parts that are really in the world (backups in ServerStorage keep their tags).
function WorldService.getTagged(tag: string): { BasePart }
	local found: { BasePart } = {}
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("BasePart") and instance:IsDescendantOf(Workspace) then
			table.insert(found, instance)
		end
	end
	return found
end

local function scan(): boolean
	table.clear(zones)
	for _, zone in WorldService.getTagged(ZONE_TAG) do
		local id = zone:GetAttribute("ZoneId")
		if type(id) == "string" then
			zones[id] = zone
		end
	end
	return next(zones) ~= nil and #WorldService.getTagged(SPAWN_TAG) > 0
end

function WorldService.isReady(): boolean
	return ready
end

-- Runs the callback once the map has been found (immediately if it already was).
function WorldService.onReady(callback: () -> ())
	if ready then
		task.spawn(callback)
	else
		table.insert(waiting, callback)
	end
end

function WorldService.getZone(roomName: string): BasePart?
	return zones[roomName]
end

-- The folder holding a room's Floor, Walls, Lights and Props.
function WorldService.getRoomFolder(roomName: string): Instance?
	local zone = zones[roomName]
	return if zone then zone.Parent else nil
end

local function contains(zone: BasePart, position: Vector3): boolean
	local offset = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(offset.X) <= half.X
		and math.abs(offset.Y) <= half.Y
		and math.abs(offset.Z) <= half.Z
end

-- Name of the room containing the position, or nil when it is outside every room.
function WorldService.zoneAt(position: Vector3): string?
	for name, zone in zones do
		if contains(zone, position) then
			return name
		end
	end
	return nil
end

-- Point on a room's floor: `offset` is measured from the room's centre.
function WorldService.floorPoint(roomName: string, offset: Vector3?): Vector3?
	local zone = zones[roomName]
	if not zone then
		return nil
	end
	local local_ = Vector3.new(0, -zone.Size.Y / 2, 0) + (offset or Vector3.zero)
	return zone.CFrame:PointToWorldSpace(local_)
end

-- Folder for everything the game creates in the world while it runs. It exists only
-- during play, so nothing created here is ever saved into the place.
function WorldService.runtimeFolder(): Instance
	local folder = Workspace:FindFirstChild(RUNTIME_FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = RUNTIME_FOLDER
		folder.Parent = Workspace
	end
	return folder :: Instance
end

local function trackPlayers()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = humanoid and humanoid.RootPart
		if humanoid and root and humanoid.Health > 0 then
			local zone = WorldService.zoneAt(root.Position)
			if zone and zone ~= playerZone[player] then
				playerZone[player] = zone
				WorldService.zoneEntered:Fire(player, zone)
			end
		end
	end
end

function WorldService.getPlayerZone(player: Player): string?
	return playerZone[player]
end

function WorldService.Start(_self: any)
	local waited = 0
	while not scan() do
		if waited == 10 or (waited > 10 and waited % 60 == 0) then
			log:warn(
				"No STATION-09 map found (no TLS_Zone / TLS_Spawn tagged parts in Workspace). "
					.. "Generate it in Studio: see docs/MAP_GENERATOR.md. Gameplay is waiting."
			)
		end
		task.wait(1)
		waited += 1
	end

	ready = true
	local count = 0
	for _ in zones do
		count += 1
	end
	log:info(`Map found: {count} rooms`)

	local callbacks = waiting
	waiting = {}
	for _, callback in callbacks do
		task.spawn(callback)
	end

	-- Runs for the lifetime of the server.
	while true do
		task.wait(TRACK_INTERVAL)
		trackPlayers()
	end
end

return WorldService
