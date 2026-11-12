--!strict
-- Text the server wants the player to read right now: short notifications at the top of
-- the screen and subtitles at the bottom. The server sends text references; they are
-- rendered here in the player's language.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Theme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Theme"))
local LocalizationController = require(script.Parent:WaitForChild("LocalizationController"))

local NOTIFICATION_SECONDS = 5.5
-- Long lines (Russian runs longer than English) wrap instead of leaving the screen.
local NOTIFICATION_MAX_WIDTH = 620
local MAX_NOTIFICATIONS = 3
local MAX_TEXT_LENGTH = 600

local MessageController = {}

local notificationList: Frame
local subtitle: TextLabel
local subtitleToken = 0
local notificationOrder = 0

local function clean(value: any): string
	local text = if type(value) == "string" then value else ""
	return string.sub(text, 1, MAX_TEXT_LENGTH)
end

-- RichText treats these characters as markup.
local function escape(text: string): string
	return (string.gsub(string.gsub(string.gsub(text, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end

local function showNotification(text: string, kind: string)
	local warning = kind == "warning"
	notificationOrder += 1

	local rows: { Frame } = {}
	for _, child in notificationList:GetChildren() do
		if child:IsA("Frame") then
			table.insert(rows, child)
		end
	end
	table.sort(rows, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	while #rows >= MAX_NOTIFICATIONS do
		(table.remove(rows, 1) :: Frame):Destroy()
	end

	local row: Frame = Theme.make("Frame", {
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = Theme.Color.Panel,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = notificationOrder,
	}, notificationList)
	Theme.padding(row, 16, 9)
	local stroke = Theme.border(row, if warning then Theme.Color.Warning else Theme.Color.Accent, 1)
	local label: TextLabel = Theme.make("TextLabel", {
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Font = Theme.Font.Medium,
		TextSize = 15,
		TextColor3 = if warning then Theme.Color.Warning else Theme.Color.Text,
		TextTransparency = 1,
		TextWrapped = true,
		Text = text,
	}, row)
	Theme.make("UISizeConstraint", { MaxSize = Vector2.new(NOTIFICATION_MAX_WIDTH, 200) }, label)

	Theme.tween(row, 0.25, { BackgroundTransparency = 0.3 })
	Theme.tween(stroke, 0.25, { Transparency = 0.45 })
	Theme.tween(label, 0.25, { TextTransparency = 0 })
	task.delay(NOTIFICATION_SECONDS, function()
		if not row.Parent then
			return
		end
		Theme.tween(row, 0.5, { BackgroundTransparency = 1 })
		Theme.tween(stroke, 0.5, { Transparency = 1 })
		Theme.tween(label, 0.5, { TextTransparency = 1 })
		task.wait(0.55)
		row:Destroy()
	end)
end

local function showSubtitle(speaker: string, text: string, seconds: number)
	subtitleToken += 1
	local token = subtitleToken
	local accent = Theme.Color.Accent:ToHex()
	subtitle.Text = if speaker ~= ""
		then `<font color="#{accent}">{escape(speaker)}</font>   {escape(text)}`
		else escape(text)
	subtitle.Visible = true
	subtitle.TextTransparency = 1
	subtitle.BackgroundTransparency = 1
	Theme.tween(subtitle, 0.2, { TextTransparency = 0, BackgroundTransparency = 0.4 })

	task.delay(math.clamp(seconds, 0.5, 20), function()
		-- A newer subtitle has replaced this one.
		if token ~= subtitleToken then
			return
		end
		Theme.tween(subtitle, 0.3, { TextTransparency = 1, BackgroundTransparency = 1 })
		task.wait(0.35)
		if token == subtitleToken then
			subtitle.Visible = false
		end
	end)
end

local function build()
	-- Above TLS_Effects (40): text stays readable over the blackout and the ending.
	local screen = Theme.screen("TLS_Messages", 50)
	local root = Theme.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, screen)

	notificationList = Theme.make("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
	}, root)
	Theme.make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
	}, notificationList)

	subtitle = Theme.make("TextLabel", {
		Name = "Subtitle",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -120),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = Theme.Color.Black,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Theme.Font.Medium,
		TextSize = 20,
		TextColor3 = Theme.Color.Text,
		TextWrapped = true,
		RichText = true,
		Visible = false,
		Text = "",
	}, root)
	Theme.autoScale(notificationList)
	Theme.autoScale(subtitle)
	Theme.padding(subtitle, 14, 8)
	Theme.make("UISizeConstraint", { MaxSize = Vector2.new(760, 400) }, subtitle)
end

function MessageController.Start(_self: any)
	build()

	Net.waitForServerEvent("Notify").OnClientEvent:Connect(function(text: any, kind: any)
		showNotification(LocalizationController.render(clean(text)), clean(kind))
	end)
	Net.waitForServerEvent("Subtitle").OnClientEvent
		:Connect(function(speaker: any, text: any, seconds: any)
			local speakerRef = clean(speaker)
			showSubtitle(
				if speakerRef == "" then "" else LocalizationController.render(speakerRef),
				LocalizationController.render(clean(text)),
				if type(seconds) == "number" then seconds else 3
			)
		end)
end

return MessageController
