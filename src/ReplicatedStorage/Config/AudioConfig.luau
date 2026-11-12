--!strict
-- Every sound in the game is named here. No audio assets have been chosen yet, so every id
-- is empty: the audio system skips empty ids silently, and the game relies on subtitles,
-- lighting and screen effects instead. To add a sound, put a verified asset id here
-- ("rbxassetid://<number>") and record it in ASSET_MANIFEST.md. Never guess ids.
--
-- Footsteps are the default Roblox character sounds and need no entry.

export type Cue = { id: string, volume: number, looped: boolean?, rollOff: number? }

local function cue(volume: number, looped: boolean?, rollOff: number?): Cue
	return { id = "", volume = volume, looped = looped, rollOff = rollOff }
end

return table.freeze({
	-- Loops started on the client when play begins.
	Ambient = table.freeze({
		Ventilation = cue(0.25, true),
		ElectricalHum = cue(0.15, true),
	} :: { [string]: Cue }),

	-- One-shots requested by the server through the `Sound` event.
	Cues = table.freeze({
		Interact = cue(0.5),
		DocumentOpen = cue(0.5),
		BreakerEngage = cue(0.7, false, 60),
		BreakerTrip = cue(0.9, false, 90),
		PowerOn = cue(1, false, 200),
		RadioStatic = cue(0.6, false, 60),
		RadioVoice = cue(0.8, false, 60),
		DoorOpen = cue(0.6, false, 60),
		DoorClose = cue(0.6, false, 60),
		DistantMetal = cue(0.5, false, 150),
		LightFlicker = cue(0.4, false, 80),
		CopyPresence = cue(0.6, false, 120),
		CopyAlert = cue(0.9),
		Caught = cue(1),
		BatteryPickup = cue(0.5),
		FlashlightClick = cue(0.4),
		-- Machinery spinning up when power or a subsystem comes on.
		Machinery = cue(0.8, false, 160),
		-- The ending: a rising, distorted, voice-like signal - not a human scream.
		FinalSignal = cue(1),
	} :: { [string]: Cue }),
})
