--!strict
-- Chapter 4: the communication center.
--
--   The door code   is in two halves, on the operator's note and on the patient chart.
--                   Reading both completes "find the code"; entering it on the antechamber
--                   keypad (KeypadSystem) opens the wing. The keypad has no power until
--                   the trace has been run.
--   The transmitter needs three things, in any order and by any player: the recording
--                   servers restarted, the mast raised, and the radio desk locked onto the
--                   carrier channel the trace named (TunerUp / TunerDown, then the desk).
--   The distress call is sent from the central computer. The answer comes too quickly;
--                   THE COPY comes with it.
--
-- A restricted archive elsewhere has its own code lock (optional objective).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MissionConfig = require(ReplicatedStorage.Config.MissionConfig)
local Logger = require(ReplicatedStorage.Shared.Logger)
local Text = require(ReplicatedStorage.Shared.Text)
local Transmissions = require(script.Parent.Parent.Parent.Data.Transmissions)
local AudioService = require(script.Parent.Parent.Parent.Services.AudioService)
local NetService = require(script.Parent.Parent.Parent.Services.NetService)
local NoiseService = require(script.Parent.Parent.Parent.Services.NoiseService)
local ObjectiveService = require(script.Parent.Parent.Parent.Services.ObjectiveService)
local WorldService = require(script.Parent.Parent.Parent.Services.WorldService)
local AudioEmitters = require(script.Parent.Parent.AudioEmitters)
local CopyAI = require(script.Parent.Parent.CopyAI)
local DocumentSystem = require(script.Parent.Parent.DocumentSystem)
local DoorSystem = require(script.Parent.Parent.DoorSystem)
local FacilityLights = require(script.Parent.Parent.FacilityLights)
local InteractionSystem = require(script.Parent.Parent.InteractionSystem)
local KeypadSystem = require(script.Parent.Parent.KeypadSystem)
local PowerSystem = require(script.Parent.Parent.PowerSystem)
local RadioSystem = require(script.Parent.Parent.RadioSystem)
local WorldProps = require(script.Parent.Parent.WorldProps)
local Mission = require(script.Parent.Mission)

local COMM_LOCK = "CommDoor"
local ARCHIVE_LOCK = "RestrictedArchive"
local CLUES = { "OperatorNote", "PatientChart" }
local COMM_CIRCUIT = "D"

local log = Logger.new("Slice")

local Comms = {}

local random = Random.new()
local serversUp = false
local mastUp = false
local carrierLocked = false
local channel = 1
local sending = false

local function half(first: boolean): string
	local code = KeypadSystem.code(COMM_LOCK)
	local middle = #code // 2
	return if first then string.sub(code, 1, middle) else string.sub(code, middle + 1)
end

local function cluesRead(): number
	local count = 0
	for _, id in CLUES do
		if DocumentSystem.hasRead(id) then
			count += 1
		end
	end
	return count
end

local function stepsDone(): number
	return (if serversUp then 1 else 0) + (if mastUp then 1 else 0) + (if carrierLocked then 1 else 0)
end

local function setStatus(id: string, title: string, status: string, color: Color3)
	local prop = WorldProps.get(id)
	if prop then
		WorldProps.setLabel(prop, Text.lines({ title, status }), color)
	end
end

