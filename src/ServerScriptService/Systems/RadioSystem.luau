--!strict
-- The radio. Two jobs:
--
--   * the receiver in the Monitor Room (object with Kind = "Radio"): dead until the
--     mission script wakes it (once the communications relay is online), then hissing with
--     an incoming signal; listening plays the first transmission to every player;
--   * `play`: the sequencer for every scripted transmission and console read-out -
--     subtitles, timed silences, sounds at the source, flickering lights and screen
--     interference.
--
-- After the first transmission the receiver is never quite silent again: `pulse` makes it
-- crackle, and what comes through grows worse with THE COPY's escalation stage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Logger)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Text = require(ReplicatedStorage.Shared.Text)
local Transmissions = require(script.Parent.Parent.Data.Transmissions)
local AudioService = require(script.Parent.Parent.Services.AudioService)
local NetService = require(script.Parent.Parent.Services.NetService)
local NoiseService = require(script.Parent.Parent.Services.NoiseService)
local SessionService = require(script.Parent.Parent.Services.SessionService)
local WorldService = require(script.Parent.Parent.Services.WorldService)
local AudioEmitters = require(script.Parent.AudioEmitters)
local FacilityLights = require(script.Parent.FacilityLights)
local InteractionSystem = require(script.Parent.InteractionSystem)
local WorldProps = require(script.Parent.WorldProps)

type RadioState = "Dead" | "Receiving" | "Playing" | "Finished"

local COLOR_RECEIVING = Color3.fromRGB(70, 170, 185)
local COLOR_IDLE = Color3.fromRGB(90, 96, 100)
local EMITTER = "RadioReceiver"
-- What the receiver lets through when it crackles, by escalation stage.
local PULSE_CUES: { [string]: string } = {
	Aware = "RadioStaticBurst",
	Hunting = "RadioInterference",
	Hostile = "RadioWhisper",
	FinalPursuit = "RadioVoice",
}
local PULSE_INTENSITY: { [string]: number } = {
	Aware = 0.5,
	Hunting = 0.7,
	Hostile = 0.9,
	FinalPursuit = 1.2,
}

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
			AudioService.play(step.cue, origin)
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

local function setAppearance(status: string, color: Color3, glowing: boolean)
	if radio then
		WorldProps.setLook(radio, color, glowing)
		WorldProps.setLabel(radio, Text.lines({ "LABEL_RECEIVER", status }), color)
	end
end

-- Brings the receiver to life (called by the mission script). Does nothing if it already is.
function RadioSystem.wake()
	if state ~= "Dead" or not radio then
		return
	end
	state = "Receiving"
	log:info("The receiver has an incoming signal")
	radio:SetAttribute("InteractEnabled", true)
	setAppearance("LABEL_RECEIVER_INCOMING", COLOR_RECEIVING, true)
	AudioEmitters.setActive(EMITTER, true)
	task.delay(4, function()
		NetService.fireAll("Notify", Text.ref("NOTIFY_RECEIVER_AWAKE"), "info")
	end)
end

-- The receiver crackles by itself. `stage` is THE COPY's escalation stage: the further the
-- mission has gone, the more comes through. Does nothing before the first transmission.
function RadioSystem.pulse(stage: string)
	local position = WorldProps.positionOf("Radio")
	local cue = PULSE_CUES[stage]
	if state ~= "Finished" or not position or not cue then
		return
	end
	log:info(`The receiver crackles ({stage})`)
	AudioEmitters.setIntensity(EMITTER, PULSE_INTENSITY[stage] or 0.5)
	AudioService.play(cue, position)
	local room = WorldService.zoneAt(position)
	if room then
		FacilityLights.flickerRooms({ room }, 1.2)
	end
end

local function onListen(player: Player, _target: Instance, _id: string)
	local position = WorldProps.positionOf("Radio")
	if not radio or not position or not SessionService.isPlaying() then
		return
	end
	if state == "Finished" then
		NetService.fire("Subtitle", player, "SPEAKER_RADIO", "RADIO_STATIC", 2)
		AudioService.playFor(player, "RadioStaticBurst", position)
		return
	elseif state ~= "Receiving" then
		return
	end

	state = "Playing"
	log:info(`Transmission started by {player.Name}`)
	radio:SetAttribute("InteractEnabled", false)
	NoiseService.make("Radio", position)
	RadioSystem.play(Transmissions.FirstContact, position, WorldService.zoneAt(position))

	state = "Finished"
	radio:SetAttribute("ActionText", "INTERACTION_LISTEN_AGAIN")
	radio:SetAttribute("InteractEnabled", true)
	setAppearance("LABEL_RECEIVER_NO_SIGNAL", COLOR_IDLE, false)
	-- It keeps hissing quietly for the rest of the mission.
	AudioEmitters.setIntensity(EMITTER, 0.4)
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
		setAppearance("LABEL_RECEIVER_OFFLINE", COLOR_IDLE, false)
	end)
end

return RadioSystem
