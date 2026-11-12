--!strict
-- Owns mission progress. Objectives are completed strictly in order and only by server
-- code; the current index is replicated through a ReplicatedStorage attribute, so every
-- player (including late joiners) always sees the same mission state.

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

local function indexOf(id: string): number?
	for position, objective in ObjectiveConfig.List do
		if objective.id == id then
			return position
		end
	end
	return nil
end

function ObjectiveService.Init(_self: any)
	ReplicatedStorage:SetAttribute(GameState.OBJECTIVE_ATTRIBUTE, index)
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
	ReplicatedStorage:SetAttribute(GameState.OBJECTIVE_ATTRIBUTE, index)
	local nextId = ObjectiveService.currentId()
	log:info(`Objective complete: {id}; next: {nextId or "none"}`)
	ObjectiveService.completed:Fire(id, nextId)
	return true
end

return ObjectiveService
