--!strict
-- Chapter 5 and the ending: the plant, the evacuation override and the freight lift.
--
--   GeneratorPanel  first read after emergency power returns (chapter 1: it reports the
--                   faults the next chapters repair); later switched to full load, which
--                   needs the ventilation plant running.
--   FanControl      starts the ventilation plant.
--   EvacConsole     authorises the evacuation: alarm, THE COPY's last stage.
--   FreightPanel    starts the freight lift once the team is aboard (or a grace period
--                   after it was first called, so nobody can hold the others forever).
--   ElevatorPanel   the arrival elevator. It never comes back.
--
-- Nothing here waits on a timer the players cannot influence, and nothing can be undone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MissionConfig = require(ReplicatedStorage.Config.MissionConfig)
local PowerConfig = require(ReplicatedStorage.Config.PowerConfig)
local GameState = require(ReplicatedStorage.Shared.GameState)
local Logger = require(ReplicatedStorage.Shared.Logger)
local Text = require(ReplicatedStorage.Shared.Text)
local Transmissions = require(script.Parent.Parent.Parent.Data.Transmissions)
local AudioService = require(script.Parent.Parent.Parent.Services.AudioService)
local NoiseService = require(script.Parent.Parent.Parent.Services.NoiseService)
local ObjectiveService = require(script.Parent.Parent.Parent.Services.ObjectiveService)
local PlayerService = require(script.Parent.Parent.Parent.Services.PlayerService)
local SessionService = require(script.Parent.Parent.Parent.Services.SessionService)
local WorldService = require(script.Parent.Parent.Parent.Services.WorldService)
local AudioEmitters = require(script.Parent.Parent.AudioEmitters)
local CopyAI = require(script.Parent.Parent.CopyAI)
local FacilityLights = require(script.Parent.Parent.FacilityLights)
local InteractionSystem = require(script.Parent.Parent.InteractionSystem)
local PowerSystem = require(script.Parent.Parent.PowerSystem)
local RadioSystem = require(script.Parent.Parent.RadioSystem)
local WorldProps = require(script.Parent.Parent.WorldProps)
local Mission = require(script.Parent.Mission)

local LIFT_ROOM = "H_FreightElevator"
local FREIGHT_CIRCUIT = "H"

local log = Logger.new("Slice")

local Evacuation = {}

local startedAt = 0
local fansRunning = false
local fullLoad = false
local finishing = false
local firstCall: number? = nil

local function setStatus(id: string, title: string, status: string, color: Color3)
	local prop = WorldProps.get(id)
	if prop then
		WorldProps.setLabel(prop, Text.lines({ title, status }), color)
	end
end

local function refresh()
	local powered = PowerSystem.isOn()
	setStatus(
		"GeneratorPanel",
		"LABEL_GENERATOR",
		if not powered
			then "LABEL_NO_POWER"
			elseif fullLoad then "LABEL_GENERATOR_FULL"
			else "LABEL_GENERATOR_STANDBY",
		if not powered
			then Mission.COLOR_DEAD
			elseif fullLoad then Mission.COLOR_OK
			else Mission.COLOR_WAIT
	)
	setStatus(
		"FanControl",
		"LABEL_FANS",
		if fansRunning then "LABEL_FANS_RUNNING" else "LABEL_FANS_STOPPED",
		if fansRunning then Mission.COLOR_OK else Mission.COLOR_OFF
	)
	local authorised = Mission.isDone("ActivateEvacuation")
	setStatus(
		"EvacConsole",
		"LABEL_EVAC",
		if authorised then "LABEL_EVAC_AUTHORISED" else "LABEL_EVAC_READY",
		if authorised then Mission.COLOR_OK else Mission.COLOR_WAIT
	)
	setStatus(
		"FreightPanel",
		"LABEL_LIFT",
		if authorised then "LABEL_LIFT_READY" else "LABEL_LIFT_LOCKED",
		if authorised then Mission.COLOR_OK else Mission.COLOR_OFF
	)
	ObjectiveService.setProgress(
		"RestoreFreightCircuit",
		Text.ref("PROGRESS_FREIGHT", {
			done = (if fansRunning then 1 else 0) + (if fullLoad then 1 else 0),
			total = 2,
		})
	)
