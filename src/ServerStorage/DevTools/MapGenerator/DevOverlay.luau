--!strict
-- Developer overlay for the generated map: floating labels that make the station readable
-- in the Studio viewport. Everything it creates lives in one folder,
-- Workspace.TLS_DevOverlay, which the game removes whenever it runs.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Plan = require(script.Parent.Plan)

local OVERLAY_NAME = "TLS_DevOverlay"

local AREA_COLOR: { [string]: Color3 } = {
	Entrance = Color3.fromRGB(200, 204, 210),
	Corridors = Color3.fromRGB(120, 190, 210),
	Laboratory = Color3.fromRGB(150, 220, 190),
	CommCenter = Color3.fromRGB(120, 150, 230),
	Medical = Color3.fromRGB(230, 230, 230),
	Archives = Color3.fromRGB(220, 200, 150),
	Power = Color3.fromRGB(240, 170, 80),
	Containment = Color3.fromRGB(230, 90, 80),
}
local WHITE = Color3.fromRGB(235, 238, 240)

local DevOverlay = {}

-- "B_MainCorridor" -> "MAIN CORRIDOR"
function DevOverlay.displayName(roomName: string): string
	local short = string.gsub(roomName, "^%u_", "")
	local spaced = string.gsub(short, "(%l)(%u)", "%1 %2")
	return string.upper((string.gsub(spaced, "(%a)(%d)", "%1 %2")))
end

local function label(
	parent: Instance,
	adornee: Instance,
	text: string,
	color: Color3,
	widthStuds: number,
	heightStuds: number,
	lift: number
)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Adornee = adornee
	-- Sized in studs, so labels shrink with distance instead of covering the view.
	gui.Size = UDim2.fromScale(widthStuds, heightStuds)
	gui.StudsOffsetWorldSpace = Vector3.new(0, lift, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundColor3 = Color3.fromRGB(8, 10, 12)
	textLabel.BackgroundTransparency = 0.35
	textLabel.BorderSizePixel = 0
	textLabel.Font = Enum.Font.GothamMedium
	textLabel.TextScaled = true
	textLabel.TextColor3 = color
	textLabel.Text = text
	textLabel.Parent = gui
	gui.Parent = parent
end

local function taggedIn(root: Instance, tag: string): { Instance }
	local found: { Instance } = {}
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsDescendantOf(root) then
			table.insert(found, instance)
		end
	end
	return found
end

-- Removes the overlay. Returns whether there was one.
function DevOverlay.hide(): boolean
	local existing = Workspace:FindFirstChild(OVERLAY_NAME)
	if existing and existing:GetAttribute(OVERLAY_NAME) == true then
		existing:Destroy()
		return true
	end
	return false
end

-- Builds the overlay for a generated map. Returns the number of labels, or a problem.
function DevOverlay.show(root: Instance, layout: Plan.Layout): (number, string?)
	local existing = Workspace:FindFirstChild(OVERLAY_NAME)
	if existing and existing:GetAttribute(OVERLAY_NAME) ~= true then
		return 0, `Workspace.{OVERLAY_NAME} exists but was not made by this tool - nothing changed.`
	end
	DevOverlay.hide()

	local folder = Instance.new("Folder")
	folder.Name = OVERLAY_NAME
	folder:SetAttribute(OVERLAY_NAME, true)
	local count = 0

	for _, zone in taggedIn(root, "TLS_Zone") do
		local id = zone:GetAttribute("ZoneId")
		local area = zone:GetAttribute("Area")
		if zone:IsA("BasePart") and type(id) == "string" then
			local color = AREA_COLOR[if type(area) == "string" then area else ""] or WHITE
			local purpose = layout.purposes[id] or ""
			local width = math.clamp(math.min(zone.Size.X, zone.Size.Z) * 0.9, 8, 26)
			label(
				folder,
				zone,
				`{DevOverlay.displayName(id)}\n{id}  -  {math.floor(zone.Size.X)} x {math.floor(
					zone.Size.Z
				)}\n{purpose}`,
				color,
				width,
				width * 0.34,
				zone.Size.Y / 2 + 4
			)
			count += 1
		end
	end

	local markers: { { tag: string, text: string, color: Color3 } } = {
		{ tag = "TLS_Spawn", text = "SPAWN", color = Color3.fromRGB(110, 220, 120) },
		{ tag = "TLS_CopyVantage", text = "COPY VANTAGE", color = Color3.fromRGB(230, 90, 80) },
		{ tag = "TLS_BreakerPanel", text = "BREAKER", color = Color3.fromRGB(240, 170, 80) },
	}
	for _, marker in markers do
		for _, instance in taggedIn(root, marker.tag) do
			local id = instance:GetAttribute("PanelId")
			local text = if id ~= nil then `{marker.text} {tostring(id)}` else marker.text
			label(folder, instance, text, marker.color, 6, 1.4, 5)
			count += 1
		end
	end

	for _, door in taggedIn(root, "TLS_Door") do
		local text: string? = nil
		if door:GetAttribute("Locked") == true then
			text = "LOCKED"
		elseif door:GetAttribute("RequiresPower") == true then
			text = "NEEDS POWER"
		end
		local adornee = if door:IsA("Model") then door.PrimaryPart else nil
		if text and adornee then
			label(folder, adornee, text, Color3.fromRGB(230, 90, 80), 6, 1.4, 6)
			count += 1
		end
	end

	folder.Parent = Workspace
	return count, nil
end

-- One line per room: zone, name, size, purpose.
function DevOverlay.roomLines(layout: Plan.Layout): { string }
	local areaNames: { [string]: string } = {}
	for _, area in layout.areas do
		areaNames[area.id] = area.name
	end
	local lines: { string } = { `STATION-09 layout v{layout.version}: {#layout.rooms} rooms` }
	for _, room in layout.rooms do
		table.insert(
			lines,
			string.format(
				"  %-12s %-24s %3d x %-3d  %s",
				areaNames[room.area] or room.area,
				room.name,
				room.x1 - room.x0,
				room.z1 - room.z0,
				layout.purposes[room.name] or ""
			)
		)
	end
	return lines
end

return DevOverlay
