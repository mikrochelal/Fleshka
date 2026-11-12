--!strict
-- Flashlight regression test: `luau tests/flashlight.luau`
-- The rules the server applies (Systems/FlashlightSystem/Battery). The light itself can
-- only be checked in Roblox Studio: see TESTING_CHECKLIST.md, "Flashlight regression".

local Battery = require("../src/ServerScriptService/Systems/FlashlightSystem/Battery")
local BatteryConfig = require("../src/ReplicatedStorage/Config/BatteryConfig")

-- The same numbers the game uses (Config/FlashlightConfig copies them).
local config: Battery.Config = BatteryConfig

local failures = 0
local total = 0

local function check(name: string, condition: boolean)
	total += 1
	if not condition then
		failures += 1
		print(`FAIL: {name}`)
	end
end

local function run(state: Battery.State, seconds: number): boolean
	local depleted = false
	for _ = 1, math.floor(seconds / 0.25 + 0.5) do
		depleted = Battery.tick(state, 0.25, config) or depleted
	end
	return depleted
end

-- Switching.
do
	local state = Battery.new(config)
	check("starts off with a full battery", not state.on and state.battery == config.BatteryMax)
	check("first press switches on", Battery.toggle(state) == "on" and state.on)
	check("second press switches off", Battery.toggle(state) == "off" and not state.on)
	for press = 1, 50 do
		Battery.toggle(state)
		check(`press {press}: state always matches the number of presses`, state.on == (press % 2 == 1))
	end
end

-- Draining.
do
	local state = Battery.new(config)
	Battery.toggle(state)
	check("no depletion in the first minute", not run(state, 60))
	check("battery drains while on", state.battery < config.BatteryMax)
	local lasted = 60
	while state.on and lasted < 3600 do
		run(state, 1)
		lasted += 1
	end
	check("a full battery lasts four to six minutes", lasted >= 240 and lasted <= 360)
	check("an empty battery switches the light off", not state.on and state.battery == 0)
	check("a dead flashlight refuses to switch on", Battery.toggle(state) == "dead" and not state.on)
	check("refusing does not change the state", not state.on)
end
do
	local state = Battery.new(config)
	Battery.toggle(state)
	state.battery = 0.05
	check("running out is reported exactly once", Battery.tick(state, 0.25, config))
	check("and not again", not Battery.tick(state, 0.25, config))
end

-- Recharging: a player can never be left permanently in the dark.
do
	local state = Battery.new(config)
	state.battery = 0
	run(state, 5)
	check("recovers while off", state.battery >= Battery.MIN_TO_START)
	check("can be switched on again after resting", Battery.toggle(state) == "on")
	Battery.toggle(state)
	run(state, 600)
	check("recharge stops at the cap", state.battery == config.RechargeCap)
	check("the cap is above the low-battery warning", config.RechargeCap > config.LowBattery)
end
do
	local state = Battery.new(config)
	state.battery = 60
	run(state, 60)
	check("a battery above the cap does not charge by itself", state.battery == 60)
end

-- Respawn: never stuck on.
do
	local state = Battery.new(config)
	Battery.toggle(state)
	run(state, 30)
	local charge = state.battery
	Battery.respawn(state)
	check("a new character starts with the light off", not state.on)
	check("respawning keeps the charge", state.battery == charge)
	check("and the light works straight away", Battery.toggle(state) == "on")
	Battery.respawn(state)
	Battery.respawn(state)
	check("respawning twice is harmless", not state.on and Battery.toggle(state) == "on")
end

-- Battery packs.
do
	local state = Battery.new(config)
	check("a full battery does not use a pack", not Battery.refill(state, config))
	state.battery = 40
	Battery.toggle(state)
	check("a pack refills", Battery.refill(state, config) and state.battery == config.BatteryMax)
	check("refilling leaves the light as it was", state.on)
	state.battery = 5
	check("low battery is reported", Battery.isLow(state, config))
end

print(`{total - failures}/{total} checks passed`)
if failures > 0 then
	error("flashlight tests failed")
end
