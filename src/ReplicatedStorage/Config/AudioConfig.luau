--!strict
-- Every sound in the game is defined here, so a sound can be replaced without touching
-- gameplay code: change its number in ASSETS and nothing else.
--
-- ASSETS holds Roblox audio asset ids. Every id listed was looked up in the Creator Store
-- and is recorded in ASSET_MANIFEST.md with its name and creator; none was guessed. A cue
-- whose id is 0 has no asset yet: it is a documented placeholder, is skipped silently and
-- is listed under "Missing" in the manifest. Never invent ids.
--
-- Footsteps are the default Roblox character sounds and need no entry.

export type Group = "Ambience" | "Effects" | "Radio" | "Entity" | "Interface"

export type Cue = {
	id: string,
	group: Group,
	volume: number,
	looped: boolean?,
	speed: number?,
	-- Positional sounds: full volume inside `min` studs, silent beyond `max`.
	min: number?,
	max: number?,
	-- Minimum seconds between two plays of the cue (per client, and per server broadcast).
	cooldown: number?,
}

-- cue name -> asset id (0 = no asset chosen yet).
local ASSETS: { [string]: number } = {
	-- Ambience loops.
	AmbRoomTone = 0,
	AmbVentilation = 0,
	AmbElectricalHum = 0,
	AmbMachineryDistant = 0,
	AmbPipes = 0,
	AmbServerRoom = 0,
	AmbFluorescent = 0,
	AmbTunnel = 0,
	AmbSource = 0,
	-- Positional loops.
	GeneratorLoop = 0,
	FanLoop = 0,
	RadioStaticLoop = 0,
	ElevatorLoop = 0,
	AlarmLoop = 0,
	-- Distant one-shots.
	DistantMetal1 = 0,
	DistantMetal2 = 0,
	DistantMetal3 = 0,
	-- Doors.
	DoorOpen = 0,
	DoorClose = 0,
	DoorLocked = 0,
	HeavyDoorOpen = 0,
	-- Controls and machinery.
	ButtonPress = 0,
	SwitchFlip = 0,
	BreakerEngage = 0,
	BreakerTrip = 0,
	PowerOn = 0,
	PowerDown = 0,
	RelayClick = 0,
	MachineryStart = 0,
	LightFlicker = 0,
	FuseInsert = 0,
	ElevatorStart = 0,
	-- Terminals and locks.
	TerminalBeep = 0,
	TerminalBoot = 0,
	KeypadPress = 0,
	AccessDenied = 0,
	AccessGranted = 0,
	WarningBeep = 0,
	-- Interface and pickups.
	DocumentOpen = 0,
	ItemPickup = 0,
	BatteryInsert = 0,
	FlashlightClick = 0,
	-- Radio.
	RadioStaticBurst = 0,
	RadioInterference = 0,
	RadioVoice = 0,
	RadioWhisper = 0,
	RadioTune = 0,
	FinalSignal = 0,
	-- THE COPY.
	CopyPresenceLoop = 0,
	CopyFootstepsLoop = 0,
	HeartbeatLoop = 0,
	CopyDistant = 0,
	CopySearch = 0,
	CopyAlert = 0,
	CopyAttack = 0,
	CopyLost = 0,
	CopyFinal = 0,
	Caught = 0,
	Whoosh = 0,
}

local function cue(name: string, group: Group, volume: number, options: { [string]: any }?): Cue
	local asset = ASSETS[name]
	assert(asset ~= nil, `AudioConfig: cue "{name}" has no ASSETS entry`)
	local settings: { [string]: any } = options or {}
	return {
		id = if asset == 0 then "" else `rbxassetid://{asset}`,
		group = group,
		volume = volume,
		looped = settings.looped,
		speed = settings.speed,
		min = settings.min,
		max = settings.max,
		cooldown = settings.cooldown,
	}
end

local LOOP = { looped = true }

