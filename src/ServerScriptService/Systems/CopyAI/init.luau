--!strict
-- THE COPY: a server-controlled entity in the world. This module runs its think loop and
-- connects its parts:
--   Brain       decides which state it is in (pure rules, unit tested)
--   Escalation  how angry it is; set by mission progress, forward only
--   Senses      line of sight, the map's points, where it may appear   (Vision: the numbers)
--   Attention   which player it concentrates on                        (Targeting: the rules)
--   Listener    the noises it heard and scripted summons               (Hearing: the rules)
--   Memory      the last known position and how sure it still is
--   Arrival     whether and where it comes into the world
--   Walker      its routes and its legs       (Planner, Patrol: the plans; Navigator: paths)
--   Presence    the one model, its state attributes, the dread value   (Body: the model)
--   Reactions   sounds, effects and notifications
--
-- There is exactly one entity for the whole server. Other systems talk to it only through
-- noise (NoiseService) and the few functions at the bottom of this file. Clients never
-- control it; they see the replicated model, its state attribute and a per-player "dread"
-- value. It is never omniscient: it knows only what it sees (line of sight, field of view,
-- light) and an approximate place for what it hears.
--
-- Every state change, appearance, refusal to appear, stage change, target change, heard
-- noise and search plan is logged as [TLS:THE_COPY].

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CopyConfig = require(ReplicatedStorage.Config.CopyConfig)
local GameState = require(ReplicatedStorage.Shared.GameState)
local Logger = require(ReplicatedStorage.Shared.Logger)
local NoiseService = require(script.Parent.Parent.Services.NoiseService)
local SessionService = require(script.Parent.Parent.Services.SessionService)
local WorldService = require(script.Parent.Parent.Services.WorldService)
local Arrival = require(script.Arrival)
local Attention = require(script.Attention)
local Brain = require(script.Brain)
local Escalation = require(script.Escalation)
local Listener = require(script.Listener)
local Memory = require(script.Memory)
local Navigator = require(script.Navigator)
local Presence = require(script.Presence)
local Reactions = require(script.Reactions)
local Senses = require(script.Senses)
local Walker = require(script.Walker)

local THINK_INTERVAL = 0.1

local log = Logger.new("THE_COPY")

local CopyAI = {}

local brain = Brain.new(CopyConfig)
local nav = Presence.nav
local escalation = Escalation.new()
local settings: CopyConfig.StageSettings = CopyConfig.Stages.Dormant
local memory: Memory.Memory<Vector3> = Memory.new()

local running = true
local lastEncounter = os.clock()
local thinkTimer = 0

local appearPoint: Vector3? = nil
local appearFacing: Vector3? = nil
-- A scripted sighting: it turns toward the closest player like a staged scare should.
local scripted = false
local living: { Senses.Living } = {}

local function active(): boolean
	return running and CopyConfig.Enabled and SessionService.isPlaying()
end

-- States in which nothing it hears can pull it away.
local function isBusy(): boolean
	local state = brain.state
	return Brain.isChasing(brain) or state == "Stalking" or state == "Disappearing"
end

local function onEnter(state: Brain.State, previous: Brain.State, seen: Senses.Seen?)
	log:info(`State: {previous} -> {state}`)
	Presence.publishState(state)

	if previous == "Dormant" then
		local point = appearPoint or nav.position
		Presence.appearAt(point, appearFacing)
		log:info(`Spawn successful: {Presence.roomAt(point)}`)
		Reactions.appeared(point, false)
	end

	if state == "Dormant" then
		Presence.hide()
		Attention.release()
		Listener.reset()
		Memory.forget(memory)
		Walker.clear()
		appearPoint = nil
		scripted = false
		lastEncounter = os.clock()
	elseif state == "Observing" then
		Navigator.stop(nav)
	elseif state == "Disappearing" then
		Navigator.stop(nav)
		Reactions.vanishing(nav.position)
	elseif state == "Patrolling" then
		Walker.startPatrol(settings.PatrolPoints)
	elseif state == "Investigating" then
		Walker.goTo(memory.position)
	elseif state == "Searching" then
		Walker.startSearch(memory, settings.SearchPoints)
		Reactions.searching(nav.position)
	elseif state == "Pursuing" then
		-- A chase that simply goes on (after a missed attack, or sight regained at once)
		-- has no warning: it keeps walking.
		if brain.warningTime > 0 then
			Navigator.stop(nav)
			Reactions.pursuitWarning(
				nav.position,
				if seen then seen.player else nil,
				brain.warningTime
			)
		end
	elseif state == "Attacking" then
		Navigator.stop(nav)
		Reactions.attack(nav.position)
	elseif state == "LostTarget" then
		Reactions.lostTarget(nav.position)
		Walker.goTo(memory.position)
	elseif state == "Returning" then
		Walker.leave(living)
	end
