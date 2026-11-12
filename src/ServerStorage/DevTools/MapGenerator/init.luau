--!strict
-- STATION-09 draft map generator. A development tool: it is never required by game code and
-- does nothing until it is called by hand from the Studio Command Bar, in Edit mode:
--
--   require(game.ServerStorage.TLS_DevTools.MapGenerator:Clone()).generate()
--
-- `:Clone()` makes Studio run the latest synced code instead of a cached copy.
--
-- Safety rules:
--   * Only ever creates or moves `Workspace.Station09`. Nothing else is touched.
--   * generate() changes nothing if `Workspace.Station09` already exists.
--   * regenerate() never deletes: the previous generated map is moved to
--     `ServerStorage.TLS_MapBackups`. A `Station09` that this tool did not create is refused.
--   * The same layout always produces the same map, with the same names.
--   * Lighting is changed only by the explicit, reversible applyLightingPreset().
--   * viewFromAbove() moves the editor camera and nothing else.
--
-- Files: Layout.luau (the floor plan - edit this), Plan.luau (rooms, walls, passages),
-- Shell.luau (rock fill, rock caps and roof sections), Builder.luau (instance creation),
-- LightingPreset.luau (optional dark base lighting).

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Builder = require(script.Builder)
local Layout = require(script.Layout)
local LightingPreset = require(script.LightingPreset)
local Plan = require(script.Plan)
local Shell = require(script.Shell)

local GENERATED_ATTRIBUTE = "TLS_Generated"
local VERSION_ATTRIBUTE = "TLS_GeneratorVersion"
local CEILINGS_HIDDEN_ATTRIBUTE = "TLS_CeilingsHidden"
local BACKUP_FOLDER = "TLS_MapBackups"
local PREFIX = "[TLS:MapGenerator]"

local layout: Plan.Layout = Layout

local MapGenerator = {}

local function say(message: string)
	print(`{PREFIX} {message}`)
end

local function refuse(message: string): boolean
	warn(`{PREFIX} {message}`)
	return false
end

local function isGenerated(instance: Instance): boolean
	return instance:GetAttribute(GENERATED_ATTRIBUTE) == true
end

-- Lets Ctrl+Z undo the operation; harmless if Studio refuses.
local function waypoint(name: string)
	pcall(function()
		ChangeHistoryService:SetWaypoint(name)
	end)
end

local function checkLayout(): boolean
	local problems = Plan.validate(layout)
	for _, problem in problems do
		warn(`{PREFIX} layout problem: {problem}`)
	end
	return #problems == 0
end

local function footprints(): { Shell.Footprint }
	local list: { Shell.Footprint } = {}
	for _, room in layout.rooms do
		table.insert(list, {
			name = room.name,
			x0 = room.x0,
			x1 = room.x1,
			z0 = room.z0,
			z1 = room.z1,
			height = room.height,
		})
	end
	return list
end

-- Hides or shows the overhead parts only (ceilings, roof sections, rock caps). They keep
-- their collision, and floors, walls and the lower rock are never touched. Hidden parts
-- are also locked, so clicks in the viewport pass through to the interior.
local function applyCeilings(root: Instance, visible: boolean): number
	local count = 0
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:HasTag(Builder.OVERHEAD_TAG) then
			descendant.Transparency = if visible then 0 else 1
			descendant.Locked = not visible
			descendant.CastShadow = visible
			count += 1
		end
	end
	root:SetAttribute(CEILINGS_HIDDEN_ATTRIBUTE, not visible)
	return count
end

local function build(ceilingsHidden: boolean): boolean
	local shell = Shell.build(footprints(), layout.shellMargin, layout.slabThickness)

	local root, summary = Builder.build(layout, Plan.build(layout), shell)
	root:SetAttribute(GENERATED_ATTRIBUTE, true)
	root:SetAttribute(VERSION_ATTRIBUTE, layout.version)
	applyCeilings(root, not ceilingsHidden)
	root.Parent = Workspace

	say(
		`Created Workspace.{layout.rootName}: {summary.rooms} rooms, {summary.doors} doors, `
			.. `{summary.archways} archways, {summary.lights} lights, {summary.parts} parts `
			.. `(layout v{layout.version}, ceilings {if ceilingsHidden then "hidden" else "shown"})`
	)
	return true