local cues: { [string]: Cue } = {
	-- Ambience (not positional; mixed by Controllers/AmbienceController).
	AmbRoomTone = cue("AmbRoomTone", "Ambience", 0.32, LOOP),
	AmbVentilation = cue("AmbVentilation", "Ambience", 0.22, LOOP),
	AmbElectricalHum = cue("AmbElectricalHum", "Ambience", 0.12, LOOP),
	AmbMachineryDistant = cue("AmbMachineryDistant", "Ambience", 0.2, LOOP),
	AmbPipes = cue("AmbPipes", "Ambience", 0.24, LOOP),
	AmbServerRoom = cue("AmbServerRoom", "Ambience", 0.22, LOOP),
	AmbFluorescent = cue("AmbFluorescent", "Ambience", 0.14, LOOP),
	AmbTunnel = cue("AmbTunnel", "Ambience", 0.26, LOOP),
	AmbSource = cue("AmbSource", "Ambience", 0.34, LOOP),

	-- Positional loops (played at emitters, see Emitters below).
	GeneratorLoop = cue("GeneratorLoop", "Effects", 0.7, { looped = true, min = 12, max = 110 }),
	FanLoop = cue("FanLoop", "Effects", 0.6, { looped = true, min = 10, max = 90 }),
	TransformerLoop = cue(
		"AmbElectricalHum",
		"Effects",
		0.5,
		{ looped = true, min = 6, max = 45 }
	),
	ServerLoop = cue("AmbServerRoom", "Effects", 0.5, { looped = true, min = 8, max = 50 }),
	PipeLoop = cue("AmbPipes", "Effects", 0.5, { looped = true, min = 6, max = 50 }),
	SourceLoop = cue("AmbSource", "Effects", 0.8, { looped = true, min = 16, max = 120 }),
	RadioStaticLoop = cue("RadioStaticLoop", "Radio", 0.45, { looped = true, min = 5, max = 60 }),
	ElevatorLoop = cue("ElevatorLoop", "Effects", 0.7, { looped = true, min = 10, max = 90 }),
	AlarmLoop = cue("AlarmLoop", "Effects", 0.55, { looped = true, min = 20, max = 220 }),

	-- Distant, unexplained noises (Ambient.Random below).
	DistantMetal1 = cue("DistantMetal1", "Ambience", 0.5, { min = 20, max = 160 }),
	DistantMetal2 = cue("DistantMetal2", "Ambience", 0.45, { min = 20, max = 160 }),
	DistantMetal3 = cue("DistantMetal3", "Ambience", 0.5, { min = 20, max = 160 }),

	-- Doors.
	DoorOpen = cue("DoorOpen", "Effects", 0.6, { min = 6, max = 70, cooldown = 0.4 }),
	DoorClose = cue("DoorClose", "Effects", 0.6, { min = 6, max = 70, cooldown = 0.4 }),
	DoorLocked = cue("DoorLocked", "Effects", 0.6, { min = 5, max = 50, cooldown = 0.6 }),
	HeavyDoorOpen = cue("HeavyDoorOpen", "Effects", 0.85, { min = 12, max = 140 }),

	-- Controls and machinery.
	ButtonPress = cue("ButtonPress", "Effects", 0.5, { min = 4, max = 40, cooldown = 0.1 }),
	SwitchFlip = cue("SwitchFlip", "Effects", 0.7, { min = 5, max = 60, cooldown = 0.15 }),
	BreakerEngage = cue("BreakerEngage", "Effects", 0.75, { min = 6, max = 70 }),
	BreakerTrip = cue("BreakerTrip", "Effects", 0.9, { min = 8, max = 110 }),
	PowerOn = cue("PowerOn", "Effects", 1, { min = 20, max = 260 }),
	PowerDown = cue("PowerDown", "Effects", 0.9, { min = 20, max = 200 }),
	RelayClick = cue("RelayClick", "Effects", 0.7, { min = 6, max = 80, cooldown = 0.2 }),
	MachineryStart = cue("MachineryStart", "Effects", 0.85, { min = 14, max = 180 }),
	LightFlicker = cue("LightFlicker", "Effects", 0.4, { min = 6, max = 80, cooldown = 1.5 }),
	FuseInsert = cue("FuseInsert", "Effects", 0.7, { min = 5, max = 50 }),
	ElevatorStart = cue("ElevatorStart", "Effects", 0.9, { min = 12, max = 150 }),

	-- Terminals and locks.
	TerminalBeep = cue("TerminalBeep", "Effects", 0.5, { min = 5, max = 45, cooldown = 0.2 }),
	TerminalBoot = cue("TerminalBoot", "Effects", 0.55, { min = 6, max = 60 }),
	KeypadPress = cue("KeypadPress", "Interface", 0.4, { cooldown = 0.05 }),
	AccessDenied = cue("AccessDenied", "Effects", 0.7, { min = 6, max = 70 }),
	AccessGranted = cue("AccessGranted", "Effects", 0.7, { min = 6, max = 70 }),
	WarningBeep = cue("WarningBeep", "Effects", 0.6, { min = 10, max = 120, cooldown = 0.5 }),

	-- Interface and pickups (heard only by the player who caused them).
	DocumentOpen = cue("DocumentOpen", "Interface", 0.5),
	ItemPickup = cue("ItemPickup", "Interface", 0.5),
	BatteryInsert = cue("BatteryInsert", "Interface", 0.5),
	FlashlightClick = cue("FlashlightClick", "Interface", 0.4, { cooldown = 0.05 }),
	ObjectiveComplete = cue("TerminalBeep", "Interface", 0.35, { speed = 0.8, cooldown = 1 }),

	-- Radio.
	RadioStaticBurst = cue("RadioStaticBurst", "Radio", 0.6, { min = 8, max = 80 }),
	RadioInterference = cue("RadioInterference", "Radio", 0.6, { min = 8, max = 90 }),
	RadioVoice = cue("RadioVoice", "Radio", 0.8, { min = 8, max = 90 }),
	RadioWhisper = cue("RadioWhisper", "Radio", 0.7, { min = 8, max = 90 }),
	RadioTune = cue("RadioTune", "Radio", 0.5, { min = 5, max = 50, cooldown = 0.15 }),
	-- The ending: a rising, distorted, scream-like signal. Not positional.
	FinalSignal = cue("FinalSignal", "Radio", 1),

	-- THE COPY (the loops are attached to its body by Controllers/CopyAudioController).
	CopyPresenceLoop = cue(
		"CopyPresenceLoop",
		"Entity",
		0.6,
		{ looped = true, min = 8, max = 75 }
	),
	CopyFootstepsLoop = cue(
		"CopyFootstepsLoop",
		"Entity",
		0.8,
		{ looped = true, min = 8, max = 85 }
	),
	HeartbeatLoop = cue("HeartbeatLoop", "Entity", 0.5, LOOP),
	CopyDistant = cue("CopyDistant", "Entity", 0.55, { min = 30, max = 260, cooldown = 8 }),
	CopySearch = cue("CopySearch", "Entity", 0.7, { min = 10, max = 100, cooldown = 6 }),
	CopyAlert = cue("CopyAlert", "Entity", 0.9, { min = 20, max = 160, cooldown = 3 }),
	CopyAttack = cue("CopyAttack", "Entity", 1, { min = 10, max = 90, cooldown = 1 }),
	CopyLost = cue("CopyLost", "Entity", 0.6, { min = 10, max = 90, cooldown = 6 }),
	CopyFinal = cue("CopyFinal", "Entity", 1, { min = 40, max = 400, cooldown = 10 }),
	Caught = cue("Caught", "Entity", 1),
	Whoosh = cue("Whoosh", "Entity", 0.6, { min = 8, max = 70, cooldown = 1 }),
}

