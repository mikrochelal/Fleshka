--!strict
-- Who THE COPY is looking at. Each think it collects the players it can actually see
-- (Senses), adds the one it is already after, and lets the pure Targeting rules choose:
-- no rapid switching, no player hounded forever, and a caught player is left alone for a
-- while. Players it does not perceive are never candidates.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CopyConfig = require(ReplicatedStorage.Config.CopyConfig)
local Logger = require(ReplicatedStorage.Shared.Logger)
local Senses = require(script.Parent.Senses)
local Targeting = require(script.Parent.Targeting)

-- A noise this close to a player is taken to be that player's.
local NOISE_OWNER_DISTANCE = 10

local log = Logger.new("THE_COPY")

local Attention = {}

local targeting: Targeting.Targeting<Player> = Targeting.new()
-- When each player last made a noise it heard.
local noiseAt: { [Player]: number } = setmetatable({} :: any, { __mode = "k" })

local function nameOf(player: Player?): string
	return if player then player.Name else "nobody"
end

function Attention.target(): Player?
	return targeting.current
end

-- Runs the clocks and chooses a target among the players it sees right now. Returns the
-- target's sighting (nil when it has no target or cannot see them) and whether the target
-- changed in this call.
function Attention.update(
	dt: number,
	eye: Vector3,
	facing: Vector3,
	body: Instance,
	scale: number,
	living: { Senses.Living }
): (Senses.Seen?, boolean)
	Targeting.tick(targeting, dt)

	local now = os.clock()
	local previous = targeting.current
	local visible = Senses.visiblePlayers(eye, facing, body, scale, living)
	local candidates: { Targeting.Candidate<Player> } = {}
	local previousVisible = false
	for _, seen in visible do
		previousVisible = previousVisible or seen.player == previous
		local heard = noiseAt[seen.player]
		table.insert(candidates, {
			id = seen.player,
			visible = true,
			distance = seen.distance,
			noiseAge = if heard then now - heard else nil,
		})
	end
	if previous and not previousVisible then
		-- Still remembered while alive, but it has to guess how far away they are.
		for _, entry in living do
			if entry.player == previous then
				table.insert(candidates, {
					id = previous,
					visible = false,
					distance = (entry.root.Position - eye).Magnitude,
					noiseAge = nil,
				})
			end
		end
	end

	local chosen, reason = Targeting.choose(targeting, candidates, CopyConfig)
	if reason then
		log:info(`Target: {nameOf(previous)} -> {nameOf(chosen)} ({reason})`)
	end
	for _, seen in visible do
		if seen.player == chosen then
			return seen, reason ~= nil
		end
	end
	return nil, reason ~= nil
end

-- A noise it reacted to: the player standing where it came from draws its attention.
function Attention.noteNoise(position: Vector3, living: { Senses.Living })
	for _, entry in living do
		if (entry.root.Position - position).Magnitude <= NOISE_OWNER_DISTANCE then
			noiseAt[entry.player] = os.clock()
		end
	end
end

-- Runs only the clocks (while it is away).
function Attention.rest(dt: number)
	Targeting.tick(targeting, dt)
end

function Attention.markCaught(player: Player)
	Targeting.markCaught(targeting, player, CopyConfig)
end

-- Lets go of the current target (it left the world).
function Attention.release()
	Targeting.release(targeting)
end

function Attention.watchPlayers()
	Players.PlayerRemoving:Connect(function(player)
		Targeting.forget(targeting, player)
		noiseAt[player] = nil
	end)
end

return Attention
