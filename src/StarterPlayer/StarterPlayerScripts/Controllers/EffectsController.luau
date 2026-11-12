--!strict
-- Full-screen presentation: radio interference, the blackout when a player is taken, the
-- loading and title cards before play, the chapter title when a chapter begins, and the
-- ending card. All text is rendered in the player's language.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local GameState = require(Shared:WaitForChild("GameState"))
local ObjectiveConfig = require(Config:WaitForChild("ObjectiveConfig"))
local Net = require(Shared:WaitForChild("Net"))
local Theme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Theme"))
local LocalizationController = require(script.Parent:WaitForChild("LocalizationController"))
local SessionController = require(script.Parent:WaitForChild("SessionController"))

local t = LocalizationController.t
local CHAPTER_SECONDS = 4

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
local chapterCard: TextLabel
-- Which card is up ("Loading" | "Intro" | "Ending"), so it can be re-rendered when the
-- language changes.
local shownCard: string? = nil
local shownChapter = 0
local chapterToken = 0

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

local function cardText(kind: string): (string, string)
	if kind == "Loading" then
		return t("UI_LOADING_TITLE"), t("UI_LOADING_BODY")
	elseif kind == "Intro" then
		return t("UI_INTRO_TITLE"), t("UI_INTRO_BODY")
	end
	local body = t("UI_ENDING_BODY")
	local seconds = ReplicatedStorage:GetAttribute(GameState.DURATION_ATTRIBUTE)
	if type(seconds) == "number" then
		body ..= "\n\n" .. t("UI_ENDING_TIME", {
			minutes = seconds // 60,
			seconds = string.format("%02d", seconds % 60),
		})
	end
	body ..= "\n" .. t("UI_ENDING_VERSION", { version = GameConfig.Version })
	return t("UI_ENDING_TITLE"), body
end

local function renderText()
	cardButton.Text = t("UI_KEEP_EXPLORING")
	if shownCard then
		cardTitle.Text, cardBody.Text = cardText(shownCard)
	end
end

local function currentChapter(): number
	local value = ReplicatedStorage:GetAttribute(GameState.OBJECTIVE_ATTRIBUTE)
	local list = ObjectiveConfig.List
	local index = math.clamp(if type(value) == "number" then value else 1, 1, #list)
	return list[index].chapter
end

-- The chapter's name, shown for a few seconds when it begins.
local function showChapter(chapter: number)
	chapterToken += 1
	local token = chapterToken
	local heading = t("UI_CHAPTER", { number = chapter })
	chapterCard.Text = heading .. "\n" .. t(ObjectiveConfig.Chapters[chapter].title)
	chapterCard.Visible = true
	chapterCard.TextTransparency = 1
	Theme.tween(chapterCard, 0.8, { TextTransparency = 0 })
	task.delay(CHAPTER_SECONDS, function()
		if token ~= chapterToken then
			return
		end
		Theme.tween(chapterCard, 1, { TextTransparency = 1 })
		task.wait(1.05)
		if token == chapterToken then
			chapterCard.Visible = false
		end
	end)
end

local function onChapterMaybeChanged()
	local chapter = currentChapter()
	if chapter ~= shownChapter then
		shownChapter = chapter
		if SessionController.getPhase() == GameState.Phase.Playing then
			showChapter(chapter)
		end
	end
end

local function onPhase(phase: GameState.Phase)
	if phase == GameState.Phase.Loading or phase == GameState.Phase.Intro then
		black.Visible = true
		black.BackgroundTransparency = 0
		shownCard = phase
		local title, body = cardText(phase)
		showCard(title, body, false)
	elseif phase == GameState.Phase.Playing then
		if card.Visible then
			hideCard()
		end
		shownCard = nil
		shownChapter = currentChapter()
		task.delay(1.5, showChapter, shownChapter)
	elseif phase == GameState.Phase.Finale then
		black.Visible = true
		Theme.tween(black, 2.5, { BackgroundTransparency = 0 })
	elseif phase == GameState.Phase.Ending then
		black.Visible = true
		black.BackgroundTransparency = 0
		shownCard = "Ending"
		local title, body = cardText("Ending")
		showCard(title, body, true)
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
		Size = UDim2.new(0.86, 0, 0, 320),
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
		Text = "",
		Modal = true,
		Visible = false,
		ZIndex = 6,
	}, card)
	Theme.border(cardButton, Theme.Color.Accent, 0.4)
	chapterCard = Theme.make("TextLabel", {
		Name = "Chapter",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.new(0.9, 0, 0, 80),
		BackgroundTransparency = 1,
		Font = Theme.Font.Bold,
		TextSize = 26,
		LineHeight = 1.3,
		TextColor3 = Theme.Color.Text,
		TextTransparency = 1,
		TextWrapped = true,
		Visible = false,
		Text = "",
		ZIndex = 4,
	}, screen)
	Theme.make("UISizeConstraint", { MaxSize = Vector2.new(900, 600) }, cardBody)
	for _, element in { cardTitle :: Instance, cardBody, cardButton, chapterCard } do
		Theme.autoScale(element)
	end
	cardButton.Activated:Connect(function()
		shownCard = nil
		hideCard()
	end)
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
	ReplicatedStorage:GetAttributeChangedSignal(GameState.OBJECTIVE_ATTRIBUTE)
		:Connect(onChapterMaybeChanged)
	LocalizationController.changed:Connect(renderText)
	renderText()

	RunService.RenderStepped:Connect(renderInterference)
end

return EffectsController
