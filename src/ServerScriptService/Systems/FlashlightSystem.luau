--!strict
-- The flashlight is a real SpotLight on the character's head, created and switched by the
-- server, so it lights the world for everyone and its battery cannot be forged.
-- Battery packs in the world (Kind = "Battery") refill it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FlashlightConfig = require(ReplicatedStorage.Config.FlashlightConfig)
local GameState = require(ReplicatedStorage.Shared.GameState)
local NetService = require(script.Parent.Parent.Services.NetService)
local PlayerService = require(script.Parent.Parent.Services.PlayerService)
local InteractionSystem = require(script.Parent.InteractionSystem)

type State = {
	battery: number,
	on: boolean,
	spot: SpotLight?,
	fill: PointLight?,
	shownBattery: number,
}

local ATTRIBUTE = GameState.PlayerAttribute
local TICK = 0.25
local SPOT_NAME = "TLS_Flashlight"
local FILL_NAME = "TLS_FlashlightFill"

local FlashlightSystem = {}

local states: { [Player]: State } = {}
local random = Random.new()
local accumulator = 0

local function publish(player: Player, state: State)
	local shown = math.ceil(state.battery)
	if shown ~= state.shownBattery then
		state.shownBattery = shown
		player:SetAttribute(ATTRIBUTE.Battery, shown)
	end
	if player:GetAttribute(ATTRIBUTE.FlashlightOn) ~= state.on then
		player:SetAttribute(ATTRIBUTE.FlashlightOn, state.on)
	end
end

local function applyLight(state: State)
	if state.spot then
		state.spot.Enabled = state.on
		state.spot.Brightness = FlashlightConfig.Brightness
	end
	if state.fill then
		state.fill.Enabled = state.on
	end
end

local function setOn(player: Player, state: State, on: boolean)
	state.on = on
	applyLight(state)
	publish(player, state)
	NetService.fire("Sound", player, "FlashlightClick")
end

local function attachLights(player: Player, character: Model)
	local state = states[player]
	local head = character:WaitForChild("Head", 15)
	if not state or not head or not head:IsA("BasePart") or player.Character ~= character then
		return
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

	state.spot = spot
	state.fill = fill
	-- A new character always starts with the light off.
	state.on = false
	publish(player, state)
end

local function tick(dt: number)
	for player, state in states do
		if state.on then
			state.battery = math.max(0, state.battery - FlashlightConfig.DrainPerSecond * dt)
			if state.battery <= 0 then
				setOn(player, state, false)
				NetService.fire("Notify", player, "Flashlight battery depleted.", "warning")
			elseif state.spot and state.battery < FlashlightConfig.LowBattery then
				state.spot.Brightness = FlashlightConfig.Brightness * random:NextNumber(0.4, 1)
			end
		elseif state.battery < FlashlightConfig.RechargeCap then
			state.battery = math.min(
				FlashlightConfig.RechargeCap,
				state.battery + FlashlightConfig.RechargePerSecond * dt
			)
		end
		publish(player, state)
	end
end

function FlashlightSystem.isOn(player: Player): boolean
	local state = states[player]
	return state ~= nil and state.on
end

function FlashlightSystem.Start(_self: any)
	PlayerService.observePlayers(function(player)
		local state: State = {
			battery = FlashlightConfig.BatteryMax,
			on = false,
			spot = nil,
			fill = nil,
			shownBattery = -1,
		}
		states[player] = state
		publish(player, state)
	end)
	PlayerService.playerRemoving:Connect(function(player: Player)
		states[player] = nil
	end)
	PlayerService.observeCharacters(attachLights)

	NetService.on("FlashlightToggle", function(player: Player)
		local state = states[player]
		if not state or not PlayerService.getAliveRoot(player) then
			return
		end
		if not state.on and state.battery < 1 then
			NetService.fire(
				"Notify",
				player,
				"The flashlight is dead. It needs a battery.",
				"warning"
			)
			return
		end
		setOn(player, state, not state.on)
	end)

	InteractionSystem.registerKind("Battery", function(player, target, _id)
		local state = states[player]
		if not state then
			return
		end
		if state.battery >= FlashlightConfig.BatteryMax - 5 then
			NetService.fire("Notify", player, "Your flashlight battery is already full.", "info")
			return
		end
		state.battery = FlashlightConfig.BatteryMax
		applyLight(state)
		publish(player, state)
		NetService.fire("Notify", player, "Battery replaced.", "info")
		NetService.fire("Sound", player, "BatteryPickup")

		-- Each pack is used once. Only objects the game created itself are removed.
		if target:GetAttribute("TLS_RuntimeProp") == true then
			target:Destroy()
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
end

return FlashlightSystem
