--!strict
-- The mission script. It starts the session, turns what happens in the world into
-- objective progress, and is the one place that decides what a completed objective
-- changes: THE COPY's escalation stage, which doors open, what wakes up.
--
-- The objectives, their chapters and their completion conditions are listed in
-- Config/ObjectiveConfig. The chapters' own objects live in the modules beside this file:
--
--   Relay       chapter 2: relay cabinet, fuse, feeder load puzzle
--   Signal      chapter 3: tape, trace, laboratory encounter
--   Comms       chapter 4: door code, transmitter, distress call, encounter
--   Evacuation  chapters 1 and 5: generator, ventilation, evacuation override, the lift
--   Mission     shared milestone record and helpers
--
-- Milestones are remembered when they happen early or out of order, and an objective whose
-- object does not exist on the current map is skipped, so the mission can never get stuck.
-- Progress is never taken away.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local ObjectiveConfig = require(ReplicatedStorage.Config.ObjectiveConfig)
local GameState = require(ReplicatedStorage.Shared.GameState)
local Logger = require(ReplicatedStorage.Shared.Logger)
local ObjectiveService = require(script.Parent.Parent.Services.ObjectiveService)
local PlayerService = require(script.Parent.Parent.Services.PlayerService)
local SessionService = require(script.Parent.Parent.Services.SessionService)
local WorldService = require(script.Parent.Parent.Services.WorldService)
local CopyAI = require(script.Parent.CopyAI)
local DocumentSystem = require(script.Parent.DocumentSystem)
local DoorSystem = require(script.Parent.DoorSystem)
local HorrorDirector = require(script.Parent.HorrorDirector)
local PowerSystem = require(script.Parent.PowerSystem)
local RadioSystem = require(script.Parent.RadioSystem)
local WorldProps = require(script.Parent.WorldProps)
local Comms = require(script.Comms)
local Evacuation = require(script.Evacuation)
local Mission = require(script.Mission)
local Relay = require(script.Relay)
local Signal = require(script.Signal)

type ZoneGoal = { id: string, rooms: { string }, after: string? }

local SPAWN_TAG = "TLS_Spawn"
-- Objectives completed by being somewhere. `after` is the objective that must be complete
-- first (walking through the room earlier does not count).
local ZONE_GOALS: { ZoneGoal } = {
	{ id = "FindPowerControls", rooms = { "B_PowerRoom" } },
	{
		id = "EscapeLaboratory",
		rooms = { "B_NorthCorridor", "B_Junction", "B_ServiceTunnel", "F_ArchiveCorridor" },
		after = "TraceSignal",
	},
	{
		id = "EscapeCommCenter",
		rooms = { "B_SouthCorridor", "B_Junction", "G_ServiceCorridor" },
		after = "SendDistress",
	},
	{ id = "ReachObservation", rooms = { "H_ObservationChamber" }, after = "RestoreFreightCircuit" },
}

local log = Logger.new("Slice")

local SliceDirector = {}

-- The rooms players start in; standing in any other room means they have entered.
local function startRooms(): { [string]: boolean }
	local rooms: { [string]: boolean } = {}
	for _, marker in WorldService.getTagged(SPAWN_TAG) do
		local room = WorldService.zoneAt(marker.Position)
		if room then
			rooms[room] = true
		end
	end
	return rooms
end

-- Checks the milestones that depend on where players are.
local function evaluateZones()
	if not SessionService.isPlaying() then
		return
	end
	local start = startRooms()
	for _, player in Players:GetPlayers() do
		local room = WorldService.getPlayerZone(player)
		if not room or not PlayerService.getAliveRoot(player) then
			continue
		end
		if not start[room] then
			Mission.mark("EnterStation")
		end
		for _, goal in ZONE_GOALS do
			if
				table.find(goal.rooms, room)
				and (goal.after == nil or ObjectiveService.isCompleted(goal.after))
			then
				Mission.reach(goal.id)
			end
		end
	end
