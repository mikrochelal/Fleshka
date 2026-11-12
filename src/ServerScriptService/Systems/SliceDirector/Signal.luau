--!strict
-- Chapter 3: the signal.
--
--   SignalTape       an Item in the laboratory archive: the reference recording.
--   AnalysisConsole  plays the tape and traces the signal. The trace names the carrier
--                    channel (needed later at the radio desk) and wakes something up:
--                    the laboratory lights die and THE COPY comes to the console.
--
-- The scripted encounter is fair: it appears at an observation point out of sight, the
-- blackout is announced, and getting out of the wing completes the objective.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MissionConfig = require(ReplicatedStorage.Config.MissionConfig)
local Logger = require(ReplicatedStorage.Shared.Logger)
local Text = require(ReplicatedStorage.Shared.Text)
local Transmissions = require(script.Parent.Parent.Parent.Data.Transmissions)
local AudioService = require(script.Parent.Parent.Parent.Services.AudioService)
local NoiseService = require(script.Parent.Parent.Parent.Services.NoiseService)
local WorldService = require(script.Parent.Parent.Parent.Services.WorldService)
local CopyAI = require(script.Parent.Parent.CopyAI)
local FacilityLights = require(script.Parent.Parent.FacilityLights)
local InteractionSystem = require(script.Parent.Parent.InteractionSystem)
local InventorySystem = require(script.Parent.Parent.InventorySystem)
local PowerSystem = require(script.Parent.Parent.PowerSystem)
local RadioSystem = require(script.Parent.Parent.RadioSystem)
local WorldProps = require(script.Parent.Parent.WorldProps)
local Mission = require(script.Parent.Mission)

local TAPE = "SignalTape"
local LAB_CIRCUIT = "C"

local log = Logger.new("Slice")

local Signal = {}

local tracing = false

local function refresh()
	local console = WorldProps.get("AnalysisConsole")
	if not console then
		return
	end
	local status, color
	if not PowerSystem.isOn() then
		status, color = "LABEL_NO_POWER", Mission.COLOR_DEAD
	elseif Mission.isDone("TraceSignal") then
		status, color =
			Text.ref("LABEL_ANALYSIS_DONE", { channel = Mission.channel }), Mission.COLOR_OK
	else
		status, color = "LABEL_ANALYSIS_IDLE", Mission.COLOR_WAIT
	end
	WorldProps.setLabel(console, Text.lines({ "LABEL_ANALYSIS", status }), color)
end

local function labEncounter(position: Vector3)
	log:info("Laboratory blackout: scripted encounter begins")
	FacilityLights.setCircuit(LAB_CIRCUIT, false)
	AudioService.play("PowerDown", position)
	Mission.notifyAll("NOTIFY_LAB_BLACKOUT", nil, "warning")
	CopyAI.summon(position, "the trace")
	task.delay(MissionConfig.LabBlackoutSeconds, function()
		if PowerSystem.isOn() then
			FacilityLights.setCircuit(LAB_CIRCUIT, true)
			log:info("Laboratory lights restored")
		end
	end)
end

local function onConsole(player: Player, _target: Instance, _id: string)
	if not Mission.playing() or tracing then
		return
	end
	local position = WorldProps.positionOf("AnalysisConsole")
	if not PowerSystem.isOn() then
		Mission.notify(player, "NOTIFY_CONSOLE_DEAD")
	elseif Mission.isDone("TraceSignal") then
		Mission.notify(player, "NOTIFY_TRACE_DONE", { channel = Mission.channel })
	elseif not Mission.isDone("InvestigateRadio") then
		Mission.notify(player, "NOTIFY_TRACE_NO_REFERENCE")
	elseif not InventorySystem.has(TAPE) then
		Mission.notify(player, "NOTIFY_TRACE_NO_TAPE")
	elseif position then
		tracing = true
		log:info(`{player.Name} started the signal trace (carrier channel {Mission.channel})`)
		NoiseService.make("Terminal", position)
		RadioSystem.play(
			Transmissions.trace(Mission.channel),
			position,
			WorldService.zoneAt(position)
		)
		Mission.reach("TraceSignal")
		refresh()
		labEncounter(position)
		tracing = false
	end
end

function Signal.start()
	InteractionSystem.registerKind("AnalysisConsole", onConsole)
	InventorySystem.collected:Connect(function(_player: Player, id: string)
		if id == TAPE then
			Mission.mark("FindSignalTape")
		end
	end)
	PowerSystem.restored:Connect(refresh)
end

function Signal.ready()
	refresh()
end

return Signal
