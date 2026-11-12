--!strict
-- Minimal in-process event. Handlers run in their own threads, so a handler that errors
-- or yields cannot break the code that fired the signal.

local Signal = {}
Signal.__index = Signal

type Handler = (...any) -> ()

export type Connection = { Disconnect: (self: Connection) -> () }
export type Signal = typeof(setmetatable({} :: { _handlers: { Handler } }, Signal))

function Signal.new(): Signal
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal.Connect(self: Signal, handler: Handler): Connection
	table.insert(self._handlers, handler)
	local connection = {}
	function connection.Disconnect(_: Connection)
		local index = table.find(self._handlers, handler)
		if index then
			table.remove(self._handlers, index)
		end
	end
	return connection
end

function Signal.Fire(self: Signal, ...: any)
	-- Copy so handlers may disconnect while the signal is firing.
	for _, handler in table.clone(self._handlers) do
		task.spawn(handler, ...)
	end
end

return Signal
