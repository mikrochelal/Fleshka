--!strict
-- Code entry panel. The server opens it when a player uses a keypad in the world
-- (`Keypad` event); the digits typed here are sent back with `SubmitCode` and checked on
-- the server, which never tells the client what the code is. A wrong code just closes the
-- panel - the server reports the result as a notification.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Theme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Theme"))
local AudioController = require(script.Parent:WaitForChild("AudioController"))
local LocalizationController = require(script.Parent:WaitForChild("LocalizationController"))

local CLOSE_ACTION = "TLS_CloseKeypad"
local KEY_SIZE = 64
local KEY_GAP = 8
local KEYS = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "CLEAR", "0", "ENTER" }

local t = LocalizationController.t

local KeypadController = {}

local screen: ScreenGui
local titleLabel: TextLabel
local hintLabel: TextLabel
local display: TextLabel
local closeButton: TextButton
local keyButtons: { [string]: TextButton } = {}
local submitRemote: RemoteEvent? = nil

local lockId = ""
local titleRef = "UI_KEYPAD_TITLE"
local digits = 4
local entered = ""

local function render()
	titleLabel.Text = LocalizationController.render(titleRef)
	hintLabel.Text = t("UI_KEYPAD_HINT", { digits = digits })
	closeButton.Text = t("UI_CLOSE")
	keyButtons.CLEAR.Text = t("UI_KEYPAD_CLEAR")
	keyButtons.ENTER.Text = t("UI_KEYPAD_ENTER")
	-- Typed digits, then a dash for each one still missing.
	display.Text = entered .. string.rep("-", math.max(0, digits - #entered))
end

local function close()
	if screen.Enabled then
		ContextActionService:UnbindAction(CLOSE_ACTION)
		screen.Enabled = false
	end
end

local function press(key: string)
	AudioController.play("KeypadPress")
	if key == "CLEAR" then
		entered = ""
	elseif key == "ENTER" then
		if #entered == digits and submitRemote then
			submitRemote:FireServer(lockId, entered)
			close()
			return
		end
	elseif #entered < digits then
		entered ..= key
	end
	render()
end

local function open(id: string, title: string, count: number)
	lockId = id
	titleRef = title
	digits = math.clamp(math.floor(count), 1, 8)
	entered = ""
	render()
	screen.Enabled = true
	ContextActionService:BindAction(CLOSE_ACTION, function(_name, state)
		if state == Enum.UserInputState.Begin then
			close()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.X, Enum.KeyCode.ButtonB)
end

local function build()
	screen = Theme.screen("TLS_Keypad", 32)
	screen.Enabled = false

	Theme.make("Frame", {
		Name = "Dim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.Black,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		Active = true,
	}, screen)

	local width = KEY_SIZE * 3 + KEY_GAP * 2
	local panel = Theme.make("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width + 48, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Color.Panel,
		BorderSizePixel = 0,
	}, screen)
	Theme.autoScale(panel)
	Theme.padding(panel, 24, 20)
	Theme.border(panel, Theme.Color.Accent, 0.4)
	Theme.make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 10),
	}, panel)

	titleLabel = Theme.make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Font = Theme.Font.Bold,
		TextSize = 16,
		TextColor3 = Theme.Color.Accent,
		Text = "",
		LayoutOrder = 1,
	}, panel)
	hintLabel = Theme.make("TextLabel", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = Theme.Font.Regular,
		TextSize = 12,
		TextColor3 = Theme.Color.Dim,
		TextWrapped = true,
		Text = "",
		LayoutOrder = 2,
	}, panel)
	display = Theme.make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = Theme.Color.Black,
		BorderSizePixel = 0,
		Font = Theme.Font.Mono,
		TextSize = 30,
		TextColor3 = Theme.Color.Text,
		Text = "",
		LayoutOrder = 3,
	}, panel)

	local grid = Theme.make("Frame", {
		Size = UDim2.fromOffset(width, KEY_SIZE * 4 + KEY_GAP * 3),
		BackgroundTransparency = 1,
		LayoutOrder = 4,
	}, panel)
	Theme.make("UIGridLayout", {
		CellSize = UDim2.fromOffset(KEY_SIZE, KEY_SIZE),
		CellPadding = UDim2.fromOffset(KEY_GAP, KEY_GAP),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	for order, key in KEYS do
		local digit = #key == 1
		local button: TextButton = Theme.make("TextButton", {
			Name = key,
			BackgroundColor3 = Theme.Color.PanelLight,
			AutoButtonColor = true,
			Font = if digit then Theme.Font.Mono else Theme.Font.Medium,
			TextSize = if digit then 26 else 11,
			TextColor3 = if key == "ENTER" then Theme.Color.Accent else Theme.Color.Text,
			TextWrapped = true,
			Text = if digit then key else "",
			LayoutOrder = order,
		}, grid)
		button.Activated:Connect(function()
			press(key)
		end)
		keyButtons[key] = button
	end

	closeButton = Theme.make("TextButton", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = Theme.Color.Black,
		AutoButtonColor = true,
		Font = Theme.Font.Medium,
		TextSize = 13,
		TextColor3 = Theme.Color.Dim,
		Text = "",
		-- Frees the mouse when the camera is in first person.
		Modal = true,
		LayoutOrder = 5,
	}, panel)
	closeButton.Activated:Connect(close)
end

function KeypadController.Start(_self: any)
	build()
	submitRemote = Net.waitForClientEvent("SubmitCode")

	Net.waitForServerEvent("Keypad").OnClientEvent:Connect(function(id: any, title: any, count: any)
		if type(id) == "string" and type(title) == "string" and type(count) == "number" then
			open(id, title, count)
		end
	end)
	LocalizationController.changed:Connect(render)
	render()
end

return KeypadController
