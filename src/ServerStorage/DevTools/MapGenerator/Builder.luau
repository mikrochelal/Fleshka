--!strict
-- Creates Roblox instances from a plan. Returns an unparented tree: nothing appears in the
-- place unless the whole build succeeded and the caller parents it.
--
-- Only built-in materials and plain parts are used - no asset IDs.

local DevOverlay = require(script.Parent.DevOverlay)
local Plan = require(script.Parent.Plan)
local Shell = require(script.Parent.Shell)

type Look = { material: Enum.Material, color: Color3 }
type Lamp = { color: Color3, fixture: Color3, brightness: number, range: number }

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- One restrained palette for the whole station: dark, cold, low saturation, with every
-- surface in a similar brightness range so no room reads as white or blue. Each wing has
-- its own wall material and tone, enough to tell where you are without a sign.
local FLOOR: { [string]: Look } = {
	default = { material = Enum.Material.Concrete, color = rgb(52, 54, 56) },
	metal = { material = Enum.Material.DiamondPlate, color = rgb(56, 59, 62) },
	lab = { material = Enum.Material.Concrete, color = rgb(62, 65, 67) },
}
local CEILING: Look = { material = Enum.Material.Metal, color = rgb(42, 43, 46) }
local WALLS: { [string]: Look } = {
	A = { material = Enum.Material.Concrete, color = rgb(74, 76, 78) },
	B = { material = Enum.Material.Concrete, color = rgb(70, 73, 76) },
	C = { material = Enum.Material.Concrete, color = rgb(80, 84, 86) },
	D = { material = Enum.Material.Concrete, color = rgb(66, 70, 74) },
	-- Medical: pale, slightly green painted walls.
	E = { material = Enum.Material.Concrete, color = rgb(82, 88, 86) },
	-- Archives: old brick, warmer and darker.
	F = { material = Enum.Material.Brick, color = rgb(72, 68, 62) },
	-- Power: bare metal.
	G = { material = Enum.Material.Metal, color = rgb(66, 64, 60) },
	-- Containment: dark corroded plating.
	H = { material = Enum.Material.CorrodedMetal, color = rgb(58, 56, 56) },
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

-- Lamps are cold and deliberately dim everywhere, so rooms keep dark corners; each wing
-- shifts the tone and level a little. Emergency lamps are red and dimmer still.
local function lamp(r: number, g: number, b: number, brightness: number, range: number): Lamp
	return {
		color = rgb(r, g, b),
		fixture = rgb(math.floor(r * 0.8), math.floor(g * 0.8), math.floor(b * 0.8)),
		brightness = brightness,
		range = range,
	}
end
local LAMPS: { [string]: Lamp } = {
	A = lamp(186, 200, 206, 0.6, 20), -- stable cold white
	B = lamp(176, 198, 204, 0.55, 20), -- muted cyan-white
	C = lamp(204, 212, 214, 0.6, 20), -- clinical
	D = lamp(150, 176, 190, 0.4, 16), -- dark; screens will carry the room
	E = lamp(190, 204, 204, 0.42, 16), -- weak cold white
	F = lamp(184, 180, 168, 0.35, 14), -- low and local
	G = lamp(214, 176, 124, 0.5, 18), -- warm electrical
	H = lamp(150, 160, 172, 0.3, 14), -- minimal
}
local EMERGENCY_LAMP: Lamp = lamp(190, 50, 44, 0.45, 16)

local SIGN_COLOR = rgb(170, 180, 184)

local Builder = {}

-- Tag on every ceiling, roof section and rock cap: everything that covers the interior from
-- above. The ceiling commands hide exactly these parts and nothing else.
Builder.OVERHEAD_TAG = "TLS_Overhead"

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

-- Stencilled room name on the wall above a doorway.
local function addSign(part: BasePart, roomName: string, faceName: string)
	local face = (Enum.NormalId :: any)[faceName]
	if not face then
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	-- Lit by the room, so signs are dark in the dark like everything else.
	gui.LightInfluence = 1

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 14)
	label.Size = UDim2.new(1, -16, 0, 44)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = SIGN_COLOR
	label.TextTransparency = 0.15
	label.Text = DevOverlay.displayName(roomName)
	label.Parent = gui
	gui.Parent = part
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
	ceiling:AddTag(Builder.OVERHEAD_TAG)

	local walls = newFolder("Walls", folder)
	for _, box in plan.walls do
		local wall = newPart(layout, box, WALLS[area.id] or WALLS.A, walls)
		if box.sign and box.face then
			addSign(wall, box.sign, box.face)
		end
	end

	local lights = newFolder("Lights", folder)
	local emergency = room.emergency == true
	local roomLamp = if emergency then EMERGENCY_LAMP else (LAMPS[area.id] or LAMPS.A)
	for _, box in plan.lights do
		local fixture = newPart(
			layout,
			box,
			{ material = Enum.Material.Neon, color = roomLamp.fixture },
			lights
		)
		makeGhost(fixture)
		fixture:SetAttribute("Circuit", if emergency then "Emergency" else area.id)
		fixture:AddTag("TLS_Light")

		local light = Instance.new("PointLight")
		light.Color = roomLamp.color
		light.Range = roomLamp.range
		light.Brightness = roomLamp.brightness
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
		model:SetAttribute("RoomA", passage.a)
		model:SetAttribute("RoomB", passage.b)
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
	local caps = newFolder("RockCaps", folder)
	for _, box in shell.rockCaps do
		newPart(layout, box, ROCK, caps):AddTag(Builder.OVERHEAD_TAG)
	end
	local roof = newFolder("Roof", folder)
	for _, box in shell.roofSections do
		newPart(layout, box, ROCK, roof):AddTag(Builder.OVERHEAD_TAG)
	end
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