local function refresh()
	setStatus(
		"ServerRack",
		"LABEL_SERVERS",
		if serversUp then "LABEL_ONLINE" else "LABEL_OFFLINE",
		if serversUp then Mission.COLOR_OK else Mission.COLOR_OFF
	)
	setStatus(
		"MastControl",
		"LABEL_MAST",
		if mastUp then "LABEL_MAST_RAISED" else "LABEL_MAST_LOWERED",
		if mastUp then Mission.COLOR_OK else Mission.COLOR_OFF
	)
	setStatus(
		"RadioDesk",
		Text.ref("LABEL_TUNER", { channel = channel }),
		if carrierLocked then "LABEL_TUNER_LOCKED" else "LABEL_TUNER_SEARCHING",
		if carrierLocked then Mission.COLOR_OK else Mission.COLOR_WAIT
	)
	ObjectiveService.setProgress("FindCommCode", Text.ref("PROGRESS_CODE", { done = cluesRead(), total = #CLUES }))
	ObjectiveService.setProgress("RestoreTransmitter", Text.ref("PROGRESS_TRANSMITTER", { done = stepsDone(), total = 3 }))
end

local function stepDone(player: Player, what: string)
	log:info(`{player.Name} {what} (transmitter {stepsDone()}/3)`)
	refresh()
	if stepsDone() == 3 then
		Mission.notifyAll("NOTIFY_TRANSMITTER_READY")
		Mission.reach("RestoreTransmitter")
	end
end

local function onServers(player: Player, _target: Instance, _id: string)
	if not Mission.playing() then
		return
	end
	if serversUp then
		Mission.notify(player, "NOTIFY_SERVERS_ALREADY")
		return
	end
	serversUp = true
	local position = WorldProps.positionOf("ServerRack")
	AudioService.play("TerminalBoot", position)
	AudioService.play("TerminalBeep", position)
	AudioEmitters.setActive("Servers", true)
	if position then
		NoiseService.make("Terminal", position)
	end
	Mission.notifyAll("NOTIFY_SERVERS_ONLINE")
	stepDone(player, "restarted the recording servers")
end

local function onMast(player: Player, _target: Instance, _id: string)
	if not Mission.playing() then
		return
	end
	if mastUp then
		Mission.notify(player, "NOTIFY_MAST_ALREADY")
		return
	end
	mastUp = true
	local position = WorldProps.positionOf("MastControl")
	AudioService.play("MachineryStart", position)
	if position then
		-- Raising the mast is the loudest thing in the wing.
		NoiseService.make("Machinery", position)
	end
	Mission.notifyAll("NOTIFY_MAST_RAISED")
	stepDone(player, "raised the antenna mast")
end

local function onTuner(player: Player, _target: Instance, id: string)
	if not Mission.playing() then
		return
	end
	if carrierLocked then
		Mission.notify(player, "NOTIFY_CARRIER_ALREADY")
		return
	end
	local step = if id == "TunerUp" then 1 else -1
	channel = (channel - 1 + step) % MissionConfig.TunerChannels + 1
	AudioService.play("RadioTune", WorldProps.positionOf("RadioDesk"))
	AudioEmitters.setActive("RadioDesk", true)
	refresh()
end

local function onDesk(player: Player, _target: Instance, _id: string)
	if not Mission.playing() then
		return
	end
	local position = WorldProps.positionOf("RadioDesk")
	if carrierLocked then
		Mission.notify(player, "NOTIFY_CARRIER_ALREADY")
	elseif channel == Mission.channel then
		carrierLocked = true
		AudioService.play("AccessGranted", position)
		AudioEmitters.setIntensity("RadioDesk", 0.4)
		Mission.notifyAll("NOTIFY_CARRIER_LOCKED", { channel = channel })
		stepDone(player, "locked the carrier channel")
	else
		log:info(`{player.Name} tried channel {channel}; the carrier is elsewhere`)
		AudioService.play("RadioInterference", position)
		NetService.fire("Effect", player, "Interference", 1.5)
		if position then
			NoiseService.make("TunerMiss", position)
		end
		Mission.notify(player, "NOTIFY_CARRIER_MISS", { channel = channel }, "warning")
	end
end

local function onConsole(player: Player, _target: Instance, _id: string)
	if not Mission.playing() or sending then
		return
	end
	local position = WorldProps.positionOf("CommConsole")
	if not PowerSystem.isOn() then
		Mission.notify(player, "NOTIFY_CONSOLE_DEAD")
	elseif Mission.isDone("SendDistress") then
		Mission.notify(player, "NOTIFY_DISTRESS_ALREADY")
	elseif stepsDone() < 3 then
		Mission.notify(player, "NOTIFY_TRANSMITTER_NOT_READY", { done = stepsDone(), total = 3 })
	elseif position then
		sending = true
		log:info(`{player.Name} sent the distress call`)
		NoiseService.make("Transmission", position)
		RadioSystem.play(Transmissions.Reply, position, WorldService.zoneAt(position))
		Mission.reach("SendDistress")

		log:info("Communication center: scripted encounter begins")
		FacilityLights.flickerCircuits({ COMM_CIRCUIT }, 4)
		Mission.notifyAll("NOTIFY_COMM_ENCOUNTER", nil, "warning")
		CopyAI.summon(position, "the distress call")
		sending = false
	end
end

function Comms.start()
	InteractionSystem.registerKind("ServerRack", onServers)
	InteractionSystem.registerKind("MastControl", onMast)
	InteractionSystem.registerKind("Tuner", onTuner)
	InteractionSystem.registerKind("RadioDesk", onDesk)
	InteractionSystem.registerKind("CommConsole", onConsole)

	DocumentSystem.setParams("OperatorNote", function(): Text.Params
		return { half = half(true) }
	end)
	DocumentSystem.setParams("PatientChart", function(): Text.Params
		return { half = half(false) }
	end)
	DocumentSystem.setParams("PersonnelFile", function(): Text.Params
		return { code = KeypadSystem.code(ARCHIVE_LOCK) }
	end)
	DocumentSystem.opened:Connect(function(_player: Player, id: string)
		if table.find(CLUES, id) then
			refresh()
			if cluesRead() == #CLUES then
				Mission.mark("FindCommCode")
			end
		end
	end)

	KeypadSystem.opened:Connect(function(lockId: string, player: Player)
		if lockId == COMM_LOCK then
			Mission.notifyAll("NOTIFY_COMM_DOOR_OPEN", { name = player.DisplayName })
			Mission.reach("EnterCommCenter")
		elseif lockId == ARCHIVE_LOCK then
			Mission.notifyAll("NOTIFY_ARCHIVE_OPEN", { name = player.DisplayName })
			DoorSystem.unlock(ARCHIVE_LOCK)
			ObjectiveService.setOptional(ARCHIVE_LOCK, 1, 1)
		end
	end)

	-- The trace routes power to the antechamber lock.
	Mission.onCompleted("TraceSignal", function()
		KeypadSystem.setPowered(COMM_LOCK, true)
	end)
	Mission.onActive("FindCommCode", refresh)
	Mission.onActive("RestoreTransmitter", refresh)

	-- The dial starts somewhere other than the carrier.
	channel = (Mission.channel + random:NextInteger(1, MissionConfig.TunerChannels - 1) - 1)
			% MissionConfig.TunerChannels
		+ 1
end

function Comms.ready()
	refresh()
end

return Comms
