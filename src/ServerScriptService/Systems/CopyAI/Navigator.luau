--!strict
-- Moves a point along the station floor using PathfindingService. The entity is kinematic
-- (its model is placed directly at this point), so it cannot fall, get pushed or get
-- physically stuck; if a path cannot be planned the walk is reported as failed and the
-- caller decides what to do.

local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")

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
	-- Bumped by every request so a slow, outdated plan is ignored.
	token: number,
}

local AGENT = {
	AgentRadius = 1,
	AgentHeight = 6,
	AgentCanJump = false,
	WaypointSpacing = 6,
}

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
		token = 0,
	}
end

local function straightLineIsClear(from: Vector3, to: Vector3, ignore: { Instance }): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local lift = Vector3.new(0, 2.5, 0)
	return Workspace:Raycast(from + lift, to - from, params) == nil
end

-- Starts walking to `destination` (a point on the floor). While the new route is being
-- planned the entity keeps following its previous one.
function Navigator.goTo(nav: Navigator, destination: Vector3, ignore: { Instance })
	nav.token += 1
	local token = nav.token
	nav.pending = true
	nav.failed = false

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
		elseif straightLineIsClear(from, destination, ignore) then
			table.insert(route, destination)
		end

		nav.pending = false
		if #route == 0 then
			nav.failed = true
			nav.hasRoute = false
			nav.waypoints = {}
		else
			nav.waypoints = route
			nav.hasRoute = true
		end
		nav.index = 1
	end)
end

function Navigator.stop(nav: Navigator)
	nav.token += 1
	nav.pending = false
	nav.failed = false
	nav.hasRoute = false
	nav.waypoints = {}
	nav.index = 1
end

-- True once the last requested walk has reached its end.
function Navigator.hasArrived(nav: Navigator): boolean
	return nav.hasRoute and not nav.pending and nav.index > #nav.waypoints
end

function Navigator.face(nav: Navigator, target: Vector3)
	local flat = Vector3.new(target.X - nav.position.X, 0, target.Z - nav.position.Z)
	if flat.Magnitude > 0.05 then
		nav.facing = flat.Unit
	end
end

-- Advances along the route by `speed * dt` studs.
function Navigator.step(nav: Navigator, dt: number, speed: number)
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