end

-- Creates the draft map. Does nothing if Workspace.Station09 already exists.
function MapGenerator.generate(): boolean
	if RunService:IsRunning() then
		return refuse("Stop the game first: changes made while playing are lost.")
	end
	local existing = Workspace:FindFirstChild(layout.rootName)
	if existing then
		if isGenerated(existing) then
			return refuse(
				`Workspace.{layout.rootName} already exists - nothing changed. `
					.. "Use .regenerate() to rebuild it (the old one is kept as a backup)."
			)
		end
		return refuse(
			`Workspace.{layout.rootName} exists but was not made by this tool - nothing changed. `
				.. "Rename or move it if you want a generated map."
		)
	end
	if not checkLayout() then
		return false
	end

	waypoint("Before TLS map generation")
	local ok = build(false)
	waypoint("TLS map generation")
	return ok
end

-- Rebuilds the draft map from the current layout. The previous generated map is moved to
-- ServerStorage.TLS_MapBackups, never deleted. Ceilings stay hidden if they were hidden.
function MapGenerator.regenerate(): boolean
	if RunService:IsRunning() then
		return refuse("Stop the game first: changes made while playing are lost.")
	end
	local existing = Workspace:FindFirstChild(layout.rootName)
	if existing and not isGenerated(existing) then
		return refuse(
			`Workspace.{layout.rootName} was not made by this tool - it will not be replaced.`
		)
	end
	-- Validate before moving anything so a bad layout leaves the current map in place.
	if not checkLayout() then
		return false
	end

	waypoint("Before TLS map regeneration")
	local ceilingsHidden = false
	if existing then
		ceilingsHidden = existing:GetAttribute(CEILINGS_HIDDEN_ATTRIBUTE) == true

		local backups = ServerStorage:FindFirstChild(BACKUP_FOLDER)
		if not backups then
			backups = Instance.new("Folder")
			backups.Name = BACKUP_FOLDER
			backups.Parent = ServerStorage
		end
		local version = existing:GetAttribute(VERSION_ATTRIBUTE)
		local backupName =
			`{layout.rootName}_v{tostring(version)}_backup_{os.date("%Y%m%d_%H%M%S")}`
		existing.Name = backupName
		existing.Parent = backups
		say(`Previous map moved to ServerStorage.{BACKUP_FOLDER}.{backupName}`)
	end
	local ok = build(ceilingsHidden)
	waypoint("TLS map regeneration")
	return ok
end

-- Shows or hides every ceiling, roof section and rock cap of the generated map, so
-- interiors can be seen and edited from above. An editing aid only: the game shows them
-- again whenever it runs (Systems/OverheadGuard).
function MapGenerator.setCeilingsVisible(visible: boolean): boolean
	local root = Workspace:FindFirstChild(layout.rootName)
	if not root or not isGenerated(root) then
		return refuse(`No generated Workspace.{layout.rootName} found.`)
	end
	waypoint("Before TLS ceilings change")
	local count = applyCeilings(root, visible)
	waypoint("TLS ceilings change")
	say(`{count} ceiling and roof parts {if visible then "shown" else "hidden"}`)
	return true
end

function MapGenerator.hideCeilings(): boolean
	return MapGenerator.setCeilingsVisible(false)
end

function MapGenerator.showCeilings(): boolean
	return MapGenerator.setCeilingsVisible(true)
end

