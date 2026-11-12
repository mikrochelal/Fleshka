--!strict
-- Writes the game's translations as a Roblox localization table (CSV) to standard output:
--   luau scripts/export_localization.luau > localization/TheLastSignal_Localization.csv
-- scripts/check.sh runs this and fails when the committed file is out of date.
--
-- The game does not need this file to show Russian - it renders its own text from
-- Shared/Locale. The CSV exists so the same keys and translations can be uploaded to the
-- experience's cloud localization table (Creator Dashboard > Localization), where
-- translators can see them. See docs/LOCALIZATION.md.

local en = require("../src/ReplicatedStorage/Shared/Locale/en")
local ru = require("../src/ReplicatedStorage/Shared/Locale/ru")

local function field(value: string): string
	return '"' .. string.gsub(value, '"', '""') .. '"'
end

local keys: { string } = {}
for key in en do
	table.insert(keys, key)
end
table.sort(keys)

print("Key,Source,Context,Example,ru")
for _, key in keys do
	print(table.concat({ field(key), field(en[key]), "", "", field(ru[key] or "") }, ","))
end