export type RoomAmbience = { cue: string, volume: number, needsPower: boolean? }

export type Emitter = {
	id: string,
	room: string,
	-- Position inside the room as fractions of its footprint (like Data/PropList), and the
	-- height above the floor.
	fx: number,
	fz: number,
	y: number,
	cue: string,
	-- Whether the emitter is sounding when the session starts.
	active: boolean,
}

return table.freeze({
	-- Mixer: one SoundGroup per name is created under SoundService.
	Groups = table.freeze({
		Ambience = 0.9,
		Effects = 1,
		Radio = 1,
		Entity = 1,
		Interface = 0.8,
	} :: { [string]: number }),

	Cues = table.freeze(cues),

	Ambient = table.freeze({
		-- Seconds a layer takes to fade in or out.
		FadeSeconds = 3,
		-- Always present while the mission runs.
		Base = table.freeze({ "AmbRoomTone" }),
		-- Added once emergency power is back: the station's systems come alive.
		Powered = table.freeze({ "AmbVentilation", "AmbElectricalHum" }),
		-- Room tone by the first letter of the room name (the wing)...
		Areas = table.freeze({
			C = { cue = "AmbFluorescent", volume = 1, needsPower = true },
			D = { cue = "AmbServerRoom", volume = 0.8, needsPower = true },
			E = { cue = "AmbFluorescent", volume = 0.9, needsPower = true },
			F = { cue = "AmbTunnel", volume = 0.6 },
			G = { cue = "AmbMachineryDistant", volume = 1, needsPower = true },
			H = { cue = "AmbTunnel", volume = 0.9 },
		} :: { [string]: RoomAmbience }),
		-- ...unless the room itself is listed here.
		Rooms = table.freeze({
			B_ServiceTunnel = { cue = "AmbTunnel", volume = 1 },
			G_PipeTunnel = { cue = "AmbPipes", volume = 1 },
			G_Ventilation = { cue = "AmbVentilation", volume = 1.6, needsPower = true },
			C_ColdStorage = { cue = "AmbMachineryDistant", volume = 0.7, needsPower = true },
			H_ObservationChamber = { cue = "AmbSource", volume = 0.7 },
			H_SignalSource = { cue = "AmbSource", volume = 1.2 },
		} :: { [string]: RoomAmbience }),
		-- Occasional distant noises from a random direction.
		Random = table.freeze({
			Cues = table.freeze({ "DistantMetal1", "DistantMetal2", "DistantMetal3" }),
			MinInterval = 22,
			MaxInterval = 55,
			MinDistance = 45,
			MaxDistance = 110,
		}),
	}),

	-- Positional sound sources placed in the world by Systems/AudioEmitters. Other systems
	-- switch them on and off by id.
	Emitters = table.freeze({
		{ id = "PowerRoomTransformer", room = "B_PowerRoom", fx = 0.28, fz = 0.6, y = 4, cue = "TransformerLoop", active = false },
		{ id = "Generator", room = "G_GeneratorHall", fx = 0.5, fz = 0.5, y = 5, cue = "GeneratorLoop", active = false },
		{ id = "Switchgear", room = "G_ElectricalControl", fx = 0.5, fz = 0.85, y = 4, cue = "TransformerLoop", active = false },
		{ id = "VentilationFan", room = "G_Ventilation", fx = 0.5, fz = 0.5, y = 5, cue = "FanLoop", active = false },
		{ id = "Pipes", room = "G_PipeTunnel", fx = 0.5, fz = 0.5, y = 6, cue = "PipeLoop", active = true },
		{ id = "Servers", room = "D_ServerRoom", fx = 0.7, fz = 0.5, y = 5, cue = "ServerLoop", active = false },
		{ id = "RadioReceiver", room = "B_MonitorRoom", fx = 0.85, fz = 0.5, y = 4, cue = "RadioStaticLoop", active = false },
		{ id = "RadioDesk", room = "D_RadioControl", fx = 0.5, fz = 0.5, y = 4, cue = "RadioStaticLoop", active = false },
		{ id = "SignalCore", room = "H_SignalSource", fx = 0.5, fz = 0.5, y = 8, cue = "SourceLoop", active = true },
		{ id = "FreightLift", room = "H_FreightElevator", fx = 0.5, fz = 0.5, y = 6, cue = "ElevatorLoop", active = false },
		{ id = "EvacuationAlarm", room = "H_CargoCorridor", fx = 0.5, fz = 0.5, y = 10, cue = "AlarmLoop", active = false },
	} :: { Emitter }),

	-- How THE COPY sounds in each behaviour state: footsteps playback speed (0 = standing
	-- still, no footsteps) and the volume of its presence loop.
	Entity = table.freeze({
		PresenceCue = "CopyPresenceLoop",
		FootstepsCue = "CopyFootstepsLoop",
		HeartbeatCue = "HeartbeatLoop",
		-- The heartbeat fades in above this dread level (0..1).
		HeartbeatFrom = 0.45,
		States = table.freeze({
			Observing = { steps = 0, presence = 0.6 },
			Patrolling = { steps = 0.8, presence = 0.7 },
			Investigating = { steps = 0.9, presence = 0.8 },
			Searching = { steps = 0.85, presence = 0.9 },
			Stalking = { steps = 0.6, presence = 0.5 },
			LostTarget = { steps = 0.7, presence = 0.9 },
			Returning = { steps = 0.8, presence = 0.6 },
			Pursuing = { steps = 1.5, presence = 1 },
			Attacking = { steps = 0, presence = 1 },
			Disappearing = { steps = 0, presence = 0.3 },
		} :: { [string]: { steps: number, presence: number } }),
	}),
})
