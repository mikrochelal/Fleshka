--!strict
-- Where THE COPY walks when it is not following a player: the places it checks in a
-- search, its patrol route, and where it goes to leave. The choices themselves are made by
-- the pure modules Memory and Patrol; this module feeds them points from the map.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CopyConfig = require(ReplicatedStorage.Config.CopyConfig)
local Memory = require(script.Parent.Memory)
local Patrol = require(script.Parent.Patrol)
local Senses = require(script.Parent.Senses)

local Planner = {}

local function between(a: Vector3, b: Vector3): number
	return (a - b).Magnitude
end

-- The places to check around a remembered position, and the radius that was used: the
-- position itself, then the nearest hiding places. The less certain it is, the wider.
function Planner.searchPlan(origin: Vector3, certainty: number, count: number): ({ Vector3 }, number)
	local radius =
		Memory.searchRadius(certainty, CopyConfig.SearchRadiusMin, CopyConfig.SearchRadiusMax)
	local candidates: { Memory.Candidate<Vector3> } = {}
	for _, point in Senses.hidingPlaces() do
		table.insert(candidates, { point = point, distance = between(point, origin) })
	end
	return Memory.plan(origin, candidates, radius, count), radius
end

-- A patrol route of `count` observation points starting near `start`.
function Planner.patrolRoute(start: Vector3, count: number): { Vector3 }
	return Patrol.route(Senses.vantagePoints(), start, count, between)
end

-- The observation point to walk away to: the one furthest from every player that is not
-- too long a walk.
function Planner.retreatPoint(from: Vector3, living: { Senses.Living }): Vector3?
	return Patrol.retreat(
		Senses.vantagePoints(),
		from,
		CopyConfig.ReturnMaxDistance,
		between,
		function(point: Vector3): number
			local nearest = math.huge
			for _, entry in living do
				nearest = math.min(nearest, between(entry.root.Position, point))
			end
			return nearest
		end
	)
end

return Planner
