--!strict
-- What THE COPY can perceive, and where it is allowed to appear. Everything here is a
-- read-only query of the world. The numbers behind its eyesight are in Vision.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CopyConfig = require(ReplicatedStorage.Config.CopyConfig)
local PlayerService = require(script.Parent.Parent.Parent.Services.PlayerService)
local WorldService = require(script.Parent.Parent.Parent.Services.WorldService)
local FacilityLights = require(script.Parent.Parent.FacilityLights)
local FlashlightSystem = require(script.Parent.Parent.FlashlightSystem)
local MovementSystem = require(script.Parent.Parent.MovementSystem)
local Vision = require(script.Parent.Vision)

export type Living = { player: Player, root: BasePart }
export type Seen = {
	player: Player,
	root: BasePart,
	distance: number,
	-- How fast it becomes sure of this player (multiplier on the acquire time).
	rate: number,
}

local VANTAGE_TAG = "TLS_CopyVantage"
local ZONE_TAG = "TLS_Zone"

local Senses = {}

-- Living players and their root parts.
function Senses.livingPlayers(): { Living }
	local living = {}
	for _, player in Players:GetPlayers() do
		local root = PlayerService.getAliveRoot(player)
		if root then
			table.insert(living, { player = player, root = root })
		end
	end
	return living
end

local function characters(): { Instance }
	local list: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	return list
end

-- True when nothing solid stands between the two points. Characters never block.
function Senses.clearLine(from: Vector3, to: Vector3, alsoIgnore: Instance?): boolean
	local ignore = characters()
	if alsoIgnore then
		table.insert(ignore, alsoIgnore)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	return Workspace:Raycast(from, to - from, params) == nil
end

-- The point on the floor under (or near) a position.
function Senses.ground(position: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = characters()
	local hit = Workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -30, 0), params)
	return if hit then hit.Position else position
end

-- Players it can see from `eye` while facing `facing`: inside its field of view (or very
-- close), within range for how well lit they are (multiplied by `scale`), and with nothing
-- solid in between. The raycast is only made for players who pass the cheaper checks.
function Senses.visiblePlayers(
	eye: Vector3,
	facing: Vector3,
	body: Instance,
	scale: number,
	living: { Living }
): { Seen }
	local seen: { Seen } = {}
	for _, entry in living do
		local position = entry.root.Position
		local offset = position - eye
		local distance = offset.Magnitude
		local flashlight = FlashlightSystem.isOn(entry.player)
		local room = WorldService.getPlayerZone(entry.player)
		local roomLit = room ~= nil and FacilityLights.isRoomLit(room)
		local range = Vision.range(CopyConfig, flashlight, roomLit, scale)
		if
			distance <= range
			and Vision.inView(CopyConfig, facing.X, facing.Z, offset.X, offset.Z, distance)
			and Senses.clearLine(eye, position, body)
		then
			local sprinting = MovementSystem.isSprinting(entry.player)
			table.insert(seen, {
				player = entry.player,
				root = entry.root,
				distance = distance,
				rate = Vision.rate(CopyConfig, distance, range, flashlight, roomLit, sprinting),
			})
		end
	end
	return seen
end

-- Floor positions of the map's observation markers.
function Senses.vantagePoints(): { Vector3 }
	local points: { Vector3 } = {}
	for _, marker in WorldService.getTagged(VANTAGE_TAG) do
		table.insert(points, Senses.ground(marker.Position))
	end
	return points
end

-- Floor centres of the rooms of the map in the world (map backups keep their tags and are
-- skipped).
function Senses.roomCentres(): { Vector3 }
	local points: { Vector3 } = {}
	for _, zone in CollectionService:GetTagged(ZONE_TAG) do
		if zone:IsA("BasePart") and zone:IsDescendantOf(Workspace) then
			local floor = zone.CFrame:PointToWorldSpace(Vector3.new(0, -zone.Size.Y / 2, 0))
			table.insert(points, Senses.ground(floor + Vector3.new(0, 1, 0)))
		end
	end
	return points
end

-- Places someone could be hiding: the observation points and the middle of every room.
function Senses.hidingPlaces(): { Vector3 }
	local points = Senses.vantagePoints()
	for _, centre in Senses.roomCentres() do
		table.insert(points, centre)
	end
	return points
end

-- The observation point closest to `interest` at which it may appear: far enough from
-- every player and out of every player's sight. Nil when there is none.
function Senses.pickAppearPoint(interest: Vector3): Vector3?
	local living = Senses.livingPlayers()
	local best: Vector3? = nil
	local bestDistance = math.huge
	for _, point in Senses.vantagePoints() do
		local allowed = true
		local chest = point + Vector3.new(0, 4, 0)
		for _, entry in living do
			local head = entry.root.Position + Vector3.new(0, 1.5, 0)
			if
				(entry.root.Position - point).Magnitude < CopyConfig.MinAppearDistance
				or Senses.clearLine(head, chest, nil)
			then
				allowed = false
				break
			end
		end
		local distance = (point - interest).Magnitude
		if allowed and distance < bestDistance then
			best = point
			bestDistance = distance
		end
	end
	return best
end

return Senses
