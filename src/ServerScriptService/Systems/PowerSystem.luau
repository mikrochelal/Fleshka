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
-- lamps go out, the start-up is heard across the station, and `restored` fires so the rest
-- of the mission can continue.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PowerConfig = require(ReplicatedStorage.Config.PowerConfig)
local GameState = require(ReplicatedStorage.Shared.GameState)
local Logger = require(ReplicatedStorage.Shared.Logger)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Text = require(ReplicatedStorage.Shared.Text)
local AudioService = require(script.Parent.Parent.Services.AudioService)
local NetService = require(script.Parent.Parent.Services.NetService)
local NoiseService = require(script.Parent.Parent.Services.NoiseService)
local SessionService = require(script.Parent.Parent.Services.SessionService)
local WorldService = require(script.Parent.Parent.Services.WorldService)
local AudioEmitters = require(script.Parent.AudioEmitters)
local DocumentSystem = require(script.Parent.DocumentSystem)
local FacilityLights = require(script.Parent.FacilityLights)
local InteractionSystem = require(script.Parent.InteractionSystem)
local WorldProps = require(script.Parent.WorldProps)

-- `name` is a localization key.
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

local function notify(player: Player, key: string, params: Text.Params?, kind: string)
	NetService.fire("Notify", player, Text.ref(key, params), kind)
end

local function notifyAll(key: string, kind: string)
	NetService.fireAll("Notify", Text.ref(key), kind)
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

local function setPanelLook(panel: Panel, color: Color3, status: string)
	panel.part.Color = color
	panel.part.Material = if color == COLOR_OFF
		then Enum.Material.SmoothPlastic
		else Enum.Material.Neon
	WorldProps.setLabel(panel.part, Text.lines({ panel.name, status }), color)
end

