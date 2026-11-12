--!strict
-- Client view of the server-owned session phase, plus the "client is ready" handshake.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameState = require(Shared:WaitForChild("GameState"))
local Logger = require(Shared:WaitForChild("Logger"))
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))

local log = Logger.new("Session")

local SessionController = {}

-- Fired with (newPhase, oldPhase) whenever the server changes the phase.
SessionController.phaseChanged = Signal.new()

local phase: GameState.Phase = GameState.Phase.Lobby

-- Keeps the current phase when the attribute is missing or not a phase name.
local function readPhase(): GameState.Phase
	local value = ReplicatedStorage:GetAttribute(GameState.PHASE_ATTRIBUTE)
	if type(value) ~= "string" then
		return phase
	end
	return GameState.parsePhase(value, phase)
end

function SessionController.getPhase(): GameState.Phase
	return phase
end

function SessionController.Init(_self: any)
	phase = readPhase()

	ReplicatedStorage:GetAttributeChangedSignal(GameState.PHASE_ATTRIBUTE):Connect(function()
		local newPhase: GameState.Phase = readPhase()
		if newPhase ~= phase then
			local oldPhase = phase
			phase = newPhase
			log:info(`Phase: {oldPhase} -> {newPhase}`)
			SessionController.phaseChanged:Fire(newPhase, oldPhase)
		end
	end)
end

function SessionController.Start(_self: any)
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	log:info(`Phase: {phase}`)
	Net.waitForClientEvent("ClientReady"):FireServer()
end

return SessionController
