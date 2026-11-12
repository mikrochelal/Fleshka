--!strict
-- Readable documents. Any object with Kind = "Document" opens the document whose id is the
-- object's `Id`. The client receives only localization keys and renders the words in the
-- player's language; values generated for this session (codes, the breaker order) are
-- added here, when the document is opened, by the system that owns them.
--
-- Reading is tracked for the whole team: it feeds the optional "read the documents"
-- objective and nothing else. A document only matters to the main mission when the
-- mission script itself listens for it (`opened`).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Logger)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Text = require(ReplicatedStorage.Shared.Text)
local Documents = require(script.Parent.Parent.Data.Documents)
local PropList = require(script.Parent.Parent.Data.PropList) :: any
local AudioService = require(script.Parent.Parent.Services.AudioService)
local NetService = require(script.Parent.Parent.Services.NetService)
local ObjectiveService = require(script.Parent.Parent.Services.ObjectiveService)
local WorldService = require(script.Parent.Parent.Services.WorldService)
local InteractionSystem = require(script.Parent.InteractionSystem)
local WorldProps = require(script.Parent.WorldProps)

local OPTIONAL_ID = "ReadDocuments"

local log = Logger.new("Documents")

local DocumentSystem = {}

-- Fired with (player: Player, documentId: string) every time a document is opened.
DocumentSystem.opened = Signal.new()

local providers: { [string]: () -> Text.Params } = {}
local read: { [string]: boolean } = {}
local readCount = 0
local total = 0

-- Registers the session values for a document's text (called by the owning system).
function DocumentSystem.setParams(id: string, provider: () -> Text.Params)
	providers[id] = provider
end

function DocumentSystem.hasRead(id: string): boolean
	return read[id] == true
end

local function onRead(player: Player, _target: Instance, id: string)
	local document = Documents[id]
	if not document then
		log:warn(`Unknown document "{id}"`)
		return
	end
	local provider = providers[id]
	local params = if provider then provider() else nil
	NetService.fire(
		"ShowDocument",
		player,
		id,
		Text.ref(document.title),
		Text.ref(document.date),
		Text.ref(document.body, params)
	)
	AudioService.playFor(player, "DocumentOpen")

	if not read[id] then
		read[id] = true
		readCount += 1
		log:info(`{player.Name} read "{id}" ({readCount}/{total})`)
		if total > 0 then
			ObjectiveService.setOptional(OPTIONAL_ID, readCount, total)
		end
	end
	DocumentSystem.opened:Fire(player, id)
end

function DocumentSystem.Start(_self: any)
	InteractionSystem.registerKind("Document", onRead)

	WorldService.onReady(function()
		WorldProps.ensure()
		-- Only documents that exist on this map count toward the optional objective.
		for _, def in PropList do
			if def.kind == "Document" and WorldProps.get(def.id) then
				total += 1
			end
		end
	end)
end

return DocumentSystem
