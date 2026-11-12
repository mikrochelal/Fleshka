--!strict
-- Owns mission progress. Main objectives are completed strictly in order and only by
-- server code; optional objectives are tracked beside them and never block anything.
-- Everything is replicated through ReplicatedStorage attributes, so every player
-- (including late joiners) always sees the same mission state. Progress only ever moves
-- forward: nothing here can lower the index or undo an optional objective.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ObjectiveConfig = require(ReplicatedStorage.Config.ObjectiveConfig)
local GameState = require(ReplicatedStorage.Shared.GameState)
local Logger = require(ReplicatedStorage.Shared.Logger)
local Signal = require(ReplicatedStorage.Shared.Signal)

local log = Logger.new("ObjectiveService")

local ObjectiveService = {}

-- Fired with (completedId: string, nextId: string?) after an objective was completed.
ObjectiveService.completed = Signal.new()

local index = 1
local optional: { [string]: GameState.Progress } = {}

local function indexOf(id: string): number?
	for position, objective in ObjectiveConfig.List do
		if objective.id == id then
			return position
		end
	end
	return nil
end

local function publishOptional()
	local list: { GameState.Progress } = {}
	for _, definition in ObjectiveConfig.Optional do
		local progress = optional[definition.id]
		if progress then
			table.insert(list, progress)
		end
	end
	ReplicatedStorage:SetAttribute(GameState.OPTIONAL_ATTRIBUTE, GameState.encodeProgress(list))
end

function ObjectiveService.Init(_self: any)
	ReplicatedStorage:SetAttribute(GameState.OBJECTIVE_ATTRIBUTE, index)
	ReplicatedStorage:SetAttribute(GameState.OBJECTIVE_PROGRESS_ATTRIBUTE, "")
	ReplicatedStorage:SetAttribute(GameState.OPTIONAL_ATTRIBUTE, "")
end

-- The id of the current objective, or nil when the mission is complete.
function ObjectiveService.currentId(): string?
	local objective = ObjectiveConfig.List[index]
	return if objective then objective.id else nil
end

function ObjectiveService.isActive(id: string): boolean
	return ObjectiveService.currentId() == id
end

-- True when the objective is behind the current one.
function ObjectiveService.isCompleted(id: string): boolean
	local position = indexOf(id)
	return position ~= nil and position < index
end

function ObjectiveService.allCompleted(): boolean
	return index > #ObjectiveConfig.List
end

-- The chapter of the current objective (the last chapter once the mission is complete).
function ObjectiveService.chapter(): number
	local objective = ObjectiveConfig.List[math.min(index, #ObjectiveConfig.List)]
	return objective.chapter
end

-- Room players are returned to after being caught or respawning.
function ObjectiveService.checkpointRoom(): string
	return ObjectiveConfig.Chapters[ObjectiveService.chapter()].checkpoint
end

-- Completes the objective only if it is the current one. Returns whether it advanced, so
-- callers can report conditions freely without tracking order themselves.
function ObjectiveService.complete(id: string): boolean
	if not indexOf(id) then
		log:warn(`Unknown objective "{id}"`)
		return false
	end
	if not ObjectiveService.isActive(id) then
		return false
	end
	index += 1
	ReplicatedStorage:SetAttribute(GameState.OBJECTIVE_PROGRESS_ATTRIBUTE, "")
	ReplicatedStorage:SetAttribute(GameState.OBJECTIVE_ATTRIBUTE, index)
	local nextId = ObjectiveService.currentId()
	log:info(`Objective complete: {id}; next: {nextId or "none"}`)
	ObjectiveService.completed:Fire(id, nextId)
	return true
end

-- Shows progress inside the current objective (an encoded text reference); ignored when
-- `id` is not the current objective, so steps done early never overwrite another line.
function ObjectiveService.setProgress(id: string, text: string)
	if ObjectiveService.isActive(id) then
		ReplicatedStorage:SetAttribute(GameState.OBJECTIVE_PROGRESS_ATTRIBUTE, text)
	end
end

-- Records progress on an optional objective. It can only grow.
function ObjectiveService.setOptional(id: string, done: number, total: number)
	local previous = optional[id]
	if previous and done <= previous.done then
		return
	end
	optional[id] = { id = id, done = math.min(done, total), total = total }
	publishOptional()
	if done >= total then
		log:info(`Optional objective complete: {id}`)
	end
end

return ObjectiveService
