--!strict
-- First-person presentation: the camera is locked to first person while the mission runs
-- (Roblox then hides the local character for the local player only), with a small step
-- bob. The flashlight beam that follows the camera lives in FlashlightController.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local CameraConfig = require(Config:WaitForChild("CameraConfig"))
local GameState = require(Shared:WaitForChild("GameState"))
local SessionController = require(script.Parent:WaitForChild("SessionController"))

local CameraController = {}

local player = Players.LocalPlayer
local bobTime = 0

local function firstPersonActive(): boolean
	local phase = SessionController.getPhase()
	return CameraConfig.FirstPerson
		and (phase == GameState.Phase.Playing or phase == GameState.Phase.Finale)
end

local function applyMode()
	player.CameraMode = if firstPersonActive()
		then Enum.CameraMode.LockFirstPerson
		else Enum.CameraMode.Classic
	local camera = Workspace.CurrentCamera
	if camera then
		camera.FieldOfView = CameraConfig.FieldOfView
	end
end

local function updateBob(dt: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local target = Vector3.zero
	local root = humanoid.RootPart
	if
		CameraConfig.Bob
		and firstPersonActive()
		and root
		and humanoid.FloorMaterial ~= Enum.Material.Air
	then
		local velocity = root.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		if speed > 1 then
			local amplitude = if speed > CameraConfig.RunSpeedThreshold
				then CameraConfig.RunBob
				else CameraConfig.WalkBob
			bobTime += dt * speed * CameraConfig.BobFrequency
			target = Vector3.new(
				math.sin(bobTime) * amplitude * 0.5,
				-math.abs(math.sin(bobTime)) * amplitude,
				0
			)
		end
	end
	local alpha = math.min(1, dt * CameraConfig.BobSmoothing)
	humanoid.CameraOffset = humanoid.CameraOffset:Lerp(target, alpha)
end

function CameraController.Start(_self: any)
	SessionController.phaseChanged:Connect(applyMode)
	applyMode()

	player.CharacterAdded:Connect(function()
		bobTime = 0
		-- Roblox resets the camera on respawn; put first person back.
		applyMode()
	end)

	RunService.RenderStepped:Connect(updateBob)
end

return CameraController
