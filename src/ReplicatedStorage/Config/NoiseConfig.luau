--!strict
-- Noises THE COPY can hear. Only the events listed here make noise: ordinary actions
-- (walking, reading, picking things up, the flashlight) are silent to it. `radius` is how
-- far the noise carries, in studs; `interval` is the minimum time between two noises of
-- the same kind from the same source.
--
-- Emitters call NoiseService.make(name, position); see CopyConfig.Stages.WakeNoiseRadius
-- for what is loud enough to draw it out while it is away.

export type Noise = { radius: number, interval: number? }

local events: { [string]: Noise } = {
	-- Player movement.
	Sprint = { radius = 34, interval = 1 },
	-- Doors.
	DoorPass = { radius = 22, interval = 2 },
	DoorLocked = { radius = 30, interval = 1 },
	DoorUnlock = { radius = 70 },
	-- Power and machinery.
	BreakerEngage = { radius = 28 },
	BreakerTrip = { radius = 140 },
	PowerStart = { radius = 60 },
	SwitchFlip = { radius = 30 },
	Overload = { radius = 120 },
	Machinery = { radius = 110 },
	-- Electronics.
	Radio = { radius = 50 },
	Terminal = { radius = 26 },
	KeypadDenied = { radius = 70 },
	TunerMiss = { radius = 60 },
	-- Mission beats that are meant to be heard across the station.
	Transmission = { radius = 400 },
	Evacuation = { radius = 600 },
}

return table.freeze({ Events = table.freeze(events) })
