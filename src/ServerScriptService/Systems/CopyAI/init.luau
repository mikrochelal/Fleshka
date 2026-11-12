--!strict
-- THE COPY: a server-controlled entity in the world. This module connects its parts:
--   Brain      decides which state it is in (pure rules, unit tested)
--   Senses     what it can see, and where it may appear
--   Navigator  walking along the floor
--   Body       the placeholder model
--
-- Other systems talk to it only through noise (NoiseService) and the few functions at the
-- bottom of this file. Clients never control it; they only see the replicated model and a
-- per-player "dread" value that drives screen interference.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CopyConfig = require(ReplicatedStorage.Config.CopyConfig)
local GameState = require(ReplicatedStorage.Shared.GameState)
local Logger = require(ReplicatedStorage.Shared.Logger)
local NetService = require(script.Parent.Parent.Services.NetService)
local NoiseService = require(script.Parent.Parent.Services.NoiseService)
local SessionService = require(script.Parent.Parent.Services.SessionService)
local WorldService = require(script.Parent.Parent.Services.WorldService)
local FacilityLights = require(script.Parent.FacilityLights)
local SpawnSystem = require(script.Parent.SpawnSystem)
local Body = require(script.Body)
local Brain = require(script.Brain)
local Navigator = require(script.Navigator)
local Senses = require(script.Senses)

local THINK_INTERVAL = 0.1
local REPATH_INTERVAL = 0.6
local SEARCH_RADIUS = 70
local DREAD_ATTRIBUTE = GameState.PlayerAttribute.Dread

local log = Logger.new("Copy")

local CopyAI = {}

local brain = Brain.new(CopyConfig)
local model: Model = Body.build()
local nav = Navigator.new(Vector3.zero)

-- Ambient visits only start after the scripted first sighting.
local active = false
local pursuitArmed = false
local lastEncounter = os.clock()

local pendingNoise: Vector3? = nil
local appearPoint: Vector3? = nil
local target: Player? = nil
local lastKnown: Vector3? = nil
local searchQueue: { Vector3 } = {}
local closeTime = 0
local nextRepath = 0
local thinkTimer = 0

local function eye(): Vector3
	return nav.position + Vector3.new(0, Body.EYE_HEIGHT, 0)
end

local function place()
	model:PivotTo(CFrame.lookAt(nav.position, nav.position + nav.facing))
end

local function appearAt(point: Vector3)
	nav = Navigator.new(point)
	Body.setTransparency(model, 0)
	place()
	model.Parent = WorldService.runtimeFolder()
end

local function hide()
	model.Parent = nil
	Navigator.stop(nav)
	target = nil
	lastKnown = nil
	appearPoint = nil
	lastEncounter = os.clock()
end

local function walkTo(point: Vector3)
	Navigator.goTo(nav, Senses.ground(point), { model })
end

local function setDread(player: Player, value: number)
	local rounded = math.floor(value * 10 + 0.5) / 10
	if player:GetAttribute(DREAD_ATTRIBUTE) ~= rounded then
		player:SetAttribute(DREAD_ATTRIBUTE, rounded)
	end
end

local function updateDread()
	local present = brain.state ~= "Dormant"
	for _, player in Players:GetPlayers() do
		local dread = 0
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if present and root and root:IsA("BasePart") then
			local distance = (root.Position - nav.position).Magnitude
			dread = math.clamp(1 - distance / CopyConfig.DreadDistance, 0, 1)
			if brain.state == "Pursuing" and player == target then
				dread = math.max(dread, 0.6)
			end
		end
		setDread(player, dread)
	end
end

-- Places to check around the last known position: the position itself, then the nearest
-- observation points.
local function buildSearchQueue(origin: Vector3): { Vector3 }
	local points = Senses.vantagePoints()
	table.sort(points, function(a, b)
		return (a - origin).Magnitude < (b - origin).Magnitude
	end)
	local queue = { origin }
	for _, point in points do
		if #queue < 4 and (point - origin).Magnitude <= SEARCH_RADIUS then
			table.insert(queue, point)
		end
	end
	return queue
end

local function nextSearchPoint()
	local point = table.remove(searchQueue, 1)
	if point then
		walkTo(point)
	end
end

local function catch(player: Player)
	log:info(`{player.Name} was caught`)
	NetService.fire("Effect", player, "Blackout", 3)
	NetService.fire("Sound", player, "Caught")
	NetService.fireAll("Notify", `{player.DisplayName} was taken.`, "warning")
	task.delay(0.8, function()
		if player.Parent == Players then
			SpawnSystem.placeInRoom(player, CopyConfig.CaughtReturnRoom)
		end
	end)
end

local function onEnter(state: Brain.State, previous: Brain.State, seen: Senses.Seen?)
	log:info(`{previous} -> {state}`)

	if previous == "Dormant" then
		appearAt(appearPoint or nav.position)
	end

	if state == "Dormant" then
		hide()
	elseif state == "Observing" or state == "Disappearing" then
		Navigator.stop(nav)
	elseif state == "Investigating" then
		local destination = lastKnown or nav.position
		walkTo(destination)
	elseif state == "Searching" then
		searchQueue = buildSearchQueue(lastKnown or nav.position)
		nextSearchPoint()
	elseif state == "Pursuing" then
		Navigator.stop(nav)
		closeTime = 0
		nextRepath = 0
		target = if seen then seen.player else nil
		if seen then
			lastKnown = seen.root.Position
			NetService.fire("Notify", seen.player, "IT HAS SEEN YOU.", "warning")
		end
		NetService.fireAll("Effect", "Interference", CopyConfig.ChaseWarningTime)
		NetService.fireAll("Sound", "CopyAlert", nav.position)
		local room = WorldService.zoneAt(nav.position + Vector3.new(0, 3, 0))
		if room then
			FacilityLights.flickerRooms({ room }, CopyConfig.ChaseWarningTime)
		end
	end
