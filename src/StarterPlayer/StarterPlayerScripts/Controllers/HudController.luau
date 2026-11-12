--!strict
-- The always-visible HUD: chapter, current objective with the completed ones above it,
-- progress inside multi-step objectives, optional objectives, stamina and flashlight
-- battery, the language switch, and the touch buttons for sprint and flashlight.
-- Everything shown here is read from server-owned attributes and rendered in the
-- player's language; it is redrawn whenever the language changes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local GameState = require(Shared:WaitForChild("GameState"))
local ObjectiveConfig = require(Config:WaitForChild("ObjectiveConfig"))
local FlashlightConfig = require(Config:WaitForChild("FlashlightConfig"))
local Theme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Theme"))
local AudioController = require(script.Parent:WaitForChild("AudioController"))
local InputController = require(script.Parent:WaitForChild("InputController"))
local LocalizationController = require(script.Parent:WaitForChild("LocalizationController"))
local SessionController = require(script.Parent:WaitForChild("SessionController"))

local ATTRIBUTE = GameState.PlayerAttribute
local BAR_WIDTH = 220
local PANEL_WIDTH = 360
-- Completed objectives kept on screen above the current one.
local HISTORY = 1
local COMPLETE_SECONDS = 2.6

local t = LocalizationController.t

local HudController = {}

local player = Players.LocalPlayer
local root: Frame
local objectiveList: Frame
local chapterLabel: TextLabel
local headingLabel: TextLabel
local powerLabel: TextLabel
local completeToast: TextLabel
local staminaFill: Frame
local staminaLabel: TextLabel
local batteryFill: Frame
local batteryLabel: TextLabel
local languageButton: TextButton
local flashlightButton: TextButton?
local sprintButton: TextButton?
local shownObjective = 0
local toastToken = 0

