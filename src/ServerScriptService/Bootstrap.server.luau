--!strict
-- Single server entry point. No other Script should exist: everything else is a
-- ModuleScript in Services/ (game-wide systems) or Systems/ (gameplay features),
-- loaded here in a controlled order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Loader = require(ReplicatedStorage.Shared.Loader)
local Logger = require(ReplicatedStorage.Shared.Logger)

local log = Logger.new("Server")
local root = script.Parent :: Instance

local function count(modules: { [string]: any }): number
	local total = 0
	for _ in modules do
		total += 1
	end
	return total
end

local services = Loader.loadFolder(root:WaitForChild("Services"), "Services")
local systems = Loader.loadFolder(root:WaitForChild("Systems"), "Systems")

log:info(
	`{GameConfig.GameName} v{GameConfig.Version} started: `
		.. `{count(services)} services, {count(systems)} systems`
)