-- Moves the Studio camera straight above the station (north at the top of the screen) and
-- hides the ceilings. Pass a room name, with or without its area prefix ("MainLab" or
-- "C_MainLab"), to frame one room. Only the editor camera is changed.
function MapGenerator.viewFromAbove(roomName: string?): boolean
	local root = Workspace:FindFirstChild(layout.rootName)
	if not root or not isGenerated(root) then
		return refuse(`No generated Workspace.{layout.rootName} found.`)
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return refuse("No camera available.")
	end

	local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
	local tallest = 0
	for _, room in layout.rooms do
		local matches = roomName == nil
			or room.name == roomName
			or string.sub(room.name, 3) == roomName
		if matches then
			x0, x1 = math.min(x0, room.x0), math.max(x1, room.x1)
			z0, z1 = math.min(z0, room.z0), math.max(z1, room.z1)
			tallest = math.max(tallest, room.height)
		end
	end
	if tallest == 0 then
		return refuse(`Unknown room "{tostring(roomName)}". Room names are listed in Layout.luau.`)
	end

	if root:GetAttribute(CEILINGS_HIDDEN_ATTRIBUTE) ~= true then
		MapGenerator.setCeilingsVisible(false)
	end

	local origin = layout.origin
	local focus = Vector3.new(origin.x + (x0 + x1) / 2, origin.y, origin.z + (z0 + z1) / 2)
	-- Height at which the framed area fills the view, with a small border.
	local viewport = camera.ViewportSize
	local aspect = if viewport.Y > 0 then viewport.X / viewport.Y else 1.6
	local span = math.max(z1 - z0, (x1 - x0) / aspect) * 1.1
	local height = span / 2 / math.tan(math.rad(camera.FieldOfView) / 2) + tallest

	-- Anything above the station that is not part of it (for example the Baseplate) would
	-- block the view, so stay just underneath it.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { root }
	local top = focus + Vector3.new(0, tallest + 3, 0)
	local hit = Workspace:Raycast(top, Vector3.new(0, height, 0), params)
	if hit and hit.Position.Y - 2 < focus.Y + height then
		height = hit.Position.Y - 2 - focus.Y
		say(
			`{hit.Instance:GetFullName()} is above the station, so the camera stays below it and `
				.. "may not show the whole area. Frame a single room instead, for example "
				.. '.viewFromAbove("MainLab").'
		)
	end

	-- Looking straight down needs an explicit up direction; -Z puts north at the top.
	camera.CFrame = CFrame.lookAt(focus + Vector3.new(0, height, 0), focus, Vector3.new(0, 0, -1))
	camera.Focus = CFrame.new(focus)
	say(`Camera placed above {roomName or "the station"}. Use the mouse wheel to zoom.`)
	return true
end

-- Optional: removes daylight and sets a low cold ambient in the place's Lighting, so the
-- station's lamps define the look. Reversible with .restoreLighting().
function MapGenerator.applyLightingPreset(): boolean
	if RunService:IsRunning() then
		return refuse("Stop the game first: changes made while playing are lost.")
	end
	waypoint("Before TLS lighting preset")
	local changed = LightingPreset.apply()
	waypoint("TLS lighting preset")
	say(
		if changed
			then "Dark base lighting applied. Undo with .restoreLighting()"
			else "Dark base lighting is already applied - nothing changed."
	)
	return true
end

function MapGenerator.restoreLighting(): boolean
	if RunService:IsRunning() then
		return refuse("Stop the game first: changes made while playing are lost.")
	end
	waypoint("Before TLS lighting restore")
	local changed = LightingPreset.restore()
	waypoint("TLS lighting restore")
	say(
		if changed
			then "Lighting restored to the values it had before the preset."
			else "The lighting preset is not applied - nothing changed."
	)
	return true
end

-- Prints what is currently in the place. Changes nothing.
function MapGenerator.status()
	local root = Workspace:FindFirstChild(layout.rootName)
	if not root then
		say(`Workspace.{layout.rootName} does not exist. Run .generate() to create it.`)
	elseif not isGenerated(root) then
		say(`Workspace.{layout.rootName} exists but was not made by this tool.`)
	else
		local parts = 0
		for _, descendant in root:GetDescendants() do
			if descendant:IsA("BasePart") then
				parts += 1
			end
		end
		local version = root:GetAttribute(VERSION_ATTRIBUTE)
		local hidden = root:GetAttribute(CEILINGS_HIDDEN_ATTRIBUTE) == true
		say(
			`Workspace.{layout.rootName}: generated from layout v{tostring(version)}, {parts} parts, `
				.. `ceilings {if hidden then "hidden" else "shown"}. `
				.. `Current layout is v{layout.version}`
				.. `{if version ~= layout.version then " - run .regenerate() to update." else "."}`
		)
	end

	local backups = ServerStorage:FindFirstChild(BACKUP_FOLDER)
	say(`Backups in ServerStorage.{BACKUP_FOLDER}: {if backups then #backups:GetChildren() else 0}`)
	say(`Dark base lighting: {if LightingPreset.isApplied() then "applied" else "not applied"}`)
end

return MapGenerator
