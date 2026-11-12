--!strict
-- Shared look of the interface: dark industrial surfaces, cold cyan accents, emergency red
-- for warnings. Every screen is built in code from these helpers, so the whole UI lives in
-- Git and stays consistent.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Theme = {}

Theme.Color = table.freeze({
	Black = Color3.fromRGB(0, 0, 0),
	Panel = Color3.fromRGB(14, 17, 20),
	PanelLight = Color3.fromRGB(30, 35, 40),
	Text = Color3.fromRGB(214, 220, 224),
	Dim = Color3.fromRGB(120, 130, 138),
	Accent = Color3.fromRGB(96, 190, 204),
	Warning = Color3.fromRGB(214, 62, 54),
	Paper = Color3.fromRGB(202, 198, 184),
	Ink = Color3.fromRGB(28, 28, 30),
})

Theme.Font = table.freeze({
	Regular = Enum.Font.Gotham,
	Medium = Enum.Font.GothamMedium,
	Bold = Enum.Font.GothamBold,
	Mono = Enum.Font.RobotoMono,
})

-- Heights the layouts are designed for; smaller screens scale everything down.
local DESIGN_HEIGHT = 820
local MIN_SCALE, MAX_SCALE = 0.62, 1.25

-- Creates an instance, applies the properties and parents it last.
function Theme.make(className: string, properties: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className) :: any
	for property, value in properties do
		instance[property] = value
	end
	instance.Parent = parent
	return instance
end

-- A ScreenGui in the local player's PlayerGui that survives respawns.
function Theme.screen(name: string, displayOrder: number): ScreenGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	return Theme.make("ScreenGui", {
		Name = name,
		DisplayOrder = displayOrder,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		-- All text is translated by the game itself (Shared/Localization). Roblox's
		-- automatic capture and translation would fight it, so it is switched off.
		AutoLocalize = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)
end

-- Adds a UIScale that follows the screen height, so one layout fits phones and monitors.
function Theme.autoScale(target: Instance)
	local scale: UIScale = Theme.make("UIScale", {}, target)
	local connection: RBXScriptConnection? = nil

	local function update()
		local camera = Workspace.CurrentCamera
		if camera then
			scale.Scale = math.clamp(camera.ViewportSize.Y / DESIGN_HEIGHT, MIN_SCALE, MAX_SCALE)
		end
	end
	local function watchCamera()
		if connection then
			connection:Disconnect()
		end
		local camera = Workspace.CurrentCamera
		if camera then
			connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		end
		update()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	watchCamera()
end

function Theme.corner(target: Instance, radius: number)
	Theme.make("UICorner", { CornerRadius = UDim.new(0, radius) }, target)
end

-- A thin outline around a frame or button.
function Theme.border(target: Instance, color: Color3, transparency: number): UIStroke
	return Theme.make("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color,
		Transparency = transparency,
		Thickness = 1,
	}, target)
end

function Theme.padding(target: Instance, horizontal: number, vertical: number)
	Theme.make("UIPadding", {
		PaddingLeft = UDim.new(0, horizontal),
		PaddingRight = UDim.new(0, horizontal),
		PaddingTop = UDim.new(0, vertical),
		PaddingBottom = UDim.new(0, vertical),
	}, target)
end

function Theme.tween(target: Instance, seconds: number, goal: { [string]: any }): Tween
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(target, info, goal)
	tween:Play()
	return tween
end

return Theme
