--!strict
-- The local player's flashlight beam.
--
-- The server owns whether the flashlight is on and its battery (attributes on the Player);
-- this controller turns that state into light the holder can actually see. In first
-- person the beam must follow the camera, including up and down, so it is a SpotLight on
-- an invisible part kept at the camera every frame. The lights the server puts on the
-- character's head are for the other players and are switched off on this client.
--
-- Most likely cause of the 0.4.0 failure (found by code inspection, not reproduced in
-- Studio), and what guards against it here: the beam casts
-- shadows and starts inside the player's own head, and a first-person character is only
-- hidden, not removed - it still blocks light. So:
--   * the local character's parts stop casting shadows on this client (other players are
--     unaffected), including accessories that arrive later;
--   * the beam starts in front of the face, not inside it;
--   * a soft fill light without shadows always lights the player's surroundings;
--   * after every switch the light is checked, rebuilt if it has gone missing, and the
--     result is written to the Output window as [TLS:Flashlight].
-- There is exactly one beam per client: it is created once, reused after respawns and
-- replaced only if the camera itself is replaced.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local FlashlightConfig = require(Config:WaitForChild("FlashlightConfig"))
local GameState = require(Shared:WaitForChild("GameState"))
local Logger = require(Shared:WaitForChild("Logger"))

local ATTRIBUTE = GameState.PlayerAttribute
local LIGHT_PART_NAME = "TLS_LocalFlashlight"
local SPOT_NAME = "Beam"
local FILL_NAME = "Fill"
-- Lights the server puts on every character's head (Systems/FlashlightSystem).
local HEAD_LIGHTS = { TLS_Flashlight = true, TLS_FlashlightFill = true }
local FLICKER_INTERVAL = 0.08

local log = Logger.new("Flashlight")

local FlashlightController = {}

local player = Players.LocalPlayer
local random = Random.new()
local lightPart: Part? = nil
local spot: SpotLight? = nil
local fill: PointLight? = nil
local nextFlicker = 0
local shownOn = false

-- The beam: an invisible part under the camera (so it exists only on this client)
-- carrying the lights. Created once per camera; stale copies are removed.
local function ensureLight(camera: Camera): (Part, SpotLight, PointLight)
	if lightPart and spot and fill and lightPart.Parent == camera and spot.Parent == lightPart then
		return lightPart, spot, fill
	end
	for _, child in camera:GetChildren() do
		if child.Name == LIGHT_PART_NAME then
			child:Destroy()
		end
	end

	local part = Instance.new("Part")
	part.Name = LIGHT_PART_NAME
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false

	local beam = Instance.new("SpotLight")
	beam.Name = SPOT_NAME
	beam.Face = Enum.NormalId.Front
	beam.Range = FlashlightConfig.Range
	beam.Angle = FlashlightConfig.Angle
	beam.Brightness = FlashlightConfig.Brightness
	beam.Color = FlashlightConfig.Color
	beam.Shadows = true
	beam.Enabled = false
	beam.Parent = part

	local glow = Instance.new("PointLight")
	glow.Name = FILL_NAME
	glow.Range = FlashlightConfig.FillRange
	glow.Brightness = FlashlightConfig.FillBrightness
	glow.Color = FlashlightConfig.Color
	glow.Shadows = false
	glow.Enabled = false
	glow.Parent = part

	part.Parent = camera
	lightPart, spot, fill = part, beam, glow
	return part, beam, glow
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

-- The player's own body must not block their own beam.
local function stopCastingShadow(instance: Instance)
	if instance:IsA("BasePart") then
		instance.CastShadow = false
	end
end

local function onCharacter(character: Model)
	log:info("Character respawned: beam kept, body shadows disabled locally")
	for _, descendant in character:GetDescendants() do
		stopCastingShadow(descendant)
	end
	character.DescendantAdded:Connect(stopCastingShadow)

	local head = character:WaitForChild("Head", 15)
	if not head then
		log:warn("Error: character has no Head; the server's head light cannot be hidden")
		return
	end
	head.ChildAdded:Connect(suppress)
	for _, child in head:GetChildren() do
		suppress(child)
	end
end

local function update()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local part, beam, glow = ensureLight(camera)
	part.CFrame = camera.CFrame * CFrame.new(FlashlightConfig.LocalOffset)

	local on = player:GetAttribute(ATTRIBUTE.FlashlightOn) == true
	if beam.Enabled ~= on then
		beam.Enabled = on
		beam.Brightness = FlashlightConfig.Brightness
	end
	if glow.Enabled ~= on then
		glow.Enabled = on
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
			beam.Brightness = FlashlightConfig.Brightness * random:NextNumber(0.4, 1)
		end
	elseif beam.Brightness ~= FlashlightConfig.Brightness then
		beam.Brightness = FlashlightConfig.Brightness
	end
end

-- Called when the server changes the flashlight state: log it, and verify that the light
-- the player should be seeing really exists.
local function onStateChanged()
	local on = player:GetAttribute(ATTRIBUTE.FlashlightOn) == true
	if on == shownOn then
		return
	end
	shownOn = on
	local battery = player:GetAttribute(ATTRIBUTE.Battery)
	log:info(
		`{if on then "Enabled" else "Disabled"} (battery {if type(battery) == "number"
			then battery
			else "?"}%)`
	)
	if not on then
		return
	end
	-- One frame later the render step has applied the state; check the result.
	task.delay(0.2, function()
		local camera = Workspace.CurrentCamera
		if player:GetAttribute(ATTRIBUTE.FlashlightOn) ~= true then
			return
		end
		if not camera then
			log:warn("Error: no camera, the beam cannot be shown")
		elseif not (lightPart and lightPart.Parent == camera and spot and spot.Enabled) then
			log:warn("Error: the beam was missing or off after switching on; rebuilding it")
			lightPart = nil
			update()
		end
	end)
end

function FlashlightController.Start(_self: any)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player:GetAttributeChangedSignal(ATTRIBUTE.FlashlightOn):Connect(onStateChanged)

	-- Bound after the camera has moved, so the beam never lags a frame behind the view.
	RunService:BindToRenderStep("TLS_Flashlight", Enum.RenderPriority.Camera.Value + 1, function()
		local ok, err = pcall(update)
		if not ok then
			log:warn(`Error: {err}`)
		end
	end)
	log:info("Initialized")
	onStateChanged()
end

return FlashlightController
