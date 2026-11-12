--!strict
-- Power Restoration puzzle.
--
-- The station's breaker panels (map parts tagged `TLS_BreakerPanel` with a numeric
-- `PanelId`) must be engaged in the order written on the maintenance memo, then the main
-- lever thrown. The order is generated here for every session and never sent to clients
-- except as the memo's text.
--
-- Progress is never taken away. A breaker thrown out of turn trips straight back out (and
-- is loud), but the breakers already engaged stay engaged; the lever simply refuses until
-- all of them are in, and once they are it always works. Every step is logged.
--
-- Consequences of restoring power: the dead lighting circuits come on, the red emergency
-- lamps go out, and `restored` fires so the rest of the mission can continue.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PowerConfig = require(ReplicatedStorage.Config.PowerConfig)
local GameState = require(ReplicatedStorage.Shared.GameState)
local Logger = require(ReplicatedStorage.Shared.Logger)
local Signal = require(ReplicatedStorage.Shared.Signal)
local NetService = require(script.Parent.Parent.Services.NetService)
local NoiseService = require(script.Parent.Parent.Services.NoiseService)
local SessionService = require(script.Parent.Parent.Services.SessionService)
local WorldService = require(script.Parent.Parent.Services.WorldService)
local FacilityLights = require(script.Parent.FacilityLights)
local InteractionSystem = require(script.Parent.InteractionSystem)
local WorldProps = require(script.Parent.WorldProps)

type Panel = { id: number, part: BasePart, name: string }

local PANEL_TAG = "TLS_BreakerPanel"
local INTERACTABLE_TAG = "TLS_Interactable"

local COLOR_OFF = Color3.fromRGB(120, 40, 38)
local COLOR_ENGAGED = Color3.fromRGB(204, 150, 56)
local COLOR_LIVE = Color3.fromRGB(70, 170, 120)
local COLOR_REJECT = Color3.fromRGB(230, 60, 50)

local log = Logger.new("Power")

local PowerSystem = {}

-- Fired once when power comes back.
PowerSystem.restored = Signal.new()
-- Fired every time a player operates a breaker or the lever.
PowerSystem.controlsUsed = Signal.new()

local panels: { Panel } = {}
local solution: { number } = {}
local engaged: { number } = {}
local powerOn = false
-- True while the start-up surge is playing; the lever cannot be thrown twice.
local starting = false
local lever: Instance? = nil

local function notify(player: Player, text: string, kind: string)
	NetService.fire("Notify", player, text, kind)
end

local function panelById(id: number): Panel?
	for _, panel in panels do
		if panel.id == id then
			return panel
		end
	end
	return nil
end

