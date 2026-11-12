--!strict
-- Development-only interaction kinds for verifying core systems in Roblox Studio.
-- They are never registered on live servers.
--
--   Kind = "DebugToggle"        toggles the object's `Active` attribute (parts also glow).
--   Kind = "DebugAdvancePhase"  moves the session to the next phase.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameState = require(ReplicatedStorage.Shared.GameState)
local Logger = require(ReplicatedStorage.Shared.Logger)
local SessionService = require(script.Parent.Parent.Services.SessionService)
local InteractionSystem = require(script.Parent.InteractionSystem)

local log = Logger.new("Debug")

local NEXT_PHASE: { [string]: GameState.Phase } = {
	Lobby = "Loading",
	Loading = "Intro",
	Intro = "Playing",
	Playing = "Finale",
	Finale = "Ending",
	Ending = "Lobby",
}

local DebugInteractables = {}

local originalMaterial: { [BasePart]: Enum.Material } = setmetatable({} :: any, { __mode = "k" })

function DebugInteractables.Start(_self: any)
	if SessionService.getMode() ~= "Studio" then
		return
	end

	InteractionSystem.registerKind("DebugToggle", function(player, target, id)
		local active = target:GetAttribute("Active") ~= true
		target:SetAttribute("Active", active)
		if target:IsA("BasePart") then
			if originalMaterial[target] == nil then
				originalMaterial[target] = target.Material
			end
			target.Material = if active then Enum.Material.Neon else originalMaterial[target]
		end
		log:info(`{player.Name} toggled "{id}" -> {if active then "on" else "off"}`)
	end)

	InteractionSystem.registerKind("DebugAdvancePhase", function(player, _target, _id)
		local nextPhase: GameState.Phase = NEXT_PHASE[SessionService.getPhase()]
		log:info(`{player.Name} requested phase {nextPhase}`)
		SessionService.setPhase(nextPhase)
	end)
end

return DebugInteractables
