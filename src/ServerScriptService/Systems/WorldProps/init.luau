--!strict
-- Creates the gameplay objects listed in Data/PropList when the game starts, inside
-- Workspace.TLS_Runtime. They exist only while the game runs and are never saved, so the
-- Studio-built map is not modified. Where the map already has a suitable part (`reuse`),
-- that part is made interactive instead; the tags and attributes added to it are likewise
-- runtime-only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Localization = require(ReplicatedStorage.Shared.Localization)
local Logger = require(ReplicatedStorage.Shared.Logger)
local PropList = require(script.Parent.Parent.Data.PropList) :: any
local WorldService = require(script.Parent.Parent.Services.WorldService)
local Placement = require(script.Placement)

type Look = { material: Enum.Material, color: Color3 }

local INTERACTABLE_TAG = "TLS_Interactable"
local RUNTIME_ATTRIBUTE = "TLS_RuntimeProp"
local LABEL_NAME = "TLS_Label"
-- Client contract (Controllers/WorldTextController): labels carry this tag and the
-- attribute holds the text reference to render.
local LABEL_TAG = "TLS_LocalizedLabel"
local LABEL_ATTRIBUTE = "TLS_Text"

local LOOKS: { [string]: Look } = {
	paper = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(196, 194, 180) },
	panel = { material = Enum.Material.Metal, color = Color3.fromRGB(70, 130, 140) },
	radio = { material = Enum.Material.Metal, color = Color3.fromRGB(48, 52, 56) },
	battery = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(150, 128, 60) },
	item = { material = Enum.Material.Metal, color = Color3.fromRGB(176, 140, 72) },
	switch = { material = Enum.Material.Metal, color = Color3.fromRGB(120, 40, 38) },
}
local STAND_LOOK: Look = { material = Enum.Material.Metal, color = Color3.fromRGB(58, 60, 64) }

local log = Logger.new("WorldProps")

local WorldProps = {}

local built = false
local props: { [string]: Instance } = {}

local function newPart(
	name: string,
	zone: BasePart,
	box: Placement.Box,
	look: Look,
	parent: Instance
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = Vector3.new(box.sx, box.sy, box.sz)
	-- Offsets are relative to the room's centre and floor; the zone box gives both.
	part.CFrame = zone.CFrame * CFrame.new(box.ox, -zone.Size.Y / 2 + box.oy, box.oz)
	part.Material = look.material
	part.Color = look.color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function create(def: Placement.PropDef, zone: BasePart): Instance
	local placement = Placement.resolve(def, zone.Size.X, zone.Size.Z)
	local model = Instance.new("Model")
	model.Name = def.id

	if placement.stand then
		newPart("Stand", zone, placement.stand, STAND_LOOK, model)
	end
	local item = newPart("Item", zone, placement.item, LOOKS[def.look] or LOOKS.panel, model)
	model.PrimaryPart = item
	model:SetAttribute(RUNTIME_ATTRIBUTE, true)
	model.Parent = WorldService.runtimeFolder()
	return model
end

local function findReusable(def: Placement.PropDef): Instance?
	local name = def.reuse
	local folder = WorldService.getRoomFolder(def.room)
	if not name or not folder then
		return nil
	end
	local found = folder:FindFirstChild(name, true)
	return if found and found:IsA("BasePart") then found else nil
end

-- Builds every prop once. Safe to call from any system, any number of times, after the map
-- is ready.
function WorldProps.ensure()
	if built then
		return
	end
	built = true

	local count = 0
	local list: { Placement.PropDef } = PropList
	for _, def in list do
		local zone = WorldService.getZone(def.room)
		if not zone then
			log:warn(`Room "{def.room}" not found; prop "{def.id}" was not placed`)
			continue
		end

		local target = findReusable(def) or create(def, zone)
		target:SetAttribute("Kind", def.kind)
		target:SetAttribute("Id", def.id)
		target:SetAttribute("ActionText", def.action)
		target:SetAttribute("ObjectText", def.object)
		target:SetAttribute("InteractEnabled", def.enabled ~= false)
		-- Tagged last: the interaction system binds as soon as the tag appears.
		target:AddTag(INTERACTABLE_TAG)

		props[def.id] = target
		count += 1
	end
	log:info(`{count} gameplay object(s) placed`)
end

function WorldProps.get(id: string): Instance?
	return props[id]
end

-- The part that represents the object in the world (for position, colour and labels).
function WorldProps.partOf(target: Instance): BasePart?
	if target:IsA("BasePart") then
		return target
	elseif target:IsA("Model") then
		return target.PrimaryPart
	end
	return nil
end

-- World position of a prop by id, or nil when it was not placed.
function WorldProps.positionOf(id: string): Vector3?
	local target = props[id]
	local part = target and WorldProps.partOf(target)
	return if part then part.Position else nil
end

-- Takes a prop out of play (a picked-up item). Objects the game created are destroyed;
-- parts of the Studio-built map are only made non-interactive.
function WorldProps.remove(id: string)
	local target = props[id]
	if not target then
		return
	end
	props[id] = nil
	if target:GetAttribute(RUNTIME_ATTRIBUTE) == true then
		target:Destroy()
	else
		target:SetAttribute("InteractEnabled", false)
	end
end

-- Changes an object's colour and whether it glows.
function WorldProps.setLook(target: Instance, color: Color3, glowing: boolean)
	local part = WorldProps.partOf(target)
	if part then
		part.Color = color
		part.Material = if glowing then Enum.Material.Neon else Enum.Material.Metal
	end
end

-- Shows (or updates) a small floating text label above an object. `text` is an encoded
-- text reference (Shared/Text); clients render it in their own language.
function WorldProps.setLabel(target: Instance, text: string, color: Color3)
	local part = WorldProps.partOf(target)
	if not part then
		return
	end
	local existing = part:FindFirstChild(LABEL_NAME)
	local gui: BillboardGui
	if existing and existing:IsA("BillboardGui") then
		gui = existing
	else
		gui = Instance.new("BillboardGui")
		gui.Name = LABEL_NAME
		gui.Size = UDim2.fromScale(8, 1.8)
		gui.StudsOffsetWorldSpace = Vector3.new(0, part.Size.Y / 2 + 1.5, 0)
		gui.MaxDistance = 36
		gui.LightInfluence = 0
		gui.ResetOnSpawn = false
		-- The game translates its own text; Roblox must not capture or translate it.
		gui.AutoLocalize = false

		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.fromRGB(10, 12, 14)
		label.BackgroundTransparency = 0.35
		label.BorderSizePixel = 0
		label.Font = Enum.Font.GothamMedium
		label.TextScaled = true
		label.Parent = gui
		gui:AddTag(LABEL_TAG)
		gui.Parent = part
	end
	local label = gui:FindFirstChild("Text")
	if label and label:IsA("TextLabel") then
		-- English is the fallback until the client renders the reference.
		label.Text = Localization.render(Localization.SOURCE, text)
		label.TextColor3 = color
	end
	gui:SetAttribute(LABEL_ATTRIBUTE, text)
end

function WorldProps.clearLabel(target: Instance)
	local part = WorldProps.partOf(target)
	local existing = part and part:FindFirstChild(LABEL_NAME)
	if existing then
		existing:Destroy()
	end
end

return WorldProps
