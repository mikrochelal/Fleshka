--!strict
-- THE COPY's eyesight as plain numbers: how far it can see a player, whether a direction is
-- inside its field of view, and how quickly it becomes sure of what it sees. No Roblox API
-- (the line-of-sight raycast is in Senses), unit tested in tests/copy.luau.

export type Config = {
	DetectionDistance: number,
	DetectionDistanceLit: number,
	DetectionDistanceDark: number,
	VisionAngle: number,
	CloseAwareness: number,
	DetectionRateNear: number,
	DetectionRateFar: number,
	DetectionRateLit: number,
	DetectionRateDark: number,
	DetectionRateSprint: number,
	DetectionRateMin: number,
	DetectionRateMax: number,
}

local Vision = {}

-- How far it can see a player: furthest when their flashlight is on, shortest in a dark
-- room with the flashlight off. `scale` is the stage's DetectionScale.
function Vision.range(
	config: Config,
	flashlightOn: boolean,
	roomLit: boolean,
	scale: number
): number
	local base = if flashlightOn
		then config.DetectionDistanceLit
		elseif roomLit then config.DetectionDistance
		else config.DetectionDistanceDark
	return base * scale
end

-- Whether the horizontal offset (dx, dz) to a player is inside the field of view around
-- the horizontal facing (fx, fz). Very close players are noticed whatever the facing.
function Vision.inView(
	config: Config,
	fx: number,
	fz: number,
	dx: number,
	dz: number,
	distance: number
): boolean
	if distance <= config.CloseAwareness then
		return true
	end
	local offsetLength = math.sqrt(dx * dx + dz * dz)
	local facingLength = math.sqrt(fx * fx + fz * fz)
	if offsetLength < 1e-3 or facingLength < 1e-3 then
		return true
	end
	local cosine = (dx * fx + dz * fz) / (offsetLength * facingLength)
	return cosine >= math.cos(math.rad(config.VisionAngle / 2))
end

-- Multiplier on how fast sight builds toward AcquireTime: quick when the player is close,
-- lit or sprinting, slow when far away in the dark.
function Vision.rate(
	config: Config,
	distance: number,
	range: number,
	flashlightOn: boolean,
	roomLit: boolean,
	sprinting: boolean
): number
	local far = if range > 0 then math.clamp(distance / range, 0, 1) else 1
	local rate = config.DetectionRateNear
		+ (config.DetectionRateFar - config.DetectionRateNear) * far
	if flashlightOn or roomLit then
		rate *= config.DetectionRateLit
	else
		rate *= config.DetectionRateDark
	end
	if sprinting then
		rate *= config.DetectionRateSprint
	end
	return math.clamp(rate, config.DetectionRateMin, config.DetectionRateMax)
end

return Vision
