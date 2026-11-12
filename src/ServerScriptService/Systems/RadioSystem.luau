--!strict
-- The radio receiver (object with Kind = "Radio"). It is dead until power returns, then
-- starts receiving; listening plays the scripted transmission to every player: subtitles,
-- timed silences, flickering lights and screen interference.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Logger)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Transmissions = require(script.Parent.Parent.Data.Transmissions)
local NetService = require(script.Parent.Parent.Services.NetService)
local NoiseService = require(script.Parent.Parent.Services.NoiseService)
local SessionService = require(script.Parent.Parent.Services.SessionService)
local WorldService = require(script.Parent.Parent.Services.WorldService)
local FacilityLights = require(script.Parent.FacilityLights)
local InteractionSystem = require(script.Parent.InteractionSystem)
local PowerSystem = require(script.Parent.PowerSystem)
local WorldProps = require(script.Parent.WorldProps)

type RadioState = "Dead" | "Receiving" | "Playing" | "Finished"

local COLOR_RECEIVING = Color3.fromRGB(70, 170, 185)
local COLOR_IDLE = Color3.fromRGB(90, 96, 100)
local NOISE_RADIUS = 50

local log = Logger.new("Radio")

local RadioSystem = {}

-- Fired once when the first transmission has played to the end.
RadioSystem.finished = Signal.new()

local state: RadioState = "Dead"
local radio: Instance? = nil

-- Plays a transmission to everyone. `origin` is where it is heard from; `room` is the room
-- whose lights react. Yields until it is over.
function RadioSystem.play(steps: { Transmissions.Step }, origin: Vector3?, room: string?)
	for _, step in steps do
		if step.text then
			NetService.fireAll("Subtitle", step.speaker or "", step.text, step.hold)
		end
		if step.cue then
			NetService.fireAll("Sound", step.cue, origin)
		end
		if step.interference then
			NetService.fireAll("Effect", "Interference", step.hold)
		end
		if step.flicker and room then
			FacilityLights.flickerRooms({ room }, step.hold)
		end
		task.wait(step.hold)
	end
end

local function setAppearance(text: string, color: Color3, glowing: boolean)
	local part = radio and WorldProps.partOf(radio)
	if radio and part then
		part.Color = color
		part.Material = if glowing then Enum.Material.Neon else Enum.Material.Metal
		WorldProps.setLabel(radio, text, color)
	end
end

local function onPowerRestored()
	if state ~= "Dead" or not radio then
		return
	end
	state = "Receiving"
	radio:SetAttribute("InteractEnabled", true)
	setAppearance("RECEIVER\nINCOMING SIGNAL", COLOR_RECEIVING, true)
	task.delay(4, function()
		NetService.fireAll(
			"Notify",
			"A receiver has come back to life somewhere in the research corridors.",
			"info"
		)
	end)
end

local function onListen(player: Player, _target: Instance, _id: string)
	local part = radio and WorldProps.partOf(radio)
	if not radio or not part or not SessionService.isPlaying() then
		return
	end
	if state == "Finished" then
		NetService.fire("Subtitle", player, "RADIO", "[static]", 2)
		return
	elseif state ~= "Receiving" then
		return
	end

	state = "Playing"
	log:info(`Transmission started by {player.Name}`)
	radio:SetAttribute("InteractEnabled", false)
	NoiseService.emit(part.Position, NOISE_RADIUS)
	RadioSystem.play(Transmissions.FirstContact, part.Position, WorldService.zoneAt(part.Position))

	state = "Finished"
	radio:SetAttribute("ActionText", "Listen again")
	radio:SetAttribute("InteractEnabled", true)
	setAppearance("RECEIVER\nNO SIGNAL", COLOR_IDLE, false)
	RadioSystem.finished:Fire()
end

function RadioSystem.Start(_self: any)
	InteractionSystem.registerKind("Radio", onListen)

	WorldService.onReady(function()
		WorldProps.ensure()
		radio = WorldProps.get("Radio")
		if not radio then
			log:warn("The radio was not placed: the transmission cannot be played")
			return
		end
		setAppearance("RECEIVER\nNO POWER", COLOR_IDLE, false)
		PowerSystem.restored:Connect(onPowerRestored)
		if PowerSystem.isOn() then
			onPowerRestored()
		end
	end)
end

return RadioSystem
