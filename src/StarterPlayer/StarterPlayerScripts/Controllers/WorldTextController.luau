--!strict
-- Translates the text on world objects, which the server creates once for everybody:
-- interaction prompts (tag `TLS_LocalizedPrompt`, attributes `TLS_Action` / `TLS_Object`)
-- and floating labels (tag `TLS_LocalizedLabel`, attribute `TLS_Text`). The attributes
-- hold text references; this controller writes the words in the local player's language
-- on this client only. The server's English text stays as the fallback if this fails.

local CollectionService = game:GetService("CollectionService")

local LocalizationController = require(script.Parent:WaitForChild("LocalizationController"))

local PROMPT_TAG = "TLS_LocalizedPrompt"
local LABEL_TAG = "TLS_LocalizedLabel"
local ACTION_ATTRIBUTE = "TLS_Action"
local OBJECT_ATTRIBUTE = "TLS_Object"
local TEXT_ATTRIBUTE = "TLS_Text"

local WorldTextController = {}

local bound: { [Instance]: { RBXScriptConnection } } = {}

local function renderAttribute(instance: Instance, attribute: string): string?
	local value = instance:GetAttribute(attribute)
	if type(value) ~= "string" then
		return nil
	end
	return if value == "" then "" else LocalizationController.render(value)
end

local function applyPrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	local action = renderAttribute(prompt, ACTION_ATTRIBUTE)
	local object = renderAttribute(prompt, OBJECT_ATTRIBUTE)
	if action and prompt.ActionText ~= action then
		prompt.ActionText = action
	end
	if object and prompt.ObjectText ~= object then
		prompt.ObjectText = object
	end
end

local function applyLabel(gui: Instance)
	local label = gui:FindFirstChild("Text")
	local text = renderAttribute(gui, TEXT_ATTRIBUTE)
	if label and label:IsA("TextLabel") and text and label.Text ~= text then
		label.Text = text
	end
end

local function bind(instance: Instance, apply: (Instance) -> (), watched: { string })
	if bound[instance] then
		return
	end
	local connections: { RBXScriptConnection } = {}
	for _, attribute in watched do
		table.insert(
			connections,
			instance:GetAttributeChangedSignal(attribute):Connect(function()
				apply(instance)
			end)
		)
	end
	if instance:IsA("ProximityPrompt") then
		-- The server rewrites its English fallback whenever the wording changes; put the
		-- translation back afterwards. `apply` only writes when the text differs, so this
		-- cannot loop.
		for _, property in { "ActionText", "ObjectText" } do
			table.insert(
				connections,
				instance:GetPropertyChangedSignal(property):Connect(function()
					task.defer(apply, instance)
				end)
			)
		end
	end
	bound[instance] = connections
	apply(instance)
end

local function unbind(instance: Instance)
	local connections = bound[instance]
	if connections then
		bound[instance] = nil
		for _, connection in connections do
			connection:Disconnect()
		end
	end
end

local function watch(tag: string, apply: (Instance) -> (), watched: { string })
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
		bind(instance, apply, watched)
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(unbind)
	for _, instance in CollectionService:GetTagged(tag) do
		bind(instance, apply, watched)
	end
end

function WorldTextController.Start(_self: any)
	watch(PROMPT_TAG, applyPrompt, { ACTION_ATTRIBUTE, OBJECT_ATTRIBUTE })
	watch(LABEL_TAG, applyLabel, { TEXT_ATTRIBUTE })

	LocalizationController.changed:Connect(function()
		for instance in bound do
			if instance:IsA("ProximityPrompt") then
				applyPrompt(instance)
			else
				applyLabel(instance)
			end
		end
	end)
end

return WorldTextController
