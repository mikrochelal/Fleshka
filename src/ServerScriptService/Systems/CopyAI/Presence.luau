--!strict
-- THE COPY's presence in the world: the one model and the point it walks with, putting it
-- in and taking it out, the replicated state attributes, and the per-player "dread" value
-- that drives screen interference. There is exactly one model for the whole server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CopyConfig = require(ReplicatedStorage.Config.CopyConfig)
local GameState = require(ReplicatedStorage.Shared.GameState)
local WorldService = require(script.Parent.Parent.Parent.Services.WorldService)
local Body = require(script.Parent.Body)
local Navigator = require(script.Parent.Navigator)
local Senses = require(script.Parent.Senses)

local DREAD_ATTRIBUTE = GameState.PlayerAttribute.Dread
-- Dread never drops below this for the player it is chasing.
local CHASE_DREAD = 0.6

local Presence = {}

Presence.model = Body.build()
Presence.nav = Navigator.new(Vector3.zero)

local model: Model = Presence.model
local nav = Presence.nav
local ignore: { Instance } = { model }

function Presence.eye(): Vector3
	return nav.position + Vector3.new(0, Body.EYE_HEIGHT, 0)
end

-- Name of the room a floor position is in, for the log.
function Presence.roomAt(position: Vector3): string
	return WorldService.zoneAt(position + Vector3.new(0, 3, 0)) or "an unknown place"
end

-- Moves the model to where the navigator is.
function Presence.place()
	model:PivotTo(CFrame.lookAt(nav.position, nav.position + nav.facing))
end

-- Puts it into the world at `point`, facing `toward`.
function Presence.appearAt(point: Vector3, toward: Vector3?)
	Navigator.teleport(nav, point)
	if toward then
		Navigator.face(nav, toward)
	end
	Body.setTransparency(model, 0)
	Presence.place()
	model.Parent = WorldService.runtimeFolder()
end

function Presence.hide()
	model.Parent = nil
	Navigator.stop(nav)
end

-- 0 = solid, 1 = gone.
function Presence.fade(alpha: number)
	Body.setTransparency(model, math.clamp(alpha, 0, 1))
end

function Presence.walkTo(point: Vector3)
	Navigator.goTo(nav, Senses.ground(point), ignore)
end

-- Publishes the Brain state: for every client on ReplicatedStorage, and on the model for
-- the client code that attaches its looping sounds.
function Presence.publishState(state: string)
	ReplicatedStorage:SetAttribute(GameState.COPY_STATE_ATTRIBUTE, state)
	model:SetAttribute(Body.STATE_ATTRIBUTE, state)
end

local function setDread(player: Player, value: number)
	local rounded = math.floor(value * 10 + 0.5) / 10
	if player:GetAttribute(DREAD_ATTRIBUTE) ~= rounded then
		player:SetAttribute(DREAD_ATTRIBUTE, rounded)
	end
end

-- Dread rises as it gets closer; the player it is chasing always feels it.
function Presence.updateDread(present: boolean, chased: Player?)
	for _, player in Players:GetPlayers() do
		local dread = 0
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if present and root and root:IsA("BasePart") then
			local distance = (root.Position - nav.position).Magnitude
			dread = math.clamp(1 - distance / CopyConfig.DreadDistance, 0, 1)
			if player == chased then
				dread = math.max(dread, CHASE_DREAD)
			end
		end
		setDread(player, dread)
	end
end

return Presence
