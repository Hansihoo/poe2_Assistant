-- Path of Building
--
-- Module: Stat Weight Report
-- Imports the cached character and measures the marginal DPS/EHP gain from
-- common item/passive modifiers by appending temporary custom modifiers.

local dkjson = require("dkjson")

local t_insert = table.insert
local s_format = string.format

local StatWeightReport = { }

local statSpecs = {
	{ id = "rare_unique_hit_damage_pct", group = "dps", label = "Rare/Unique Hit Damage", labelKo = "희귀/고유 적 명중 피해", line = "#% increased Damage with Hits against Rare and Unique Enemies", unit = 1, unitLabel = "1%" },
	{ id = "quarterstaff_damage_pct", group = "dps", label = "Quarterstaff Damage", labelKo = "육척봉 피해", line = "#% increased Damage with Quarterstaves", unit = 1, unitLabel = "1%" },
	{ id = "attack_damage_pct", group = "dps", label = "Attack Damage", labelKo = "공격 피해", line = "#% increased Attack Damage", unit = 1, unitLabel = "1%" },
	{ id = "melee_damage_pct", group = "dps", label = "Melee Damage", labelKo = "근접 피해", line = "#% increased Melee Damage", unit = 1, unitLabel = "1%" },
	{ id = "physical_damage_pct", group = "dps", label = "Physical Damage", labelKo = "물리 피해", line = "#% increased Physical Damage", unit = 1, unitLabel = "1%" },
	{ id = "attack_speed_pct", group = "dps", label = "Attack Speed", labelKo = "공격 속도", line = "#% increased Attack Speed", unit = 1, unitLabel = "1%" },
	{ id = "quarterstaff_attack_speed_pct", group = "dps", label = "Quarterstaff Attack Speed", labelKo = "육척봉 공격 속도", line = "#% increased Attack Speed with Quarterstaves", unit = 1, unitLabel = "1%" },
	{ id = "attack_crit_chance_pct", group = "dps", label = "Attack Critical Hit Chance", labelKo = "공격 치명타 확률", line = "#% increased Critical Hit Chance for Attacks", unit = 1, unitLabel = "1%" },
	{ id = "attack_crit_damage_bonus_pct", group = "dps", label = "Attack Critical Damage Bonus", labelKo = "공격 치명타 피해 보너스", line = "#% increased Critical Damage Bonus for Attack Damage", unit = 1, unitLabel = "1%" },
	{ id = "crit_damage_bonus_pct", group = "dps", label = "Critical Damage Bonus", labelKo = "치명타 피해 보너스", line = "#% increased Critical Damage Bonus", unit = 1, unitLabel = "1%" },
	{ id = "elemental_pen_pct", group = "dps", label = "Elemental Penetration", labelKo = "원소 관통", line = "Damage Penetrates #% Elemental Resistance", unit = 1, unitLabel = "1%" },
	{ id = "elemental_damage_pct", group = "dps", label = "Elemental Damage", labelKo = "원소 피해", line = "#% increased Elemental Damage", unit = 1, unitLabel = "1%" },
	{ id = "lightning_damage_pct", group = "dps", label = "Lightning Damage", labelKo = "번개 피해", line = "#% increased Lightning Damage", unit = 1, unitLabel = "1%" },
	{ id = "cold_damage_pct", group = "dps", label = "Cold Damage", labelKo = "냉기 피해", line = "#% increased Cold Damage", unit = 1, unitLabel = "1%" },
	{ id = "accuracy_flat", group = "dps", label = "Accuracy Rating", labelKo = "정확도", line = "+# to Accuracy Rating", unit = 10, unitLabel = "+10" },

	{ id = "life_pct", group = "ehp", label = "Maximum Life", labelKo = "최대 생명력", line = "#% increased maximum Life", unit = 1, unitLabel = "1%" },
	{ id = "life_flat", group = "ehp", label = "Flat Life", labelKo = "생명력", line = "+# to maximum Life", unit = 10, unitLabel = "+10" },
	{ id = "energy_shield_pct", group = "ehp", label = "Maximum Energy Shield", labelKo = "최대 에너지 보호막", line = "#% increased maximum Energy Shield", unit = 1, unitLabel = "1%" },
	{ id = "energy_shield_flat", group = "ehp", label = "Flat Energy Shield", labelKo = "에너지 보호막", line = "+# to maximum Energy Shield", unit = 10, unitLabel = "+10" },
	{ id = "evasion_pct", group = "ehp", label = "Evasion Rating", labelKo = "회피", line = "#% increased Evasion Rating", unit = 1, unitLabel = "1%" },
	{ id = "armour_pct", group = "ehp", label = "Armour", labelKo = "방어도", line = "#% increased Armour", unit = 1, unitLabel = "1%" },
	{ id = "armour_evasion_pct", group = "ehp", label = "Armour and Evasion", labelKo = "방어도 및 회피", line = "#% increased Armour and Evasion Rating", unit = 1, unitLabel = "1%" },
	{ id = "fire_res_pct", group = "ehp", label = "Fire Resistance", labelKo = "화염 저항", line = "+#% to Fire Resistance", unit = 1, unitLabel = "1%" },
	{ id = "cold_res_pct", group = "ehp", label = "Cold Resistance", labelKo = "냉기 저항", line = "+#% to Cold Resistance", unit = 1, unitLabel = "1%" },
	{ id = "lightning_res_pct", group = "ehp", label = "Lightning Resistance", labelKo = "번개 저항", line = "+#% to Lightning Resistance", unit = 1, unitLabel = "1%" },
	{ id = "chaos_res_pct", group = "ehp", label = "Chaos Resistance", labelKo = "카오스 저항", line = "+#% to Chaos Resistance", unit = 1, unitLabel = "1%" },
	{ id = "all_ele_res_pct", group = "ehp", label = "All Elemental Resistances", labelKo = "모든 원소 저항", line = "+#% to all Elemental Resistances", unit = 1, unitLabel = "1%" },
	{ id = "all_max_ele_res_pct", group = "ehp", label = "All Maximum Elemental Resistances", labelKo = "모든 최대 원소 저항", line = "+#% to all Maximum Elemental Resistances", unit = 1, unitLabel = "1%" },
	{ id = "life_regen_pct", group = "ehp", label = "Life Regeneration Rate", labelKo = "생명력 재생 속도", line = "#% increased Life Regeneration rate", unit = 1, unitLabel = "1%" },
	{ id = "stun_threshold_pct", group = "ehp", label = "Stun Threshold", labelKo = "기절 한계치", line = "#% increased Stun Threshold", unit = 1, unitLabel = "1%" },
	{ id = "strength_flat", group = "ehp", label = "Strength", labelKo = "힘", line = "+# to Strength", unit = 5, unitLabel = "+5" },
	{ id = "dexterity_flat", group = "dps", label = "Dexterity", labelKo = "민첩", line = "+# to Dexterity", unit = 5, unitLabel = "+5" },
	{ id = "intelligence_flat", group = "ehp", label = "Intelligence", labelKo = "지능", line = "+# to Intelligence", unit = 5, unitLabel = "+5" },
}

