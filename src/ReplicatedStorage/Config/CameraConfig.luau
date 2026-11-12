--!strict

return table.freeze({
	-- First person while the mission runs. Set to false for the default Roblox camera.
	FirstPerson = true,
	FieldOfView = 75,

	-- Subtle movement feedback: the view dips slightly with each step. Amplitudes are in
	-- studs and deliberately small; set Bob to false to switch it off.
	Bob = true,
	WalkBob = 0.05,
	RunBob = 0.09,
	-- Bob cycles per stud travelled (so faster movement means faster steps).
	BobFrequency = 0.55,
	-- Horizontal speed above which the run amplitude is used.
	RunSpeedThreshold = 15,
	-- How quickly the view settles (higher = snappier).
	BobSmoothing = 10,
})
