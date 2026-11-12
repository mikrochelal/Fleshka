--!strict
-- Puts characters into the station. The spawn point is the map's `TLS_Spawn` marker; the
-- height comes from the real floor under it (found by raycast, with the room's Floor part
-- as a fallback), so nothing here depends on fixed coordinates or folder types.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PlayerConfig = require(ReplicatedStorage.Config.PlayerConfig)
local Logger = require(ReplicatedStorage.Shared.Logger)
local PlayerService = require(script.Parent.Parent.Services.PlayerService)
local WorldService = require(script.Parent.Parent.Services.WorldService)

local SPAWN_TAG = "TLS_Spawn"
local ROOT_TIMEOUT = 15

local log = Logger.new("Spawn")

local SpawnSystem = {}

local slots: { [Player]: number } = setmetatable({} :: any, { __mode = "k" })
local nextSlot = 0

local function slotOffset(player: Player): Vector3
	local slot = slots[player]
	if not slot then
		slot = nextSlot % #PlayerConfig.SpawnSlots + 1
		nextSlot += 1
		slots[player] = slot
	end
	return PlayerConfig.SpawnSlots[slot]
end

-- Height of the walkable surface under a point inside a room.
local function floorHeight(position: Vector3): number?
	local characters: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(characters, player.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = characters

	local hit = Workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -40, 0), params)
	if hit then
		return hit.Position.Y
	end

	-- Fallback: the Floor part of the room the point is in.
	local roomName = WorldService.zoneAt(position)
	local folder = roomName and WorldService.getRoomFolder(roomName)
	local floor = folder and folder:FindFirstChild("Floor")
	if floor and floor:IsA("BasePart") then
		return floor.Position.Y + floor.Size.Y / 2
	end
	return nil
end

local function startMarker(): BasePart?
	local markers = WorldService.getTagged(SPAWN_TAG)
	for _, marker in markers do
		if marker:GetAttribute("Checkpoint") == "Start" then
			return marker
		end
	end
	return markers[1]
end

-- Standing position at `point`, shifted by the player's slot when the shifted spot is
-- still inside the same room (never inside a wall or outside the station).
local function standingCFrame(player: Player, point: Vector3, faceRoom: string?): CFrame?
	local room = WorldService.zoneAt(point)
	local shifted = point + slotOffset(player)
	if room == nil or WorldService.zoneAt(shifted) ~= room then
		shifted = point
	end
	local floorY = floorHeight(shifted)
	if not floorY then
		return nil
	end
	local position = Vector3.new(shifted.X, floorY + PlayerConfig.SpawnDropHeight, shifted.Z)

	local faceZone = faceRoom and WorldService.getZone(faceRoom)
	if faceZone then
		local target = Vector3.new(faceZone.Position.X, position.Y, faceZone.Position.Z)
		if (target - position).Magnitude > 1 then
			return CFrame.lookAt(position, target)
		end
	end
	return CFrame.new(position)
end

local function moveCharacter(player: Player, character: Model, cframe: CFrame): boolean
	local root = character:WaitForChild("HumanoidRootPart", ROOT_TIMEOUT)
	if not root or not root:IsA("BasePart") or player.Character ~= character then
		return false
	end
	-- With instance streaming the destination must be loaded on the client first.
	pcall(function()
		player:RequestStreamAroundAsync(cframe.Position, 5)
	end)
	if player.Character ~= character or not character:IsDescendantOf(Workspace) then
		return false
	end
	character:PivotTo(cframe)
	root.AssemblyLinearVelocity = Vector3.zero
	return true
end

-- Places the player's current character at the station entrance.
function SpawnSystem.placeAtStart(player: Player): boolean
	local character = player.Character
	local marker = startMarker()
	if not character or not marker then
		return false
	end
	local cframe = standingCFrame(player, marker.Position, PlayerConfig.SpawnFacingRoom)
	if not cframe then
		log:warn(`No floor found under spawn marker {marker:GetFullName()}`)
		return false
	end
	return moveCharacter(player, character, cframe)
end

-- Places the player's current character in the middle of a room; falls back to the
-- entrance when the room does not exist.
function SpawnSystem.placeInRoom(player: Player, roomName: string): boolean
	local character = player.Character
	local point = WorldService.floorPoint(roomName, Vector3.new(0, 3, 0))
	if character and point then
		local cframe = standingCFrame(player, point, nil)
		if cframe then
			return moveCharacter(player, character, cframe)
		end
	end
	return SpawnSystem.placeAtStart(player)
end

function SpawnSystem.Start(_self: any)
	PlayerService.observePlayers(function(player)
		-- Shift is the sprint key, so it must not toggle the mouse lock.
		player.DevEnableMouseLock = false
	end)

	PlayerService.observeCharacters(function(player, character)
		WorldService.onReady(function()
			if player.Character ~= character then
				return
			end
			if SpawnSystem.placeAtStart(player) then
				log:info(`{player.Name} placed at the station entrance`)
			else
				log:warn(`Could not place {player.Name} in the station`)
			end
		end)
	end)
end

return SpawnSystem
