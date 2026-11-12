--!strict
-- THE COPY's body: a temporary placeholder built from plain parts - a tall, thin, almost
-- black figure. No external assets. Every part is anchored and has no collision, queries or
-- touch events: the server moves the whole model directly, and it can never block a
-- player, a raycast or an interaction.

local CollectionService = game:GetService("CollectionService")

local Body = {}

-- Clients find the model by this tag and read its "State" attribute (the Brain state) to
-- attach its looping sounds.
Body.TAG = "TLS_Copy"
Body.STATE_ATTRIBUTE = "State"

-- Height of the eyes above the feet, for sight checks.
Body.EYE_HEIGHT = 6.4

local COLOR = Color3.fromRGB(12, 12, 14)
local ROOT_NAME = "Root"
local GLOW_NAME = "Glow"

-- name, size, centre offset from the feet
local PARTS: { { any } } = {
	{ "LegLeft", Vector3.new(0.6, 3.4, 0.6), Vector3.new(-0.45, 1.7, 0) },
	{ "LegRight", Vector3.new(0.6, 3.4, 0.6), Vector3.new(0.45, 1.7, 0) },
	{ "Torso", Vector3.new(1.7, 2.3, 0.8), Vector3.new(0, 4.55, 0) },
	{ "ArmLeft", Vector3.new(0.45, 3.6, 0.45), Vector3.new(-1.15, 3.9, 0) },
	{ "ArmRight", Vector3.new(0.45, 3.6, 0.45), Vector3.new(1.15, 3.9, 0) },
	{ "Head", Vector3.new(1, 1.3, 1), Vector3.new(0, 6.4, 0) },
}

local function newPart(name: string, size: Vector3, offset: Vector3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = CFrame.new(offset)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Color = COLOR
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Returns an unparented model whose pivot is at the figure's feet, facing -Z.
function Body.build(): Model
	local model = Instance.new("Model")
	model.Name = "TheCopy"
	model:SetAttribute("Placeholder", true)
	model:SetAttribute(Body.STATE_ATTRIBUTE, "Dormant")
	CollectionService:AddTag(model, Body.TAG)

	local root = newPart(ROOT_NAME, Vector3.new(1, 1, 1), Vector3.new(0, 0.5, 0), model)
	root.Transparency = 1
	root.CastShadow = false
	root.PivotOffset = CFrame.new(0, -0.5, 0)
	model.PrimaryPart = root

	for _, definition in PARTS do
		newPart(definition[1], definition[2], definition[3], model)
	end

	-- An almost black figure is invisible in an unlit room. A faint cold glow at chest
	-- height lights the floor and walls around it, so its outline reads against them.
	local glow = Instance.new("PointLight")
	glow.Name = GLOW_NAME
	glow.Color = Color3.fromRGB(120, 140, 150)
	glow.Range = 11
	glow.Brightness = 0.7
	glow.Shadows = false
	glow.Parent = model:FindFirstChild("Torso")
	return model
end

-- 0 = solid, 1 = invisible.
function Body.setTransparency(model: Model, transparency: number)
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child.Name ~= ROOT_NAME then
			child.Transparency = transparency
		end
	end
	local torso = model:FindFirstChild("Torso")
	local glow = torso and torso:FindFirstChild(GLOW_NAME)
	if glow and glow:IsA("PointLight") then
		glow.Enabled = transparency < 0.5
	end
end

return Body