end

local function think(dt: number)
	local playing = active()
	living = if playing then Senses.livingPlayers() else {}
	local present = brain.state ~= "Dormant"

	-- Sight and the choice of target. It turns to whoever it is watching when standing.
	local seen: Senses.Seen? = nil
	local targetChanged = false
	if present and playing then
		seen, targetChanged = Attention.update(
			dt,
			Presence.eye(),
			nav.facing,
			Presence.model,
			settings.DetectionScale,
			living
		)
	else
		Attention.rest(dt)
	end
	if seen then
		Memory.remember(memory, seen.root.Position, 1)
		if not Navigator.isBusy(nav) then
			Navigator.face(nav, seen.root.Position)
		end
		if targetChanged and Brain.isChasing(brain) then
			Reactions.noticed(seen.player)
		end
	end

	local nearest = math.huge
	local nearestPosition: Vector3? = nil
	for _, entry in living do
		local distance = (entry.root.Position - nav.position).Magnitude
		if distance < nearest then
			nearest = distance
			nearestPosition = entry.root.Position
		end
	end

	-- Hearing: an approximate place, and never while it is busy with a player.
	if Listener.summonExpired() then
		log:info("Summon dropped: it found no fair way to answer it in time")
	end
	local heard = if playing then Listener.take(not isBusy()) else nil
	local interval = settings.VisitInterval
	local wake = interval ~= nil and os.clock() - lastEncounter >= interval
	if not present then
		appearPoint, appearFacing = nil, nil
		if #living > 0 then
			appearPoint, appearFacing =
				Arrival.consider(brain, memory, heard, wake, nearestPosition)
		end
	elseif heard then
		Memory.remember(memory, heard.estimate, Arrival.certaintyOf(heard))
		Attention.noteNoise(heard.source, living)
		Arrival.logHeard(heard)
		if heard.name == Listener.SUMMON then
			Listener.clearSummon()
		end
	end

	local previous: Brain.State = brain.state
	local state: Brain.State = Brain.update(brain, dt, {
		playersPresent = #living > 0,
		canAppear = appearPoint ~= nil,
		noise = heard ~= nil and (present or appearPoint ~= nil),
		wakeRequested = wake,
		seesTarget = seen ~= nil,
		targetDistance = if seen then seen.distance else math.huge,
		nearestDistance = nearest,
		arrived = Navigator.hasArrived(nav),
		pathFailed = nav.failed,
		pursuitArmed = settings.Pursues,
		patrolArmed = settings.Patrols,
		stalkArmed = settings.Stalks,
		detectionRate = if seen then seen.rate else 1,
		inReach = seen ~= nil and seen.distance <= (if brain.state == "Attacking"
			then CopyConfig.AttackReach
			else CopyConfig.CatchDistance),
		routeDone = previous == "Patrolling" and Walker.isDone(),
		searchDone = previous == "Searching" and (Memory.isSpent(memory) or Walker.isDone()),
	})

	if brain.caught and seen then
		log:info(`{seen.player.Name} was caught`)
		Reactions.caught(seen.player)
		Attention.markCaught(seen.player)
	end
	if state ~= previous then
		onEnter(state, previous, seen)
	elseif state == "Investigating" and heard then
		-- Something louder than what it was walking to: it changes course.
		Walker.goTo(heard.estimate)
	end
	if state == "Searching" then
		-- Its certainty fades only while it searches; at 0 the search is over.
		Memory.decay(memory, dt, settings.MemoryTime)
	end

	Walker.act(brain, memory, seen, if scripted then nearestPosition else nil)
	Presence.updateDread(
		state ~= "Dormant",
		if Brain.isChasing(brain) then Attention.target() else nil
	)
end

