--!strict
-- Owns the server mode and the current session phase. The phase is replicated to clients
-- through attributes on ReplicatedStorage, so late joiners always read the current value.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameState = require(ReplicatedStorage.Shared.GameState)
local Logger = require(ReplicatedStorage.Shared.Logger)
local Signal = require(ReplicatedStorage.Shared.Signal)

-- Lobby:   public server; menu and party forming only.
-- Session: reserved server created for one party; runs the story.
-- Studio:  Roblox Studio, where teleporting is unavailable; lobby and story share a server.
export type Mode = "Lobby" | "Session" | "Studio"

local log = Logger.new("SessionService")

local SessionService = {}

-- Fired with (newPhase, oldPhase) after the phase changed.
SessionService.phaseChanged = Signal.new()

local mode: Mode = "Lobby"
local phase: GameState.Phase = GameState.Phase.Lobby

local function detectMode(): Mode
	if RunService:IsStudio() then
		return "Studio"
	end
	-- Reserved servers have a PrivateServerId but no owner (owned ones are paid VIP servers).
	if game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0 then
		return "Session"
	end
	return "Lobby"
end

function SessionService.Init(_self: any)
	mode = detectMode()
	ReplicatedStorage:SetAttribute(GameState.MODE_ATTRIBUTE, mode)
	ReplicatedStorage:SetAttribute(GameState.PHASE_ATTRIBUTE, phase)
	log:info(`Mode: {mode}, phase: {phase}`)
end

function SessionService.getMode(): Mode
	return mode
end

function SessionService.getPhase(): GameState.Phase
	return phase
end

-- True while the mission itself is running (not during menus, intro or ending).
function SessionService.isPlaying(): boolean
	return phase == GameState.Phase.Playing
end

-- Returns false (and changes nothing) when the transition is not allowed.
function SessionService.setPhase(to: GameState.Phase): boolean
	if not GameState.canTransition(phase, to) then
		log:warn(`Refused phase change {phase} -> {to}`)
		return false
	end
	local from = phase
	phase = to
	ReplicatedStorage:SetAttribute(GameState.PHASE_ATTRIBUTE, to)
	log:info(`Phase: {from} -> {to}`)
	SessionService.phaseChanged:Fire(to, from)
	return true
end

return SessionService