end

local function onGenerator(player: Player, _target: Instance, _id: string)
	if not Mission.playing() then
		return
	end
	local position = WorldProps.positionOf("GeneratorPanel")
	if not PowerSystem.isOn() then
		Mission.notify(player, "NOTIFY_GENERATOR_DEAD")
	elseif not Mission.isDone("InspectGenerator") then
		log:info(`{player.Name} read the generator status panel`)
		Mission.reach("InspectGenerator")
		if position then
			RadioSystem.play(Transmissions.GeneratorReadout, position, nil)
		end
	elseif fullLoad then
		Mission.notify(player, "NOTIFY_GENERATOR_ALREADY_FULL")
	elseif not Mission.isDone("SendDistress") then
		Mission.notify(player, "NOTIFY_GENERATOR_STANDBY")
	elseif not fansRunning then
		Mission.notify(player, "NOTIFY_GENERATOR_INTERLOCK", nil, "warning")
	else
		fullLoad = true
		log:info(`{player.Name} switched the main generator to full load`)
		AudioService.play("SwitchFlip", position)
		AudioService.play("PowerOn", position)
		AudioEmitters.setIntensity("Generator", 1.5)
		if position then
			NoiseService.make("Machinery", position)
		end
		Mission.notifyAll("NOTIFY_FREIGHT_CIRCUIT")
		refresh()
		Mission.reach("RestoreFreightCircuit")
	end
end

local function onFans(player: Player, _target: Instance, _id: string)
	if not Mission.playing() then
		return
	end
	local position = WorldProps.positionOf("FanControl")
	if not PowerSystem.isOn() then
		Mission.notify(player, "NOTIFY_FANS_DEAD")
	elseif fansRunning then
		Mission.notify(player, "NOTIFY_FANS_ALREADY")
	elseif not Mission.isDone("SendDistress") then
		Mission.notify(player, "NOTIFY_FANS_LOCKED")
	else
		fansRunning = true
		log:info(`{player.Name} started the ventilation plant`)
		AudioService.play("MachineryStart", position)
		AudioEmitters.setActive("VentilationFan", true)
		if position then
			NoiseService.make("Machinery", position)
		end
		Mission.notifyAll("NOTIFY_FANS_RUNNING")
		refresh()
	end
end

local function onEvacConsole(player: Player, _target: Instance, _id: string)
	if not Mission.playing() then
		return
	end
	if Mission.isDone("ActivateEvacuation") then
		Mission.notify(player, "NOTIFY_EVAC_ALREADY")
		return
	end
	local position = WorldProps.positionOf("EvacConsole")
	log:info(`{player.Name} authorised the evacuation`)
	AudioService.play("AccessGranted", position)
	AudioEmitters.setActive("EvacuationAlarm", true)
	FacilityLights.setCircuit(PowerConfig.EmergencyCircuit, true)
	FacilityLights.flickerCircuits({ FREIGHT_CIRCUIT }, 3)
	Mission.notifyAll("NOTIFY_EVAC_AUTHORISED", nil, "warning")
	if position then
		NoiseService.make("Evacuation", position)
	end
	-- Completing the objective raises THE COPY to its last stage and opens the lift doors.
	Mission.reach("ActivateEvacuation")
	refresh()
	RadioSystem.play(Transmissions.Evacuation, nil, nil)
end

-- Living players aboard the lift, and living players in total.
local function aboard(): (number, number)
	local inside, total = 0, 0
	for _, player in Players:GetPlayers() do
		if PlayerService.getAliveRoot(player) then
			total += 1
			if WorldService.getPlayerZone(player) == LIFT_ROOM then
				inside += 1
			end
		end
	end
	return inside, total
end

