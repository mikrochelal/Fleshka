--!strict
-- Code locks. An object with Kind = "Keypad" and Id = <lock id> (Config/MissionConfig.Locks)
-- opens a code entry panel on the player's screen; the digits come back through the
-- `SubmitCode` remote and are checked here. The code is generated for every session and
-- never sent to a client: players learn it from documents in the world.
--
-- A wrong code costs nothing but noise. An opened lock stays open.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InteractionConfig = require(ReplicatedStorage.Config.InteractionConfig)
local MissionConfig = require(ReplicatedStorage.Config.MissionConfig)
local Logger = require(ReplicatedStorage.Shared.Logger)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Text = require(ReplicatedStorage.Shared.Text)
local AudioService = require(script.Parent.Parent.Services.AudioService)
local NetService = require(script.Parent.Parent.Services.NetService)
local NoiseService = require(script.Parent.Parent.Services.NoiseService)
local PlayerService = require(script.Parent.Parent.Services.PlayerService)
local SessionService = require(script.Parent.Parent.Services.SessionService)
local WorldService = require(script.Parent.Parent.Services.WorldService)
local InteractionSystem = require(script.Parent.InteractionSystem)
local WorldProps = require(script.Parent.WorldProps)

type LockState = { code: string, open: boolean, powered: boolean }

local COLOR_LOCKED = Color3.fromRGB(214, 62, 54)
local COLOR_DEAD = Color3.fromRGB(90, 96, 100)
local COLOR_OPEN = Color3.fromRGB(70, 170, 120)

local log = Logger.new("Keypad")

local KeypadSystem = {}

-- Fired with (lockId: string, player: Player) when a lock is opened.
KeypadSystem.opened = Signal.new()

local locks: { [string]: LockState } = {}

local function refresh(id: string)
	local lock = locks[id]
	local keypad = WorldProps.get(MissionConfig.Locks[id].prop)
	if not lock or not keypad then
		return
	end
	local status, color
	if lock.open then
		status, color = "LABEL_KEYPAD_OPEN", COLOR_OPEN
	elseif lock.powered then
		status, color = "LABEL_KEYPAD_LOCKED", COLOR_LOCKED
	else
		status, color = "LABEL_KEYPAD_DEAD", COLOR_DEAD
	end
	WorldProps.setLabel(keypad, Text.lines({ "LABEL_KEYPAD", status }), color)
end

-- The code of a lock, as a string of digits ("" for an unknown lock).
function KeypadSystem.code(id: string): string
	local lock = locks[id]
	return if lock then lock.code else ""
end

function KeypadSystem.isOpen(id: string): boolean
	local lock = locks[id]
	return lock ~= nil and lock.open
end

-- Gives the keypad power (the mission switches some locks on only when it is their turn).
function KeypadSystem.setPowered(id: string, powered: boolean)
	local lock = locks[id]
	if lock and lock.powered ~= powered then
		lock.powered = powered
		refresh(id)
	end
end

local function withinReach(player: Player, id: string): boolean
	local root = PlayerService.getAliveRoot(player)
	local position = WorldProps.positionOf(MissionConfig.Locks[id].prop)
	if not root or not position then
		return false
	end
	local limit = InteractionConfig.MaxDistance + InteractionConfig.DistanceTolerance
	return (position - root.Position).Magnitude <= limit
end

local function onUse(player: Player, _target: Instance, id: string)
	local lock = locks[id]
	if not lock or not SessionService.isPlaying() then
		return
	end
	if lock.open then
		NetService.fire("Notify", player, Text.ref("NOTIFY_KEYPAD_ALREADY_OPEN"), "info")
	elseif not lock.powered then
		NetService.fire("Notify", player, Text.ref("NOTIFY_KEYPAD_DEAD"), "info")
	else
		NetService.fire(
			"Keypad",
			player,
			id,
			Text.ref("UI_KEYPAD_TITLE"),
			MissionConfig.Locks[id].digits
		)
	end
end

local function onSubmit(player: Player, id: string, digits: string)
	local lock = locks[id]
	-- The usual checks: a real lock, the right moment, and the player actually standing
	-- at the keypad. Anything else is ignored without a word.
	if
		not lock
		or lock.open
		or not lock.powered
		or not SessionService.isPlaying()
		or not withinReach(player, id)
		or #digits > 12
	then
		return
	end
	local position = WorldProps.positionOf(MissionConfig.Locks[id].prop) :: Vector3

	if digits ~= lock.code then
		log:info(`{player.Name} entered a wrong code on {id}`)
		AudioService.play("AccessDenied", position)
		NoiseService.make("KeypadDenied", position)
		NetService.fire("Notify", player, Text.ref("NOTIFY_KEYPAD_WRONG"), "warning")
		return
	end

	lock.open = true
	log:info(`{player.Name} opened {id}`)
	AudioService.play("AccessGranted", position)
	refresh(id)
	KeypadSystem.opened:Fire(id, player)
end

function KeypadSystem.Init(_self: any)
	local random = Random.new()
	for id, definition in MissionConfig.Locks do
		local digits: { string } = {}
		for _ = 1, definition.digits do
			table.insert(digits, tostring(random:NextInteger(0, 9)))
		end
		locks[id] = { code = table.concat(digits), open = false, powered = definition.powered }
	end
end

function KeypadSystem.Start(_self: any)
	InteractionSystem.registerKind("Keypad", onUse)
	NetService.on("SubmitCode", onSubmit)

	WorldService.onReady(function()
		WorldProps.ensure()
		for id in locks do
			refresh(id)
		end
		log:info("Code locks ready; codes generated for this session")
	end)
end

return KeypadSystem