end

local function chapterOf(id: string?): number?
	for _, objective in ObjectiveConfig.List do
		if objective.id == id then
			return objective.chapter
		end
	end
	return nil
end

local function onObjectiveCompleted(id: string, nextId: string?)
	log:info(`Objective state: {id} complete -> {nextId or "mission complete"}`)
	for _, objective in ObjectiveConfig.List do
		if objective.id == id and objective.stage then
			CopyAI.setStage(objective.stage)
		end
	end
	-- Doors sealed with this objective as their key open now (Config/DoorConfig).
	DoorSystem.unlock(id)
	if id == "RouteRelayPower" then
		RadioSystem.wake()
	end

	local chapter, nextChapter = chapterOf(id), chapterOf(nextId)
	if chapter and nextChapter and nextChapter ~= chapter then
		log:info(
			`Chapter {nextChapter} begins; checkpoint: {ObjectiveConfig.Chapters[nextChapter].checkpoint}`
		)
	end
	if nextId == nil then
		-- Every objective is complete (the last one may have been skipped on an old map).
		task.defer(Evacuation.finish)
	else
		-- A room-based objective may already be satisfied where the players stand.
		task.defer(evaluateZones)
	end
end

local function anyPlayerReady(): boolean
	for _, player in Players:GetPlayers() do
		local data = PlayerService.getData(player)
		if data and data.ready then
			return true
		end
	end
	return false
end

-- Lobby -> Loading -> Intro -> Playing, once the map and a player are there.
local function autoStart()
	while not anyPlayerReady() do
		task.wait(0.5)
	end
	if SessionService.getPhase() ~= GameState.Phase.Lobby then
		return
	end
	SessionService.setPhase(GameState.Phase.Loading)
	task.wait(GameConfig.LoadingSeconds)
	SessionService.setPhase(GameState.Phase.Intro)
	task.wait(GameConfig.IntroSeconds)
	SessionService.setPhase(GameState.Phase.Playing)
end

-- Objectives whose objects are missing from this map are skipped rather than blocking.
local function skipImpossible()
	for _, objective in ObjectiveConfig.List do
		for _, prop in objective.props or {} do
			if not WorldProps.get(prop) then
				Mission.mark(objective.id)
				log:warn(
					`Objective {objective.id} will be skipped: this map has no "{prop}". `
						.. "Regenerate the map to get the full station (docs/MAP_GENERATOR.md)."
				)
				break
			end
		end
	end
end

function SliceDirector.Start(_self: any)
	Mission.Init()
	Relay.start()
	Signal.start()
	Comms.start()
	Evacuation.start()

	ObjectiveService.completed:Connect(onObjectiveCompleted)
	WorldService.zoneEntered:Connect(evaluateZones)
	SessionService.phaseChanged:Connect(function(phase: GameState.Phase)
		if phase == GameState.Phase.Playing then
			evaluateZones()
			Mission.reconcile()
		end
	end)

	DocumentSystem.opened:Connect(function(_player: Player, id: string)
		if id == "IncidentLog" then
			Mission.mark("ReadIncidentLog")
		end
	end)
	PowerSystem.controlsUsed:Connect(function()
		Mission.reach("FindPowerControls")
	end)
	PowerSystem.restored:Connect(function()
		Mission.reach("RestorePower")
	end)
	RadioSystem.finished:Connect(function()
		Mission.reach("InvestigateRadio")
		HorrorDirector.armCorridorSighting()
	end)

	WorldService.onReady(function()
		WorldProps.ensure()
		skipImpossible()
		Relay.ready()
		Signal.ready()
		Comms.ready()
		Evacuation.ready()
		log:info(`Mission ready: {#ObjectiveConfig.List} objectives in {#ObjectiveConfig.Chapters} chapters`)
		if GameConfig.AutoStartSession then
			autoStart()
		end
	end)
end

return SliceDirector
