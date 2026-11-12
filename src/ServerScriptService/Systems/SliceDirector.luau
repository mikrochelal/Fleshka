--!strict
-- The mission script for the current playable slice. It starts the session, turns what
-- happens in the world into objective progress, and owns the two objects that belong to
-- the mission itself (the communication console and the elevator panel).
--
--   EnterStation       a player walks from the elevator into the lobby
--   FindPowerControls  a player reaches the power room or operates a breaker
--   RestorePower       the power puzzle is solved
--   InvestigateRadio   the radio transmission has been heard to the end
--   ReachCommCenter    a player uses the console in the communication center
--   Escape             a player uses the recalled elevator

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
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

-- Rooms whose entry counts for an objective.
local ENTRY_ROOM = "A_Lobby"
local POWER_ROOM = "B_PowerRoom"
local RECALL_NOISE_RADIUS = 400

local log = Logger.new("Slice")

local SliceDirector = {}

local startedAt = 0
local finishing = false

local function notify(player: Player, text: string, kind: string)
	NetService.fire("Notify", player, text, kind)
end

-- Checks the objectives that depend on where players are.
local function evaluateZones()
	if not SessionService.isPlaying() then
		return
	end
	for _, player in Players:GetPlayers() do
		local room = WorldService.getPlayerZone(player)
		if room == ENTRY_ROOM then
			ObjectiveService.complete("EnterStation")
		elseif room == POWER_ROOM then
			ObjectiveService.complete("FindPowerControls")
		end
	end
end

local function onConsole(player: Player, target: Instance, _id: string)
	if not SessionService.isPlaying() then
		return
	end
	if not PowerSystem.isOn() then
		notify(player, "The console is dead. The station has no power.", "info")
	elseif ObjectiveService.isActive("ReachCommCenter") then
		ObjectiveService.complete("ReachCommCenter")
		NetService.fireAll(
			"Notify",
			"Recall signal sent. The freight elevator is on its way down.",
			"info"
		)
		local panel = WorldProps.get("ElevatorPanel")
		if panel then
			panel:SetAttribute("InteractEnabled", true)
		end
		-- The recall is loud, and from here on THE COPY may give chase.
		CopyAI.arm()
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
	ObjectiveService.complete("Escape")
	ReplicatedStorage:SetAttribute(GameState.DURATION_ATTRIBUTE, math.floor(os.clock() - startedAt))
	CopyAI.shutdown()
	SessionService.setPhase(GameState.Phase.Finale)
	NetService.fireAll("Notify", "The elevator doors close.", "info")

	local panel = WorldProps.get("ElevatorPanel")
	local part = panel and WorldProps.partOf(panel)
	RadioSystem.play(Transmissions.FinalWords, if part then part.Position else nil, nil)
	SessionService.setPhase(GameState.Phase.Ending)
	log:info("Slice complete")
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
	InteractionSystem.registerKind("CommConsole", onConsole)
	InteractionSystem.registerKind("ElevatorPanel", onElevator)

	WorldService.zoneEntered:Connect(evaluateZones)
	ObjectiveService.completed:Connect(evaluateZones)
	SessionService.phaseChanged:Connect(function(phase: GameState.Phase)
		if phase == GameState.Phase.Playing then
			startedAt = os.clock()
			evaluateZones()
		end
	end)

	PowerSystem.controlsUsed:Connect(function()
		ObjectiveService.complete("FindPowerControls")
	end)
	PowerSystem.restored:Connect(function()
		-- Whoever solved it has necessarily found the controls.
		ObjectiveService.complete("FindPowerControls")
		ObjectiveService.complete("RestorePower")
	end)
	RadioSystem.finished:Connect(function()
		ObjectiveService.complete("InvestigateRadio")
		HorrorDirector.armCorridorSighting()
	end)

	WorldService.onReady(function()
		WorldProps.ensure()
		if GameConfig.AutoStartSession then
			autoStart()
		end
	end)
end

return SliceDirector
