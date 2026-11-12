--!strict
-- Localization coverage: `luau tests/localization.luau`
-- Every key exists in every language with the same placeholders, every key the game's data
-- refers to exists, and text references survive the trip from server to client.

local Text = require("../src/ReplicatedStorage/Shared/Text")
local en = require("../src/ReplicatedStorage/Shared/Locale/en")
local ru = require("../src/ReplicatedStorage/Shared/Locale/ru")
local ObjectiveConfig = require("../src/ReplicatedStorage/Config/ObjectiveConfig")
local PowerConfig = require("../src/ReplicatedStorage/Config/PowerConfig")
local DoorConfig = require("../src/ReplicatedStorage/Config/DoorConfig")
local Documents = require("../src/ServerScriptService/Data/Documents")
local Transmissions = require("../src/ServerScriptService/Data/Transmissions")
local PropList = require("../src/ServerScriptService/Data/PropList")

local failures = 0
local total = 0

local function check(name: string, condition: boolean)
	total += 1
	if not condition then
		failures += 1
		print(`FAIL: {name}`)
	end
end

local function count(map: { [string]: string }): number
	local n = 0
	for _ in map do
		n += 1
	end
	return n
end

local function hasCyrillic(text: string): boolean
	-- Cyrillic letters are two bytes in UTF-8, starting with 0xD0 or 0xD1.
	return string.find(text, "[\208\209]") ~= nil
end