-- Raises the escalation stage to `stage` ("Aware", "Hunting", "Hostile", "FinalPursuit").
-- Stages are passed through one at a time and never go back; asking for the current or an
-- earlier stage does nothing.
function CopyAI.setStage(stage: string)
	local steps = Escalation.advanceTo(escalation, stage, function(from, to)
		log:info(`Escalation: {string.upper(from)} -> {string.upper(to)}`)
	end)
	if steps == 0 then
		return
	end
	local current = Escalation.stage(escalation)
	settings = CopyConfig.Stages[current]
	Brain.tune(brain, {
		LoseSightTime = settings.LoseSightTime,
		EncounterCooldown = settings.Cooldown,
		SearchDuration = settings.MemoryTime,
	})
	ReplicatedStorage:SetAttribute(GameState.COPY_STAGE_ATTRIBUTE, current)
	if current == "FinalPursuit" then
		Reactions.finalPursuit()
	end

	-- Each escalation is felt soon: no leftover quiet time, and the next visit is near.
	Brain.clearCooldown(brain)
	local interval = settings.VisitInterval
	if interval then
		lastEncounter = os.clock() - interval * 0.6
	end
end

function CopyAI.getStage(): Escalation.Stage
	return Escalation.stage(escalation)
end

function CopyAI.getStageSettings(): CopyConfig.StageSettings
	return settings
end

-- Stops everything; it fades out if it is in the world.
function CopyAI.shutdown()
	running = false
end

function CopyAI.getState(): Brain.State
	return brain.state
end

-- True while it is in the world, in any state.
function CopyAI.isOut(): boolean
	return brain.state ~= "Dormant"
end

-- Scripted sighting: it stands at `position` watching, then vanishes after `seconds` or as
-- soon as a player comes within `fleeDistance`. Returns false if it is already out.
function CopyAI.stageSighting(position: Vector3, seconds: number, fleeDistance: number): boolean
	log:info(`Spawn requested (scripted sighting) in {Presence.roomAt(position)}`)
	if not CopyConfig.Enabled then
		log:info("Spawn failed: CopyConfig.Enabled is false")
		return false
	elseif brain.state ~= "Dormant" then
		log:info(`Spawn failed: it is already in the world ({brain.state})`)
		return false
	end
	local point = Senses.ground(position)
	Presence.appearAt(point, nil)
	scripted = true
	Brain.stage(brain, seconds, fleeDistance)
	Presence.publishState(brain.state)
	log:info(`Spawn successful: {Presence.roomAt(point)}`)
	log:info("State: Dormant -> Observing (scripted sighting)")
	Reactions.appeared(point, true)
	return true
end

-- Scripted encounter: it comes to investigate `position` as if it had heard something very
-- loud there, skipping the quiet time after its last encounter. It still appears only at a
-- fair point (out of sight, far from every player) and keeps trying for a while if there
-- is none. If it is already out it changes course as soon as it can be interrupted; a
-- chase is never interrupted. Returns whether the request was accepted.
function CopyAI.summon(position: Vector3, reason: string): boolean
	if not active() then
		log:info(`Summon refused ({reason}): the mission is not running or it is disabled`)
		return false
	elseif Brain.isChasing(brain) then
		log:info(`Summon refused ({reason}): it is busy ({brain.state})`)
		return false
	end
	log:info(`Summon accepted ({reason}): {Presence.roomAt(position)}`)
	Listener.summon(Senses.ground(position), reason)
	return true
end

function CopyAI.Start(_self: any)
	ReplicatedStorage:SetAttribute(GameState.COPY_STAGE_ATTRIBUTE, Escalation.stage(escalation))
	Presence.publishState(brain.state)
	Attention.watchPlayers()

	NoiseService.heard:Connect(function(position: Vector3, radius: number, name: string)
		if active() then
			local out = brain.state ~= "Dormant"
			Listener.offer(position, radius, name, out, isBusy(), nav.position, settings)
		end
	end)

	WorldService.onReady(function()
		local points = #Senses.vantagePoints()
		if points == 0 then
			log:warn(
				"Spawn failed: the map has no TLS_CopyVantage markers, so it has nowhere to appear. "
					.. "Regenerate the map (docs/MAP_GENERATOR.md)."
			)
		else
			log:info(
				`AI initialized: {points} observation points, stage {Escalation.stage(escalation)}`
			)
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		thinkTimer += dt
		if thinkTimer >= THINK_INTERVAL then
			think(thinkTimer)
			thinkTimer = 0
		end
		Walker.move(brain, dt, settings.PursueSpeed)
	end)
end

return CopyAI
