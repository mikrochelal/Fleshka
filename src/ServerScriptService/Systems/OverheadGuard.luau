--!strict
-- Ceilings and roof sections carry the tag `TLS_Overhead`. Map tools may hide them in
-- Studio to make interiors easier to edit; this system makes that an edit-time-only aid by
-- showing them again whenever the game runs. The saved place is not modified.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Logger = require(ReplicatedStorage.Shared.Logger)

local TAG = "TLS_Overhead"

local log = Logger.new("OverheadGuard")

local OverheadGuard = {}

function OverheadGuard.Start(_self: any)
	local restored = 0
	for _, instance in CollectionService:GetTagged(TAG) do
		if
			instance:IsA("BasePart")
			and instance:IsDescendantOf(Workspace)
			and instance.Transparency ~= 0
		then
			instance.Transparency = 0
			instance.CastShadow = true
			restored += 1
		end
	end
	if restored > 0 then
		log:info(`{restored} hidden ceiling part(s) shown for this play session`)
	end
end

return OverheadGuard
