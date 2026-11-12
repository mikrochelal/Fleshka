--!strict
-- The mission script. It starts the session, turns what happens in the world into
-- objective progress, raises THE COPY's escalation stage as objectives are completed, and
-- owns the objects that belong to the mission itself.
--
--   Objective          Completed when                                  THE COPY becomes
--   EnterStation       a player leaves the elevator room
--   FindPowerControls  a player reaches the power room or a breaker
--   RestorePower       the power puzzle is solved                      Aware
--   RestoreSystems     the switchgear in Electrical Control is used    (radio wakes)
--   InvestigateRadio   the transmission has been heard to the end      Hunting
--   TraceSignal        the analysis console has traced the source      Hostile
--   ReachCommCenter    the central computer recalls the elevator       FinalPursuit
--   Escape             a player uses the recalled elevator
--
-- Milestones are remembered when they happen early or out of order, and an objective whose
-- object does not exist on the current map is skipped, so the mission can never get stuck.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local ObjectiveConfig = require(ReplicatedStorage.Config.ObjectiveConfig)
local GameState = require(ReplicatedStorage.Shared.GameState)
local Logger = require(ReplicatedStorage.Shared.Logger)
local Transmissions = require(script.Parent.Parent.Data.Transmissions)
local NetService = require(script.Parent.Parent.Services.NetService)
local NoiseService = require(script.Parent.Parent.Services.NoiseService)
local ObjectiveService = require(script.Parent.Parent.Services.ObjectiveService)
local PlayerService = require(script.Parent.Parent.Services.PlayerService)
local SessionService = require(script.Parent.Parent.Services.SessionService)
local WorldService = require(script.Parent.Parent.Services.WorldService)
local CopyAI = require(script.Parent.CopyAI)
local HorrorDirector = require(script.Parent.HorrorDirector)
local InteractionSystem = require(script.Parent.InteractionSystem)
local PowerSystem = require(script.Parent.PowerSystem)
local RadioSystem = require(script.Parent.RadioSystem)
local WorldProps = require(script.Parent.WorldProps)

-- Reaching this room counts as finding the power controls.
local POWER_ROOM = "B_PowerRoom"
local SPAWN_TAG = "TLS_Spawn"
local RECALL_NOISE_RADIUS = 400
local COLOR_ONLINE = Color3.fromRGB(70, 170, 120)

-- Completing an objective raises THE COPY to this stage.
local STAGE_AFTER: { [string]: string } = {
	RestorePower = "Aware",
	InvestigateRadio = "Hunting",
	TraceSignal = "Hostile",
	ReachCommCenter = "FinalPursuit",
}
-- Objectives that need an object from the expanded map (layout v4). On an older map the
-- object is missing and the objective is skipped.
local REQUIRED_PROP: { [string]: string } = {
	RestoreSystems = "Switchgear",
	TraceSignal = "AnalysisConsole",
}

local log = Logger.new("Slice")

local SliceDirector = {}

local startedAt = 0
local finishing = false
local tracing = false
-- Milestones that have happened, by objective id.
local reached: { [string]: boolean } = {}
local skipped: { [string]: boolean } = {}

local function notify(player: Player, text: string, kind: string)
	NetService.fire("Notify", player, text, kind)
end

-- Completes the current objective for as long as its milestone has been reached.
local function reconcile()
	if not SessionService.isPlaying() then
		return
	end
	local current = ObjectiveService.currentId()
	while current and (reached[current] or skipped[current]) do
		ObjectiveService.complete(current)
		current = ObjectiveService.currentId()
	end
end

-- Records a milestone. Each one physically requires the ones before it (no power without
-- entering the station, no transmission without power), so they count as reached too.
local function reach(id: string)
	for _, objective in ObjectiveConfig.List do
		reached[objective.id] = true
		if objective.id == id then
			break
		end
	end
	reconcile()
end

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
		if room == POWER_ROOM then
			reach("FindPowerControls")
		elseif room and not start[room] then
			reach("EnterStation")
		end
	end
end

local function onObjectiveCompleted(id: string, nextId: string?)
	log:info(`Objective state: {id} complete -> {nextId or "mission complete"}`)
	if id == "RestoreSystems" then
		RadioSystem.wake()
	end
	local stage = STAGE_AFTER[id]
	if stage then
		CopyAI.setStage(stage)
	end
end

local function onSwitchgear(player: Player, target: Instance, _id: string)
	if not SessionService.isPlaying() then
		return
	end
	if not PowerSystem.isOn() then
		notify(player, "The switchgear is dead. Restore emergency power first.", "info")
	elseif ObjectiveService.isCompleted("RestoreSystems") then
		notify(player, "The communications relay is already online.", "info")
	else
		log:info(`{player.Name} switched the communications relay on`)
		local part = WorldProps.partOf(target)
		if part then
			part.Color = COLOR_ONLINE
			WorldProps.setLabel(target, "COMMS RELAY\nONLINE", COLOR_ONLINE)
			NetService.fireAll("Sound", "Machinery", part.Position)
		end
		NetService.fireAll("Notify", "Communications relay online.", "info")
		reach("RestoreSystems")
	end