-- ---- Coverage: every key in both languages, same placeholders, nothing blank ----
-- Proper names and strings made only of values are the same in every language.
local SAME_IN_EVERY_LANGUAGE = {
	UI_LOADING_TITLE = true,
	UI_INTRO_TITLE = true,
	UI_ENDING_VERSION = true,
	UI_OPTIONAL_PROGRESS = true,
}
local untranslated: { string } = {}
for key, source in en do
	check(`{key}: is a valid key name`, string.match(key, "^[%u%d_]+$") ~= nil)
	check(`{key}: English text is not blank`, #source > 0)
	local translated = ru[key]
	check(`{key}: has a Russian translation`, translated ~= nil)
	if translated then
		check(`{key}: Russian text is not blank`, #translated > 0)
		check(
			`{key}: same placeholders in both languages`,
			table.concat(Text.placeholders(source), ",")
				== table.concat(Text.placeholders(translated), ",")
		)
		if not SAME_IN_EVERY_LANGUAGE[key] and not hasCyrillic(translated) then
			table.insert(untranslated, key)
		end
	end
end
for key in ru do
	check(`{key}: Russian key also exists in English`, en[key] ~= nil)
end
table.sort(untranslated)
check(`no untranslated strings (found: {table.concat(untranslated, ", ")})`, #untranslated == 0)

-- ---- Every key the game's data refers to exists ----
local function known(label: string, reference: string?)
	if reference == nil or reference == "" then
		return
	end
	for line in string.gmatch(reference .. "\n", "(.-)\n") do
		local key = Text.parse(line)
		check(`{label}: key "{key}" exists`, en[key] ~= nil)
	end
end

for _, objective in ObjectiveConfig.List do
	known(`objective {objective.id} title`, objective.title)
	check(`objective {objective.id} has a hint`, objective.hint ~= nil)
	known(`objective {objective.id} hint`, objective.hint)
end
for index, chapter in ObjectiveConfig.Chapters do
	known(`chapter {index}`, chapter.title)
end
for _, optional in ObjectiveConfig.Optional do
	known(`optional {optional.id}`, optional.title)
end
for id, document in Documents :: { [string]: any } do
	known(`document {id} title`, document.title)
	known(`document {id} date`, document.date)
	known(`document {id} body`, document.body)
end
for _, def in PropList :: { any } do
	known(`prop {def.id} action`, def.action)
	known(`prop {def.id} object`, def.object)
end
for id, key in PowerConfig.BreakerNames do
	known(`breaker {id} name`, key)
end
for id, key in PowerConfig.BreakerLocations do
	known(`breaker {id} location`, key)
end
for _, lock in DoorConfig.Locks do
	known(`door {lock.a}/{lock.b} reason`, lock.reason)
end
local sequences: { [string]: { any } } = {
	GeneratorReadout = Transmissions.GeneratorReadout,
	FirstContact = Transmissions.FirstContact,
	Trace = Transmissions.trace(7),
	Reply = Transmissions.Reply,
	Evacuation = Transmissions.Evacuation,
	FinalWords = Transmissions.FinalWords,
}
for name, steps in sequences do
	for index, step in steps do
		known(`{name} step {index} speaker`, step.speaker)
		known(`{name} step {index} text`, step.text)
	end
end

-- ---- Text references ----
local function lookup(language: { [string]: string }): Text.Lookup
	return function(key: string): string?
		return language[key] or en[key]
	end
end

do
	local ref = Text.ref("NOTIFY_BREAKER_ENGAGED", {
		name = Text.key("BREAKER_NAME_1"),
		engaged = 2,
		total = 3,
	})
	check("a reference is one line of plain text", string.find(ref, "\n", 1, true) == nil)
	check("encoding is deterministic", ref == Text.ref("NOTIFY_BREAKER_ENGAGED", {
		total = 3,
		engaged = 2,
		name = Text.key("BREAKER_NAME_1"),
	}))
	local english, missing = Text.render(ref, lookup(en))
	check("renders in English", english == "SECURITY BUS engaged (2/3).")
	check("nothing missing", #missing == 0)
	local russian = Text.render(ref, lookup(ru))
	check("renders in Russian", russian ~= english and hasCyrillic(russian))
	check("Russian keeps the numbers", string.find(russian, "2/3", 1, true) ~= nil)
end
do
	-- Player names may contain anything, including the characters used by the encoding.
	local nasty = "A&B=C?D@E%F\nG"
	local text = Text.render(Text.ref("NOTIFY_PLAYER_TAKEN", { name = nasty }), lookup(en))
	check("values with special characters survive", text == `{nasty} was taken.`)
	local spoofed = Text.render(Text.ref("NOTIFY_PLAYER_TAKEN", { name = "@UI_ON" }), lookup(en))
	check("a value cannot pose as a key", spoofed == "@UI_ON was taken.")
end
do
	local label =
		Text.lines({ "LABEL_RELAY", Text.ref("LABEL_RELAY_LOAD", { load = 30, target = 55 }) })
	check("multi-line labels", Text.render(label, lookup(en)) == "COMMS RELAY\nLOAD 30 / 55 kW")
end
do
	-- Fallbacks: never blank, never an error.
	local text, missing = Text.render("NO_SUCH_KEY", lookup(ru))
	check("an unknown key is shown as written", text == "NO_SUCH_KEY")
	check("and reported", missing[1] == "NO_SUCH_KEY")
	local plain = Text.render("Who is this?", lookup(ru))
	check("plain text typed in Studio is shown as written", plain == "Who is this?")
	local partial: { [string]: string } = { UI_ON = "ВКЛ" }
	check(
		"a key missing from one language falls back to English",
		Text.render("UI_OFF", lookup(partial)) == "OFF"
	)
	check(
		"a missing value leaves its placeholder visible",
		Text.render("NOTIFY_PLAYER_TAKEN", lookup(en)) == "{name} was taken."
	)
	check("an empty reference renders empty", Text.render("", lookup(en)) == "")
end
do
	-- Documents with session values.
	local memo = Text.render(
		Text.ref("DOCUMENT_STARTUP_MEMO_BODY", {
			name1 = Text.key("BREAKER_NAME_2"),
			location1 = Text.key("BREAKER_LOCATION_2"),
			name2 = Text.key("BREAKER_NAME_1"),
			location2 = Text.key("BREAKER_LOCATION_1"),
			name3 = Text.key("BREAKER_NAME_3"),
			location3 = Text.key("BREAKER_LOCATION_3"),
		}),
		lookup(ru)
	)
	check("the memo has no unfilled placeholders", string.find(memo, "{", 1, true) == nil)
	local first = string.find(memo, ru.BREAKER_NAME_2, 1, true)
	local second = string.find(memo, ru.BREAKER_NAME_1, 1, true)
	check("the memo lists the steps in order", first ~= nil and second ~= nil and first < second)
	for _, key in { "DOCUMENT_OPERATOR_NOTE_BODY", "DOCUMENT_PATIENT_CHART_BODY" } do
		local text = Text.render(Text.ref(key, { half = "47" }), lookup(ru))
		check(`{key} shows its half of the code`, string.find(text, "47", 1, true) ~= nil)
	end
	local file =
		Text.render(Text.ref("DOCUMENT_PERSONNEL_FILE_BODY", { code = "9031" }), lookup(ru))
	check("the personnel file shows the archive code", string.find(file, "9031", 1, true) ~= nil)
end

-- The story's fixed points.
check(
	"the incident log carries the last transmission",
	string.find(en.DOCUMENT_INCIDENT_LOG_BODY, "IT KNOWS WE ARE LISTENING", 1, true) ~= nil
)
check("the first transmission says it too", en.RADIO_FIRST_3 == "IT KNOWS WE ARE LISTENING.")
check(
	"the proper names are kept in Russian",
	string.find(ru.DOCUMENT_QUARANTINE_ORDER_BODY, "THE COPY", 1, true) ~= nil
)

print(`{count(en)} keys, {count(ru)} translated to Russian`)
print(`{total - failures}/{total} checks passed`)
if failures > 0 then
	error("localization tests failed")
end