local function publish()
	ReplicatedStorage:SetAttribute(GameState.BREAKERS_ENGAGED_ATTRIBUTE, #engaged)
	ReplicatedStorage:SetAttribute(GameState.BREAKERS_TOTAL_ATTRIBUTE, #panels)
end

local function refresh()
	for _, panel in panels do
		local position = table.find(engaged, panel.id)
		local color, status
		if powerOn then
			color, status = COLOR_LIVE, "LIVE"
		elseif position then
			color, status = COLOR_ENGAGED, `ENGAGED {position}/{#panels}`
		else
			color, status = COLOR_OFF, "OFF"
		end
		panel.part.Color = color
		panel.part.Material = if color == COLOR_OFF
			then Enum.Material.SmoothPlastic
			else Enum.Material.Neon
		WorldProps.setLabel(panel.part, `{panel.name}\n{status}`, color)
	end

	local leverPart = lever and WorldProps.partOf(lever)
	if lever and leverPart then
		local ready = #engaged == #panels
		local color = if powerOn then COLOR_LIVE elseif ready then COLOR_ENGAGED else COLOR_OFF
		local status = if powerOn
			then "ON"
			elseif ready then "READY"
			else `{#engaged}/{#panels} BREAKERS`
		leverPart.Color = color
		leverPart.Material = if color == COLOR_OFF
			then Enum.Material.SmoothPlastic
			else Enum.Material.Neon
		WorldProps.setLabel(lever, `EMERGENCY POWER\n{status}`, color)
	end
	publish()
end

local function restore(player: Player)
	starting = true
	log:info(`Lever thrown by {player.Name}: start-up sequence begins`)
	if lever then
		lever:SetAttribute("InteractEnabled", false)
	end

	local leverPart = lever and WorldProps.partOf(lever)
	local origin = if leverPart then leverPart.Position else nil
	NetService.fireAll("Notify", "Emergency power starting...", "info")
	NetService.fireAll("Sound", "PowerOn", origin)
	local circuits = table.clone(PowerConfig.UnpoweredCircuits)
	table.insert(circuits, PowerConfig.EmergencyCircuit)
	FacilityLights.flickerCircuits(circuits, PowerConfig.SurgeSeconds)
	task.wait(PowerConfig.SurgeSeconds)

	powerOn = true
	for _, circuit in PowerConfig.UnpoweredCircuits do
		FacilityLights.setCircuit(circuit, true)
	end
	FacilityLights.setCircuit(PowerConfig.EmergencyCircuit, false)
	ReplicatedStorage:SetAttribute(GameState.POWER_ATTRIBUTE, true)
	refresh()

	log:info("Power state: OFF -> ON")
	NetService.fireAll("Notify", "Emergency power restored.", "info")
	NetService.fireAll("Sound", "Machinery", origin)
	if origin then
		NoiseService.emit(origin, PowerConfig.SuccessNoiseRadius)
	end
	starting = false
	PowerSystem.restored:Fire(player)
end

-- The breaker refuses: it flashes, makes noise and stays out. Nothing else changes.
local function reject(player: Player, panel: Panel)
	log:info(
		`{player.Name} threw {panel.name} out of turn ({#engaged}/{#panels} engaged); it tripped back out`
	)
	notify(
		player,
		`{panel.name} trips straight back out. It is not next in the start-up order.`,
		"warning"
	)
	NetService.fireAll("Sound", "BreakerTrip", panel.part.Position)
	NoiseService.emit(panel.part.Position, PowerConfig.FailureNoiseRadius)

	panel.part.Color = COLOR_REJECT
	panel.part.Material = Enum.Material.Neon
	WorldProps.setLabel(panel.part, `{panel.name}\nTRIPPED`, COLOR_REJECT)
	task.delay(0.9, refresh)
end

local function onPanel(player: Player, _target: Instance, id: string)
	local panel = panelById(tonumber(id) or -1)
	if not panel or not SessionService.isPlaying() or starting then
		return
	end
	PowerSystem.controlsUsed:Fire(player)

	if powerOn then
		notify(player, `{panel.name} is live.`, "info")
	elseif table.find(engaged, panel.id) then
		notify(player, `{panel.name} is already engaged.`, "info")
	elseif solution[#engaged + 1] == panel.id then
		table.insert(engaged, panel.id)
		log:info(`{player.Name} engaged {panel.name} ({#engaged}/{#panels})`)
		NetService.fireAll("Sound", "BreakerEngage", panel.part.Position)
		refresh()
		if #engaged == #panels then
			NetService.fireAll(
				"Notify",
				"All breakers engaged. Throw the main lever in the Power Room.",
				"info"
			)
		else
			notify(player, `{panel.name} engaged ({#engaged}/{#panels}).`, "info")
		end
	else
		reject(player, panel)
	end
end

local function onLever(player: Player, _target: Instance, _id: string)
	if not SessionService.isPlaying() or starting then
		return
	end
	PowerSystem.controlsUsed:Fire(player)

	if powerOn then
		notify(player, "Emergency power is already on.", "info")
	elseif #engaged < #panels then
		log:info(`{player.Name} tried the lever with {#engaged}/{#panels} breakers engaged`)
		notify(
			player,
			`The lever will not move yet: {#engaged} of {#panels} breakers engaged. `
				.. "The start-up order is on the maintenance memo in the Security Booth.",
			"warning"
		)
	else
		restore(player)
	end
end

local function collectPanels()
	for _, part in WorldService.getTagged(PANEL_TAG) do
		local id = part:GetAttribute("PanelId")
		if type(id) == "number" and not panelById(id) then
			local name = PowerConfig.BreakerNames[id] or `BREAKER {id}`
			table.insert(panels, { id = id, part = part, name = name })
			part:SetAttribute("Kind", "BreakerPanel")
			part:SetAttribute("Id", tostring(id))
			part:SetAttribute("ActionText", "Switch breaker")
			part:SetAttribute("ObjectText", name)
			part:AddTag(INTERACTABLE_TAG)
		end
	end
	table.sort(panels, function(a, b)
		return a.id < b.id
	end)

	-- A new order every session, so it cannot be memorised.
	local random = Random.new()
	for _, panel in panels do
		table.insert(solution, random:NextInteger(1, #solution + 1), panel.id)
	end
end

function PowerSystem.isOn(): boolean
	return powerOn
end

-- The start-up order as text lines for the maintenance memo.
function PowerSystem.orderSteps(): { string }
	local steps: { string } = {}
	for _, id in solution do
		local panel = panelById(id)
		local location = PowerConfig.BreakerLocations[id]
		local name = if panel then panel.name else `BREAKER {id}`
		table.insert(steps, if location then `{name}  ({location})` else name)
	end
	return steps
end

function PowerSystem.Start(_self: any)
	ReplicatedStorage:SetAttribute(GameState.POWER_ATTRIBUTE, false)
	publish()
	InteractionSystem.registerKind("BreakerPanel", onPanel)
	InteractionSystem.registerKind("MainLever", onLever)

	WorldService.onReady(function()
		WorldProps.ensure()
		lever = WorldProps.get("MainLever")
		collectPanels()
		if #panels == 0 then
			log:warn(`No {PANEL_TAG} parts in the map: the lever alone will restore power`)
		end
		if not lever then
			log:warn("Main lever was not placed: power cannot be restored")
		end

		-- The station starts on emergency power only.
		for _, circuit in PowerConfig.UnpoweredCircuits do
			FacilityLights.setCircuit(circuit, false)
		end
		refresh()
		log:info(`{#panels} breaker panel(s); start-up order generated`)
	end)
end

return PowerSystem
