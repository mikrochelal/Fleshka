--!strict
-- Player controls beyond Roblox's built-in movement: sprint and flashlight. This module
-- only reports intent to the server; stamina, speed and the light itself are server-owned.
--
--   Keyboard: hold Left Shift to sprint, F to switch the flashlight.
--   Gamepad:  hold L3 to sprint, Y to switch the flashlight.
--   Touch:    on-screen buttons (created by HudController) call the functions below.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local SPRINT_KEYS = { Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3 }
local FLASHLIGHT_KEYS = { Enum.KeyCode.F, Enum.KeyCode.ButtonY }

local InputController = {}

local sprintRemote: RemoteEvent? = nil
local flashlightRemote: RemoteEvent? = nil
local sprinting = false

-- Reports whether the sprint control is held. Repeated identical values are not re-sent.
function InputController.setSprint(wants: boolean)
	if wants == sprinting then
		return
	end
	sprinting = wants
	if sprintRemote then
		sprintRemote:FireServer(wants)
	end
end

function InputController.isSprintHeld(): boolean
	return sprinting
end

function InputController.toggleFlashlight()
	if flashlightRemote then
		flashlightRemote:FireServer()
	end
end

function InputController.Start(_self: any)
	sprintRemote = Net.waitForClientEvent("SprintIntent")
	flashlightRemote = Net.waitForClientEvent("FlashlightToggle")

	UserInputService.InputBegan:Connect(function(input, processed)
		-- `processed` is true while typing in chat or pressing a GUI button.
		if processed then
			return
		end
		if table.find(SPRINT_KEYS, input.KeyCode) then
			InputController.setSprint(true)
		elseif table.find(FLASHLIGHT_KEYS, input.KeyCode) then
			InputController.toggleFlashlight()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if table.find(SPRINT_KEYS, input.KeyCode) then
			InputController.setSprint(false)
		end
	end)
	-- A new character starts walking on the server, so the local state must match.
	Players.LocalPlayer.CharacterAdded:Connect(function()
		InputController.setSprint(false)
	end)
	-- Losing focus swallows the key release, so stop sprinting explicitly.
	UserInputService.WindowFocusReleased:Connect(function()
		InputController.setSprint(false)
	end)
end

return InputController
