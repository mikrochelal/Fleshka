--!strict
-- Turns world objects into interactive ones.
--
-- World contract: an object tagged `TLS_Interactable` (a BasePart, Attachment, or a Model
-- with a PrimaryPart, inside Workspace) with string attributes `Kind` and `Id`.
-- Optional attributes: `ActionText`, `ObjectText` (prompt wording) and `InteractEnabled`
-- (boolean, default true). Changing any of them at runtime updates the prompt.
--
-- The server adds a ProximityPrompt to each tagged object. Prompts give keyboard, touch and
-- gamepad input for free, but the trigger comes from the client, so every trigger is
-- re-validated here before the handler registered for the object's Kind runs.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local InteractionConfig = require(ReplicatedStorage.Config.InteractionConfig)
local Logger = require(ReplicatedStorage.Shared.Logger)
local PlayerService = require(script.Parent.Parent.Services.PlayerService)

export type Handler = (player: Player, target: Instance, id: string) -> ()

type Binding = { prompt: ProximityPrompt, connections: { RBXScriptConnection } }

local TAG = "TLS_Interactable"
local PROMPT_NAME = "TLS_Prompt"
local WATCHED_ATTRIBUTES = { "ActionText", "ObjectText", "InteractEnabled" }

local log = Logger.new("Interaction")

local InteractionSystem = {}

local handlers: { [string]: Handler } = {}
local lastUse: { [Player]: number } = setmetatable({} :: any, { __mode = "k" })
local bindings: { [Instance]: Binding } = {}

-- The instance that carries the prompt and defines the object's position.
local function anchorOf(target: Instance): Instance?
	if target:IsA("BasePart") or target:IsA("Attachment") then
		return target
	elseif target:IsA("Model") then
		return target.PrimaryPart
	end
	return nil
end

local function positionOf(target: Instance): Vector3?
	local anchor = anchorOf(target)
	if not anchor then
		return nil
	elseif anchor:IsA("BasePart") then
		return anchor.Position
	elseif anchor:IsA("Attachment") then
		return anchor.WorldPosition
	end
	return nil
end

local function isEnabled(target: Instance): boolean
	return target:GetAttribute("InteractEnabled") ~= false
end

local function hasLineOfSight(
	character: Model,
	from: Vector3,
	to: Vector3,
	target: Instance
): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local result = Workspace:Raycast(from, to - from, params)
	if not result then
		return true
	end
	local hit = result.Instance
	if hit == target or hit:IsDescendantOf(target) then
		return true
	end
	-- An Attachment has no geometry of its own; reaching the part it sits on is enough.
	return target:IsA("Attachment") and hit == target.Parent
end

-- Returns nil when the interaction is allowed, otherwise the reason it was refused.
local function validate(player: Player, target: Instance): string?
	if not PlayerService.getData(player) then
		return "unknown player"
	end
	local root = PlayerService.getAliveRoot(player)
	local character = player.Character
	if not root or not character then
		return "no living character"
	end
	if not target:IsDescendantOf(Workspace) or not CollectionService:HasTag(target, TAG) then
		return "target is not interactable"
	end
	if not isEnabled(target) then
		return "disabled"
	end

	local now = os.clock()
	local last = lastUse[player]
	if last and now - last < InteractionConfig.Cooldown then
		return "cooldown"
	end

	local position = positionOf(target)
	if not position then
		return "unsupported target"
	end
	local limit = InteractionConfig.MaxDistance + InteractionConfig.DistanceTolerance
	if (position - root.Position).Magnitude > limit then
		return "too far"
	end
	if
		InteractionConfig.RequireLineOfSight
		and not hasLineOfSight(character, root.Position, position, target)
	then
		return "no line of sight"
	end

	lastUse[player] = now
	return nil
end

local function onTriggered(player: Player, target: Instance)
	if validate(player, target) then
		return
	end

	local kind = target:GetAttribute("Kind")
	local id = target:GetAttribute("Id")
	if type(kind) ~= "string" or type(id) ~= "string" then
		return
	end
	local handler = handlers[kind]
	if not handler then
		log:warn(`No handler for Kind "{kind}" on {target:GetFullName()}`)
		return
	end

	local ok, err = pcall(handler :: any, player, target, id)
	if not ok then
		log:warn(`Handler for Kind "{kind}" failed: {err}`)
	end
end

local function refresh(target: Instance, prompt: ProximityPrompt)
	local actionText = target:GetAttribute("ActionText")
	local objectText = target:GetAttribute("ObjectText")
	prompt.ActionText = if type(actionText) == "string" then actionText else "Interact"
	prompt.ObjectText = if type(objectText) == "string" then objectText else ""
	prompt.Enabled = isEnabled(target)
end

local function bind(target: Instance)
	if bindings[target] or not target:IsDescendantOf(Workspace) then
		return
	end
	local anchor = anchorOf(target)
	if not anchor then
		log:warn(
			`{target:GetFullName()} is tagged {TAG} but is not a Part, Attachment or Model with a PrimaryPart`
		)
		return
	end
	if
		type(target:GetAttribute("Kind")) ~= "string"
		or type(target:GetAttribute("Id")) ~= "string"
	then
		log:warn(`{target:GetFullName()} needs string attributes "Kind" and "Id"`)
		return
	end

	-- Reuse a prompt left by a previous bind so objects never collect duplicates.
	local existing = anchor:FindFirstChild(PROMPT_NAME)
	local prompt: ProximityPrompt
	if existing and existing:IsA("ProximityPrompt") then
		prompt = existing
	else
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = PROMPT_NAME
	end
	prompt.MaxActivationDistance = InteractionConfig.MaxDistance
	prompt.RequiresLineOfSight = InteractionConfig.RequireLineOfSight
	refresh(target, prompt)
	prompt.Parent = anchor

	local connections = {
		prompt.Triggered:Connect(function(player)
			onTriggered(player, target)
		end),
	}
	for _, attribute in WATCHED_ATTRIBUTES do
		table.insert(
			connections,
			target:GetAttributeChangedSignal(attribute):Connect(function()
				refresh(target, prompt)
			end)
		)
	end
	bindings[target] = { prompt = prompt, connections = connections }
end

local function unbind(target: Instance)
	local binding = bindings[target]
	if not binding then
		return
	end
	bindings[target] = nil
	for _, connection in binding.connections do
		connection:Disconnect()
	end
	binding.prompt:Destroy()
end

-- Registers the server-side behaviour for every object whose `Kind` attribute equals `kind`.
function InteractionSystem.registerKind(kind: string, handler: Handler)
	assert(not handlers[kind], `Interaction kind "{kind}" is already registered`)
	handlers[kind] = handler
end

function InteractionSystem.Start(_self: any)
	CollectionService:GetInstanceAddedSignal(TAG):Connect(bind)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(unbind)
	local tagged = CollectionService:GetTagged(TAG)
	for _, target in tagged do
		bind(target)
	end
	log:info(`{#tagged} tagged object(s) found`)
end

return InteractionSystem
