--!strict
-- The flashlight's rules: switching, battery drain and recharge. Pure logic with no Roblox
-- API, so it is covered by the regression test tests/flashlight.luau; the system around it
-- (init.luau) only applies the result to lights and attributes.

export type Config = {
	BatteryMax: number,
	DrainPerSecond: number,
	RechargePerSecond: number,
	RechargeCap: number,
	LowBattery: number,
}

export type State = { battery: number, on: boolean }

-- "on" / "off": the new state. "dead": the battery is empty and the light stayed off.
export type ToggleResult = "on" | "off" | "dead"

local Battery = {}

-- Below this charge the light cannot be switched on.
Battery.MIN_TO_START = 1

function Battery.new(config: Config): State
	return { battery = config.BatteryMax, on = false }
end

function Battery.toggle(state: State): ToggleResult
	if state.on then
		state.on = false
		return "off"
	end
	if state.battery < Battery.MIN_TO_START then
		return "dead"
	end
	state.on = true
	return "on"
end

-- Advances time. Returns true when the battery ran out during this step (the light has
-- been switched off).
function Battery.tick(state: State, dt: number, config: Config): boolean
	if state.on then
		state.battery = math.max(0, state.battery - config.DrainPerSecond * dt)
		if state.battery <= 0 then
			state.on = false
			return true
		end
	elseif state.battery < config.RechargeCap then
		state.battery = math.min(config.RechargeCap, state.battery + config.RechargePerSecond * dt)
	end
	return false
end

-- A new character always starts with the light off; the charge is kept.
function Battery.respawn(state: State)
	state.on = false
end

-- Returns false when the battery was already (nearly) full and nothing was used.
function Battery.refill(state: State, config: Config): boolean
	if state.battery >= config.BatteryMax - 5 then
		return false
	end
	state.battery = config.BatteryMax
	return true
end

function Battery.isLow(state: State, config: Config): boolean
	return state.battery < config.LowBattery
end

return Battery
