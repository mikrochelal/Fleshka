--!strict
-- Power restoration puzzle and facility lighting circuits.

return table.freeze({
	-- Display names of the breaker panels, by the `PanelId` attribute on the map object.
	BreakerNames = table.freeze({
		[1] = "SECURITY BUS",
		[2] = "GENERATOR FEED",
		[3] = "MAINTENANCE LOOP",
	} :: { [number]: string }),
	-- Where each panel is, for the start-up memo.
	BreakerLocations = table.freeze({
		[1] = "Security Booth",
		[2] = "Power Room",
		[3] = "Maintenance",
	} :: { [number]: string }),

	-- Light circuits (the `Circuit` attribute on TLS_Light fixtures) that are dead until
	-- power is restored. Circuit "A" (entrance) runs on its own backup and stays lit.
	UnpoweredCircuits = table.freeze({ "B", "C", "D" }),
	-- Red emergency lamps: lit while the power is out, switched off once it returns.
	EmergencyCircuit = "Emergency",

	-- Seconds the lights surge before settling when the lever is thrown.
	SurgeSeconds = 1.6,
	-- How far the start-up can be heard by THE COPY, in studs. A clean start-up is quiet
	-- enough not to draw it out (see CopyConfig.WakeNoiseRadius); a failed one is not.
	SuccessNoiseRadius = 60,
	FailureNoiseRadius = 140,
})