local function bar(parent: Instance, name: string, order: number): (Frame, TextLabel)
	local row = Theme.make("Frame", {
		Name = name,
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
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
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

local function textRow(properties: { [string]: any }): TextLabel
	local base: { [string]: any } = {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = Theme.Font.Regular,
		TextSize = 13,
		TextColor3 = Theme.Color.Dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	}
	for property, value in properties do
		base[property] = value
	end
	return Theme.make("TextLabel", base, objectiveList)
end

local function objectiveIndex(): number
	local value = ReplicatedStorage:GetAttribute(GameState.OBJECTIVE_ATTRIBUTE)
	return if type(value) == "number" then value else 1
end

-- Rebuilds the objective panel. `animate` plays the fade-in of a newly received objective.
local function renderObjectives(animate: boolean)
	local index = objectiveIndex()
	local list = ObjectiveConfig.List
	for _, child in objectiveList:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	local current = list[index]
	local chapter = (current or list[#list]).chapter
	chapterLabel.Text =
		`{t("UI_CHAPTER", { number = chapter })}  -  {t(ObjectiveConfig.Chapters[chapter].title)}`
	headingLabel.Text = t("UI_OBJECTIVE")

	for position = math.max(1, index - HISTORY), math.min(index, #list) do
		local completed = position < index
		local text = t(list[position].title)
		local row = textRow({
			Font = if completed then Theme.Font.Regular else Theme.Font.Medium,
			TextSize = if completed then 13 else 16,
			TextColor3 = if completed then Theme.Color.Dim else Theme.Color.Text,
			TextTransparency = if completed then 0.35 else 0,
			RichText = completed,
			-- Completed objectives are dimmed and struck through.
			Text = if completed then `<s>{text}</s>` else text,
			LayoutOrder = position * 10,
		})
		if position == index and animate then
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
		textRow({
			Font = Theme.Font.Medium,
			TextSize = 16,
			TextColor3 = Theme.Color.Text,
			Text = t("UI_ALL_COMPLETE"),
			LayoutOrder = index * 10,
		})
	end

	-- Progress inside a multi-step objective.
	local progress = ReplicatedStorage:GetAttribute(GameState.OBJECTIVE_PROGRESS_ATTRIBUTE)
	if current and type(progress) == "string" and progress ~= "" then
		textRow({
			Name = "Progress",
			Font = Theme.Font.Medium,
			TextColor3 = Theme.Color.Accent,
			Text = LocalizationController.render(progress),
			LayoutOrder = index * 10 + 1,
		})
	end
	-- One line of practical help under the current objective.
	if current and current.hint then
		textRow({
			Name = "Hint",
			TextSize = 12,
			Text = t(current.hint),
			LayoutOrder = index * 10 + 2,
		})
	end

	-- Optional objectives, once the team has started any of them.
	local optional = ReplicatedStorage:GetAttribute(GameState.OPTIONAL_ATTRIBUTE)
	local entries: { GameState.Progress } = if type(optional) == "string"
		then GameState.decodeProgress(optional)
		else {}
	if #entries > 0 then
		textRow({
			Name = "OptionalHeading",
			Font = Theme.Font.Bold,
			TextSize = 10,
			Text = t("UI_OPTIONAL"),
			LayoutOrder = 100000,
		})
		for order, entry in entries do
			for _, definition in ObjectiveConfig.Optional do
				if definition.id == entry.id then
					local done = entry.done >= entry.total
					local text = t("UI_OPTIONAL_PROGRESS", {
						title = t(definition.title),
						done = entry.done,
						total = entry.total,
					})
					textRow({
						TextSize = 12,
						RichText = done,
						TextTransparency = if done then 0.35 else 0,
						Text = if done then `<s>{text}</s>` else text,
						LayoutOrder = 100000 + order,
					})
				end
			end
		end
	end
end

local function showCompleteToast()
	toastToken += 1
	local token = toastToken
	completeToast.Text = t("UI_OBJECTIVE_COMPLETE")
	completeToast.Visible = true
	completeToast.TextTransparency = 1
	Theme.tween(completeToast, 0.3, { TextTransparency = 0 })
	AudioController.play("ObjectiveComplete")
	task.delay(COMPLETE_SECONDS, function()
		if token ~= toastToken then
			return
		end
		Theme.tween(completeToast, 0.6, { TextTransparency = 1 })
		task.wait(0.65)
		if token == toastToken then
			completeToast.Visible = false
		end
	end)
end

local function onObjectiveChanged()
	local index = objectiveIndex()
	local advanced = shownObjective ~= 0 and index > shownObjective
	shownObjective = index
	renderObjectives(advanced)
	if advanced then
		showCompleteToast()
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

	staminaLabel.Text = t("UI_STAMINA")
	staminaFill.Size = UDim2.fromScale(staminaRatio, 1)
	staminaFill.BackgroundColor3 = if exhausted then Theme.Color.Warning else Theme.Color.Text

	local low = batteryRatio * 100 < FlashlightConfig.LowBattery
	batteryFill.Size = UDim2.fromScale(batteryRatio, 1)
	batteryFill.BackgroundColor3 = if low then Theme.Color.Warning else Theme.Color.Accent
	batteryLabel.Text = t("UI_FLASHLIGHT_STATUS", {
		state = t(if lightOn then "UI_ON" else "UI_OFF"),
		percent = math.floor(batteryRatio * 100),
	})
	batteryLabel.TextColor3 = if lightOn then Theme.Color.Accent else Theme.Color.Dim

	if sprintButton then
		local held = InputController.isSprintHeld()
		sprintButton.BackgroundColor3 = if held then Theme.Color.Accent else Theme.Color.Panel
		sprintButton.TextColor3 = if held then Theme.Color.Ink else Theme.Color.Text
	end
	if flashlightButton then
		flashlightButton.BackgroundColor3 = if lightOn
			then Theme.Color.Accent
			else Theme.Color.Panel
		flashlightButton.TextColor3 = if lightOn then Theme.Color.Ink else Theme.Color.Text
	end
end

local function renderPower()
	local engaged = ReplicatedStorage:GetAttribute(GameState.BREAKERS_ENGAGED_ATTRIBUTE)
	local total = ReplicatedStorage:GetAttribute(GameState.BREAKERS_TOTAL_ATTRIBUTE)
	if ReplicatedStorage:GetAttribute(GameState.POWER_ATTRIBUTE) == true then
		powerLabel.Text = t("UI_POWER_ONLINE")
		powerLabel.TextColor3 = Theme.Color.Accent
	elseif type(engaged) == "number" and type(total) == "number" and total > 0 then
		powerLabel.Text = t("UI_POWER_BREAKERS", { engaged = engaged, total = total })
		powerLabel.TextColor3 = Theme.Color.Warning
	else
		powerLabel.Text = t("UI_POWER_OFFLINE")
		powerLabel.TextColor3 = Theme.Color.Warning
	end
end

-- Static texts that only change with the language.
local function renderStatic()
	languageButton.Text = LocalizationController.switchLabel()
	if flashlightButton then
		flashlightButton.Text = t("UI_TOUCH_LIGHT")
	end
	if sprintButton then
		sprintButton.Text = t("UI_TOUCH_RUN")
	end
end

local function renderAll()
	renderStatic()
	renderObjectives(false)
	renderBars()
	renderPower()
end

local function touchButton(name: string, offsetY: number): TextButton
	local button = Theme.make("TextButton", {
		Name = name,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -20, 0.5, offsetY),
		Size = UDim2.fromOffset(80, 80),
		BackgroundColor3 = Theme.Color.Panel,
		BackgroundTransparency = 0.25,
		AutoButtonColor = true,
		Font = Theme.Font.Medium,
		TextSize = 13,
		TextColor3 = Theme.Color.Text,
		TextWrapped = true,
		Text = "",
	}, root)
	Theme.autoScale(button)
	Theme.corner(button, 40)
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
		Size = UDim2.fromOffset(PANEL_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Color.Panel,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
	}, root)
	Theme.autoScale(objective)
	Theme.padding(objective, 14, 10)
	Theme.border(objective, Theme.Color.PanelLight, 0.3)
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
		LayoutOrder = -2,
	}, objective)
	chapterLabel = Theme.make("TextLabel", {
		Name = "Chapter",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = Theme.Font.Medium,
		TextSize = 11,
		TextColor3 = Theme.Color.Dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = "",
		LayoutOrder = -1,
	}, objective)
	headingLabel = Theme.make("TextLabel", {
		Name = "Heading",
		Size = UDim2.new(1, 0, 0, 12),
		BackgroundTransparency = 1,
		Font = Theme.Font.Bold,
		TextSize = 11,
		TextColor3 = Theme.Color.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
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
	powerLabel = Theme.make("TextLabel", {
		Name = "Power",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = Theme.Font.Medium,
		TextSize = 11,
		TextColor3 = Theme.Color.Warning,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = "",
		LayoutOrder = 2,
	}, objective)

	-- "Objective complete", centred above the middle of the screen.
	completeToast = Theme.make("TextLabel", {
		Name = "Complete",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.22),
		Size = UDim2.new(0.8, 0, 0, 30),
		BackgroundTransparency = 1,
		Font = Theme.Font.Bold,
		TextSize = 20,
		TextColor3 = Theme.Color.Accent,
		TextTransparency = 1,
		Visible = false,
		Text = "",
	}, root)
	Theme.autoScale(completeToast)

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
	staminaFill, staminaLabel = bar(status, "Stamina", 1)
	batteryFill, batteryLabel = bar(status, "Flashlight", 2)

	-- Language switch, bottom right: AUTO -> ENGLISH -> РУССКИЙ.
	languageButton = Theme.make("TextButton", {
		Name = "Language",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -18),
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Color.Panel,
		BackgroundTransparency = 0.35,
		AutoButtonColor = true,
		Font = Theme.Font.Medium,
		TextSize = 11,
		TextColor3 = Theme.Color.Dim,
		Text = "",
	}, root)
	Theme.padding(languageButton, 10, 0)
	Theme.border(languageButton, Theme.Color.PanelLight, 0.3)
	Theme.autoScale(languageButton)
	languageButton.Activated:Connect(LocalizationController.cycle)

	-- Touch controls, right edge above the jump button. Keyboard and gamepad use keys.
	if UserInputService.TouchEnabled then
		local flashlight = touchButton("Light", -70)
		flashlight.Activated:Connect(InputController.toggleFlashlight)
		flashlightButton = flashlight

		-- Sprint is a toggle on touch: holding a button while steering is awkward.
		local sprint = touchButton("Run", 24)
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
		:Connect(onObjectiveChanged)
	for _, attribute in { GameState.OBJECTIVE_PROGRESS_ATTRIBUTE, GameState.OPTIONAL_ATTRIBUTE } do
		ReplicatedStorage:GetAttributeChangedSignal(attribute):Connect(function()
			renderObjectives(false)
		end)
	end
	for _, attribute in ATTRIBUTE do
		player:GetAttributeChangedSignal(attribute):Connect(renderBars)
	end
	-- The server forgets the sprint request when the character respawns; refresh the
	-- touch button after InputController has reset its own state.
	player.CharacterAdded:Connect(function()
		task.defer(renderBars)
	end)
	for _, attribute in
		{
			GameState.POWER_ATTRIBUTE,
			GameState.BREAKERS_ENGAGED_ATTRIBUTE,
			GameState.BREAKERS_TOTAL_ATTRIBUTE,
		}
	do
		ReplicatedStorage:GetAttributeChangedSignal(attribute):Connect(renderPower)
	end
	LocalizationController.changed:Connect(renderAll)

	-- The HUD belongs to the mission, not to the title and ending cards.
	local function onPhase(phase: GameState.Phase)
		root.Visible = phase == GameState.Phase.Playing
	end
	SessionController.phaseChanged:Connect(onPhase)
	onPhase(SessionController.getPhase())

	shownObjective = objectiveIndex()
	renderAll()
end

return HudController
