--!strict
-- Tracks every player's session data across join, leave, respawn and reconnect.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Logger = require(ReplicatedStorage.Shared.Logger)
local Signal = require(ReplicatedStorage.Shared.Signal)
local NetService = require(script.Parent.NetService)

export type PlayerData = {
	userId: number,
	joinedAt: number,
	-- True once this client reported that it finished loading.
	ready: boolean,
	-- Bumped on every join; lets a delayed cleanup detect that the player came back.
	generation: number,
}

local log = Logger.new("PlayerService")

local PlayerService = {}

-- (player, data, isReconnect)
PlayerService.playerAdded = Signal.new()
-- (player, data)
PlayerService.playerRemoving = Signal.new()
-- (player, data)
PlayerService.playerReady = Signal.new()
-- (player, character)
PlayerService.characterAdded = Signal.new()

-- Keyed by UserId so data survives the Player instance being destroyed on leave.
local records: { [number]: PlayerData } = {}

local function onCharacterAdded(player: Player, character: Model)
	PlayerService.characterAdded:Fire(player, character)
end

local function onPlayerAdded(player: Player)
	local data = records[player.UserId]
	local isReconnect = data ~= nil
	if data then
		data.ready = false
		data.generation += 1
	else
		data = { userId = player.UserId, joinedAt = os.time(), ready = false, generation = 1 }
		records[player.UserId] = data
	end

	log:info(`{player.Name} {if isReconnect then "reconnected" else "joined"}`)
	PlayerService.playerAdded:Fire(player, data, isReconnect)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	local data = records[player.UserId]
	if not data then
		return
	end
	log:info(`{player.Name} left`)
	PlayerService.playerRemoving:Fire(player, data)

	local userId = player.UserId
	local generation = data.generation
	task.delay(GameConfig.ReconnectGraceSeconds, function()
		local current = records[userId]
		if
			current
			and current.generation == generation
			and not Players:GetPlayerByUserId(userId)
		then
			records[userId] = nil
		end
	end)
end

function PlayerService.Start(_self: any)
	NetService.on("ClientReady", function(player: Player)
		local data = PlayerService.getData(player)
		if data and not data.ready then
			data.ready = true
			log:info(`{player.Name} is ready`)
			PlayerService.playerReady:Fire(player, data)
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	-- Players can already be present by the time services start.
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

-- Calls the callback for every player already in the game and every player who joins.
-- Systems use this instead of the raw signal so start-up order never matters.
function PlayerService.observePlayers(callback: (player: Player) -> ())
	PlayerService.playerAdded:Connect(function(player: Player)
		callback(player)
	end)
	for _, player in Players:GetPlayers() do
		if records[player.UserId] then
			task.spawn(callback, player)
		end
	end
end

-- Calls the callback for every existing character and every character that spawns.
function PlayerService.observeCharacters(callback: (player: Player, character: Model) -> ())
	PlayerService.characterAdded:Connect(function(player: Player, character: Model)
		callback(player, character)
	end)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and records[player.UserId] then
			task.spawn(callback, player, character)
		end
	end
end

-- Nil only for a player who has already left.
function PlayerService.getData(player: Player): PlayerData?
	if player.Parent ~= Players then
		return nil
	end
	return records[player.UserId]
end

-- The character's root part, or nil when the player has no living character.
function PlayerService.getAliveRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return humanoid.RootPart
end

return PlayerService
