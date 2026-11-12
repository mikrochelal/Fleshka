--!strict
-- Readable documents. Any object with Kind = "Document" opens the document whose id is the
-- object's `Id`. The text is sent to the reading player only when they open it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Logger)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Documents = require(script.Parent.Parent.Data.Documents)
local NetService = require(script.Parent.Parent.Services.NetService)
local InteractionSystem = require(script.Parent.InteractionSystem)
local PowerSystem = require(script.Parent.PowerSystem)

local log = Logger.new("Documents")

local DocumentSystem = {}

-- Fired with (player: Player, documentId: string) every time a document is opened.
DocumentSystem.opened = Signal.new()

function DocumentSystem.Start(_self: any)
	InteractionSystem.registerKind("Document", function(player, _target, id)
		local document = Documents[id]
		if not document then
			log:warn(`Unknown document "{id}"`)
			return
		end
		local body = document.body
		local text = if type(body) == "function"
			then body({ breakerSteps = PowerSystem.orderSteps() })
			else body
		NetService.fire("ShowDocument", player, document.title, document.date, text)
		NetService.fire("Sound", player, "DocumentOpen")
		DocumentSystem.opened:Fire(player, id)
	end)
end

return DocumentSystem
