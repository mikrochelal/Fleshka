--!strict
-- The player's language, and the client's one way to turn text references into words.
--
-- Language choice ("AUTO" unless the player uses the switch on the HUD):
--   1. the locale of the Translator Roblox gives for this player
--      (LocalizationService:GetTranslatorForPlayerAsync) - it follows the experience
--      language the player picked in the Roblox menu, and changes live;
--   2. if that is the source language, the Roblox app language (RobloxLocaleId), so a
--      Russian player still gets Russian when the experience's supported languages have
--      not been configured on the Creator Dashboard;
--   3. English.
-- The asynchronous call is wrapped in pcall; if it fails the game keeps working in the
-- language from step 2 and says so in the Output window.
--
-- The words come from Shared/Locale through Shared/Localization, so nothing depends on
-- the cloud localization table: a missing key falls back to English, never to a blank.

local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Localization = require(Shared:WaitForChild("Localization"))
local Logger = require(Shared:WaitForChild("Logger"))
local Signal = require(Shared:WaitForChild("Signal"))
local Text = require(Shared:WaitForChild("Text"))

local log = Logger.new("Localization")

local LocalizationController = {}

-- Fired with (language) whenever the language shown changes; every screen re-renders.
LocalizationController.changed = Signal.new()

local player = Players.LocalPlayer
local detected: Localization.Language = Localization.SOURCE
-- nil = AUTO.
local override: Localization.Language? = nil

local function robloxLanguage(): Localization.Language
	local ok, locale = pcall(function(): string
		return LocalizationService.RobloxLocaleId
	end)
	return Localization.languageOf(if ok then locale else nil)
end

function LocalizationController.language(): Localization.Language
	return override or detected
end

-- Translates a key with optional values.
function LocalizationController.t(key: string, params: Text.Params?): string
	return Localization.t(LocalizationController.language(), key, params)
end

-- Renders an encoded text reference received from the server.
function LocalizationController.render(encoded: string): string
	return Localization.render(LocalizationController.language(), encoded)
end

-- Text for the language switch.
function LocalizationController.switchLabel(): string
	local name = Localization.NAMES[LocalizationController.language()]
	return LocalizationController.t(
		if override then "UI_LANGUAGE" else "UI_LANGUAGE_AUTO",
		{ name = name }
	)
end

local function setDetected(language: Localization.Language, source: string)
	local before = LocalizationController.language()
	detected = language
	log:info(`Detected language: {language} ({source})`)
	if LocalizationController.language() ~= before then
		LocalizationController.changed:Fire(LocalizationController.language())
	end
end

-- AUTO -> each supported language in turn -> AUTO.
function LocalizationController.cycle()
	local before = LocalizationController.language()
	local languages = Localization.LANGUAGES
	local index = if override then table.find(languages, override) else 0
	override = languages[(index or 0) + 1]
	log:info(`Language switch: {override or "AUTO"} (showing {LocalizationController.language()})`)
	-- The switch label itself changes even when the language shown does not.
	LocalizationController.changed:Fire(LocalizationController.language())
	if before ~= LocalizationController.language() then
		log:info(`Language changed: {before} -> {LocalizationController.language()}`)
	end
end

function LocalizationController.Init(_self: any)
	-- Synchronous first guess, so the first frame is already in the right language.
	detected = robloxLanguage()
end

function LocalizationController.Start(_self: any)
	local ok, result = pcall(function(): Translator
		return LocalizationService:GetTranslatorForPlayerAsync(player)
	end)
	if not ok then
		log:warn(
			`GetTranslatorForPlayerAsync failed ({result}); using the Roblox app language "{detected}"`
		)
		return
	end
	local translator = result :: Translator

	local function update()
		local fromTranslator = Localization.languageOf(translator.LocaleId)
		if fromTranslator ~= Localization.SOURCE then
			setDetected(fromTranslator, `player locale {translator.LocaleId}`)
		else
			setDetected(
				robloxLanguage(),
				`player locale {translator.LocaleId}, Roblox app language used instead`
			)
		end
	end
	-- Players can change the experience language from the Roblox menu while playing.
	translator:GetPropertyChangedSignal("LocaleId"):Connect(update)
	update()
end

return LocalizationController