end

local function onAnalysis(player: Player, target: Instance, _id: string)
	if not SessionService.isPlaying() or tracing then
		return
	end
	if not ObjectiveService.isCompleted("InvestigateRadio") then
		notify(player, "The console shows only noise. There is nothing to trace yet.", "info")
	elseif ObjectiveService.isCompleted("TraceSignal") then
		notify(
			player,
			"Trace complete: the source is beneath the station. It is answering.",
			"info"
		)
	else
		tracing = true
		log:info(`{player.Name} started the signal trace`)
		local part = WorldProps.partOf(target)
		local position = if part then part.Position else nil
		RadioSystem.play(
			Transmissions.Trace,
			position,
			if position then WorldService.zoneAt(position) else nil
		)
		reach("TraceSignal")
	end
end

local function onConsole(player: Player, target: Instance, _id: string)
	if not SessionService.isPlaying() then
		return
	end
	if not PowerSystem.isOn() then
		notify(player, "The console is dead. The station has no power.", "info")
	elseif ObjectiveService.isActive("ReachCommCenter") then
		log:info(`{player.Name} recalled the elevator`)
		NetService.fireAll(
			"Notify",
			"Recall signal sent. The elevator is on its way down. Something heard it.",
			"warning"
		)
		local panel = WorldProps.get("ElevatorPanel")
		if panel then
			panel:SetAttribute("InteractEnabled", true)
		end
		reach("ReachCommCenter")
		-- The recall is loud: it comes straight away.
		local part = WorldProps.partOf(target)
		if part then
			NoiseService.emit(part.Position, RECALL_NOISE_RADIUS)
		end
	elseif ObjectiveService.isCompleted("ReachCommCenter") then
		notify(player, "The elevator has already been recalled.", "info")
	else
		notify(player, "No carrier signal. Something else is transmitting on this channel.", "info")
	end
end

local function finish()
	finishing = true
	log:info("Escape sequence begins")
	reach("Escape")
	ReplicatedStorage:SetAttribute(GameState.DURATION_ATTRIBUTE, math.floor(os.clock() - startedAt))
	CopyAI.shutdown()
	SessionService.setPhase(GameState.Phase.Finale)
	NetService.fireAll("Notify", "The elevator doors close.", "info")

	local panel = WorldProps.get("ElevatorPanel")
	local part = panel and WorldProps.partOf(panel)
	RadioSystem.play(Transmissions.FinalWords, if part then part.Position else nil, nil)
	SessionService.setPhase(GameState.Phase.Ending)
	log:info("Mission complete")
end

local function onElevator(player: Player, _target: Instance, _id: string)
	if finishing or not SessionService.isPlaying() then
		return
	end
	if ObjectiveService.isActive("Escape") then
		finish()
	else
		notify(player, "The elevator does not respond.", "info")
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
	task.wait(1)
	SessionService.setPhase(GameState.Phase.Intro)
	task.wait(GameConfig.IntroSeconds)
	SessionService.setPhase(GameState.Phase.Playing)
end

function SliceDirector.Start(_self: any)
	InteractionSystem.registerKind("Switchgear", onSwitchgear)
	InteractionSystem.registerKind("AnalysisConsole", onAnalysis)
	InteractionSystem.registerKind("CommConsole", onConsole)
	InteractionSystem.registerKind("ElevatorPanel", onElevator)

	ObjectiveService.completed:Connect(onObjectiveCompleted)
	WorldService.zoneEntered:Connect(evaluateZones)
	SessionService.phaseChanged:Connect(function(phase: GameState.Phase)
		if phase == GameState.Phase.Playing then
			startedAt = os.clock()
			evaluateZones()
			reconcile()
		end
	end)

	PowerSystem.controlsUsed:Connect(function()
		reach("FindPowerControls")
	end)
	PowerSystem.restored:Connect(function()
		reach("RestorePower")
	end)
	RadioSystem.finished:Connect(function()
		reach("InvestigateRadio")
		HorrorDirector.armCorridorSighting()
	end)

	WorldService.onReady(function()
		WorldProps.ensure()
		for objective, prop in REQUIRED_PROP do
			if not WorldProps.get(prop) then
				skipped[objective] = true
				log:warn(
					`Objective {objective} will be skipped: this map has no "{prop}". `
						.. "Regenerate the map to get the expanded station (docs/MAP_GENERATOR.md)."
				)
			end
		end
		if GameConfig.AutoStartSession then
			autoStart()
		end
	end)
end

return SliceDirector