-- The ending. The doors close on it, the lift climbs, and the signal follows.
function Evacuation.finish()
	if finishing then
		return
	end
	finishing = true
	log:info("Escape sequence begins")
	Mission.reach("Escape")
	ReplicatedStorage:SetAttribute(GameState.DURATION_ATTRIBUTE, math.floor(os.clock() - startedAt))

	local position = WorldProps.positionOf("FreightPanel")
	Mission.notifyAll("NOTIFY_LIFT_DEPARTS")
	AudioService.play("ElevatorStart", position)
	AudioEmitters.setActive("FreightLift", true)
	-- Its last sound, from the corridor it was coming down.
	AudioService.play("CopyFinal", WorldService.floorPoint("H_CargoCorridor", Vector3.new(0, 4, 0)))
	CopyAI.shutdown()
	task.wait(3)

	SessionService.setPhase(GameState.Phase.Finale)
	AudioEmitters.setActive("EvacuationAlarm", false)
	RadioSystem.play(Transmissions.FinalWords, nil, nil)
	AudioEmitters.setActive("FreightLift", false)
	SessionService.setPhase(GameState.Phase.Ending)
	log:info("Mission complete")
end

local function watchBoarding()
	while not finishing and SessionService.isPlaying() do
		local inside, total = aboard()
		local waited = os.clock() - (firstCall or os.clock())
		ObjectiveService.setProgress("Escape", Text.ref("PROGRESS_ABOARD", { inside = inside, total = total }))
		if total > 0 and inside >= total then
			Evacuation.finish()
		elseif inside > 0 and waited >= MissionConfig.BoardingGraceSeconds then
			log:info(`Lift leaves with {inside}/{total} aboard after the grace period`)
			Evacuation.finish()
		end
		task.wait(0.5)
	end
end

local function onFreightPanel(player: Player, _target: Instance, _id: string)
	if finishing or not Mission.playing() then
		return
	end
	if not Mission.isDone("ActivateEvacuation") then
		Mission.notify(player, "NOTIFY_LIFT_LOCKED")
		return
	end
	local inside, total = aboard()
	if inside >= total then
		Evacuation.finish()
	elseif not firstCall then
		firstCall = os.clock()
		log:info(`{player.Name} called the lift with {inside}/{total} aboard`)
		Mission.notifyAll("NOTIFY_LIFT_WAITING", {
			inside = inside,
			total = total,
			seconds = MissionConfig.BoardingGraceSeconds,
		}, "warning")
		task.spawn(watchBoarding)
	else
		Mission.notify(player, "NOTIFY_LIFT_WAITING_SHORT", { inside = inside, total = total })
	end
end

function Evacuation.start()
	InteractionSystem.registerKind("GeneratorPanel", onGenerator)
	InteractionSystem.registerKind("FanControl", onFans)
	InteractionSystem.registerKind("EvacConsole", onEvacConsole)
	InteractionSystem.registerKind("FreightPanel", onFreightPanel)
	InteractionSystem.registerKind("ElevatorPanel", function(player, _target, _id)
		if Mission.playing() then
			Mission.notify(player, "NOTIFY_ELEVATOR_DEAD")
			AudioService.playFor(player, "AccessDenied", WorldProps.positionOf("ElevatorPanel"))
		end
	end)

	SessionService.phaseChanged:Connect(function(phase: GameState.Phase)
		if phase == GameState.Phase.Playing then
			startedAt = os.clock()
		end
	end)
	PowerSystem.restored:Connect(function()
		-- The main generator wakes on standby as soon as there is power to start it.
		AudioEmitters.setActive("Generator", true)
		AudioEmitters.setIntensity("Generator", 0.6)
		refresh()
		task.delay(5, function()
			if not Mission.isDone("InspectGenerator") then
				Mission.notifyAll("NOTIFY_GENERATOR_WAKES")
			end
		end)
	end)
	Mission.onActive("RestoreFreightCircuit", refresh)
	Mission.onCompleted("SendDistress", function()
		local panel = WorldProps.get("GeneratorPanel")
		if panel then
			panel:SetAttribute("ActionText", "INTERACTION_FULL_LOAD")
		end
	end)
end

function Evacuation.ready()
	refresh()
end

return Evacuation
