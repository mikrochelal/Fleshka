--!strict
-- Single client entry point. All client behaviour lives in ModuleScripts under Controllers/.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Loader = require(Shared:WaitForChild("Loader"))
local Logger = require(Shared:WaitForChild("Logger"))

local log = Logger.new("Client")
local root = script.Parent :: Instance

local controllers = Loader.loadFolder(root:WaitForChild("Controllers"), "Controllers")

local total = 0
for _ in controllers do
	total += 1
end
log:info(`Client started: {total} controllers`)
