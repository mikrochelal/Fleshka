--!strict
-- Which player THE COPY concentrates on when there are several (1-4 players). Candidates
-- are only players it perceives. It keeps its target unless another candidate is clearly
-- better and the current one has been held for a minimum time, ignores a player it has
-- just caught, and slowly loses interest in whoever it has been after for a long time.
-- No Roblox API (players are opaque ids), unit tested in tests/copy.luau.

export type Config = {
	TargetSwitchMargin: number,
	TargetCommitTime: number,
	CaughtGraceTime: number,
	TargetVisibleScore: number,
	TargetDistanceScore: number,
	TargetRange: number,
	TargetNoiseScore: number,
	TargetNoiseMemory: number,
	TargetAttentionPenalty: number,
	TargetAttentionTime: number,
}

export type Candidate<T> = {
	id: T,
	visible: boolean,
	distance: number,
	-- Seconds since this player last made a noise it heard (nil = none).
	noiseAge: number?,
}

export type Targeting<T> = {
	current: T?,
	-- How long the current target has been held.
	held: number,
	-- Seconds of attention each player has had; fades while it is on someone else.
	attention: { [T]: number },
	-- Seconds left during which a caught player is ignored.
	grace: { [T]: number },
}

local Targeting = {}

function Targeting.new<T>(): Targeting<T>
	return { current = nil, held = 0, attention = {}, grace = {} }
end

function Targeting.score<T>(candidate: Candidate<T>, attention: number, config: Config): number
	local score = 0
	if candidate.visible then
		score += config.TargetVisibleScore
	end
	score += config.TargetDistanceScore
		* (1 - math.clamp(candidate.distance / config.TargetRange, 0, 1))
	local age = candidate.noiseAge
	if age and age < config.TargetNoiseMemory then
		score += config.TargetNoiseScore * (1 - age / config.TargetNoiseMemory)
	end
	score -= config.TargetAttentionPenalty
		* math.clamp(attention / config.TargetAttentionTime, 0, 1)
	return score
end

-- Runs the clocks. Call it on every think, even when there is nobody to choose from.
function Targeting.tick<T>(state: Targeting<T>, dt: number)
	for id, left in state.grace do
		state.grace[id] = if left > dt then left - dt else nil
	end
	for id, attention in state.attention do
		if id == state.current then
			state.attention[id] = attention + dt
		else
			-- Interest in the others comes back at half the speed it was lost.
			state.attention[id] = if attention > dt / 2 then attention - dt / 2 else nil
		end
	end
	if state.current ~= nil then
		state.held += dt
	end
end

function Targeting.isIgnored<T>(state: Targeting<T>, id: T): boolean
	return state.grace[id] ~= nil
end

local function switch<T>(state: Targeting<T>, id: T?)
	state.current = id
	state.held = 0
	if id ~= nil and state.attention[id] == nil then
		state.attention[id] = 0
	end
end

-- Chooses among the candidates. Returns the target and, when it changed, the reason.
function Targeting.choose<T>(
	state: Targeting<T>,
	candidates: { Candidate<T> },
	config: Config
): (T?, string?)
	local best: Candidate<T>? = nil
	local bestScore = -math.huge
	local currentScore: number? = nil
	for _, candidate in candidates do
		if state.grace[candidate.id] == nil then
			local score = Targeting.score(candidate, state.attention[candidate.id] or 0, config)
			if candidate.id == state.current then
				currentScore = score
			end
			if score > bestScore then
				best = candidate
				bestScore = score
			end
		end
	end

	local current = state.current
	if not best then
		if current ~= nil then
			switch(state, nil)
			return nil, "nobody left to follow"
		end
		return nil, nil
	elseif current == nil then
		switch(state, best.id)
		return best.id, "first one it noticed"
	elseif currentScore == nil then
		switch(state, best.id)
		return best.id, "the previous target is gone"
	elseif
		best.id ~= current
		and state.held >= config.TargetCommitTime
		and bestScore > currentScore + config.TargetSwitchMargin
	then
		switch(state, best.id)
		return best.id, "a clearly better target"
	end
	return current, nil
end

-- The player was just caught: dropped as the target and ignored for a while.
function Targeting.markCaught<T>(state: Targeting<T>, id: T, config: Config)
	state.grace[id] = config.CaughtGraceTime
	if state.current == id then
		switch(state, nil)
	end
end

-- Drops the current target but keeps the attention and grace clocks.
function Targeting.release<T>(state: Targeting<T>)
	switch(state, nil)
end

-- Forgets a player completely (they left the game).
function Targeting.forget<T>(state: Targeting<T>, id: T)
	state.grace[id] = nil
	state.attention[id] = nil
	if state.current == id then
		switch(state, nil)
	end
end

return Targeting
