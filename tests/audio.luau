--!strict
-- Audio configuration tests: `luau tests/audio.luau`
-- Every cue that anything refers to exists, asset ids are well formed, and the numbers
-- make sense. Whether a sound can actually be heard is a Studio test.

local AudioConfig = require("../src/ReplicatedStorage/Config/AudioConfig")
local NoiseConfig = require("../src/ReplicatedStorage/Config/NoiseConfig")
local Layout = require("../src/ServerStorage/DevTools/MapGenerator/Layout")
local Transmissions = require("../src/ServerScriptService/Data/Transmissions")

local failures = 0
local total = 0

local function check(name: string, condition: boolean)
	total += 1
	if not condition then
		failures += 1
		print(`FAIL: {name}`)
	end
end

local rooms: { [string]: boolean } = {}
for _, room in Layout.rooms :: { any } do
	rooms[room.name] = true
end

local function exists(label: string, cue: string?)
	check(`{label}: cue "{cue}" exists`, cue ~= nil and AudioConfig.Cues[cue] ~= nil)
end

-- ---- Cues ----
local withAsset, placeholders = 0, {}
for name, cue in AudioConfig.Cues do
	check(
		`{name}: id is empty or a Roblox asset id`,
		cue.id == "" or string.match(cue.id, "^rbxassetid://%d+$") ~= nil
	)
	if cue.id == "" then
		table.insert(placeholders, name)
	else
		withAsset += 1
	end
	check(`{name}: belongs to a mixer group`, AudioConfig.Groups[cue.group] ~= nil)
	check(`{name}: volume is between 0 and 1`, cue.volume > 0 and cue.volume <= 1)
	check(`{name}: speed is sensible`, cue.speed == nil or (cue.speed >= 0.25 and cue.speed <= 3))
	if cue.max then
		check(`{name}: fades between min and max`, (cue.min or 10) < cue.max)
		check(`{name}: cannot be heard across the whole station`, cue.max <= 400)
	end
	check(`{name}: a looped sound has no cooldown`, not (cue.looped and cue.cooldown))
end
table.sort(placeholders)
check("most cues have an audio asset", withAsset >= 50)
check(
	"the game is not silent: the base ambience has an asset",
	AudioConfig.Cues.AmbRoomTone.id ~= ""
)
check("the final signal has an asset", AudioConfig.Cues.FinalSignal.id ~= "")

-- ---- Ambience ----
local ambient = AudioConfig.Ambient
for _, name in ambient.Base do
	exists("base ambience", name)
	check(`{name}: base ambience loops`, AudioConfig.Cues[name].looped == true)
end
for _, name in ambient.Powered do
	exists("powered ambience", name)
	check(`{name}: powered ambience loops`, AudioConfig.Cues[name].looped == true)
