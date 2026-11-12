--!strict
-- Moves a point along the station floor using PathfindingService. The entity is kinematic
-- (its model is placed directly at this point), so it cannot fall, get pushed or get
-- physically stuck; if a path cannot be planned the walk is reported as failed and the
-- caller decides what to do.
--
-- Path requests are kept rare: at most one per CopyConfig.RepathInterval, none when the
-- new destination is where the current route already ends, and none for a point that has
-- just been found unreachable (a locked door is a solid part, so what is behind it simply
-- fails). A route that becomes blocked is planned again once; a plan that takes too long
-- counts as a failure.

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CopyConfig = require(ReplicatedStorage.Config.CopyConfig)

export type Navigator = {
	position: Vector3,
	-- Horizontal unit vector the entity faces.
	facing: Vector3,
	waypoints: { Vector3 },
	index: number,
	-- A path is being planned.
	pending: boolean,
	failed: boolean,
	hasRoute: boolean,
	-- Walks in a row that could not be planned.
	failures: number,
	-- Bumped by every request so a slow, outdated plan is ignored.
	token: number,
	-- Where the current route (or the plan in progress) leads.
	destination: Vector3?,
	-- A request waiting for the minimum interval to pass.
	queued: Vector3?,
	lastRequest: number,
	-- The route ahead was reported blocked and has to be planned again.
	blocked: boolean,
	blockedConnection: RBXScriptConnection?,
	-- The last destination that could not be reached, and when that was found out.
	unreachable: Vector3?,
	unreachableAt: number,
	ignore: { Instance },
}

local AGENT = {
	AgentRadius = 1,
	AgentHeight = 6,
	AgentCanJump = false,
	WaypointSpacing = 6,
}
-- Destinations this close together are the same destination.
local SAME_DESTINATION = 3
-- A point found unreachable is not tried again for this long.
local UNREACHABLE_MEMORY = 8

local Navigator = {}

function Navigator.new(position: Vector3): Navigator
	return {
		position = position,
		facing = Vector3.new(0, 0, -1),
		waypoints = {},
		index = 1,
		pending = false,
		failed = false,
		hasRoute = false,
		failures = 0,
		token = 0,
		destination = nil,
		queued = nil,
		lastRequest = -math.huge,
		blocked = false,
		blockedConnection = nil,
		unreachable = nil,
		unreachableAt = -math.huge,
		ignore = {},
	}
end

local function straightLineIsClear(from: Vector3, to: Vector3, ignore: { Instance }): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local lift = Vector3.new(0, 2.5, 0)
	return Workspace:Raycast(from + lift, to - from, params) == nil
end

local function unwatch(nav: Navigator)
	local connection = nav.blockedConnection
	if connection then
		connection:Disconnect()
		nav.blockedConnection = nil
	end
	nav.blocked = false
end

local function fail(nav: Navigator, destination: Vector3)
	nav.pending = false
	nav.failed = true
	nav.hasRoute = false
	nav.waypoints = {}
	nav.index = 1
	nav.destination = nil
	nav.failures += 1
	nav.unreachable = destination
	nav.unreachableAt = os.clock()
end

local function plan(nav: Navigator, destination: Vector3)
	unwatch(nav)
	nav.token += 1
	local token = nav.token
	nav.pending = true
	nav.failed = false
	nav.queued = nil
	nav.destination = destination
	nav.lastRequest = os.clock()

	task.delay(CopyConfig.PathTimeout, function()
		if token == nav.token and nav.pending then
			-- Too slow: whatever the plan turns out to be, it is no longer wanted.
			nav.token += 1
			fail(nav, destination)
		end
	end)

	task.spawn(function()
		local from = nav.position
		local path = PathfindingService:CreatePath(AGENT)
		local ok = pcall(function()
			path:ComputeAsync(from, destination)
		end)
		if token ~= nav.token then
			return
		end

		local route: { Vector3 } = {}
		if ok and path.Status == Enum.PathStatus.Success then
			for index, waypoint in path:GetWaypoints() do
				if index > 1 then
					table.insert(route, waypoint.Position)
				end
			end
			-- Route entry i is path waypoint i + 1.
			nav.blockedConnection = path.Blocked:Connect(function(blockedIndex: number)
				if token == nav.token and blockedIndex - 1 >= nav.index then
					nav.blocked = true
				end
			end)
		elseif straightLineIsClear(from, destination, nav.ignore) then
			table.insert(route, destination)
		end

		if #route == 0 then
			fail(nav, destination)
			return
		end
		nav.pending = false
		nav.waypoints = route
		nav.index = 1
		nav.hasRoute = true
		nav.failures = 0
	end)
