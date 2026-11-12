--!strict
-- Full-screen presentation: radio interference, the blackout when a player is taken, the
-- title card before play and the completion card at the end of the current build.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local GameState = require(Shared:WaitForChild("GameState"))
local Net = require(Shared:WaitForChild("Net"))
local Theme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Theme"))
local SessionController = require(script.Parent:WaitForChild("SessionController"))

local BAR_COUNT = 7
local DREAD_ATTRIBUTE = GameState.PlayerAttribute.Dread

local EffectsController = {}

local player = Players.LocalPlayer
local random = Random.new()

local bars: { Frame } = {}
local vignette: Frame
local black: Frame
local card: Frame
local cardTitle: TextLabel
local cardBody: TextLabel
local cardButton: TextButton

-- Interference requested by the server: full strength until this time.
local interferenceUntil = 0

local function renderInterference()
	local dread = player:GetAttribute(DREAD_ATTRIBUTE)
	local level = if type(dread) == "number" then dread else 0
	if os.clock() < interferenceUntil then
		level = math.max(level, 0.85)
	end

	vignette.BackgroundTransparency = 1 - 0.45 * level
	for _, bar in bars do
		-- Below a threshold the screen stays clean; above it bars jump around each frame.
		local visible = level > 0.25 and random:NextNumber() < level * 0.7
		bar.Visible = visible
		if visible then
			bar.Position = UDim2.fromScale(0, random:NextNumber())
			bar.Size = UDim2.new(1, 0, 0, random:NextInteger(1, 2 + math.floor(level * 10)))
			bar.BackgroundTransparency = 1 - random:NextNumber(0.03, 0.05 + 0.2 * level)
		end
	end
end

local function blackout(seconds: number)
	black.Visible = true
	black.BackgroundTransparency = 1
	Theme.tween(black, 0.5, { BackgroundTransparency = 0 })
	task.delay(math.max(1, seconds - 0.8), function()
		Theme.tween(black, 0.8, { BackgroundTransparency = 1 })
		task.wait(0.85)
		-- The ending keeps the screen black on its own; do not fight it.
		if black.BackgroundTransparency >= 0.99 then
			black.Visible = false
		end
	end)
end

local function showCard(title: string, body: string, closable: boolean)
	cardTitle.Text = title
	cardBody.Text = body
	cardButton.Visible = closable
	card.Visible = true
	cardTitle.TextTransparency = 1
	cardBody.TextTransparency = 1
	Theme.tween(cardTitle, 1.2, { TextTransparency = 0 })
	Theme.tween(cardBody, 1.8, { TextTransparency = 0 })
end

local function hideCard()
	Theme.tween(cardTitle, 0.8, { TextTransparency = 1 })
	Theme.tween(cardBody, 0.8, { TextTransparency = 1 })
	Theme.tween(black, 1.2, { BackgroundTransparency = 1 })
	task.delay(1.25, function()
		card.Visible = false
		black.Visible = false
	end)
end

local function formatDuration(): string
	local seconds = ReplicatedStorage:GetAttribute(GameState.DURATION_ATTRIBUTE)
	if type(seconds) ~= "number" then
		return ""
	end
	return string.format("\n\nTime inside: %d:%02d", seconds // 60, seconds % 60)
end

local function onPhase(phase: GameState.Phase)
	if phase == GameState.Phase.Intro then
		black.Visible = true
		black.BackgroundTransparency = 0
		showCard(
			"STATION-09",
			"17 October 1998. All contact with the station is lost.\n"
				.. 'The last transmission: "IT KNOWS WE ARE LISTENING."\n\n'
				.. "Years later, a new signal. You have been sent down to find out why.",
			false
		)
	elseif phase == GameState.Phase.Playing then
		if card.Visible then
			hideCard()
		end
	elseif phase == GameState.Phase.Finale then
		black.Visible = true
		Theme.tween(black, 2.5, { BackgroundTransparency = 0 })
	elseif phase == GameState.Phase.Ending then
		black.Visible = true
		black.BackgroundTransparency = 0
		showCard(
			"SIGNAL LOST",
			`You reached the surface. Something came with you.\n\nEnd of the current build ({GameConfig.Version}).`
				.. formatDuration(),
			true
		)
	end
end

local function build()
	local screen = Theme.screen("TLS_Effects", 40)

	vignette = Theme.make("Frame", {
		Name = "Darken",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.Black,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, screen)
	for index = 1, BAR_COUNT do
		bars[index] = Theme.make("Frame", {
			Name = "Bar",
			Size = UDim2.new(1, 0, 0, 2),
			BackgroundColor3 = Theme.Color.Text,
			BorderSizePixel = 0,
			Visible = false,
		}, screen)
	end

	black = Theme.make("Frame", {
		Name = "Black",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.Black,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 5,
	}, screen)

	card = Theme.make("Frame", {
		Name = "Card",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 6,
	}, screen)
	cardTitle = Theme.make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(0.9, 0, 0, 60),
		BackgroundTransparency = 1,
		Font = Theme.Font.Bold,
		TextSize = 44,
		TextColor3 = Theme.Color.Text,
		Text = "",
		ZIndex = 6,
	}, card)
	cardBody = Theme.make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.new(0.86, 0, 0, 200),
		BackgroundTransparency = 1,
		Font = Theme.Font.Regular,
		TextSize = 18,
		LineHeight = 1.25,
		TextColor3 = Theme.Color.Dim,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
		ZIndex = 6,
	}, card)
	cardButton = Theme.make("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -70),
		Size = UDim2.fromOffset(240, 48),
		BackgroundColor3 = Theme.Color.Panel,
		AutoButtonColor = true,
		Font = Theme.Font.Medium,
		TextSize = 15,
		TextColor3 = Theme.Color.Text,
		Text = "KEEP EXPLORING",
		Modal = true,
		Visible = false,
		ZIndex = 6,
	}, card)
	Theme.border(cardButton, Theme.Color.Accent, 0.4)
	for _, element in { cardTitle :: Instance, cardBody, cardButton } do
		Theme.autoScale(element)
	end
	cardButton.Activated:Connect(hideCard)
end

function EffectsController.Start(_self: any)
	build()

	Net.waitForServerEvent("Effect").OnClientEvent:Connect(function(name: any, seconds: any)
		local duration = if type(seconds) == "number" then math.clamp(seconds, 0, 15) else 2
		if name == "Interference" then
			interferenceUntil = math.max(interferenceUntil, os.clock() + duration)
		elseif name == "Blackout" then
			blackout(duration)
		end
	end)

	SessionController.phaseChanged:Connect(onPhase)
	onPhase(SessionController.getPhase())

	RunService.RenderStepped:Connect(renderInterference)
end

return EffectsController
