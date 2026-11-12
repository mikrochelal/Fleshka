--!strict
-- The always-visible HUD: current objective with the completed ones above it, stamina and
-- flashlight battery, and the touch buttons for sprint and flashlight on mobile.
-- Everything shown here is read from server-owned attributes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local GameState = require(Shared:WaitForChild("GameState"))
local ObjectiveConfig = require(Config:WaitForChild("ObjectiveConfig"))
local FlashlightConfig = require(Config:WaitForChild("FlashlightConfig"))
local Theme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Theme"))
local InputController = require(script.Parent:WaitForChild("InputController"))

local ATTRIBUTE = GameState.PlayerAttribute
local BAR_WIDTH = 200
-- Completed objectives kept on screen above the current one.
local HISTORY = 2

local HudController = {}

local player = Players.LocalPlayer
local root: Frame
local objectiveList: Frame
local staminaFill: Frame
local batteryFill: Frame
local batteryLabel: TextLabel
local sprintButton: TextButton?
local shownObjective = 0

local function bar(parent: Instance, title: string, order: number): (Frame, TextLabel)
	local row = Theme.make("Frame", {
		Name = title,
		Size = UDim2.fromOffset(BAR_WIDTH, 26),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, parent)
	local label = Theme.make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundTransparency = 1,
		Font = Theme.Font.Medium,
		TextSize = 11,
		TextColor3 = Theme.Color.Dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = title,
	}, row)
	local track = Theme.make("Frame", {
		Position = UDim2.fromOffset(0, 17),
		Size = UDim2.new(1, 0, 0, 5),
		BackgroundColor3 = Theme.Color.PanelLight,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
	}, row)
	local fill = Theme.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.Text,
		BorderSizePixel = 0,
	}, track)
	return fill, label
end

local function objectiveRow(text: string, completed: boolean, order: number): TextLabel
	return Theme.make("TextLabel", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = if completed then Theme.Font.Regular else Theme.Font.Medium,
		TextSize = if completed then 13 else 16,
		TextColor3 = if completed then Theme.Color.Dim else Theme.Color.Text,
		TextTransparency = if completed then 0.35 else 0,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		RichText = true,
		-- Completed objectives are dimmed and struck through.
		Text = if completed then `<s>{text}</s>` else text,
		LayoutOrder = order,
	}, objectiveList)
end

local function renderObjectives()
	local value = ReplicatedStorage:GetAttribute(GameState.OBJECTIVE_ATTRIBUTE)
	local index = if type(value) == "number" then value else 1
	if index == shownObjective then
		return
	end
	local advanced = shownObjective ~= 0 and index > shownObjective
	shownObjective = index

	for _, child in objectiveList:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local list = ObjectiveConfig.List
	for position = math.max(1, index - HISTORY), math.min(index, #list) do
		local row = objectiveRow(list[position].text, position < index, position)
		if position == index and advanced then
			-- The new objective fades in from the accent colour.
			row.TextColor3 = Theme.Color.Accent
			row.TextTransparency = 1
			Theme.tween(row, 0.6, { TextTransparency = 0 })
			task.delay(1.6, function()
				if row.Parent then
					Theme.tween(row, 1.2, { TextColor3 = Theme.Color.Text })
				end
			end)
		end
	end
	if index > #list then
		objectiveRow("All objectives complete.", false, index)
	end
end

local function renderBars()
	local stamina = player:GetAttribute(ATTRIBUTE.Stamina)
	local battery = player:GetAttribute(ATTRIBUTE.Battery)
	local exhausted = player:GetAttribute(ATTRIBUTE.Exhausted) == true
	local lightOn = player:GetAttribute(ATTRIBUTE.FlashlightOn) == true

	local staminaRatio =
		math.clamp((if type(stamina) == "number" then stamina else 100) / 100, 0, 1)
	local batteryRatio =
		math.clamp((if type(battery) == "number" then battery else 100) / 100, 0, 1)

	staminaFill.Size = UDim2.fromScale(staminaRatio, 1)
	staminaFill.BackgroundColor3 = if exhausted then Theme.Color.Warning else Theme.Color.Text

	local low = batteryRatio * 100 < FlashlightConfig.LowBattery
	batteryFill.Size = UDim2.fromScale(batteryRatio, 1)
	batteryFill.BackgroundColor3 = if low then Theme.Color.Warning else Theme.Color.Accent
	batteryLabel.Text =
		`FLASHLIGHT  {if lightOn then "ON" else "OFF"}  {math.floor(batteryRatio * 100)}%`
	batteryLabel.TextColor3 = if lightOn then Theme.Color.Accent else Theme.Color.Dim

	if sprintButton then
		local held = InputController.isSprintHeld()
		sprintButton.BackgroundColor3 = if held then Theme.Color.Accent else Theme.Color.Panel
		sprintButton.TextColor3 = if held then Theme.Color.Ink else Theme.Color.Text
	end
end

local function touchButton(text: string, offsetY: number): TextButton
	local button = Theme.make("TextButton", {
		Name = text,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -20, 0.5, offsetY),
		Size = UDim2.fromOffset(76, 76),
		BackgroundColor3 = Theme.Color.Panel,
		BackgroundTransparency = 0.25,
		AutoButtonColor = true,
		Font = Theme.Font.Medium,
		TextSize = 13,
		TextColor3 = Theme.Color.Text,
		Text = text,
	}, root)
	Theme.autoScale(button)
	Theme.corner(button, 38)
	Theme.border(button, Theme.Color.Accent, 0.5)
	return button
