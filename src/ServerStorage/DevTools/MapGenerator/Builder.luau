--!strict
-- Creates Roblox instances from a plan. Returns an unparented tree: nothing appears in the
-- place unless the whole build succeeded and the caller parents it.
--
-- Only built-in materials and plain parts are used - no asset IDs.

local Plan = require(script.Parent.Plan)
local Shell = require(script.Parent.Shell)

type Look = { material: Enum.Material, color: Color3 }

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local FLOOR: { [string]: Look } = {
	default = { material = Enum.Material.Concrete, color = rgb(58, 60, 63) },
	metal = { material = Enum.Material.DiamondPlate, color = rgb(66, 69, 72) },
	lab = { material = Enum.Material.SmoothPlastic, color = rgb(96, 102, 106) },
}
local CEILING: Look = { material = Enum.Material.Metal, color = rgb(42, 43, 46) }
-- One wall tone per area helps orientation.
local WALLS: { [string]: Look } = {
	A = { material = Enum.Material.Concrete, color = rgb(88, 90, 92) },
	B = { material = Enum.Material.Concrete, color = rgb(72, 76, 80) },
	C = { material = Enum.Material.SmoothPlastic, color = rgb(130, 138, 142) },
	D = { material = Enum.Material.Metal, color = rgb(62, 70, 76) },
}
local ROCK: Look = { material = Enum.Material.Slate, color = rgb(38, 38, 41) }
local PROPS: { [string]: Look } = {
	wall = { material = Enum.Material.Metal, color = rgb(70, 72, 76) },
	furniture = { material = Enum.Material.SmoothPlastic, color = rgb(104, 104, 108) },
	-- Muted cyan marks everything a puzzle will later attach to.
	puzzle = { material = Enum.Material.SmoothPlastic, color = rgb(70, 130, 140) },
}
local DOOR: Look = { material = Enum.Material.Metal, color = rgb(96, 102, 108) }
local DOOR_LOCKED: Look = { material = Enum.Material.Metal, color = rgb(140, 44, 44) }
-- Frame colour tells the kind of passage apart at a glance.
local FRAME: Look = { material = Enum.Material.Metal, color = rgb(44, 46, 50) }
local FRAME_POWERED: Look = { material = Enum.Material.Metal, color = rgb(52, 104, 114) }
local FRAME_LOCKED: Look = { material = Enum.Material.Metal, color = rgb(120, 36, 36) }

local LIGHT_COLOR = rgb(214, 228, 240)
local EMERGENCY_COLOR = rgb(210, 44, 40)

local Builder = {}

-- Set on every ceiling and on the roof; MapGenerator.setCeilingsVisible looks for it.
Builder.OVERHEAD_ATTRIBUTE = "TLS_Overhead"

