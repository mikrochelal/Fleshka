--!strict
-- Document viewer: a sheet of paper over a dimmed screen, with title, date, text and a
-- close control. Opened by the server when the player reads a document in the world.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Theme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Theme"))

local CLOSE_ACTION = "TLS_CloseDocument"
local MAX_BODY_LENGTH = 6000

local DocumentController = {}

local screen: ScreenGui
local dim: Frame
local sheet: Frame
local titleLabel: TextLabel
local dateLabel: TextLabel
local bodyLabel: TextLabel
local scroller: ScrollingFrame

local function close()
	if not screen.Enabled then
		return
	end
	ContextActionService:UnbindAction(CLOSE_ACTION)
	Theme.tween(dim, 0.15, { BackgroundTransparency = 1 })
	Theme.tween(sheet, 0.15, { Position = UDim2.fromScale(0.5, 0.54) })
	task.delay(0.16, function()
		screen.Enabled = false
	end)
end

local function open(title: string, date: string, body: string)
	titleLabel.Text = title
	dateLabel.Text = date
	bodyLabel.Text = body
	scroller.CanvasPosition = Vector2.zero

	screen.Enabled = true
	dim.BackgroundTransparency = 1
	sheet.Position = UDim2.fromScale(0.5, 0.54)
	Theme.tween(dim, 0.2, { BackgroundTransparency = 0.45 })
	Theme.tween(sheet, 0.2, { Position = UDim2.fromScale(0.5, 0.5) })

	-- X (keyboard) or B (gamepad) closes; on touch the button on the sheet does.
	ContextActionService:BindAction(CLOSE_ACTION, function(_name, state)
		if state == Enum.UserInputState.Begin then
			close()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.X, Enum.KeyCode.ButtonB)
end

local function build()
	screen = Theme.screen("TLS_Document", 30)
	screen.Enabled = false

	dim = Theme.make("Frame", {
		Name = "Dim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.Black,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		-- Stops clicks from reaching the game behind the document.
		Active = true,
	}, screen)

	sheet = Theme.make("Frame", {
		Name = "Sheet",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.82),
		BackgroundColor3 = Theme.Color.Paper,
		BorderSizePixel = 0,
	}, screen)
	Theme.make("UISizeConstraint", { MaxSize = Vector2.new(620, 760) }, sheet)
	Theme.padding(sheet, 26, 22)

	titleLabel = Theme.make("TextLabel", {
		Name = "Title",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = Theme.Font.Bold,
		TextSize = 20,
		TextColor3 = Theme.Color.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = "",
	}, sheet)
	dateLabel = Theme.make("TextLabel", {
		Name = "Date",
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Font = Theme.Font.Mono,
		TextSize = 14,
		TextColor3 = Theme.Color.Ink,
		TextTransparency = 0.35,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	}, sheet)
	Theme.make("Frame", {
		Name = "Rule",
		Position = UDim2.fromOffset(0, 82),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.Color.Ink,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
	}, sheet)

	scroller = Theme.make("ScrollingFrame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, 94),
		Size = UDim2.new(1, 0, 1, -160),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Color.Ink,
		CanvasSize = UDim2.fromScale(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, sheet)
	bodyLabel = Theme.make("TextLabel", {
		Size = UDim2.new(1, -10, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = Theme.Font.Mono,
		TextSize = 16,
		LineHeight = 1.15,
		TextColor3 = Theme.Color.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Text = "",
	}, scroller)

	local closeButton: TextButton = Theme.make("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(150, 46),
		BackgroundColor3 = Theme.Color.Ink,
		AutoButtonColor = true,
		Font = Theme.Font.Medium,
		TextSize = 15,
		TextColor3 = Theme.Color.Paper,
		Text = "CLOSE  [X]",
		-- Frees the mouse when the camera is in first person.
		Modal = true,
	}, sheet)
	closeButton.Activated:Connect(close)
end

function DocumentController.Start(_self: any)
	build()

	Net.waitForServerEvent("ShowDocument").OnClientEvent
		:Connect(function(title: any, date: any, body: any)
			if type(title) == "string" and type(date) == "string" and type(body) == "string" then
				open(title, date, string.sub(body, 1, MAX_BODY_LENGTH))
			end
		end)
end

return DocumentController
