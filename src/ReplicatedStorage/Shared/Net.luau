--!strict
-- The single list of remotes in the game. The server creates them (NetService); clients
-- only look them up. Adding a remote anywhere else is a bug.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type Definition = {
	-- typeof() name expected for each argument sent by the client, in order.
	args: { string },
	-- Token bucket applied per player: `burst` calls at once, refilled at `perSecond`.
	burst: number,
	perSecond: number,
}

local Net = {}

-- Created at runtime directly under ReplicatedStorage, outside the Rojo-managed folders.
Net.FOLDER_NAME = "TLS_Remotes"

-- Client -> server events.
Net.ClientEvents = table.freeze({
	-- Sent once when the client has finished loading and its controllers are running.
	ClientReady = { args = {}, burst = 2, perSecond = 0.2 },
} :: { [string]: Definition })

-- Client only: yields until the server has created the remote.
function Net.waitForClientEvent(name: string): RemoteEvent
	assert(Net.ClientEvents[name], `Unknown client event "{name}"`)
	local folder = ReplicatedStorage:WaitForChild(Net.FOLDER_NAME)
	return folder:WaitForChild(name) :: RemoteEvent
end

return Net
