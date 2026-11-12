--!strict
-- What the parts of the mission script share: the milestone record, the values generated
-- for this session, and small helpers for telling players what happened. The chapter
-- modules beside this file report milestones here; SliceDirector (init.luau) is the only
-- place that decides what a completed objective changes in the world.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MissionConfig = require(ReplicatedStorage.Config.MissionConfig)
local ObjectiveConfig = require(ReplicatedStorage.Config.ObjectiveConfig)
local Logger = require(ReplicatedStorage.Shared.Logger)
local Text = require(ReplicatedStorage.Shared.Text)
local NetService = require(script.Parent.Parent.Parent.Services.NetService)
local ObjectiveService = require(script.Parent.Parent.Parent.Services.ObjectiveService)
local SessionService = require(script.Parent.Parent.Parent.Services.SessionService)
local Progress = require(script.Parent.Progress)

local log = Logger.new("Slice")

local Mission = {}

Mission.COLOR_OFF = Color3.fromRGB(120, 40, 38)
Mission.COLOR_WAIT = Color3.fromRGB(204, 150, 56)
Mission.COLOR_OK = Color3.fromRGB(70, 170, 120)
Mission.COLOR_DEAD = Color3.fromRGB(90, 96, 100)

local order: { string } = {}
for _, objective in ObjectiveConfig.List do
	table.insert(order, objective.id)
end
local progress = Progress.new(order)
local completedHooks: { [string]: { () -> () } } = {}
local activeHooks: { [string]: { () -> () } } = {}

-- The carrier channel the trace finds and the radio desk must be tuned to.
Mission.channel = Random.new():NextInteger(1, MissionConfig.TunerChannels)

function Mission.playing(): boolean
	return SessionService.isPlaying()
end

function Mission.isDone(id: string): boolean
	return ObjectiveService.isCompleted(id)
end

-- Completes the current objective for as long as its milestone has been reached.
function Mission.reconcile()
	if not SessionService.isPlaying() then
		return
	end
	local current = ObjectiveService.currentId()
	while current and Progress.has(progress, current) do
		ObjectiveService.complete(current)
		current = ObjectiveService.currentId()
	end
end

-- A hard milestone: everything before it counts as done as well (see Progress).
function Mission.reach(id: string)
	if Progress.reach(progress, id) then
		Mission.reconcile()
	else
		log:warn(`Unknown milestone "{id}"`)
	end
end

-- A soft milestone: remembered until its objective's turn comes.
function Mission.mark(id: string)
	if Progress.mark(progress, id) then
		Mission.reconcile()
	else
		log:warn(`Unknown milestone "{id}"`)
	end
end

-- Runs `callback` once the objective is complete (immediately if it already is).
function Mission.onCompleted(id: string, callback: () -> ())
	if ObjectiveService.isCompleted(id) then
		task.spawn(callback)
		return
	end
	local hooks = completedHooks[id] or {}
	completedHooks[id] = hooks
	table.insert(hooks, callback)
end

-- Runs `callback` every time the objective becomes the current one.
function Mission.onActive(id: string, callback: () -> ())
	local hooks = activeHooks[id] or {}
	activeHooks[id] = hooks
	table.insert(hooks, callback)
end

function Mission.notify(player: Player, key: string, params: Text.Params?, kind: string?)
	NetService.fire("Notify", player, Text.ref(key, params), kind or "info")
end

function Mission.notifyAll(key: string, params: Text.Params?, kind: string?)
	NetService.fireAll("Notify", Text.ref(key, params), kind or "info")
end

function Mission.Init()
	ObjectiveService.completed:Connect(function(id: string, nextId: string?)
		local hooks = completedHooks[id]
		completedHooks[id] = nil
		for _, callback in hooks or {} do
			task.spawn(callback)
		end
		for _, callback in (if nextId then activeHooks[nextId] else nil) or {} do
			task.spawn(callback)
		end
	end)
end

return Mission