end

local function think(dt: number)
	local playing = SessionService.isPlaying() and CopyConfig.Enabled
	local living: { { player: Player, root: BasePart } } = {}
	if playing then
		living = Senses.livingPlayers()
	end
	local present = brain.state ~= "Dormant"

	-- Sight: keep the current target if it is still visible, otherwise the closest one.
	local seen: Senses.Seen? = nil
	if present and playing then
		for _, candidate in Senses.visiblePlayers(eye(), model) do
			if candidate.player == target then
				seen = candidate
				break
			elseif not seen or candidate.distance < seen.distance then
				seen = candidate
			end
		end
	end
	if seen then
		lastKnown = seen.root.Position
		Navigator.face(nav, seen.root.Position)
		-- If the one it was chasing is out of sight, it turns on whoever it can see.
		if brain.state == "Pursuing" and seen.player ~= target then
			target = seen.player
			closeTime = 0
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

	-- Hearing.
	local noise = pendingNoise
	pendingNoise = nil
	local heard = noise ~= nil and brain.state ~= "Pursuing"
	if heard and noise then
		lastKnown = noise
	end

	-- Waking up needs a fair place to appear.
	local wake = active and os.clock() - lastEncounter >= CopyConfig.AmbientInterval
	if not present then
		appearPoint = nil
		local interest = noise or nearestPosition
		if interest and (heard or wake) and brain.cooldown <= 0 then
			appearPoint = Senses.pickAppearPoint(interest)
		end
	end

	-- Catching: the target has to stay within reach, in view, for a moment.
	local caught = false
	if
		brain.state == "Pursuing"
		and not Brain.isWarning(brain)
		and seen
		and seen.player == target
	then
		closeTime = if seen.distance <= CopyConfig.CatchDistance then closeTime + dt else 0
		caught = closeTime >= CopyConfig.CatchTime
	else
		closeTime = 0
	end
	if caught and target then
		catch(target)
	end

	local previous: Brain.State = brain.state
	local state: Brain.State = Brain.update(brain, dt, {
		playersPresent = #living > 0,
		canAppear = appearPoint ~= nil,
		noise = heard,
		wakeRequested = wake,
		seesTarget = seen ~= nil,
		targetDistance = if seen then seen.distance else math.huge,
		nearestDistance = nearest,
		arrived = Navigator.hasArrived(nav),
		pathFailed = nav.failed,
		pursuitArmed = pursuitArmed,
		caught = caught,
	})
	if state ~= previous then
		onEnter(state, previous, seen)
	end

	if state == "Searching" then
		if Navigator.hasArrived(nav) or nav.failed then
			nextSearchPoint()
		end
	elseif state == "Pursuing" and not Brain.isWarning(brain) then
		local now = os.clock()
		if lastKnown and now >= nextRepath then
			nextRepath = now + REPATH_INTERVAL
			walkTo(lastKnown)
		end
	elseif state == "Observing" and nearestPosition then
		Navigator.face(nav, nearestPosition)
	elseif state == "Disappearing" then
		Body.setTransparency(model, math.clamp(brain.stateTime / CopyConfig.FadeTime, 0, 1))
	end

	updateDread()
end

local function move(dt: number)
	local state = brain.state
	if state == "Dormant" then
		return
	end
	if state == "Investigating" or state == "Searching" then
		Navigator.step(nav, dt, CopyConfig.WalkSpeed)
	elseif state == "Pursuing" and not Brain.isWarning(brain) then
		Navigator.step(nav, dt, CopyConfig.PursueSpeed)
	end
	place()
end

-- Lets ambient visits begin (called after the scripted first sighting).
function CopyAI.setActive(value: boolean)
	active = value
	lastEncounter = os.clock()
end

-- Allows pursuits from now on and ends any cooldown, so the next noise brings it.
function CopyAI.arm()
	pursuitArmed = true
	Brain.clearCooldown(brain)
end

-- Stops everything; it fades out if it is in the world.
function CopyAI.shutdown()
	active = false
	pursuitArmed = false
end

-- Scripted sighting: it stands at `position` watching, then vanishes after `seconds` or as
-- soon as a player comes within `fleeDistance`. Returns false if it is already out.
function CopyAI.stageSighting(position: Vector3, seconds: number, fleeDistance: number): boolean
	if brain.state ~= "Dormant" or not CopyConfig.Enabled then
		return false
	end
	appearAt(Senses.ground(position))
	Brain.stage(brain, seconds, fleeDistance)
	log:info("Dormant -> Observing (staged sighting)")
	NetService.fireAll("Sound", "CopyPresence", position)
	return true
end

function CopyAI.getState(): Brain.State
	return brain.state
end

function CopyAI.Start(_self: any)
	NoiseService.heard:Connect(function(position: Vector3, radius: number)
		-- While dormant it is not in the world: only something loud draws it in.
		-- Once it is out, it hears whatever reaches the place it is standing.
		local audible = if brain.state == "Dormant"
			then radius >= CopyConfig.WakeNoiseRadius
			else (position - nav.position).Magnitude <= radius
		if audible then
			pendingNoise = position
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		thinkTimer += dt
		if thinkTimer >= THINK_INTERVAL then
			think(thinkTimer)
			thinkTimer = 0
		end
		move(dt)
	end)
end

return CopyAI
