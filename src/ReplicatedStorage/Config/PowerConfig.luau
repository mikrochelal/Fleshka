--!strict
-- Power restoration puzzle and facility lighting circuits.

return table.freeze({
	-- Localization keys of the breaker panels' names, by the `PanelId` attribute on the
	-- map object.
	BreakerNames = table.freeze({
		[1] = "BREAKER_NAME_1",
		[2] = "BREAKER_NAME_2",
		[3] = "BREAKER_NAME_3",
	} :: { [number]: string }),
	-- Where each panel is, for the start-up memo (localization keys).
	BreakerLocations = table.freeze({
		[1] = "BREAKER_LOCATION_1",
		[2] = "BREAKER_LOCATION_2",
		[3] = "BREAKER_LOCATION_3",
	} :: { [number]: string }),
	-- Number of steps the start-up memo's text has room for.
	MemoSteps = 3,

	-- Light circuits (the `Circuit` attribute on TLS_Light fixtures) that are dead until
	-- power is restored. Circuit "A" (entrance) runs on its own backup and stays lit.
	UnpoweredCircuits = table.freeze({ "B", "C", "D", "E", "F", "G", "H" }),
	-- Red emergency lamps: lit while the power is out, switched off once it returns.
	EmergencyCircuit = "Emergency",

	-- Seconds the lights surge before settling when the lever is thrown. The start-up
	-- sounds (relays, machinery) are timed across it.
	SurgeSeconds = 2.4,
})
