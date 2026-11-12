--!strict
-- Text references. Player-facing text never travels as finished sentences: the server sends
-- a reference ("KEY" plus named values) through remotes and attributes, and every client
-- turns it into words in its own language (Shared/Localization). Pure logic, no Roblox
-- API, unit tested in tests/localization.luau.
--
--   Text.ref("NOTIFY_BREAKER_ENGAGED", { name = Text.key("BREAKER_NAME_1"), engaged = 2 })
--     -> "NOTIFY_BREAKER_ENGAGED?engaged=2&name=@BREAKER_NAME_1"
--   Text.lines({ ... })   several references shown as separate lines
--   Text.render(encoded, lookup)   the finished text; `lookup(key)` returns the template
--
-- Templates use {name} placeholders, the same syntax as Roblox localization tables, so the
-- exported CSV can be used with Translator:FormatByKey unchanged.

export type KeyRef = { key: string }
export type Value = string | number | KeyRef
-- Values are strings, numbers or Text.key(...) references (see Value).
export type Params = { [string]: any }
export type Lookup = (key: string) -> string?

local Text = {}

local function escape(value: string): string
	return (
		string.gsub(value, "[%%&=?@\n]", function(character: string): string
			return string.format("%%%02X", string.byte(character))
		end)
	)
end

local function unescape(value: string): string
	return (
		string.gsub(value, "%%(%x%x)", function(hex: string): string
			return string.char(tonumber(hex, 16) :: number)
		end)
	)
end

-- A value that is itself a localization key (translated on the client).
function Text.key(key: string): KeyRef
	return { key = key }
end

function Text.ref(key: string, params: Params?): string
	if not params then
		return key
	end
	local names: { string } = {}
	for name in params do
		table.insert(names, name)
	end
	if #names == 0 then
		return key
	end
	-- Sorted so the same reference always encodes to the same string.
	table.sort(names)
	local parts: { string } = {}
	for _, name in names do
		local value = params[name]
		local encoded = if type(value) == "table"
			then "@" .. escape(value.key)
			else escape(tostring(value))
		table.insert(parts, `{name}={encoded}`)
	end
	return `{key}?{table.concat(parts, "&")}`
end

function Text.lines(refs: { string }): string
	return table.concat(refs, "\n")
end

-- Replaces {name} placeholders. Unknown placeholders are left as written.
function Text.format(template: string, values: { [string]: string }): string
	return (
		string.gsub(template, "{([%w_]+)}", function(name: string): string
			return values[name] or `\{{name}\}`
		end)
	)
end

-- Splits one encoded line into its key and raw (still escaped) values.
function Text.parse(line: string): (string, { [string]: string })
	local mark = string.find(line, "?", 1, true)
	local values: { [string]: string } = {}
	if not mark then
		return line, values
	end
	for pair in string.gmatch(string.sub(line, mark + 1), "[^&]+") do
		local equals = string.find(pair, "=", 1, true)
		if equals then
			values[string.sub(pair, 1, equals - 1)] = string.sub(pair, equals + 1)
		end
	end
	return string.sub(line, 1, mark - 1), values
end

local function renderLine(line: string, lookup: Lookup, missing: { string }): string
	local key, raw = Text.parse(line)
	local template = lookup(key)
	if not template then
		-- Not a key: plain text (for example an attribute typed in Studio). Show it as is.
		table.insert(missing, key)
		return unescape(line)
	end
	local values: { [string]: string } = {}
	for name, value in raw do
		if string.sub(value, 1, 1) == "@" then
			local nested = unescape(string.sub(value, 2))
			local found = lookup(nested)
			if not found then
				table.insert(missing, nested)
			end
			values[name] = found or nested
		else
			values[name] = unescape(value)
		end
	end
	return Text.format(template, values)
end

-- The finished text, and the keys that had no template (shown untranslated).
function Text.render(encoded: string, lookup: Lookup): (string, { string })
	local missing: { string } = {}
	local lines: { string } = {}
	for line in string.gmatch(encoded .. "\n", "(.-)\n") do
		table.insert(lines, if line == "" then "" else renderLine(line, lookup, missing))
	end
	return table.concat(lines, "\n"), missing
end

-- Names of the {placeholders} in a template, sorted (used by the coverage test).
function Text.placeholders(template: string): { string }
	local seen: { [string]: boolean } = {}
	local names: { string } = {}
	for name in string.gmatch(template, "{([%w_]+)}") do
		if not seen[name] then
			seen[name] = true
			table.insert(names, name)
		end
	end
	table.sort(names)
	return names
end

return Text
