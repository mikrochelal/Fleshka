--!strict
-- Scoped logging so every Output line shows which module produced it.

local Logger = {}
Logger.__index = Logger

export type Logger = typeof(setmetatable({} :: { _prefix: string }, Logger))

function Logger.new(scope: string): Logger
	return setmetatable({ _prefix = `[TLS:{scope}]` }, Logger)
end

function Logger.info(self: Logger, message: string)
	print(`{self._prefix} {message}`)
end

function Logger.warn(self: Logger, message: string)
	warn(`{self._prefix} {message}`)
end

return Logger
