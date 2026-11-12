--!strict
-- First-person presentation.
--
--   Camera      locked to first person while the mission runs (Roblox then hides the local
--               character for the local player only), with a small step bob.
--   Flashlight  in first person the beam must follow where the player looks, including up
--               and down. The server's light sits on the character's head, which does not
--               pitch, so the local player gets their own beam attached to the camera and
--               their head light is hidden locally. Other players still see the head
--               light. Whether the light is on, and its battery, stay server-owned.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local CameraConfig = require(Config:WaitForChild("CameraConfig"))
local FlashlightConfig = require(Config:WaitForChild("FlashlightConfig"))
local GameState = require(Shared:WaitForChild("GameState"))
local SessionController = require(script.Parent:WaitForChild("SessionController"))

local ATTRIBUTE = GameState.PlayerAttribute
local LOCAL_LIGHT_NAME = "TLS_LocalFlashlight"
-- Lights the server puts on every character's head (Systems/FlashlightSystem).
local HEAD_LIGHTS = { TLS_Flashlight = true, TLS_FlashlightFill = true }
local FLICKER_INTERVAL = 0.08

local CameraController = {}

local player = Players.LocalPlayer
local random = Random.new()
local bobTime = 0
local lightPart: Part? = nil
local spot: SpotLight? = nil
local nextFlicker = 0

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

-- The local beam: an invisible part under the camera (so it exists only on this client)
-- carrying a SpotLight. Created once per camera.
local function ensureLight(camera: Camera): (Part, SpotLight)
	if lightPart and spot and lightPart.Parent == camera then
		return lightPart, spot
	end
	local stale = camera:FindFirstChild(LOCAL_LIGHT_NAME)
	if stale then
		stale:Destroy()
	end

	local part = Instance.new("Part")
	part.Name = LOCAL_LIGHT_NAME
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false

	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Range = FlashlightConfig.Range
	light.Angle = FlashlightConfig.Angle
	light.Brightness = FlashlightConfig.Brightness
	light.Color = FlashlightConfig.Color
	light.Shadows = true
	light.Enabled = false
	light.Parent = part
	part.Parent = camera

	lightPart, spot = part, light
	return part, light
end

-- Keeps the server's head light switched off for the local player only.
local function suppress(light: Instance)
	if not light:IsA("Light") or not HEAD_LIGHTS[light.Name] then
		return
	end
	local function enforce()
		if light.Enabled then
			light.Enabled = false
		end
	end
	light:GetPropertyChangedSignal("Enabled"):Connect(enforce)
	enforce()
end

local function onCharacter(character: Model)
	bobTime = 0
	local head = character:WaitForChild("Head", 15)
	if not head then
		return
	end
	head.ChildAdded:Connect(suppress)
	for _, child in head:GetChildren() do
		suppress(child)
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

local function updateFlashlight(camera: Camera)
	local part, light = ensureLight(camera)
	part.CFrame = camera.CFrame * CFrame.new(CameraConfig.FlashlightOffset)

	local on = player:GetAttribute(ATTRIBUTE.FlashlightOn) == true
	if light.Enabled ~= on then
		light.Enabled = on
		light.Brightness = FlashlightConfig.Brightness
	end
	if not on then
		return
	end
	-- A nearly empty battery makes the beam unsteady.
	local battery = player:GetAttribute(ATTRIBUTE.Battery)
	local now = os.clock()
	if type(battery) == "number" and battery < FlashlightConfig.LowBattery then
		if now >= nextFlicker then
			nextFlicker = now + FLICKER_INTERVAL
			light.Brightness = FlashlightConfig.Brightness * random:NextNumber(0.4, 1)
		end
	elseif light.Brightness ~= FlashlightConfig.Brightness then
		light.Brightness = FlashlightConfig.Brightness
	end
end

function CameraController.Start(_self: any)
	SessionController.phaseChanged:Connect(applyMode)
	applyMode()

	player.CharacterAdded:Connect(function(character)
		onCharacter(character)
		-- Roblox resets the camera on respawn; put first person back.
		applyMode()
	end)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end

	RunService.RenderStepped:Connect(function(dt)
		updateBob(dt)
		local camera = Workspace.CurrentCamera
		if camera then
			updateFlashlight(camera)
		end
	end)
end

return CameraController
