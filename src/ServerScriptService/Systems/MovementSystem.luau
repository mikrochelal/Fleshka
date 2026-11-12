--!strict
-- Walking, sprinting and stamina. The client only says whether the sprint control is held;
-- the server owns stamina and sets the character's speed, so neither can be forged.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlayerConfig = require(ReplicatedStorage.Config.PlayerConfig)
local GameState = require(ReplicatedStorage.Shared.GameState)
local NetService = require(script.Parent.Parent.Services.NetService)
local NoiseService = require(script.Parent.Parent.Services.NoiseService)
local PlayerService = require(script.Parent.Parent.Services.PlayerService)

type State = {
	stamina: number,
	wantsSprint: boolean,
	sprinting: boolean,
	exhausted: boolean,
	lastSprint: number,
	shownStamina: number,
}

local ATTRIBUTE = GameState.PlayerAttribute

local MovementSystem = {}

local states: { [Player]: State } = {}

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local function publish(player: Player, state: State)
	local shown = math.ceil(state.stamina)
	if shown ~= state.shownStamina then
		state.shownStamina = shown
		player:SetAttribute(ATTRIBUTE.Stamina, shown)
	end
	if player:GetAttribute(ATTRIBUTE.Exhausted) ~= state.exhausted then
		player:SetAttribute(ATTRIBUTE.Exhausted, state.exhausted)
	end
end

local function step(dt: number)
	local now = os.clock()
	for player, state in states do
		local root = PlayerService.getAliveRoot(player)
		local humanoid = humanoidOf(player)
		if not root or not humanoid then
			state.sprinting = false
			continue
		end

		local velocity = root.AssemblyLinearVelocity
		local moving = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			> PlayerConfig.MovingSpeedThreshold
		state.sprinting = state.wantsSprint and moving and not state.exhausted

		if state.sprinting then
			state.stamina = math.max(0, state.stamina - PlayerConfig.StaminaDrainPerSecond * dt)
			state.lastSprint = now
			if state.stamina <= 0 then
				state.exhausted = true
				state.sprinting = false
			end
			-- Running is audible to THE COPY at close range (Config/NoiseConfig "Sprint").
			NoiseService.make("Sprint", root.Position, player)
		elseif now - state.lastSprint >= PlayerConfig.StaminaRegenDelay then
			state.stamina = math.min(
				PlayerConfig.StaminaMax,
				state.stamina + PlayerConfig.StaminaRegenPerSecond * dt
			)
			if state.exhausted and state.stamina >= PlayerConfig.ExhaustedRecoverAt then
				state.exhausted = false
			end
		end

		local speed = if state.sprinting then PlayerConfig.SprintSpeed else PlayerConfig.WalkSpeed
		if humanoid.WalkSpeed ~= speed then
			humanoid.WalkSpeed = speed
		end
		publish(player, state)
	end
end

function MovementSystem.isSprinting(player: Player): boolean
	local state = states[player]
	return state ~= nil and state.sprinting
end

function MovementSystem.Start(_self: any)
	PlayerService.observePlayers(function(player)
		local state: State = {
			stamina = PlayerConfig.StaminaMax,
			wantsSprint = false,
			sprinting = false,
			exhausted = false,
			lastSprint = 0,
			shownStamina = -1,
		}
		states[player] = state
		publish(player, state)
	end)
	PlayerService.playerRemoving:Connect(function(player: Player)
		states[player] = nil
	end)
	PlayerService.observeCharacters(function(player, _character)
		-- A fresh character starts walking; the held key has to be reported again.
		local state = states[player]
		if state then
			state.wantsSprint = false
		end
	end)

	NetService.on("SprintIntent", function(player: Player, wants: boolean)
		local state = states[player]
		if state then
			state.wantsSprint = wants
		end
	end)

	RunService.Heartbeat:Connect(step)
end

return MovementSystem
