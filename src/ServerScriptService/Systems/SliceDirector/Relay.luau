--!strict
-- Chapter 2: the communications relay in Electrical Control.
--
--   Switchgear   the relay cabinet. Its fuse has been pulled; once the fuse (an Item found
--                in Storage 102) is fitted, the load puzzle starts.
--   Feeder_1..4  feeder switches. The closed ones must add up to the relay's demand
--                exactly (LoadBalance). An overload trips the feeder back open and is loud.
--
-- Solving it closes the relay: the receiver wakes and the sealed bulkheads open (both
-- happen in SliceDirector when the objective completes).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MissionConfig = require(ReplicatedStorage.Config.MissionConfig)
local Logger = require(ReplicatedStorage.Shared.Logger)
local Text = require(ReplicatedStorage.Shared.Text)
local AudioService = require(script.Parent.Parent.Parent.Services.AudioService)
local NoiseService = require(script.Parent.Parent.Parent.Services.NoiseService)
local ObjectiveService = require(script.Parent.Parent.Parent.Services.ObjectiveService)
local AudioEmitters = require(script.Parent.Parent.AudioEmitters)
local InteractionSystem = require(script.Parent.Parent.InteractionSystem)
local InventorySystem = require(script.Parent.Parent.InventorySystem)
local PowerSystem = require(script.Parent.Parent.PowerSystem)
local WorldProps = require(script.Parent.Parent.WorldProps)
local LoadBalance = require(script.Parent.LoadBalance)
local Mission = require(script.Parent.Mission)

local FUSE = "RelayFuse"
local OBJECTIVE = "RouteRelayPower"

local log = Logger.new("Slice")

local Relay = {}

local random = Random.new()
local puzzle = LoadBalance.generate(
	MissionConfig.LoadPuzzle.Values,
	MissionConfig.LoadPuzzle.Feeders,
	function(min: number, max: number): number
		return random:NextInteger(min, max)
	end
)
local fuseFitted = false
local online = false

local function loadParams(): Text.Params
	return { load = LoadBalance.load(puzzle), target = puzzle.target }
end

local function refresh()
	local powered = PowerSystem.isOn()
	local cabinet = WorldProps.get("Switchgear")
	if cabinet then
		local status, color
		if not powered then
			status, color = "LABEL_NO_POWER", Mission.COLOR_DEAD
		elseif online then
			status, color = "LABEL_RELAY_ONLINE", Mission.COLOR_OK
		elseif not fuseFitted then
			status, color = "LABEL_RELAY_NO_FUSE", Mission.COLOR_OFF
		else
			status, color = Text.ref("LABEL_RELAY_LOAD", loadParams()), Mission.COLOR_WAIT
		end
		WorldProps.setLook(cabinet, color, powered)
		WorldProps.setLabel(cabinet, Text.lines({ "LABEL_RELAY", status }), color)
	end

	for index, value in puzzle.values do
		local feeder = WorldProps.get(`Feeder_{index}`)
		if feeder then
			local closed = puzzle.closed[index]
			local color = if not powered
				then Mission.COLOR_DEAD
				elseif closed then Mission.COLOR_OK
				else Mission.COLOR_OFF
			WorldProps.setLook(feeder, color, powered and closed)
			WorldProps.setLabel(
				feeder,
				Text.lines({
					Text.ref("LABEL_FEEDER", { number = index, value = value }),
					if closed then "LABEL_FEEDER_CLOSED" else "LABEL_FEEDER_OPEN",
				}),
				color
			)
		end
	end

	if fuseFitted and not online then
		ObjectiveService.setProgress(OBJECTIVE, Text.ref("PROGRESS_RELAY_LOAD", loadParams()))
	end
end

local function closeRelay(player: Player)
	online = true
	log:info(`{player.Name} balanced the relay load ({puzzle.target} kW): relay closed`)
	local position = WorldProps.positionOf("Switchgear")
	AudioService.play("RelayClick", position)
	AudioService.play("MachineryStart", position)
	AudioEmitters.setActive("Switchgear", true)
	if position then
		NoiseService.make("Machinery", position)
	end
	Mission.notifyAll("NOTIFY_RELAY_ONLINE")
	refresh()
	Mission.reach(OBJECTIVE)
end

local function onSwitchgear(player: Player, target: Instance, _id: string)
	if not Mission.playing() then
		return
	end
	if not PowerSystem.isOn() then
		Mission.notify(player, "NOTIFY_SWITCHGEAR_DEAD")
	elseif online then
		Mission.notify(player, "NOTIFY_RELAY_ALREADY_ONLINE")
	elseif fuseFitted then
		Mission.notify(player, "NOTIFY_RELAY_LOAD", loadParams())
	elseif InventorySystem.has(FUSE) then
		fuseFitted = true
		log:info(`{player.Name} fitted the relay fuse; demand is {puzzle.target} kW`)
		AudioService.play("FuseInsert", WorldProps.positionOf("Switchgear"))
		target:SetAttribute("ActionText", "INTERACTION_INSPECT")
		Mission.notifyAll("NOTIFY_FUSE_FITTED", { target = puzzle.target })
		Mission.reach("FindRelayFuse")
		refresh()
	else
		log:info(`{player.Name} found the relay fuse missing`)
		Mission.notify(player, "NOTIFY_FUSE_MISSING", nil, "warning")
		Mission.reach("InspectSwitchgear")
	end
end

local function onFeeder(player: Player, target: Instance, id: string)
	local index = tonumber(string.match(id, "%d+$"))
	if not index or not Mission.playing() then
		return
	end
	local part = WorldProps.partOf(target)
	local position = if part then part.Position else nil

	if not PowerSystem.isOn() then
		Mission.notify(player, "NOTIFY_FEEDER_DEAD")
	elseif online then
		Mission.notify(player, "NOTIFY_RELAY_ALREADY_ONLINE")
	elseif not fuseFitted then
		AudioService.play("SwitchFlip", position)
		Mission.notify(player, "NOTIFY_FEEDER_NO_FUSE")
	else
		local result = LoadBalance.toggle(puzzle, index)
		AudioService.play("SwitchFlip", position)
		if position then
			NoiseService.make("SwitchFlip", position)
		end
		if result == "overload" then
			log:info(`{player.Name} overloaded the relay bus with feeder {index}`)
			AudioService.play("BreakerTrip", position)
			if position then
				NoiseService.make("Overload", position)
			end
			Mission.notify(player, "NOTIFY_FEEDER_OVERLOAD", { target = puzzle.target }, "warning")
		elseif result == "solved" then
			closeRelay(player)
			return
		end
		refresh()
	end
end

function Relay.start()
	InteractionSystem.registerKind("Switchgear", onSwitchgear)
	InteractionSystem.registerKind("Feeder", onFeeder)

	InventorySystem.collected:Connect(function(_player: Player, id: string)
		if id == FUSE then
			local cabinet = WorldProps.get("Switchgear")
			if cabinet and not fuseFitted then
				cabinet:SetAttribute("ActionText", "INTERACTION_FIT_FUSE")
			end
			Mission.mark("FindRelayFuse")
		end
	end)
	PowerSystem.restored:Connect(refresh)
	Mission.onActive(OBJECTIVE, refresh)
end

function Relay.ready()
	refresh()
end

return Relay
