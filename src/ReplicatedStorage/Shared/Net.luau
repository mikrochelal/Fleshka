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

-- Client -> server events. Clients send intent only; the server decides the outcome.
Net.ClientEvents = table.freeze({
	-- Sent once when the client has finished loading and its controllers are running.
	ClientReady = { args = {}, burst = 2, perSecond = 0.2 },
	-- The player pressed (true) or released (false) the sprint control.
	SprintIntent = { args = { "boolean" }, burst = 8, perSecond = 4 },
	-- The player pressed the flashlight control.
	FlashlightToggle = { args = {}, burst = 4, perSecond = 2 },
} :: { [string]: Definition })

-- Server -> client events (presentation only; state lives in attributes).
--   Notify(text: string, kind: "info" | "warning" | "objective")
--   Subtitle(speaker: string, text: string, seconds: number)
--   ShowDocument(title: string, date: string, body: string)
--   Effect(name: "Interference" | "Blackout", seconds: number)
--   Sound(cue: string, position: Vector3?)   cue names are keys of Config/AudioConfig
Net.ServerEvents = table.freeze({ "Notify", "Subtitle", "ShowDocument", "Effect", "Sound" })

local function waitForRemote(name: string): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild(Net.FOLDER_NAME)
	return folder:WaitForChild(name) :: RemoteEvent
end

-- Client only: yields until the server has created the remote.
function Net.waitForClientEvent(name: string): RemoteEvent
	assert(Net.ClientEvents[name], `Unknown client event "{name}"`)
	return waitForRemote(name)
end

-- Client only: yields until the server has created the remote.
function Net.waitForServerEvent(name: string): RemoteEvent
	assert(table.find(Net.ServerEvents, name), `Unknown server event "{name}"`)
	return waitForRemote(name)
end

return Net
