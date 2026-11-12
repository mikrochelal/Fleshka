--!strict
-- Controls the station's ceiling lights (parts tagged `TLS_Light` with a `Circuit`
-- attribute). Circuits can be switched as a whole, and any group of lights can be made to
-- flicker. All changes happen on the server at runtime and are not saved into the place.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Logger)
local NetService = require(script.Parent.Parent.Services.NetService)
local WorldService = require(script.Parent.Parent.Services.WorldService)

type Entry = {
	fixture: BasePart,
	light: Light?,
	color: Color3,
	material: Enum.Material,
	room: string,
	circuit: string,
	-- Bumped by every flicker so an older flicker cannot overwrite a newer one.
	flickerToken: number,
}

local LIGHT_TAG = "TLS_Light"
local OFF_COLOR = Color3.fromRGB(34, 37, 40)
-- On/off durations of a flicker, repeated until the flicker ends.
local FLICKER_PATTERN = { 0.07, 0.12, 0.05, 0.2, 0.06, 0.09, 0.3, 0.05, 0.14 }

local log = Logger.new("FacilityLights")

local FacilityLights = {}

local entries: { Entry } = {}
local circuitOff: { [string]: boolean } = {}
local collected = false

local function apply(entry: Entry, lit: boolean)
	if entry.light then
		entry.light.Enabled = lit
	end
	entry.fixture.Material = if lit then entry.material else Enum.Material.SmoothPlastic
	entry.fixture.Color = if lit then entry.color else OFF_COLOR
end

local function ensure()
	if collected then
		return
	end
	collected = true
	for _, fixture in WorldService.getTagged(LIGHT_TAG) do
		local circuit = fixture:GetAttribute("Circuit")
		table.insert(entries, {
			fixture = fixture,
			light = fixture:FindFirstChildWhichIsA("Light"),
			color = fixture.Color,
			material = fixture.Material,
			room = WorldService.zoneAt(fixture.Position) or "",
			circuit = if type(circuit) == "string" then circuit else "",
			flickerToken = 0,
		})
	end
	log:info(`{#entries} light fixture(s) under control`)
end

function FacilityLights.isCircuitOn(circuit: string): boolean
	return circuitOff[circuit] ~= true
end

-- True when at least one lamp in the room is on a live circuit (a flicker does not count
-- as darkness). A room with no lamps at all is dark.
function FacilityLights.isRoomLit(room: string): boolean
	ensure()
	for _, entry in entries do
		if entry.room == room and FacilityLights.isCircuitOn(entry.circuit) then
			return true
		end
	end
	return false
end

function FacilityLights.setCircuit(circuit: string, on: boolean)
	ensure()
	circuitOff[circuit] = not on
	for _, entry in entries do
		if entry.circuit == circuit then
			entry.flickerToken += 1
			apply(entry, on)
		end
	end
end

local function flicker(matches: (entry: Entry) -> boolean, seconds: number)
	ensure()
	local group: { Entry } = {}
	local tokens: { number } = {}
	local origin: Vector3? = nil
	for _, entry in entries do
		if matches(entry) then
			entry.flickerToken += 1
			table.insert(group, entry)
			table.insert(tokens, entry.flickerToken)
			origin = origin or entry.fixture.Position
		end
	end
	if #group == 0 then
		return
	end
	NetService.fireAll("Sound", "LightFlicker", origin)

	task.spawn(function()
		local elapsed, step, lit = 0, 1, false
		while elapsed < seconds do
			for index, entry in group do
				if entry.flickerToken == tokens[index] then
					apply(entry, lit)
				end
			end
			local wait = FLICKER_PATTERN[(step - 1) % #FLICKER_PATTERN + 1]
			task.wait(wait)
			elapsed += wait
			step += 1
			lit = not lit
		end
		-- Settle on whatever the circuit state is now.
		for index, entry in group do
			if entry.flickerToken == tokens[index] then
				apply(entry, FacilityLights.isCircuitOn(entry.circuit))
			end
		end
	end)
end

-- Flickers every light in the named rooms, then returns them to their circuit state.
function FacilityLights.flickerRooms(rooms: { string }, seconds: number)
	flicker(function(entry)
		return table.find(rooms, entry.room) ~= nil
	end, seconds)
end

-- Flickers every light on the named circuits, then returns them to their circuit state.
function FacilityLights.flickerCircuits(circuits: { string }, seconds: number)
	flicker(function(entry)
		return table.find(circuits, entry.circuit) ~= nil
	end, seconds)
end

return FacilityLights
