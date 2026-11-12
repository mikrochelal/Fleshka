--!strict
-- The game's translations and the one place that turns text references into words.
-- English is the source language; Russian is fully supported. Templates live in
-- Shared/Locale/<language>.luau, keyed by stable localization keys.
--
-- Fallback order for a key: the requested language, then English, then the text as
-- written - a label is never blank, and every missing key is logged once as
-- [TLS:Localization].
--
-- The server uses this only for English fallback text on world objects; each client
-- renders in its own language (Controllers/LocalizationController).

local Logger = require(script.Parent.Logger)
local Text = require(script.Parent.Text)

export type Language = "en" | "ru"

local log = Logger.new("Localization")

local Localization = {}

Localization.SOURCE = "en" :: Language
Localization.LANGUAGES = table.freeze({ "en" :: Language, "ru" :: Language })
-- Shown in the language switch; never translated.
Localization.NAMES = table.freeze({ en = "ENGLISH", ru = "РУССКИЙ" } :: { [string]: string })

local tables: { [string]: { [string]: string } } = {}
local reported: { [string]: boolean } = {}

local function load(language: string): { [string]: string }
	local loaded = tables[language]
	if loaded then
		return loaded
	end
	local folder = script.Parent:FindFirstChild("Locale")
	local source = folder and folder:FindFirstChild(language)
	local result: { [string]: string } = {}
	if source and source:IsA("ModuleScript") then
		local ok, value = pcall(require :: any, source)
		if ok and type(value) == "table" then
			result = value
		else
			log:warn(`Could not load the "{language}" translations: {value}`)
		end
	else
		log:warn(`No translations found for "{language}"`)
	end
	tables[language] = result
	return result
end

local function report(key: string, language: string)
	local id = `{language}:{key}`
	if not reported[id] then
		reported[id] = true
		log:warn(`Missing key "{key}" ({language})`)
	end
end

-- "ru-ru", "ru_RU" or "ru" -> "ru"; anything unsupported -> the source language.
function Localization.languageOf(localeId: string?): Language
	local prefix = if localeId then string.lower(string.sub(localeId, 1, 2)) else ""
	for _, language in Localization.LANGUAGES do
		if language == prefix then
			return language
		end
	end
	return Localization.SOURCE
end

-- The template for a key, or nil when no language has it.
function Localization.lookup(language: string, key: string): string?
	local template = load(language)[key]
	if template == nil and language ~= Localization.SOURCE then
		template = load(Localization.SOURCE)[key]
		if template ~= nil then
			report(key, language)
		end
	end
	return template
end

-- Renders an encoded reference (see Shared/Text). Unknown keys are shown as written.
function Localization.render(language: string, encoded: string): string
	local text, missing = Text.render(encoded, function(key: string): string?
		return Localization.lookup(language, key)
	end)
	for _, key in missing do
		-- Plain sentences (typed in Studio) are not keys and are not worth a warning.
		if string.match(key, "^[%u%d_]+$") then
			report(key, language)
		end
	end
	return text
end

function Localization.t(language: string, key: string, params: Text.Params?): string
	return Localization.render(language, Text.ref(key, params))
end

return Localization
