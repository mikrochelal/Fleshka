--!strict
-- Scripted horror events and small environmental disturbances. Everything is decided on
-- the server, so every player sees the same thing, and nothing here blocks the mission.
--
-- Corridor sighting (once): after the radio transmission, the next time a player is in the
-- main corridor the lights there flicker and a silhouette stands at the far end. It leaves
-- after a few seconds, or as soon as someone walks toward it.
--
-- Disturbances (repeating): while THE COPY is away, the lights of a room a player is in
-- stutter briefly. How often depends on its escalation stage; before power, never.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CopyConfig = require(ReplicatedStorage.Config.CopyConfig)
local Logger = require(ReplicatedStorage.Shared.Logger)
local NetService = require(script.Parent.Parent.Services.NetService)
local SessionService = require(script.Parent.Parent.Services.SessionService)
local WorldService = require(script.Parent.Parent.Services.WorldService)
local CopyAI = require(script.Parent.CopyAI)
local FacilityLights = require(script.Parent.FacilityLights)
local Senses = require(script.Parent.CopyAI.Senses)

local FLICKER_SECONDS = 2.4
-- How far from the end wall the silhouette stands.
local END_INSET = 6
local DISTURBANCE_SECONDS = 0.9
local DISTURBANCE_CHECK = 4
local SIGHTING_RETRY_SECONDS = 8
local SIGHTING_MAX_ATTEMPTS = 12

local log = Logger.new("Horror")

local HorrorDirector = {}

local sightingArmed = false
local sightingPlayed = false
-- True while one attempt at the sighting is running.
local sightingBusy = false
local sightingAttempts = 0
local random = Random.new()

-- The end of the room's long axis that is farthest from every player.
local function farEnd(zone: BasePart): Vector3
	local size = zone.Size
	local alongX = size.X >= size.Z
	local reach = (if alongX then size.X else size.Z) / 2 - END_INSET
	local axis = if alongX then Vector3.new(reach, 0, 0) else Vector3.new(0, 0, reach)
	local floor = Vector3.new(0, -size.Y / 2, 0)

	local best, bestDistance = zone.CFrame:PointToWorldSpace(floor + axis), -1
	for _, sign in { 1, -1 } do
		local point = zone.CFrame:PointToWorldSpace(floor + axis * sign)
		local closest = math.huge
		for _, entry in Senses.livingPlayers() do
			closest = math.min(closest, (entry.root.Position - point).Magnitude)
		end
		if closest > bestDistance then
			best, bestDistance = point, closest
		end
	end
	return best
end

local function playSighting()
	if sightingPlayed or sightingBusy or not sightingArmed or not SessionService.isPlaying() then
		return
	end
	local room = CopyConfig.SightingRoom
	local zone = WorldService.getZone(room)
	if not zone then
		sightingPlayed = true
		log:warn(`Room "{room}" not found; the corridor sighting was skipped`)
		return
	end

	sightingBusy = true
	sightingAttempts += 1
	log:info(`Corridor sighting (attempt {sightingAttempts})`)
	FacilityLights.flickerRooms({ room }, FLICKER_SECONDS)
	NetService.fireAll("Effect", "Interference", FLICKER_SECONDS)
	task.wait(FLICKER_SECONDS * 0.5)

	local appeared = SessionService.isPlaying()
		and CopyAI.stageSighting(
			farEnd(zone),
			CopyConfig.SightingDuration,
			CopyConfig.SightingFleeDistance
		)
	sightingBusy = false
	if appeared then
		sightingPlayed = true
		sightingArmed = false
	elseif sightingAttempts < SIGHTING_MAX_ATTEMPTS then
		-- It was already out on another encounter: stay armed and try again shortly.
		task.delay(SIGHTING_RETRY_SECONDS, playSighting)
	else
		sightingPlayed = true
		log:warn("Corridor sighting abandoned: THE COPY was busy every time")
	end
end

-- Makes the corridor sighting ready: it plays when a player is next in the corridor, or
-- after a fallback delay if nobody goes there.
function HorrorDirector.armCorridorSighting()
	if sightingArmed or sightingPlayed then
		return
	end
	sightingArmed = true
	log:info("Corridor sighting armed")

	for _, entry in Senses.livingPlayers() do
		if WorldService.getPlayerZone(entry.player) == CopyConfig.SightingRoom then
			task.spawn(playSighting)
			return
		end
	end
	task.delay(CopyConfig.SightingFallbackSeconds, playSighting)
end

local function disturb()
	local living = Senses.livingPlayers()
	if #living == 0 then
		return
	end
	local entry = living[random:NextInteger(1, #living)]
	local room = WorldService.getPlayerZone(entry.player)
	if room then
		FacilityLights.flickerRooms({ room }, DISTURBANCE_SECONDS)
		NetService.fireAll("Sound", "DistantMetal", entry.root.Position)
	end
end

function HorrorDirector.Start(_self: any)
	WorldService.zoneEntered:Connect(function(_player: Player, room: string)
		if sightingArmed and room == CopyConfig.SightingRoom then
			playSighting()
		end
	end)

	-- Runs for the lifetime of the server; cheap (one check every few seconds).
	local lastDisturbance = os.clock()
	while true do
		task.wait(DISTURBANCE_CHECK)
		local interval = CopyAI.getStageSettings().DisturbanceInterval
		local quiet = SessionService.isPlaying() and CopyAI.getState() == "Dormant"
		if interval and quiet and os.clock() - lastDisturbance >= interval then
			lastDisturbance = os.clock()
			disturb()
		end
	end
end

return HorrorDirector
