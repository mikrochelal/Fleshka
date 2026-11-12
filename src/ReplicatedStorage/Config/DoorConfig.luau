--!strict
-- Which doors are sealed, and what opens them. Every door of the map (tag `TLS_Door`) that
-- is not listed here is open from the start. A sealed door is solid until its key is
-- unlocked (Systems/DoorSystem.unlock): the key is the id of the objective whose
-- completion opens it, or a free-standing key for doors outside the main mission.
--
-- Doors are identified by the two rooms they join (attributes `RoomA` / `RoomB`), in
-- either order. tests/mission.luau proves that every objective can still be reached with
-- only the doors opened by the objectives before it.

export type Lock = {
	a: string,
	b: string,
	-- Objective id, or a free key such as "RestrictedArchive".
	key: string,
	-- Localization key of the explanation shown when a player tries the sealed door.
	reason: string,
	-- Heavy bulkheads get the big opening sound.
	heavy: boolean?,
}

local locks: { Lock } = {
	-- Shortcuts that run off the emergency supply.
	{
		a = "B_MonitorRoom",
		b = "B_ServiceTunnel",
		key = "RestorePower",
		reason = "DOOR_REASON_POWER",
	},
	{
		a = "B_ServiceTunnel",
		b = "B_NorthCorridor",
		key = "RestorePower",
		reason = "DOOR_REASON_POWER",
	},
	{
		a = "G_ServiceCorridor",
		b = "B_SouthCorridor",
		key = "RestorePower",
		reason = "DOOR_REASON_POWER",
	},
	-- Bulkheads held shut by the communications relay.
	{
		a = "B_NorthCorridor",
		b = "C_Airlock",
		key = "RouteRelayPower",
		reason = "DOOR_REASON_RELAY",
		heavy = true,
	},
	{
		a = "E_MedCorridor",
		b = "E_QuarantineCorridor",
		key = "RouteRelayPower",
		reason = "DOOR_REASON_RELAY",
		heavy = true,
	},
	-- Opened by the trace.
	{
		a = "C_SignalChamber",
		b = "C_Containment",
		key = "TraceSignal",
		reason = "DOOR_REASON_CONTAINMENT",
	},
	-- Code locks.
	{
		a = "D_Antechamber",
		b = "D_CommCenter",
		key = "EnterCommCenter",
		reason = "DOOR_REASON_CODE",
		heavy = true,
	},
	{
		a = "F_DocumentArchive",
		b = "F_RestrictedArchive",
		key = "RestrictedArchive",
		reason = "DOOR_REASON_CODE",
	},
	-- The freight wing.
	{
		a = "G_PipeTunnel",
		b = "H_CargoCorridor",
		key = "RestoreFreightCircuit",
		reason = "DOOR_REASON_FREIGHT",
		heavy = true,
	},
	{
		a = "H_Checkpoint",
		b = "H_ObservationChamber",
		key = "RestoreFreightCircuit",
		reason = "DOOR_REASON_FREIGHT",
	},
	{
		a = "H_CargoCorridor",
		b = "H_FreightElevator",
		key = "ActivateEvacuation",
		reason = "DOOR_REASON_EVACUATION",
		heavy = true,
	},
	{
		a = "A_AccessControl",
		b = "H_CargoCorridor",
		key = "ActivateEvacuation",
		reason = "DOOR_REASON_EVACUATION",
	},
}

local DoorConfig = {}

DoorConfig.Locks = table.freeze(locks)

-- The lock on the door between two rooms, or nil when that door is never sealed.
function DoorConfig.lockBetween(roomA: string, roomB: string): Lock?
	for _, lock in locks do
		if (lock.a == roomA and lock.b == roomB) or (lock.a == roomB and lock.b == roomA) then
			return lock
		end
	end
	return nil
end

return table.freeze(DoorConfig)
