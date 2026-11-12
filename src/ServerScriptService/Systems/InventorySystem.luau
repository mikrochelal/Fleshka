--!strict
-- Things the team carries. Any object with Kind = "Item" can be picked up once; it then
-- belongs to the whole team (co-op: whoever reaches the place it is needed can use it),
-- and it is never lost again. Picking something up is silent to THE COPY.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Logger)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Text = require(ReplicatedStorage.Shared.Text)
local AudioService = require(script.Parent.Parent.Services.AudioService)
local NetService = require(script.Parent.Parent.Services.NetService)
local InteractionSystem = require(script.Parent.InteractionSystem)
local WorldProps = require(script.Parent.WorldProps)

local log = Logger.new("Inventory")

local InventorySystem = {}

-- Fired with (player: Player, itemId: string) when an item is picked up.
InventorySystem.collected = Signal.new()

local carried: { [string]: boolean } = {}

function InventorySystem.has(id: string): boolean
	return carried[id] == true
end

function InventorySystem.Start(_self: any)
	InteractionSystem.registerKind("Item", function(player, target, id)
		if carried[id] then
			return
		end
		carried[id] = true
		log:info(`{player.Name} picked up "{id}"`)

		local object = target:GetAttribute("ObjectText")
		AudioService.playFor(player, "ItemPickup")
		NetService.fireAll(
			"Notify",
			Text.ref("NOTIFY_ITEM_TAKEN", {
				name = player.DisplayName,
				item = Text.key(if type(object) == "string" then object else id),
			}),
			"info"
		)
		if WorldProps.get(id) == target then
			WorldProps.remove(id)
		else
			target:SetAttribute("InteractEnabled", false)
		end
		InventorySystem.collected:Fire(player, id)
	end)
end

return InventorySystem
