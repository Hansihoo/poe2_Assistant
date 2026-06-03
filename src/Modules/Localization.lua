-- Path of Building
--
-- Module: Localization
-- Render-time text translation layer.
--

local type = type
local ipairs = ipairs
local pairs = pairs
local tostring = tostring
local t_insert = table.insert

local localization = {
	language = "en",
	enabled = false,
	installed = false,
	glyphsAvailable = true,
	glyphsChecked = false,
	force = false,
	exact = { },
	numeric = { },
	patterns = { },
}

local rawDrawString
local rawDrawStringWidth
local rawDrawStringCursorIndex

local function normalizeNumberValue(value)
	if type(value) ~= "string" then
		return value
	end
	local cleaned = value:gsub(",", ""):gsub("^%+", "")
	local numeric = tonumber(cleaned)
	if numeric then
		return tostring(numeric)
	end
	return cleaned
end

local function normalizeNumericLine(text)
	local values = { }
	local normalized = text:gsub("[%+%-]?%d[%d,]*%.?%d*", function(value)
		t_insert(values, value)
		return "#"
	end)
	return normalized, values
end

local function stripEscapes(text)
	return text:gsub("%^x%x%x%x%x%x%x", ""):gsub("%^%d", "")
end

local function splitLeadingEscapes(text)
	local prefix = { }
	local pos = 1
	while true do
		local rest = text:sub(pos)
		local escape = rest:match("^(%^x%x%x%x%x%x%x)") or rest:match("^(%^%d)")
		if not escape then
			break
		end
		t_insert(prefix, escape)
		pos = pos + #escape
	end
	return table.concat(prefix)
end

local function mergeLocale(locale)
	if type(locale) ~= "table" then
		return
	end
	if type(locale.exact) == "table" then
		for source, translated in pairs(locale.exact) do
			localization.exact[source] = translated
		end
	end
	if type(locale.numeric) == "table" then
		for source, entries in pairs(locale.numeric) do
			localization.numeric[source] = localization.numeric[source] or { }
			if type(entries) == "string" then
				t_insert(localization.numeric[source], { replace = entries })
			elseif type(entries) == "table" then
				if entries.replace then
					t_insert(localization.numeric[source], entries)
				else
					for _, entry in ipairs(entries) do
						if type(entry) == "table" and entry.replace then
							t_insert(localization.numeric[source], entry)
						end
					end
				end
			end
		end
	end
	if type(locale.patterns) == "table" then
		for _, rule in ipairs(locale.patterns) do
			if type(rule) == "table" then
				if rule.pattern and rule.replace then
					t_insert(localization.patterns, { rule.pattern, rule.replace })
				elseif rule[1] and rule[2] then
					t_insert(localization.patterns, { rule[1], rule[2] })
				end
			end
		end
	end
end

local function loadOptionalLocaleModule(moduleName, fileName)
	local scriptPath = GetScriptPath and GetScriptPath() or "."
	local localePath = scriptPath .. "/Modules/Localization/" .. fileName .. ".lua"
	local localeFile = io.open(localePath, "r")
	if localeFile then
		localeFile:close()
		local ok, locale = pcall(LoadModule, moduleName)
		if ok then
			mergeLocale(locale)
		end
	end
end

local function loadLocale(language)
	local ok, locale = pcall(LoadModule, "Modules/Localization/" .. language)
	if ok then
		mergeLocale(locale)
	end

	loadOptionalLocaleModule("Modules/Localization/" .. language .. "_official_generated", language .. "_official_generated")
	loadOptionalLocaleModule("Modules/Localization/" .. language .. "_user", language .. "_user")
end

local function translateNumeric(text)
	local normalized, values = normalizeNumericLine(text)
	local entries = localization.numeric[normalized]
	if not entries then
		return
	end
	for _, entry in ipairs(entries) do
		local literalsMatch = true
		if type(entry.literals) == "table" then
			for valueIndex, expected in pairs(entry.literals) do
				if normalizeNumberValue(values[valueIndex]) ~= expected then
					literalsMatch = false
					break
				end
			end
		end
		if literalsMatch then
			local replacements = { }
			if type(entry.values) == "table" then
				for _, valueIndex in ipairs(entry.values) do
					t_insert(replacements, values[valueIndex])
				end
			else
				for _, value in ipairs(values) do
					t_insert(replacements, value)
				end
			end
			local used = 0
			local translated = entry.replace:gsub("#", function()
				used = used + 1
				return replacements[used] or "#"
			end)
			if used == #replacements then
				return translated
			end
		end
	end
end

local function translateLine(text)
	if text == "" then
		return text
	end

	local translated = localization.exact[text]
	if translated then
		return translated
	end

	local stripped = stripEscapes(text)
	translated = localization.exact[stripped]
	if translated then
		return splitLeadingEscapes(text) .. translated
	end

	translated = translateNumeric(stripped)
	if translated then
		return splitLeadingEscapes(text) .. translated
	end

	for _, rule in ipairs(localization.patterns) do
		local replaced, count = stripped:gsub(rule[1], rule[2], 1)
		if count > 0 and replaced ~= stripped then
			return splitLeadingEscapes(text) .. replaced
		end
	end

	return text
end

local function containsNonAscii(text)
	return type(text) == "string" and text:find("[\128-\255]") ~= nil
end

local function ensureGlyphSupportChecked()
	if localization.glyphsChecked or not localization.enabled or localization.force or localization.language ~= "ko" then
		return
	end
	localization.glyphsChecked = true
	localization.glyphsAvailable = false
	if ConPrintf then
		ConPrintf("Korean localization disabled: current SimpleGraphic fonts do not contain Hangul glyphs.")
	end
end

function localization.Translate(text)
	if not localization.enabled or type(text) ~= "string" then
		return text
	end
	ensureGlyphSupportChecked()
	if text:find("\n", 1, true) then
		local translated = translateLine(text)
		if translated == text then
			translated = text:gsub("[^\n]+", translateLine)
		end
		if not localization.glyphsAvailable and containsNonAscii(translated) then
			return text
		end
		return translated
	end
	local translated = translateLine(text)
	if not localization.glyphsAvailable and containsNonAscii(translated) then
		return text
	end
	return translated
end

function localization.SetEnabled(enabled)
	localization.enabled = enabled and true or false
end

function localization.Install(options)
	options = options or { }
	localization.language = options.language or localization.language
	localization.enabled = options.enabled ~= false
	localization.force = options.force or os.getenv("POB_KO_FORCE") == "1"

	if not localization.localeLoaded then
		loadLocale(localization.language)
		localization.localeLoaded = true
	end

	if localization.installed then
		return localization
	end

	rawDrawString = DrawString
	rawDrawStringWidth = DrawStringWidth
	rawDrawStringCursorIndex = DrawStringCursorIndex

	function DrawString(left, top, align, height, font, text)
		return rawDrawString(left, top, align, height, font, localization.Translate(text))
	end

	function DrawStringWidth(height, font, text)
		return rawDrawStringWidth(height, font, localization.Translate(text))
	end

	function DrawStringCursorIndex(height, font, text, cursorX, cursorY)
		return rawDrawStringCursorIndex(height, font, text, cursorX, cursorY)
	end

	_G.TranslateString = localization.Translate
	_G.Localization = localization
	localization.installed = true
	return localization
end

return localization
