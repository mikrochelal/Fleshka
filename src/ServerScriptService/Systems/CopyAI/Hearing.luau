--!strict
-- THE COPY's hearing. It reacts only to noises announced through NoiseService, and it never
-- learns exactly where one came from: each accepted noise becomes an estimate that is off
-- by a random horizontal error, larger the further away the noise was and the worse the
-- stage's hearing is. No Roblox API (positions are handled by the caller as an opaque
-- value), unit tested in tests/copy.luau with an injected random function.

export type Context = {
	-- It is in the world. While it is away only loud noises count.
	out: boolean,
	-- It is chasing or attacking: nothing distracts it.
	busy: boolean,
	-- Distance from it to the noise.
	distance: number,
	-- Stage values.
	wakeRadius: number,
	scale: number,
	errorFactor: number,
	-- Limits on the error, and how long a noise it turned toward shuts out weaker ones.
	minError: number,
	maxError: number,
	focusTime: number,
}

export type Estimate<T> = {
	-- Where the noise really was. The caller must add the offset before using it.
	source: T,
	name: string,
	-- How far above the threshold of hearing it was.
	loudness: number,
	-- Horizontal offset of the estimate from the source, and its length.
	offsetX: number,
	offsetZ: number,
	error: number,
}

export type Ear<T> = {
	pending: Estimate<T>?,
	-- Loudness of the noise it last turned toward, and when.
	focus: number,
	focusedAt: number,
}

local Hearing = {}

function Hearing.new<T>(): Ear<T>
	return { pending = nil, focus = 0, focusedAt = -math.huge }
end

-- Whether a noise that carries `radius` studs can be heard at all.
function Hearing.audible(context: Context, radius: number): boolean
	if context.busy then
		return false
	elseif not context.out then
		return radius >= context.wakeRadius
	end
	return context.distance <= radius * context.scale
end

-- How wrong the estimate is, in studs: proportional to the distance and the stage's
-- error factor, between the limits, and never exact (`roll` is a random number in 0..1).
function Hearing.errorFor(context: Context, roll: number): number
	local spread =
		math.clamp(context.distance * context.errorFactor, context.minError, context.maxError)
	return spread * (0.5 + 0.5 * roll)
end

-- What is left of the last noise's hold on its attention at time `now`.
local function focusAt<T>(ear: Ear<T>, now: number, focusTime: number): number
	if focusTime <= 0 then
		return 0
	end
	local left = 1 - (now - ear.focusedAt) / focusTime
	return ear.focus * math.clamp(left, 0, 1)
end

-- Offers a noise. It is kept (replacing a weaker one that is still waiting) when it is
-- audible and louder than both the waiting noise and the one it recently turned toward.
-- Returns the estimate when the noise was kept.
function Hearing.offer<T>(
	ear: Ear<T>,
	now: number,
	source: T,
	radius: number,
	name: string,
	context: Context,
	random: () -> number
): Estimate<T>?
	if not Hearing.audible(context, radius) then
		return nil
	end
	local loudness = if context.out then radius * context.scale - context.distance else radius
	local pending = ear.pending
	if pending and pending.loudness >= loudness then
		return nil
	elseif context.out and loudness <= focusAt(ear, now, context.focusTime) then
		return nil
	end
	local error = Hearing.errorFor(context, random())
	local angle = random() * 2 * math.pi
	local estimate: Estimate<T> = {
		source = source,
		name = name,
		loudness = loudness,
		offsetX = math.cos(angle) * error,
		offsetZ = math.sin(angle) * error,
		error = error,
	}
	ear.pending = estimate
	return estimate
end

-- Takes the waiting noise, if any, and turns its attention to it.
function Hearing.take<T>(ear: Ear<T>, now: number): Estimate<T>?
	local pending = ear.pending
	ear.pending = nil
	if pending then
		ear.focus = pending.loudness
		ear.focusedAt = now
	end
	return pending
end

-- Drops the waiting noise without reacting to it.
function Hearing.discard<T>(ear: Ear<T>)
	ear.pending = nil
end

function Hearing.reset<T>(ear: Ear<T>)
	ear.pending = nil
	ear.focus = 0
	ear.focusedAt = -math.huge
end

return Hearing
