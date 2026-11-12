--!strict
-- THE COPY's ears in the world: collects the noises announced through NoiseService between
-- two thinks, and holds a scripted summon until it can be answered. What counts as heard
-- and how wrong its guess is are decided by the pure Hearing rules.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CopyConfig = require(ReplicatedStorage.Config.CopyConfig)
local Hearing = require(script.Parent.Hearing)

export type Heard = {
	-- Where it thinks the noise came from, and where it really did.
	estimate: Vector3,
	source: Vector3,
	name: string,
	error: number,
}

-- Name under which a scripted summon is heard.
local SUMMON = "Summon"

local Listener = {}

Listener.SUMMON = SUMMON

local ear: Hearing.Ear<Vector3> = Hearing.new()
local random = Random.new()
local summon: { position: Vector3, reason: string, expires: number }? = nil

local function roll(): number
	return random:NextNumber()
end

-- A noise was made. `out`: it is in the world, standing at `position`. `busy`: it is
-- committed to a player and cannot be distracted.
function Listener.offer(
	source: Vector3,
	radius: number,
	name: string,
	out: boolean,
	busy: boolean,
	position: Vector3,
	settings: CopyConfig.StageSettings
)
	Hearing.offer(ear, os.clock(), source, radius, name, {
		out = out,
		busy = busy,
		distance = if out
			then (source - position).Magnitude
			else CopyConfig.HearingDormantDistance,
		wakeRadius = settings.WakeNoiseRadius,
		scale = settings.HearingScale,
		errorFactor = settings.HearingError,
		minError = CopyConfig.HearingMinError,
		maxError = CopyConfig.HearingMaxError,
		focusTime = CopyConfig.HearingFocusTime,
	}, roll)
end

-- Asks it to come to `position` as soon as it can be interrupted.
function Listener.summon(position: Vector3, reason: string)
	summon = {
		position = position,
		reason = reason,
		expires = os.clock() + CopyConfig.SummonPatience,
	}
end

-- The waiting summon's reason, or nil.
function Listener.summonReason(): string?
	return if summon then summon.reason else nil
end

-- True when the summon ran out of patience just now (it is dropped).
function Listener.summonExpired(): boolean
	if summon and os.clock() > summon.expires then
		summon = nil
		return true
	end
	return false
end

function Listener.clearSummon()
	summon = nil
end

-- What it reacts to this think: a waiting summon first (when `interruptible`), otherwise
-- the loudest noise since the last think. A summon is known exactly.
function Listener.take(interruptible: boolean): Heard?
	local now = os.clock()
	if summon and interruptible then
		Hearing.discard(ear)
		local position = summon.position
		return { estimate = position, source = position, name = SUMMON, error = 0 }
	end
	local heard = Hearing.take(ear, now)
	if not heard then
		return nil
	end
	return {
		estimate = heard.source + Vector3.new(heard.offsetX, 0, heard.offsetZ),
		source = heard.source,
		name = heard.name,
		error = heard.error,
	}
end

function Listener.reset()
	Hearing.reset(ear)
end

return Listener
