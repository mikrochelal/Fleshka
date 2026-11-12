--!strict
-- Loads every ModuleScript in a folder and runs its lifecycle hooks.
-- Used by both bootstraps: services on the server, controllers on the client.
--
-- A module may expose:
--   Init(self)  - synchronous setup; must not yield and must not call other modules.
--   Start(self) - runs after every module finished Init; may yield.

local Logger = require(script.Parent.Logger)

export type Lifecycle = {
	Init: ((self: any) -> ...any)?,
	Start: ((self: any) -> ...any)?,
	[any]: any,
}

type Loaded = { name: string, module: Lifecycle }

local Loader = {}

local function requireModule(moduleScript: ModuleScript): (boolean, any)
	-- Dynamic require: the analyzer cannot resolve it, so it is intentionally untyped.
	return pcall(require :: any, moduleScript)
end

-- Returns the successfully loaded modules keyed by ModuleScript name.
-- One broken module is reported and skipped so it cannot take the whole game down.
function Loader.loadFolder(folder: Instance, scope: string): { [string]: Lifecycle }
	local log = Logger.new(scope)

	local moduleScripts: { ModuleScript } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			table.insert(moduleScripts, child)
		end
	end
	-- Deterministic order; modules must not depend on it (cross-module calls belong in Start).
	table.sort(moduleScripts, function(a, b)
		return a.Name < b.Name
	end)

	local loaded: { Loaded } = {}
	for _, moduleScript in moduleScripts do
		local ok, result = requireModule(moduleScript)
		if not ok then
			log:warn(`Failed to require {moduleScript.Name}: {result}`)
		elseif type(result) ~= "table" then
			log:warn(`{moduleScript.Name} must return a table, got {typeof(result)}`)
		else
			table.insert(loaded, { name = moduleScript.Name, module = result })
		end
	end

	local started: { [string]: Lifecycle } = {}
	for _, entry in loaded do
		local init = entry.module.Init
		if init then
			local ok, err = pcall(init, entry.module)
			if not ok then
				log:warn(`{entry.name}.Init failed: {err}`)
				continue
			end
		end
		started[entry.name] = entry.module
	end

	for name, module in started do
		local start = module.Start
		if start then
			task.spawn(function()
				local ok, err = pcall(start, module)
				if not ok then
					log:warn(`{name}.Start failed: {err}`)
				end
			end)
		end
	end

	return started
end

return Loader