local function newFolder(name: string, parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function newPart(layout: Plan.Layout, box: Plan.Box, look: Look, parent: Instance): Part
	local origin = layout.origin
	local part = Instance.new("Part")
	part.Name = box.name
	part.Anchored = true
	part.Size = Vector3.new(box.sx, box.sy, box.sz)
	part.Position = Vector3.new(origin.x + box.x, origin.y + box.y, origin.z + box.z)
	part.Material = look.material
	part.Color = look.color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Markers, zones and light fixtures must never block movement, raycasts or touches.
local function makeGhost(part: BasePart)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

local function buildRoom(
	layout: Plan.Layout,
	plan: Plan.RoomPlan,
	area: Plan.Area,
	parent: Instance
)
	local room = plan.room
	local folder = newFolder(room.name, parent)

	newPart(layout, plan.floor, FLOOR[room.style or "default"] or FLOOR.default, folder)
	local ceiling = newPart(layout, plan.ceiling, CEILING, folder)
	ceiling:SetAttribute(Builder.OVERHEAD_ATTRIBUTE, true)

	local walls = newFolder("Walls", folder)
	for _, box in plan.walls do
		newPart(layout, box, WALLS[area.id] or WALLS.A, walls)
	end

	local lights = newFolder("Lights", folder)
	local emergency = room.emergency == true
	local color = if emergency then EMERGENCY_COLOR else LIGHT_COLOR
	for _, box in plan.lights do
		local fixture =
			newPart(layout, box, { material = Enum.Material.Neon, color = color }, lights)
		makeGhost(fixture)
		fixture:SetAttribute("Circuit", if emergency then "Emergency" else area.id)
		fixture:AddTag("TLS_Light")

		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = if emergency then 18 else 26
		light.Brightness = if emergency then 0.8 else 1.2
		-- Shadows from dozens of lights are too expensive for mobile.
		light.Shadows = false
		light.Parent = fixture
	end

	local zone = newPart(layout, plan.zone, CEILING, folder)
	zone.Transparency = 1
	makeGhost(zone)
	zone:SetAttribute("Area", area.name)
	zone:SetAttribute("ZoneId", room.name)
	zone:AddTag("TLS_Zone")
end

local function buildPassage(layout: Plan.Layout, passage: Plan.PassagePlan, parent: Instance)
	local model = Instance.new("Model")
	model.Name = passage.name

	local frameLook = FRAME
	if passage.locked then
		frameLook = FRAME_LOCKED
	elseif passage.requiresPower then
		frameLook = FRAME_POWERED
	end
	local frame = newFolder("Frame", model)
	for _, box in passage.frame do
		newPart(layout, box, frameLook, frame)
	end

	local panelBox = passage.panel
	if panelBox then
		local panel = newPart(layout, panelBox, if passage.locked then DOOR_LOCKED else DOOR, model)
		-- Draft only: doors are see-through and walkable until the door system exists.
		panel.Transparency = 0.5
		panel.CanCollide = false
		panel.CanQuery = false
		model.PrimaryPart = panel

		model:SetAttribute("DoorId", passage.name)
		model:SetAttribute("RequiresPower", passage.requiresPower)
		model:SetAttribute("Locked", passage.locked)
		model:AddTag("TLS_Door")
	end
	model.Parent = parent
end

local function buildShell(layout: Plan.Layout, shell: Shell.Result, parent: Instance)
	local folder = newFolder("Shell", parent)
	local rock = newFolder("Rock", folder)
	for _, box in shell.rock do
		newPart(layout, box, ROCK, rock)
	end
	local roof = newPart(layout, shell.roof, ROCK, folder)
	roof:SetAttribute(Builder.OVERHEAD_ATTRIBUTE, true)
end

local function buildProp(layout: Plan.Layout, prop: Plan.Prop, parent: Instance)
	local part = newPart(layout, {
		name = prop.name,
		x = prop.x,
		y = (prop.y or 0) + prop.sy / 2,
		z = prop.z,
		sx = prop.sx,
		sy = prop.sy,
		sz = prop.sz,
	}, PROPS[prop.look] or PROPS.furniture, parent)
	part:SetAttribute("Placeholder", true)
	if prop.panelId then
		part:SetAttribute("PanelId", prop.panelId)
	end
	if prop.tag then
		part:AddTag(prop.tag)
	end
end

local function buildMarker(
	layout: Plan.Layout,
	marker: Plan.Marker,
	area: Plan.Area,
	parent: Instance
)
	local part = newPart(layout, {
		name = marker.name,
		x = marker.x,
		y = 3,
		z = marker.z,
		sx = 2,
		sy = 2,
		sz = 2,
	}, CEILING, parent)
	part.Transparency = 1
	makeGhost(part)
	part:SetAttribute("Area", area.name)
	if marker.checkpoint then
		part:SetAttribute("Checkpoint", marker.checkpoint)
	end
	part:AddTag(marker.tag)
end

export type Summary = {
	rooms: number,
	doors: number,
	archways: number,
	lights: number,
	parts: number,
}

function Builder.build(
	layout: Plan.Layout,
	plan: Plan.Result,
	shell: Shell.Result
): (Folder, Summary)
	local root = Instance.new("Folder")
	root.Name = layout.rootName

	local areas: { [string]: Plan.Area } = {}
	local areaFolders: { [string]: Folder } = {}
	for _, area in layout.areas do
		areas[area.id] = area
		areaFolders[area.id] = newFolder(area.folder, root)
	end

	local roomFolders: { [string]: Instance } = {}
	local roomAreas: { [string]: Plan.Area } = {}
	local lightCount = 0
	for _, roomPlan in plan.rooms do
		local area = areas[roomPlan.room.area]
		buildRoom(layout, roomPlan, area, areaFolders[area.id])
		roomFolders[roomPlan.room.name] =
			areaFolders[area.id]:FindFirstChild(roomPlan.room.name) :: Instance
		roomAreas[roomPlan.room.name] = area
		lightCount += #roomPlan.lights
	end

	local doors = newFolder("Doors", root)
	local archways = newFolder("Archways", root)
	local doorCount = 0
	for _, passage in plan.passages do
		if passage.isDoor then
			doorCount += 1
		end
		buildPassage(layout, passage, if passage.isDoor then doors else archways)
	end

	buildShell(layout, shell, root)

	for _, prop in layout.props do
		local roomFolder = roomFolders[prop.room]
		local props = roomFolder:FindFirstChild("Props") or newFolder("Props", roomFolder)
		buildProp(layout, prop, props)
	end

	local markers = newFolder("Markers", root)
	for _, marker in layout.markers do
		buildMarker(layout, marker, roomAreas[marker.room], markers)
	end

	local partCount = 0
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			partCount += 1
		end
	end

	return root,
		{
			rooms = #plan.rooms,
			doors = doorCount,
			archways = #plan.passages - doorCount,
			lights = lightCount,
			parts = partCount,
		}
end

return Builder