end
for area, ambience in ambient.Areas do
	exists(`area {area}`, ambience.cue)
	check(`area {area}: is a wing letter`, #area == 1)
end
for room, ambience in ambient.Rooms do
	exists(`room {room}`, ambience.cue)
	check(`ambience room {room} exists on the map`, rooms[room] == true)
end
for _, name in ambient.Random.Cues do
	exists("random noise", name)
	check(`{name}: random noises are positional one-shots`, AudioConfig.Cues[name].max ~= nil)
end
check("random noises are occasional", ambient.Random.MinInterval >= 10)
check("random interval is a range", ambient.Random.MaxInterval > ambient.Random.MinInterval)

-- ---- Emitters ----
local emitterIds: { [string]: boolean } = {}
for _, emitter in AudioConfig.Emitters do
	check(`emitter {emitter.id}: id is unique`, not emitterIds[emitter.id])
	emitterIds[emitter.id] = true
	exists(`emitter {emitter.id}`, emitter.cue)
	local cue = AudioConfig.Cues[emitter.cue]
	check(
		`emitter {emitter.id}: loops and is positional`,
		cue ~= nil and cue.looped == true and cue.max ~= nil
	)
	check(`emitter {emitter.id}: room {emitter.room} exists`, rooms[emitter.room] == true)
	check(
		`emitter {emitter.id}: sits inside its room`,
		emitter.fx > 0 and emitter.fx < 1 and emitter.fz > 0 and emitter.fz < 1 and emitter.y > 0
	)
end
-- Emitters that game code switches by name.
for _, id in
	{
		"PowerRoomTransformer",
		"Generator",
		"Switchgear",
		"VentilationFan",
		"Servers",
		"RadioReceiver",
		"RadioDesk",
		"FreightLift",
		"EvacuationAlarm",
	}
do
	check(`emitter {id} is configured`, emitterIds[id] == true)
end

-- ---- THE COPY ----
local entity = AudioConfig.Entity
exists("entity presence", entity.PresenceCue)
exists("entity footsteps", entity.FootstepsCue)
exists("entity heartbeat", entity.HeartbeatCue)
for _, state in
	{
		"Observing",
		"Patrolling",
		"Investigating",
		"Searching",
		"Stalking",
		"LostTarget",
		"Returning",
		"Pursuing",
		"Attacking",
		"Disappearing",
	}
do
	check(`entity state {state} has a sound profile`, entity.States[state] ~= nil)
end
check(
	"a chase sounds faster than a patrol",
	entity.States.Pursuing.steps > entity.States.Patrolling.steps
)
check(
	"it is quietest while stalking",
	entity.States.Stalking.presence <= entity.States.Patrolling.presence
)
-- One-shots the server plays by name.
for _, name in
	{
		"CopyDistant",
		"CopySearch",
		"CopyAlert",
		"CopyAttack",
		"CopyLost",
		"CopyFinal",
		"Caught",
		"Whoosh",
		"DoorOpen",
		"DoorClose",
		"DoorLocked",
		"HeavyDoorOpen",
		"SwitchFlip",
		"BreakerEngage",
		"BreakerTrip",
		"PowerOn",
		"PowerDown",
		"RelayClick",
		"MachineryStart",
		"WarningBeep",
		"LightFlicker",
		"FuseInsert",
		"TerminalBeep",
		"TerminalBoot",
		"AccessDenied",
		"AccessGranted",
		"KeypadPress",
		"RadioTune",
		"RadioStaticBurst",
		"RadioInterference",
		"RadioWhisper",
		"RadioVoice",
		"FinalSignal",
		"ElevatorStart",
		"DocumentOpen",
		"ItemPickup",
		"BatteryInsert",
		"FlashlightClick",
		"ObjectiveComplete",
		"DistantMetal1",
	}
do
	exists("used by game code", name)
end

-- ---- Transmissions ----
local sequences: { [string]: { any } } = {
	GeneratorReadout = Transmissions.GeneratorReadout,
	FirstContact = Transmissions.FirstContact,
	Trace = Transmissions.trace(3),
	Reply = Transmissions.Reply,
	Evacuation = Transmissions.Evacuation,
	FinalWords = Transmissions.FinalWords,
}
for name, steps in sequences do
	local seconds = 0
	for index, step in steps do
		check(`{name} step {index}: has a duration`, type(step.hold) == "number" and step.hold > 0)
		if step.cue then
			exists(`{name} step {index}`, step.cue)
		end
		seconds += step.hold
	end
	check(`{name}: lasts between 8 and 60 seconds`, seconds >= 8 and seconds <= 60)
end
do
	local silences = 0
	for _, step in Transmissions.FirstContact do
		if not step.text then
			silences += 1
		end
	end
	check("the first transmission has pauses between its lines", silences >= 2)
	local final = false
	for _, step in Transmissions.FinalWords do
		final = final or step.cue == "FinalSignal"
	end
	check("the ending plays the final signal", final)
	local last = Transmissions.FinalWords[#Transmissions.FinalWords - 1]
	check("the ending closes on a spoken line", last.text == "RADIO_FINAL_6")
end

-- ---- Noise ----
for name, noise in NoiseConfig.Events do
	check(`noise {name}: has a radius`, noise.radius > 0)
	check(`noise {name}: interval is sensible`, noise.interval == nil or noise.interval > 0)
end
for _, name in
	{
		"Sprint",
		"DoorPass",
		"DoorLocked",
		"DoorUnlock",
		"BreakerEngage",
		"BreakerTrip",
		"PowerStart",
		"SwitchFlip",
		"Overload",
		"Machinery",
		"Radio",
		"Terminal",
		"KeypadDenied",
		"TunerMiss",
		"Transmission",
		"Evacuation",
	}
do
	check(`noise {name} is configured`, NoiseConfig.Events[name] ~= nil)
end
check(
	"a mistake is louder than doing it right",
	NoiseConfig.Events.BreakerTrip.radius > NoiseConfig.Events.BreakerEngage.radius
)
check(
	"running is quieter than machinery",
	NoiseConfig.Events.Sprint.radius < NoiseConfig.Events.Machinery.radius
)

print(`{withAsset} cue(s) with an audio asset; placeholders: {table.concat(placeholders, ", ")}`)
print(`{total - failures}/{total} checks passed`)
if failures > 0 then
	error("audio tests failed")
end
