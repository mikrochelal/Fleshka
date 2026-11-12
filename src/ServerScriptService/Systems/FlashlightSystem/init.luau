--!strict
-- The flashlight. The server owns whether it is on and how much battery is left (rules in
-- Battery.luau), so neither can be forged, and replicates both through player attributes.
--
-- Two lights show it:
--   * a SpotLight and a soft fill on the character's head, created here, which is what
--     OTHER players see;
--   * the holder's own beam, created on their client and attached to the camera so it
--     follows where they look (Controllers/FlashlightController), which hides the head
--     lights for that one player.
--
-- Battery packs in the world (Kind = "Battery") refill it. Every switch is logged as
-- [TLS:Flashlight] so a broken flashlight can be diagnosed from the Output window.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FlashlightConfig = require(ReplicatedStorage.Config.FlashlightConfig)
local GameState = require(ReplicatedStorage.Shared.GameState)
local Logger = require(ReplicatedStorage.Shared.Logger)
local Text = require(ReplicatedStorage.Shared.Text)
local AudioService = require(script.Parent.Parent.Services.AudioService)
local NetService = require(script.Parent.Parent.Services.NetService)
local PlayerService = require(script.Parent.Parent.Services.PlayerService)
local InteractionSystem = require(script.Parent.InteractionSystem)
local WorldProps = require(script.Parent.WorldProps)
local Battery = require(script.Battery)

type Entry = {
	state: Battery.State,
	spot: SpotLight?,
	fill: PointLight?,
	shownBattery: number,
}

local ATTRIBUTE = GameState.PlayerAttribute
local TICK = 0.25
local SPOT_NAME = "TLS_Flashlight"
local FILL_NAME = "TLS_FlashlightFill"

local log = Logger.new("Flashlight")

local FlashlightSystem = {}

local entries: { [Player]: Entry } = {}
local random = Random.new()
local accumulator = 0

local function notify(player: Player, key: string, kind: string)
	NetService.fire("Notify", player, Text.ref(key), kind)
end

local function publish(player: Player, entry: Entry)
	local shown = math.ceil(entry.state.battery)
	if shown ~= entry.shownBattery then
		entry.shownBattery = shown
		player:SetAttribute(ATTRIBUTE.Battery, shown)
	end
	if player:GetAttribute(ATTRIBUTE.FlashlightOn) ~= entry.state.on then
		player:SetAttribute(ATTRIBUTE.FlashlightOn, entry.state.on)
	end
end

local function applyLight(entry: Entry)
	local on = entry.state.on
	if entry.spot then
		entry.spot.Enabled = on
		entry.spot.Brightness = FlashlightConfig.Brightness
	end
	if entry.fill then
		entry.fill.Enabled = on
	end
end

local function changed(player: Player, entry: Entry)
	applyLight(entry)
	publish(player, entry)
	AudioService.playFor(player, "FlashlightClick")
	log:info(
		`{if entry.state.on then "Enabled" else "Disabled"} for {player.Name} `
			.. `(battery {math.ceil(entry.state.battery)}%)`
	)
end

local function attachLights(player: Player, character: Model)
	local entry = entries[player]
	local head = character:WaitForChild("Head", 15)
	if not entry or player.Character ~= character then
		return
	end
	if not head or not head:IsA("BasePart") then
		log:warn(`Error: {player.Name}'s character has no Head part; other players will not see the light`)
		Battery.respawn(entry.state)
		publish(player, entry)
		return
	end

	-- Never more than one pair of lights per head, whatever called this twice.
	for _, child in head:GetChildren() do
		if child.Name == SPOT_NAME or child.Name == FILL_NAME then
			child:Destroy()
		end
	end

	local spot = Instance.new("SpotLight")
	spot.Name = SPOT_NAME
	spot.Face = Enum.NormalId.Front
	spot.Range = FlashlightConfig.Range
	spot.Angle = FlashlightConfig.Angle
	spot.Brightness = FlashlightConfig.Brightness
	spot.Color = FlashlightConfig.Color
	spot.Shadows = true
	spot.Enabled = false
	spot.Parent = head

	local fill = Instance.new("PointLight")
	fill.Name = FILL_NAME
	fill.Range = FlashlightConfig.FillRange
	fill.Brightness = FlashlightConfig.FillBrightness
	fill.Color = FlashlightConfig.Color
	fill.Shadows = false
	fill.Enabled = false
	fill.Parent = head

	entry.spot = spot
	entry.fill = fill
	-- A new character always starts with the light off, so the state can never be stuck
	-- "on" with no light.
	Battery.respawn(entry.state)
	publish(player, entry)
	log:info(`Character respawned: lights attached for {player.Name}`)
end

local function tick(dt: number)
	for player, entry in entries do
		if Battery.tick(entry.state, dt, FlashlightConfig) then
			changed(player, entry)
			notify(player, "NOTIFY_FLASHLIGHT_DEPLETED", "warning")
		elseif entry.state.on and entry.spot and Battery.isLow(entry.state, FlashlightConfig) then
			entry.spot.Brightness = FlashlightConfig.Brightness * random:NextNumber(0.4, 1)
		end
		publish(player, entry)
	end
end

function FlashlightSystem.isOn(player: Player): boolean
	local entry = entries[player]
	return entry ~= nil and entry.state.on
end

function FlashlightSystem.Start(_self: any)
	PlayerService.observePlayers(function(player)
		local entry: Entry = {
			state = Battery.new(FlashlightConfig),
			spot = nil,
			fill = nil,
			shownBattery = -1,
		}
		entries[player] = entry
		publish(player, entry)
	end)
	PlayerService.playerRemoving:Connect(function(player: Player)
		entries[player] = nil
	end)
	PlayerService.observeCharacters(attachLights)

	NetService.on("FlashlightToggle", function(player: Player)
		local entry = entries[player]
		if not entry then
			log:warn(`Error: toggle from {player.Name} before their flashlight was set up`)
			return
		end
		if not PlayerService.getAliveRoot(player) then
			return
		end
		local result = Battery.toggle(entry.state)
		if result == "dead" then
			notify(player, "NOTIFY_FLASHLIGHT_DEAD", "warning")
			log:info(`Refused for {player.Name}: battery empty`)
			return
		end
		changed(player, entry)
	end)

	InteractionSystem.registerKind("Battery", function(player, target, id)
		local entry = entries[player]
		if not entry then
			return
		end
		if not Battery.refill(entry.state, FlashlightConfig) then
			notify(player, "NOTIFY_BATTERY_FULL", "info")
			return
		end
		applyLight(entry)
		publish(player, entry)
		notify(player, "NOTIFY_BATTERY_REPLACED", "info")
		AudioService.playFor(player, "BatteryInsert")
		-- Each pack is used once. Only objects the game created itself are removed.
		if WorldProps.get(id) == target then
			WorldProps.remove(id)
		else
			target:SetAttribute("InteractEnabled", false)
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= TICK then
			tick(accumulator)
			accumulator = 0
		end
	end)
	log:info("Initialized (server)")
end

return FlashlightSystem
