--!strict
-- Where THE COPY is walking: the points left in its current search or patrol, what it
-- does with its legs in each state, and how fast. Path requests go through the Navigator,
-- which keeps them rare.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CopyConfig = require(ReplicatedStorage.Config.CopyConfig)
local Logger = require(ReplicatedStorage.Shared.Logger)
local Brain = require(script.Parent.Brain)
local Memory = require(script.Parent.Memory)
local Navigator = require(script.Parent.Navigator)
local Planner = require(script.Parent.Planner)
local Presence = require(script.Parent.Presence)
local Senses = require(script.Parent.Senses)

local log = Logger.new("THE_COPY")

local Walker = {}

local nav = Presence.nav
-- Points still to walk to in the current search or patrol.
local route: { Vector3 } = {}

local function nextPoint()
	local point = table.remove(route, 1)
	if point then
		Presence.walkTo(point)
	end
end

local function describe(points: { Vector3 }): string
	local rooms: { string } = {}
	for _, point in points do
		table.insert(rooms, Presence.roomAt(point))
	end
	return if #rooms > 0 then table.concat(rooms, " > ") else "nowhere"
end

function Walker.clear()
	route = {}
end

-- True when the search or patrol has no point left and it is standing still.
function Walker.isDone(): boolean
	return #route == 0 and not Navigator.isBusy(nav)
end

function Walker.startPatrol(points: number)
	route = Planner.patrolRoute(nav.position, points)
	log:info(`Patrol route: {describe(route)}`)
	nextPoint()
end

-- Plans a search around what it remembers and starts walking.
function Walker.startSearch(memory: Memory.Memory<Vector3>, places: number)
	local origin = memory.position or nav.position
	if Memory.isSpent(memory) then
		Memory.remember(memory, origin, CopyConfig.NoiseCertainty)
	end
	local plan, radius = Planner.searchPlan(origin, memory.certainty, places)
	route = plan
	log:info(
		`Search plan ({#plan} place(s) within {math.floor(radius)} studs, certainty `
			.. `{math.floor(memory.certainty * 100)}%): {describe(plan)}`
	)
	nextPoint()
end

-- Walks straight to one place, dropping whatever route it had.
function Walker.goTo(point: Vector3?)
	route = {}
	Presence.walkTo(point or nav.position)
end

-- Walks away to an observation point far from every player.
function Walker.leave(living: { Senses.Living })
	Walker.goTo(Planner.retreatPoint(nav.position, living))
end

-- Called on every think: keeps it moving according to its state.
function Walker.act(
	brain: Brain.Brain,
	memory: Memory.Memory<Vector3>,
	seen: Senses.Seen?,
	-- Position of the closest player when this is a scripted sighting (it turns to them).
	staged: Vector3?
)
	local state = brain.state
	if state == "Searching" or state == "Patrolling" then
		if not Navigator.isBusy(nav) then
			nextPoint()
		end
	elseif state == "Pursuing" and not Brain.isWarning(brain) then
		if memory.position then
			Presence.walkTo(memory.position)
		end
	elseif state == "Stalking" then
		if seen and seen.distance <= CopyConfig.StalkDistance then
			Navigator.stop(nav)
		elseif memory.position then
			Presence.walkTo(memory.position)
		end
	elseif state == "Observing" and staged then
		Navigator.face(nav, staged)
	elseif state == "Disappearing" then
		Presence.fade(brain.stateTime / CopyConfig.FadeTime)
	end
	Navigator.update(nav)
end

local WALKING: { [Brain.State]: boolean } = {
	Investigating = true,
	Searching = true,
	Patrolling = true,
	Returning = true,
}

-- Called on every frame: advances it along its route at the speed of its state.
function Walker.move(brain: Brain.Brain, dt: number, pursueSpeed: number)
	local state = brain.state
	if state == "Dormant" then
		return
	end
	local speed = 0
	if state == "Pursuing" then
		speed = if Brain.isWarning(brain) then 0 else pursueSpeed
	elseif state == "LostTarget" then
		speed = pursueSpeed
	elseif state == "Stalking" then
		speed = CopyConfig.StalkSpeed
	elseif WALKING[state] then
		speed = CopyConfig.WalkSpeed
	end
	if speed > 0 then
		Navigator.step(nav, dt, speed)
	end
	Presence.place()
end

return Walker