local function refresh()
	for _, panel in panels do
		local position = table.find(engaged, panel.id)
		if powerOn then
			setPanelLook(panel, COLOR_LIVE, "LABEL_STATUS_LIVE")
		elseif position then
			setPanelLook(
				panel,
				COLOR_ENGAGED,
				Text.ref("LABEL_STATUS_ENGAGED", { position = position, total = #panels })
			)
		else
			setPanelLook(panel, COLOR_OFF, "LABEL_STATUS_OFF")
		end
	end

	local leverPart = lever and WorldProps.partOf(lever)
	if lever and leverPart then
		local ready = #engaged == #panels
		local color = if powerOn then COLOR_LIVE elseif ready then COLOR_ENGAGED else COLOR_OFF
		local status = if powerOn
			then "LABEL_LEVER_ON"
			elseif ready then "LABEL_LEVER_READY"
			else Text.ref("LABEL_LEVER_BREAKERS", { engaged = #engaged, total = #panels })
		leverPart.Color = color
		leverPart.Material = if color == COLOR_OFF
			then Enum.Material.SmoothPlastic
			else Enum.Material.Neon
		WorldProps.setLabel(lever, Text.lines({ "LABEL_LEVER", status }), color)
	end
	publish()
end

-- The start-up: a heavy switch, the supply winding up, relays closing one after another
-- while the lights surge, then machinery and a warning tone as the station comes alive.
local function restore(player: Player)
	starting = true
	log:info(`Lever thrown by {player.Name}: start-up sequence begins`)
	if lever then
		lever:SetAttribute("InteractEnabled", false)
	end

	local leverPart = lever and WorldProps.partOf(lever)
	local origin = if leverPart then leverPart.Position else nil
	local surge = PowerConfig.SurgeSeconds
	notifyAll("NOTIFY_POWER_STARTING", "info")
	AudioService.play("SwitchFlip", origin)
	AudioService.play("PowerOn", origin)
	for _, fraction in { 0.3, 0.55, 0.8 } do
		task.delay(surge * fraction, AudioService.play, "RelayClick", origin)
	end
	local circuits = table.clone(PowerConfig.UnpoweredCircuits)
	table.insert(circuits, PowerConfig.EmergencyCircuit)
	FacilityLights.flickerCircuits(circuits, surge)
	task.wait(surge)

	powerOn = true
	for _, circuit in PowerConfig.UnpoweredCircuits do
		FacilityLights.setCircuit(circuit, true)
	end
	FacilityLights.setCircuit(PowerConfig.EmergencyCircuit, false)
	-- Clients fade the powered ambience in when this attribute turns true.
	ReplicatedStorage:SetAttribute(GameState.POWER_ATTRIBUTE, true)
	refresh()

	log:info("Power state: OFF -> ON")
	notifyAll("NOTIFY_POWER_RESTORED", "info")
	AudioService.play("MachineryStart", origin)
	AudioService.play("WarningBeep", origin)
	AudioEmitters.setActive("PowerRoomTransformer", true)
	if origin then
		NoiseService.make("PowerStart", origin)
	end
	starting = false
	PowerSystem.restored:Fire(player)
end

-- The breaker refuses: it flashes, makes noise and stays out. Nothing else changes.
local function reject(player: Player, panel: Panel)
	log:info(
		`{player.Name} threw breaker {panel.id} out of turn ({#engaged}/{#panels} engaged); it tripped back out`
	)
	notify(player, "NOTIFY_BREAKER_REJECTED", { name = Text.key(panel.name) }, "warning")
	AudioService.play("BreakerTrip", panel.part.Position)
	NoiseService.make("BreakerTrip", panel.part.Position)

	setPanelLook(panel, COLOR_REJECT, "LABEL_STATUS_TRIPPED")
	task.delay(0.9, refresh)
end

local function onPanel(player: Player, _target: Instance, id: string)
	local panel = panelById(tonumber(id) or -1)
	if not panel or not SessionService.isPlaying() or starting then
		return
	end
	PowerSystem.controlsUsed:Fire(player)
	local name = Text.key(panel.name)

	if powerOn then
		notify(player, "NOTIFY_BREAKER_LIVE", { name = name }, "info")
	elseif table.find(engaged, panel.id) then
		notify(player, "NOTIFY_BREAKER_ALREADY", { name = name }, "info")
	elseif solution[#engaged + 1] == panel.id then
		table.insert(engaged, panel.id)
		log:info(`{player.Name} engaged breaker {panel.id} ({#engaged}/{#panels})`)
		AudioService.play("BreakerEngage", panel.part.Position)
		NoiseService.make("BreakerEngage", panel.part.Position)
		refresh()
		if #engaged == #panels then
			notifyAll("NOTIFY_BREAKERS_ALL", "info")
		else
			notify(
				player,
				"NOTIFY_BREAKER_ENGAGED",
				{ name = name, engaged = #engaged, total = #panels },
				"info"
			)
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
		notify(player, "NOTIFY_POWER_ALREADY_ON", nil, "info")
	elseif #engaged < #panels then
		log:info(`{player.Name} tried the lever with {#engaged}/{#panels} breakers engaged`)
		notify(player, "NOTIFY_LEVER_NOT_READY", { engaged = #engaged, total = #panels }, "warning")
	else
		restore(player)
	end
end

local function collectPanels()
	for _, part in WorldService.getTagged(PANEL_TAG) do
		local id = part:GetAttribute("PanelId")
		if type(id) == "number" and not panelById(id) then
			local name = PowerConfig.BreakerNames[id] or "BREAKER_NAME_UNKNOWN"
			table.insert(panels, { id = id, part = part, name = name })
			part:SetAttribute("Kind", "BreakerPanel")
			part:SetAttribute("Id", tostring(id))
			part:SetAttribute("ActionText", "INTERACTION_SWITCH_BREAKER")
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

-- The start-up order as values for the maintenance memo's text: name1/location1,
-- name2/location2... Steps the memo has room for but the map lacks are shown as a dash.
function PowerSystem.memoParams(): Text.Params
	local params: Text.Params = {}
	for step = 1, PowerConfig.MemoSteps do
		local id = solution[step]
		local panel = if id then panelById(id) else nil
		local location = if id then PowerConfig.BreakerLocations[id] else nil
		params[`name{step}`] = if panel then Text.key(panel.name) else "-"
		params[`location{step}`] = if location then Text.key(location) else "-"
	end
	return params
end

function PowerSystem.Start(_self: any)
	ReplicatedStorage:SetAttribute(GameState.POWER_ATTRIBUTE, false)
	publish()
	InteractionSystem.registerKind("BreakerPanel", onPanel)
	InteractionSystem.registerKind("MainLever", onLever)
	DocumentSystem.setParams("StartupMemo", PowerSystem.memoParams)

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