local function readFile(path)
	local f = io.open(path, "rb")
	if not f then
		return nil
	end
	local body = f:read("*a")
	f:close()
	return body
end

local function writeFile(path, body)
	local f, err = io.open(path, "wb")
	if not f then
		error(err or ("failed to open " .. path))
	end
	f:write(body)
	f:close()
end

local function fileExists(path)
	local f = io.open(path, "rb")
	if f then
		f:close()
		return true
	end
	return false
end

local function firstExistingPath(paths)
	for _, path in ipairs(paths) do
		if path and path ~= "" and fileExists(path) then
			return path
		end
	end
end

local function pathJoin(base, leaf)
	if not base or base == "" then
		return leaf
	end
	if base:match("[/\\]$") then
		return base .. leaf
	end
	return base .. "/" .. leaf
end

local function trim(text)
	return (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function stripEscapes(text)
	return (text or ""):gsub("%^%d", ""):gsub("%^x%x%x%x%x%x%x", "")
end

local function makeLine(spec)
	return (spec.line:gsub("#", tostring(spec.unit)))
end

local function percentGain(baseValue, newValue)
	baseValue = tonumber(baseValue) or 0
	newValue = tonumber(newValue) or 0
	if baseValue == 0 then
		return nil
	end
	return (newValue - baseValue) / baseValue * 100
end

local function numberOrZero(value)
	return tonumber(value) or 0
end

local function snapshotOutput(output)
	output = output or { }
	return {
		CombinedDPS = numberOrZero(output.CombinedDPS),
		FullDPS = numberOrZero(output.FullDPS),
		TotalDPS = numberOrZero(output.TotalDPS),
		TotalDotDPS = numberOrZero(output.TotalDotDPS),
		TotalEHP = numberOrZero(output.TotalEHP),
		Life = numberOrZero(output.Life),
		LifeUnreserved = numberOrZero(output.LifeUnreserved),
		EnergyShield = numberOrZero(output.EnergyShield),
		Armour = numberOrZero(output.Armour),
		Evasion = numberOrZero(output.Evasion),
		FireResist = numberOrZero(output.FireResist),
		ColdResist = numberOrZero(output.ColdResist),
		LightningResist = numberOrZero(output.LightningResist),
		ChaosResist = numberOrZero(output.ChaosResist),
	}
end

local function selectMainSkill(build, requestedName)
	if requestedName and requestedName ~= "" then
		local needle = requestedName:lower()
		for index, group in ipairs(build.skillsTab.socketGroupList) do
			for _, gem in ipairs(group.gemList or {}) do
				local effect = gem.grantedEffect
				local name = effect and effect.name or gem.nameSpec or group.label or ""
				if name:lower():find(needle, 1, true) then
					build.mainSocketGroup = index
					return name
				end
			end
		end
	end
	if not build.mainSocketGroup and build.importTab.GuessMainSocketGroup then
		build.mainSocketGroup = build.importTab:GuessMainSocketGroup()
	end
	local mainGroup = build.skillsTab.socketGroupList[build.mainSocketGroup or 1]
	if mainGroup then
		for _, gem in ipairs(mainGroup.gemList or {}) do
			if gem.grantedEffect and not gem.grantedEffect.support then
				return gem.grantedEffect.name
			end
		end
		return mainGroup.label or mainGroup.displayLabel
	end
	return nil
end

local function skillList(build)
	local out = { }
	for _, group in ipairs(build.skillsTab.socketGroupList or {}) do
		for _, gem in ipairs(group.gemList or {}) do
			if gem.grantedEffect and not gem.grantedEffect.support then
				t_insert(out, gem.grantedEffect.name)
				break
			end
		end
	end
	return out
end

local function apiSkillList(charData)
	local out = { }
	for _, skill in ipairs(charData.skills or {}) do
		if skill.typeLine and not skill.support then
			t_insert(out, skill.typeLine)
		end
	end
	return out
end

local function defaultCalibrationPath()
	local userProfile = os.getenv("USERPROFILE")
	if not userProfile or userProfile == "" then
		return nil
	end
	return pathJoin(userProfile:gsub("\\", "/"), "Documents/0_MD_Data/poe/poe2/build-calibrations/martial-hollow-whirling-jewel-2026-06-01.json")
end

local function loadCalibration(path)
	local calibrationPath = firstExistingPath({
		path,
		defaultCalibrationPath(),
	})
	if not calibrationPath then
		return nil
	end
	local body = readFile(calibrationPath)
	if not body then
		return nil
	end
	local decoded = dkjson.decode(body)
	if not decoded then
		return nil
	end
	decoded.path = calibrationPath
	return decoded
end

local function buildCalibrationWeightMap(calibration)
	local map = { }
	if not calibration then
		return map
	end
	for _, weight in ipairs(calibration.weights or {}) do
		if weight.en then
			map[weight.en] = weight
		end
		if weight.en == "Accuracy" then
			map["+# to Accuracy Rating"] = weight
		end
	end
	return map
end

local function calculate(build)
	build.configTab:BuildModList()
	build.calcsTab:BuildOutput()
	return snapshotOutput(build.calcsTab.mainOutput)
end

local function appendCustomMod(existing, line)
	existing = trim(existing)
	if existing == "" then
		return line
	end
	return existing .. "\n" .. line
end

local function isParsed(line)
	local mods, extra = modLib.parseMod(line)
	return mods and not extra and #mods > 0
end

local function compareByKeyDesc(key)
	return function(a, b)
		return (a[key] or -math.huge) > (b[key] or -math.huge)
	end
end

local function fmtNum(value, digits)
	if value == nil then
		return "-"
	end
	digits = digits or 4
	return s_format("%." .. digits .. "f", value)
end

local function fmtWhole(value)
	return s_format("%.0f", tonumber(value) or 0)
end

local function markdownTable(results, key, limit)
	table.sort(results, compareByKeyDesc(key))
	local lines = {
		"| 순위 | 옵션 | 단위 | DPS %/단위 | EHP %/단위 | 출처 | 적용 모드 |",
		"| ---: | --- | ---: | ---: | ---: | --- | --- |",
	}
	local count = 0
	for _, row in ipairs(results) do
		if row.parsed and not row.error and (row[key] or 0) > 0 then
			count = count + 1
			t_insert(lines, s_format("| %d | %s | %s | %s | %s | %s | `%s` |",
				count,
				row.labelKo or row.label,
				row.unitLabel,
				fmtNum(row.dpsPercentPerUnit, 4),
				fmtNum(row.ehpPercentPerUnit, 4),
				row.dpsSource or row.ehpSource or "PoB",
				row.line:gsub("|", "\\|")
			))
			if limit and count >= limit then
				break
			end
		end
	end
	if count == 0 then
		t_insert(lines, "| - | 유효한 상승 옵션 없음 | - | - | - | - | - |")
	end
	return table.concat(lines, "\n")
end

local function unsupportedTable(results)
	local lines = {
		"| 옵션 | 이유 | 적용 모드 |",
		"| --- | --- | --- |",
	}
	local count = 0
	for _, row in ipairs(results) do
		if not row.parsed or row.error then
			count = count + 1
			t_insert(lines, s_format("| %s | %s | `%s` |",
				row.labelKo or row.label,
				row.error or "PoB 커스텀 모드 파서가 인식하지 못함",
				row.line:gsub("|", "\\|")
			))
		end
	end
	if count == 0 then
		t_insert(lines, "| - | 없음 | - |")
	end
	return table.concat(lines, "\n")
end

local function buildMarkdown(report)
	local lines = { }
	t_insert(lines, "# PoB2 현재 캐릭터 스탯 가중치")
	t_insert(lines, "")
	t_insert(lines, s_format("- 캐릭터: `%s` / %s Lv.%s", report.character.name or "Unknown", report.character.class or "?", tostring(report.character.level or "?")))
	t_insert(lines, s_format("- 리그: `%s`", report.character.league or "?"))
	t_insert(lines, s_format("- 선택 스킬: `%s`", report.mainSkill or "Unknown"))
	t_insert(lines, s_format("- DPS 기준: `%s`, EHP 기준: `TotalEHP`", report.dpsMetric))
	t_insert(lines, s_format("- DPS 출처: `%s`", report.dpsSource or "PoB direct"))
	if report.calibration then
		t_insert(lines, s_format("- 보정 파일: `%s` (%s)", report.calibration.name or "calibration", report.calibration.last_updated or "?"))
	end
	t_insert(lines, s_format("- 기본값: DPS `%s`, EHP `%s`, 생명력 `%s`, ES `%s`, 방어도 `%s`, 회피 `%s`",
		fmtWhole(report.baseline[report.dpsMetric]),
		fmtWhole(report.baseline.TotalEHP),
		fmtWhole(report.baseline.LifeUnreserved > 0 and report.baseline.LifeUnreserved or report.baseline.Life),
		fmtWhole(report.baseline.EnergyShield),
		fmtWhole(report.baseline.Armour),
		fmtWhole(report.baseline.Evasion)
	))
	t_insert(lines, "")
	t_insert(lines, "## DPS 상승 효율")
	t_insert(lines, "")
	t_insert(lines, markdownTable(report.results, "dpsPercentPerUnit", 20))
	t_insert(lines, "")
	t_insert(lines, "## EHP 상승 효율")
	t_insert(lines, "")
	t_insert(lines, markdownTable(report.results, "ehpPercentPerUnit", 20))
	t_insert(lines, "")
	t_insert(lines, "## 인식 실패/무효 옵션")
	t_insert(lines, "")
	t_insert(lines, unsupportedTable(report.results))
	t_insert(lines, "")
	t_insert(lines, "## 해석 메모")
	t_insert(lines, "")
	t_insert(lines, "- 표의 값은 해당 옵션을 현재 빌드에 임시 커스텀 모드로 추가했을 때의 상대 증가율입니다.")
	t_insert(lines, "- `% 증가` 옵션은 1%당 값이고, 생명력/정확도/능력치처럼 정수 옵션은 표의 단위당 값입니다.")
	t_insert(lines, "- 저항이 이미 상한이면 일반 저항의 EHP 값은 0에 가깝게 나올 수 있습니다.")
	t_insert(lines, "- 현재 PoB2가 특정 스킬 메커니즘을 완전히 지원하지 않으면 해당 스킬의 DPS 가중치도 그 한계를 그대로 따릅니다.")
	t_insert(lines, "")
	t_insert(lines, "## 스킬 목록")
	t_insert(lines, "")
	for _, skill in ipairs(report.skills) do
		t_insert(lines, "- " .. skill)
	end
	t_insert(lines, "")
	return table.concat(lines, "\n")
end

function StatWeightReport.Generate(options)
	options = options or { }
	local inputPath = firstExistingPath({
		options.inputPath,
		"poe_api_response.json",
		"src/poe_api_response.json",
		pathJoin(GetScriptPath and GetScriptPath() or "", "poe_api_response.json"),
	})
	if not inputPath then
		error("Could not find poe_api_response.json; set POB_STAT_INPUT to the cached character JSON path.")
	end

	local body = readFile(inputPath)
	local decoded, _, err = dkjson.decode(body)
	if not decoded then
		error("Could not parse character JSON: " .. tostring(err))
	end
	local charData = decoded.character or decoded
	if not (charData.equipment and charData.passives) then
		error("Character JSON must contain equipment and passives.")
	end

	local build = launch.main.modes["BUILD"]
	launch.main:SetMode("BUILD", false, "")
	if launch.main.OnFrame then
		launch.main:OnFrame()
	end
	build.importTab:ImportItemsAndSkills(charData)
	build.importTab:ImportPassiveTreeAndJewels(charData)

	local mainSkill = selectMainSkill(build, options.mainSkill)
	local dpsMetric = options.dpsMetric
	if not dpsMetric or dpsMetric == "" then
		dpsMetric = "CombinedDPS"
	end
	local calibration = loadCalibration(options.calibrationPath)
	local calibrationWeights = buildCalibrationWeightMap(calibration)

	local originalCustomMods = build.configTab.input.customMods or ""
	build.configTab.input.customMods = originalCustomMods
	local baseline = calculate(build)
	local useCalibrationDps = baseline[dpsMetric] <= 0 and calibration ~= nil
	if (not mainSkill or mainSkill == "") and calibration and calibration.build_context then
		mainSkill = calibration.build_context.core_engine
	end

	local report = {
		generatedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		inputPath = inputPath,
		character = {
			name = stripEscapes(charData.name),
			class = charData.class,
			league = charData.league,
			level = charData.level,
		},
		mainSkill = mainSkill,
		skills = skillList(build),
		dpsMetric = dpsMetric,
		dpsSource = useCalibrationDps and "calibration fallback" or "PoB direct",
		baseline = baseline,
		results = { },
	}
	if #report.skills == 0 then
		report.skills = apiSkillList(charData)
	end
	if calibration then
		report.calibration = {
			name = calibration.name,
			last_updated = calibration.last_updated,
			path = calibration.path,
			build_context = calibration.build_context,
		}
	end

	for _, spec in ipairs(statSpecs) do
		local line = makeLine(spec)
		local row = {
			id = spec.id,
			group = spec.group,
			label = spec.label,
			labelKo = spec.labelKo,
			unit = spec.unit,
			unitLabel = spec.unitLabel,
			line = line,
			parsed = isParsed(line),
		}
		if row.parsed then
			local ok, outputOrErr = pcall(function()
				build.configTab.input.customMods = appendCustomMod(originalCustomMods, line)
				return calculate(build)
			end)
			if ok then
				row.output = outputOrErr
				local dpsPercent = percentGain(baseline[dpsMetric], outputOrErr[dpsMetric])
				local ehpPercent = percentGain(baseline.TotalEHP, outputOrErr.TotalEHP)
				row.dpsPercentPerUnit = dpsPercent and (dpsPercent / spec.unit) or nil
				row.ehpPercentPerUnit = ehpPercent and (ehpPercent / spec.unit) or nil
				row.dpsDelta = (outputOrErr[dpsMetric] or 0) - (baseline[dpsMetric] or 0)
				row.ehpDelta = (outputOrErr.TotalEHP or 0) - (baseline.TotalEHP or 0)
				row.dpsSource = "PoB"
				row.ehpSource = "PoB"
			else
				row.error = tostring(outputOrErr)
			end
		end
		local calibrationWeight = calibrationWeights[spec.line]
		if useCalibrationDps and calibrationWeight then
			row.dpsPercentPerUnit = calibrationWeight.weight_per_1_percent or calibrationWeight.weight_per_1_unit or row.dpsPercentPerUnit
			row.dpsSource = "calibration"
			row.tradeStatId = calibrationWeight.trade_stat_id
			row.calibrationNote = calibrationWeight.note
			row.error = nil
			row.parsed = true
		end
		t_insert(report.results, row)
	end

	build.configTab.input.customMods = originalCustomMods
	build.configTab:BuildModList()

	local outputDir = options.outputDir
	if not outputDir or outputDir == "" then
		outputDir = "work/stat-weight-reports"
	end
	MakeDir(outputDir)

	local jsonPath = pathJoin(outputDir, "latest.json")
	local markdownPath = pathJoin(outputDir, "latest.md")
	os.remove(pathJoin(outputDir, "latest-error.txt"))
	writeFile(jsonPath, dkjson.encode(report, { indent = true }))
	writeFile(markdownPath, buildMarkdown(report))
	report.jsonPath = jsonPath
	report.markdownPath = markdownPath
	return report
end

return StatWeightReport
