--!strict
-- STATION-09 draft map generator. A development tool: it is never required by game code and
-- does nothing until it is called by hand from the Studio Command Bar (game stopped):
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
--
-- Files: Layout.luau (the floor plan - edit this), Plan.luau (geometry math),
-- Builder.luau (instance creation).

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Builder = require(script.Builder)
local Layout = require(script.Layout)
local Plan = require(script.Plan)

local GENERATED_ATTRIBUTE = "TLS_Generated"
local VERSION_ATTRIBUTE = "TLS_GeneratorVersion"
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

local function build(): boolean
	local root, summary = Builder.build(layout, Plan.build(layout))
	root:SetAttribute(GENERATED_ATTRIBUTE, true)
	root:SetAttribute(VERSION_ATTRIBUTE, layout.version)
	root.Parent = Workspace

	say(
		`Created Workspace.{layout.rootName}: {summary.rooms} rooms, {summary.doors} doors, `
			.. `{summary.lights} lights, {summary.parts} parts (layout v{layout.version})`
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
	local ok = build()
	waypoint("TLS map generation")
	return ok
end

-- Rebuilds the draft map. The previous generated map is moved to
-- ServerStorage.TLS_MapBackups, never deleted.
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
	if existing then
		local backups = ServerStorage:FindFirstChild(BACKUP_FOLDER)
		if not backups then
			backups = Instance.new("Folder")
			backups.Name = BACKUP_FOLDER
			backups.Parent = ServerStorage
		end
		local backupName = `{layout.rootName}_backup_{os.date("%Y%m%d_%H%M%S")}`
		existing.Name = backupName
		existing.Parent = backups
		say(`Previous map moved to ServerStorage.{BACKUP_FOLDER}.{backupName}`)
	end
	local ok = build()
	waypoint("TLS map regeneration")
	return ok
end

-- Shows or hides the ceilings of the generated map so the layout can be viewed from above.
function MapGenerator.setCeilingsVisible(visible: boolean): boolean
	local root = Workspace:FindFirstChild(layout.rootName)
	if not root or not isGenerated(root) then
		return refuse(`No generated Workspace.{layout.rootName} found.`)
	end
	local count = 0
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name == "Ceiling" then
			descendant.Transparency = if visible then 0 else 1
			count += 1
		end
	end
	say(`{count} ceilings {if visible then "shown" else "hidden"}`)
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
		say(
			`Workspace.{layout.rootName}: generated from layout v{tostring(version)}, {parts} parts. `
				.. `Current layout is v{layout.version}.`
		)
	end

	local backups = ServerStorage:FindFirstChild(BACKUP_FOLDER)
	say(`Backups in ServerStorage.{BACKUP_FOLDER}: {if backups then #backups:GetChildren() else 0}`)
end

return MapGenerator