end

local function build()
	local screen = Theme.screen("TLS_HUD", 10)
	root = Theme.make("Frame", {
		Name = "Root",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, screen)

	-- Objective, top left. Kept clear of the Roblox top bar.
	local objective = Theme.make("Frame", {
		Name = "Objective",
		Position = UDim2.fromOffset(24, 64),
		Size = UDim2.fromOffset(340, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Color.Panel,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
	}, root)
	Theme.autoScale(objective)
	Theme.padding(objective, 14, 10)
	Theme.make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	}, objective)
	-- A short accent dash; fixed size, so it takes part in the list without affecting it.
	Theme.make("Frame", {
		Name = "Accent",
		Size = UDim2.fromOffset(28, 2),
		BackgroundColor3 = Theme.Color.Accent,
		BorderSizePixel = 0,
		LayoutOrder = -1,
	}, objective)
	Theme.make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 12),
		BackgroundTransparency = 1,
		Font = Theme.Font.Bold,
		TextSize = 11,
		TextColor3 = Theme.Color.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "OBJECTIVE",
		LayoutOrder = 0,
	}, objective)
	objectiveList = Theme.make("Frame", {
		Name = "List",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
	}, objective)
	Theme.make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, objectiveList)

	-- Status bars, bottom left.
	local status = Theme.make("Frame", {
		Name = "Status",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 24, 1, -28),
		Size = UDim2.fromOffset(BAR_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, root)
	Theme.make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	}, status)
	Theme.autoScale(status)
	staminaFill = bar(status, "STAMINA", 1)
	batteryFill, batteryLabel = bar(status, "FLASHLIGHT", 2)

	-- Touch controls, right edge above the jump button. Keyboard and gamepad use keys.
	if UserInputService.TouchEnabled then
		local flashlight = touchButton("LIGHT", -70)
		flashlight.Activated:Connect(InputController.toggleFlashlight)

		-- Sprint is a toggle on touch: holding a button while steering is awkward.
		local sprint = touchButton("RUN", 20)
		sprint.Activated:Connect(function()
			InputController.setSprint(not InputController.isSprintHeld())
			renderBars()
		end)
		sprintButton = sprint
	end
end

function HudController.Start(_self: any)
	build()

	ReplicatedStorage:GetAttributeChangedSignal(GameState.OBJECTIVE_ATTRIBUTE)
		:Connect(renderObjectives)
	for _, attribute in ATTRIBUTE do
		player:GetAttributeChangedSignal(attribute):Connect(renderBars)
	end
	-- The server forgets the sprint request when the character respawns; refresh the
	-- touch button after InputController has reset its own state.
	player.CharacterAdded:Connect(function()
		task.defer(renderBars)
	end)
	renderObjectives()
	renderBars()
end

return HudController
