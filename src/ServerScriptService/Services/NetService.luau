--!strict
-- Creates every remote declared in Shared/Net and guards all client -> server traffic:
-- each call is rate limited and its arguments are type checked before a handler sees it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Logger)
local Net = require(ReplicatedStorage.Shared.Net)
local RateLimiter = require(ReplicatedStorage.Shared.RateLimiter)

local log = Logger.new("NetService")

local NetService = {}

local remotes: { [string]: RemoteEvent } = {}
local limiters: { [string]: RateLimiter.RateLimiter } = {}
local handled: { [string]: boolean } = {}

local function argsMatch(definition: Net.Definition, args: { n: number, [number]: any }): boolean
	if args.n ~= #definition.args then
		return false
	end
	for index, expected in definition.args do
		if typeof(args[index]) ~= expected then
			return false
		end
	end
	return true
end

-- Reuses an existing remote so a second run can never create duplicates.
local function ensureRemote(folder: Instance, name: string): RemoteEvent
	local remote = folder:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end
	local created = Instance.new("RemoteEvent")
	created.Name = name
	created.Parent = folder
	return created
end

function NetService.Init(_self: any)
	local folder = ReplicatedStorage:FindFirstChild(Net.FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = Net.FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end

	for name, definition in Net.ClientEvents do
		remotes[name] = ensureRemote(folder :: Instance, name)
		limiters[name] = RateLimiter.new(definition.burst, definition.perSecond)
	end
	for _, name in Net.ServerEvents do
		remotes[name] = ensureRemote(folder :: Instance, name)
	end

	Players.PlayerRemoving:Connect(function(player)
		for _, limiter in limiters do
			limiter:forget(player)
		end
	end)
end

-- Registers the one handler for a client event. Call from a module's Start().
-- The handler only runs for calls that passed rate limiting and argument type checks;
-- game-rule validation (phase, distance, ownership) is the handler's job.
function NetService.on(name: string, handler: (player: Player, ...any) -> ())
	local definition = Net.ClientEvents[name]
	local remote = remotes[name]
	assert(definition and remote, `Unknown client event "{name}"`)
	assert(not handled[name], `Client event "{name}" already has a handler`)
	handled[name] = true

	remote.OnServerEvent:Connect(function(player: Player, ...: any)
		if not limiters[name]:allow(player, os.clock()) then
			return
		end
		if not argsMatch(definition, table.pack(...)) then
			log:warn(`Rejected {name} from {player.Name}: bad arguments`)
			return
		end
		local ok, err = pcall(handler :: any, player, ...)
		if not ok then
			log:warn(`Handler for {name} failed: {err}`)
		end
	end)
end

local function serverRemote(name: string): RemoteEvent
	assert(table.find(Net.ServerEvents, name), `Unknown server event "{name}"`)
	return remotes[name]
end

-- Sends a server event (see Shared/Net) to one player.
function NetService.fire(name: string, player: Player, ...: any)
	serverRemote(name):FireClient(player, ...)
end

-- Sends a server event to every player.
function NetService.fireAll(name: string, ...: any)
	serverRemote(name):FireAllClients(...)
end

return NetService