end

local function near(a: Vector3?, b: Vector3): boolean
	return a ~= nil and (a - b).Magnitude <= SAME_DESTINATION
end

-- Starts walking to `destination` (a point on the floor); `ignore` lists instances that do
-- not block it. While the new route is being planned the entity keeps following its
-- previous one. Calling this again for the same destination costs nothing.
function Navigator.goTo(nav: Navigator, destination: Vector3, ignore: { Instance })
	nav.ignore = ignore
	local now = os.clock()
	if near(nav.destination, destination) and not nav.failed and not nav.blocked then
		nav.queued = nil
		return
	elseif near(nav.unreachable, destination) and now - nav.unreachableAt < UNREACHABLE_MEMORY then
		-- Known to be unreachable: fail at once instead of asking again.
		if not nav.failed then
			nav.token += 1
			unwatch(nav)
			fail(nav, destination)
		end
		nav.queued = nil
		return
	end
	nav.failed = false
	if nav.pending or now - nav.lastRequest < CopyConfig.RepathInterval then
		nav.queued = destination
	else
		plan(nav, destination)
	end
end

function Navigator.stop(nav: Navigator)
	unwatch(nav)
	nav.token += 1
	nav.pending = false
	nav.failed = false
	nav.hasRoute = false
	nav.waypoints = {}
	nav.index = 1
	nav.destination = nil
	nav.queued = nil
end

-- Puts it somewhere else with nothing planned and nothing remembered.
function Navigator.teleport(nav: Navigator, position: Vector3)
	Navigator.stop(nav)
	nav.position = position
	nav.failures = 0
	nav.unreachable = nil
end

-- True while a walk has been asked for and has neither finished nor failed.
function Navigator.isBusy(nav: Navigator): boolean
	return nav.pending or nav.queued ~= nil or (nav.hasRoute and nav.index <= #nav.waypoints)
end

-- True once the last requested walk has reached its end.
function Navigator.hasArrived(nav: Navigator): boolean
	return nav.hasRoute and not nav.pending and nav.queued == nil and nav.index > #nav.waypoints
end

function Navigator.face(nav: Navigator, target: Vector3)
	local flat = Vector3.new(target.X - nav.position.X, 0, target.Z - nav.position.Z)
	if flat.Magnitude > 0.05 then
		nav.facing = flat.Unit
	end
end

-- Sends the request that was waiting for the minimum interval, and plans a blocked route
-- again. Cheap; called on every think.
function Navigator.update(nav: Navigator)
	if nav.pending or os.clock() - nav.lastRequest < CopyConfig.RepathInterval then
		return
	end
	local queued = nav.queued
	local destination = nav.destination
	if queued then
		plan(nav, queued)
	elseif nav.blocked and destination then
		-- The old route leads through whatever now blocks it: drop it.
		nav.waypoints = {}
		nav.index = 1
		nav.hasRoute = false
		plan(nav, destination)
	end
end

-- Advances along the route by `speed * dt` studs. It waits in front of a blocked route
-- until the new plan arrives.
function Navigator.step(nav: Navigator, dt: number, speed: number)
	if nav.blocked then
		return
	end
	local remaining = speed * dt
	while remaining > 0 and nav.index <= #nav.waypoints do
		local waypoint = nav.waypoints[nav.index]
		local offset = waypoint - nav.position
		local distance = offset.Magnitude
		Navigator.face(nav, waypoint)
		if distance <= remaining then
			nav.position = waypoint
			nav.index += 1
			remaining -= distance
		else
			nav.position += offset.Unit * remaining
			remaining = 0
		end
	end
end

return Navigator
