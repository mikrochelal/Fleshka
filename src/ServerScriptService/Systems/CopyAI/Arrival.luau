--!strict
-- How THE COPY comes into the world. While it is away, something has to bring it out (a
-- noise loud enough for the stage, a visit, a scripted summon), its quiet time has to be
-- over, and there has to be a fair place: an observation point out of every player's sight
-- and at least CopyConfig.MinAppearDistance from all of them. Otherwise it stays away and
-- tries again; it never appears in front of a player.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CopyConfig = require(ReplicatedStorage.Config.CopyConfig)
local Logger = require(ReplicatedStorage.Shared.Logger)
local Brain = require(script.Parent.Brain)
local Listener = require(script.Parent.Listener)
local Memory = require(script.Parent.Memory)
local Presence = require(script.Parent.Presence)
local Senses = require(script.Parent.Senses)

-- A refused appearance is retried every think; say why at most this often.
local FAILURE_LOG_INTERVAL = 15

local log = Logger.new("THE_COPY")

local Arrival = {}

local lastFailureLog = 0

-- Logs what it heard and how wrong its guess is.
function Arrival.logHeard(heard: Listener.Heard)
	if heard.name == Listener.SUMMON then
		log:info(`Summoned to {Presence.roomAt(heard.source)}`)
	else
		log:info(
			`Heard "{heard.name}" in {Presence.roomAt(heard.source)}; its guess is `
				.. `{math.floor(heard.error + 0.5)} studs off ({Presence.roomAt(heard.estimate)})`
		)
	end
end

-- How sure it is of a place it only heard about (a summon is known exactly).
function Arrival.certaintyOf(heard: Listener.Heard): number
	return if heard.name == Listener.SUMMON then 1 else CopyConfig.NoiseCertainty
end

-- Finds a fair place to appear near `interest`, logging the request and any refusal.
local function request(interest: Vector3, reason: string): Vector3?
	local point = Senses.pickAppearPoint(interest)
	local now = os.clock()
	if point then
		log:info(`Spawn requested ({reason}) near {Presence.roomAt(interest)}`)
	elseif now - lastFailureLog >= FAILURE_LOG_INTERVAL then
		lastFailureLog = now
		log:info(
			`Spawn failed: {reason} near {Presence.roomAt(interest)}, but no observation point `
				.. `is both out of sight and at least {CopyConfig.MinAppearDistance} studs from `
				.. "every player. It will keep trying."
		)
	end
	return point
end

-- Decides whether something brings it out this think. Returns the point to appear at (nil
-- = it stays away) and what it should face there. A noise that brings it out is stored in
-- `memory` so it knows where to go.
function Arrival.consider(
	brain: Brain.Brain,
	memory: Memory.Memory<Vector3>,
	heard: Listener.Heard?,
	wake: boolean,
	nearest: Vector3?
): (Vector3?, Vector3?)
	local summoned = heard ~= nil and heard.name == Listener.SUMMON
	if summoned then
		-- A scripted encounter does not wait for the quiet time to pass.
		Brain.clearCooldown(brain)
	end
	local interest = if heard then heard.estimate elseif wake then nearest else nil
	if not interest or brain.cooldown > 0 then
		return nil, nil
	end
	local reason = if summoned
		then `summoned: {Listener.summonReason() or "no reason given"}`
		elseif heard then `it heard "{heard.name}"`
		else "a visit"
	local point = request(interest, reason)
	if point and heard then
		Memory.remember(memory, heard.estimate, Arrival.certaintyOf(heard))
		Arrival.logHeard(heard)
		if summoned then
			Listener.clearSummon()
		end
	end
	return point, interest
end

return Arrival
