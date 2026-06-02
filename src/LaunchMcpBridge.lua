#@ SimpleGraphic
-- Path of Building
--
-- MCP bridge launcher.
-- Loads a build through existing PoB import/load APIs, executes one JSON
-- request, writes one JSON result file, then exits.

POB_MCP_RUN = true

local dkjson = require("dkjson")
local t_insert = table.insert
local s_format = string.format

local jsonArrayMeta = { __jsontype = "array" }

local function jsonArray(value)
	return setmetatable(value or {}, jsonArrayMeta)
end

local function readFile(path)
	local file = io.open(path, "rb")
	if not file then
		error("Could not open file for reading: " .. tostring(path))
	end
	local body = file:read("*a")
	file:close()
	return body
end

local function writeFile(path, body)
	local file = io.open(path, "wb")
	if not file then
		error("Could not open file for writing: " .. tostring(path))
	end
	file:write(body)
	file:close()
end

local function stripEscapes(text)
	if text == nil then
		return nil
	end
	text = tostring(text)
	if StripEscapes then
		return StripEscapes(text)
	end
	return text:gsub("%^%d", ""):gsub("%^x%x%x%x%x%x%x", "")
end

local function shallowCopyScalars(src)
	local out = { }
	for key, value in pairs(src or { }) do
		local valueType = type(value)
		if valueType == "number" or valueType == "string" or valueType == "boolean" then
			out[key] = value
		end
	end
	return out
end

local function tableContains(list, value)
	for _, item in ipairs(list or { }) do
		if item == value then
			return true
		end
	end
	return false
end

local defaultSections = {
	"metadata",
	"equipment",
	"skills",
	"calcs",
	"sidebar",
	"warnings",
}

local defaultStats = {
	"AverageDamage",
	"Speed",
	"PreEffectiveCritChance",
	"CritMultiplier",
	"HitChance",
	"TotalDPS",
	"CombinedDPS",
	"ManaCost",
	"ManaPerSecondCost",
	"Str",
	"ReqStr",
	"Dex",
	"ReqDex",
	"Int",
	"ReqInt",
	"TotalEHP",
	"PhysicalMaximumHitTaken",
	"FireMaximumHitTaken",
	"ColdMaximumHitTaken",
	"LightningMaximumHitTaken",
	"ChaosMaximumHitTaken",
	"Life",
	"Spec:LifeInc",
	"LifeRegenRecovery",
	"Mana",
	"ManaRegenRecovery",
	"Spirit",
	"SpiritUnreserved",
	"SpiritUnreservedPercent",
	"EnergyShield",
	"Spec:EnergyShieldInc",
	"Evasion",
	"Spec:EvasionInc",
	"EvadeChance",
	"DeflectionRating",
	"DeflectChance",
	"Armour",
	"PhysicalDamageReduction",
	"FireResist",
	"FireResistOverCap",
	"ColdResist",
	"ColdResistOverCap",
	"LightningResist",
	"LightningResistOverCap",
	"ChaosResist",
	"ChaosResistOverCap",
	"EffectiveMovementSpeedMod",
	"PresenceRadiusMetres",
	"LootRarity",
}

local bridgeState = {
	request = nil,
	source = nil,
	character = nil,
}

local function requestedSections(args)
	return args.sections or defaultSections
end

local function wants(args, section)
	return tableContains(requestedSections(args), section)
end

local function currentBuild()
	return launch.main.modes["BUILD"]
end

local function rebuild(build)
	build.configTab:BuildModList()
	build.buildFlag = true
	build.outputRevision = (build.outputRevision or 0) + 1
	build.calcsTab:BuildOutput()
	build:RefreshSkillSelectControls(build.controls, build.mainSocketGroup, "")
	build:RefreshStatList()
end

local function lowerText(text)
	return tostring(text or ""):lower()
end

local function skillDisplayName(active)
	if not active then
		return nil
	end
	local granted = active.activeEffect and active.activeEffect.grantedEffect or { }
	return stripEscapes(granted.name or active.name)
end

local function selectMainSkill(build, args)
	local requestedGroup = tonumber(args.mainSocketGroup or args.socketGroup)
	local requestedActive = tonumber(args.activeSkill or args.mainActiveSkill)
	local requestedName = args.mainSkillName or args.mainSkill

	if requestedName and requestedName ~= "" then
		local needle = lowerText(requestedName)
		local best = nil
		local fallbackGroup = nil
		for groupIndex, group in ipairs(build.skillsTab.socketGroupList or { }) do
			local groupLabel = lowerText(group.displayLabel or group.label)
			if groupLabel:find(needle, 1, true) then
				fallbackGroup = fallbackGroup or groupIndex
			end
			for activeIndex, active in ipairs(group.displaySkillList or { }) do
				local name = lowerText(skillDisplayName(active))
				local id = lowerText(active.activeEffect and active.activeEffect.grantedEffect and active.activeEffect.grantedEffect.id)
				if name == needle or name:find(needle, 1, true) or id == needle then
					local score = 0
					if name == needle then
						score = score + 100
					elseif name:find(needle, 1, true) then
						score = score + 50
					end
					if id == needle then
						score = score + 40
					end
					if groupLabel == needle then
						score = score + 60
					elseif groupLabel:find(needle, 1, true) then
						score = score + 10
					end
					if #(group.displaySkillList or { }) == 1 then
						score = score + 25
					end
					if not best or score > best.score then
						best = {
							score = score,
							group = groupIndex,
							active = activeIndex,
						}
					end
				end
			end
		end
		if best then
			requestedGroup = best.group
			requestedActive = best.active
		elseif not requestedGroup and fallbackGroup then
			requestedGroup = fallbackGroup
		end
	end

	if requestedGroup then
		local group = build.skillsTab.socketGroupList[requestedGroup]
		if not group then
			error("Unknown mainSocketGroup: " .. tostring(requestedGroup))
		end
		build.mainSocketGroup = requestedGroup
		if requestedActive then
			group.mainActiveSkill = requestedActive
			group.mainActiveSkillCalcs = requestedActive
		end
		build.buildFlag = true
		rebuild(build)
		return {
			mainSocketGroup = requestedGroup,
			activeSkill = requestedActive or group.mainActiveSkill,
			mainSkillName = requestedName,
		}
	end
	return nil
end

local function decodeJsonFile(path)
	local decoded, _, err = dkjson.decode(readFile(path))
	if not decoded then
		error("Could not parse JSON " .. tostring(path) .. ": " .. tostring(err))
	end
	return decoded
end

local function chooseSourcePath(args)
	if args.inputPath and args.inputPath ~= "" then
		return args.inputPath
	end
	if args.source == "xml" then
		error("source=xml requires inputPath")
	end
	return "src/poe_api_response.json"
end

local function loadXmlBuild(args)
	local inputPath = chooseSourcePath(args)
	local xmlText = readFile(inputPath)
	launch.main:SetMode("BUILD", false, inputPath, xmlText)
	if launch.main.OnFrame then
		launch.main:OnFrame()
	end
	local build = currentBuild()
	rebuild(build)
	bridgeState.source = {
		type = "xml",
		inputPath = inputPath,
	}
	bridgeState.character = nil
	return build
end

local function setImportControl(importTab, name, value)
	if value ~= nil and importTab.controls[name] then
		importTab.controls[name].state = value and true or false
	end
end

local function loadCachedJsonBuild(args)
	local inputPath = chooseSourcePath(args)
	local decoded = decodeJsonFile(inputPath)
	local charData = decoded.character or decoded
	if not charData then
		error("Character JSON did not contain character data.")
	end
	if not charData.equipment then
		error("Character JSON must contain equipment for PoB import.")
	end

	launch.main:SetMode("BUILD", false, "")
	if launch.main.OnFrame then
		launch.main:OnFrame()
	end
	local build = currentBuild()
	local importTab = build.importTab
	local clear = args.clear or { }
	setImportControl(importTab, "charImportItemsClearItems", clear.items ~= false)
	setImportControl(importTab, "charImportItemsClearSkills", clear.skills ~= false)
	setImportControl(importTab, "charImportTreeClearJewels", clear.jewels ~= false)

	if args.includeItemsAndSkills ~= false then
		importTab:ImportItemsAndSkills(charData)
	end
	if args.includePassives ~= false and charData.passives then
		importTab:ImportPassiveTreeAndJewels(charData)
	end
	rebuild(build)

	bridgeState.source = {
		type = "cached_json",
		inputPath = inputPath,
	}
	bridgeState.character = {
		name = stripEscapes(charData.name),
		class = charData.class,
		league = charData.league,
		level = charData.level,
	}
	return build
end

local function loadSource(args)
	args.source = args.source or "cached_json"
	if args.source == "live" then
		error("source=live is not implemented in MCP v1. Use a cached JSON path; this bridge will not read PoB Settings.xml or OAuth tokens.")
	elseif args.source == "xml" then
		return loadXmlBuild(args)
	elseif args.source == "none" then
		local build = currentBuild()
		rebuild(build)
		bridgeState.source = { type = "none" }
		bridgeState.character = nil
		return build
	else
		return loadCachedJsonBuild(args)
	end
end

local function getOutputPathValue(output, path)
	local value = output
	for part in tostring(path):gmatch("[^%.]+") do
		if type(value) ~= "table" then
			return nil
		end
		value = value[part]
	end
	return value
end

local function scalarOrNil(value)
	local valueType = type(value)
	if valueType == "number" or valueType == "string" or valueType == "boolean" then
		return value
	end
	return nil
end

local function outputStats(build, stats)
	stats = stats or defaultStats
	local output = build.calcsTab.mainOutput or { }
	local values = { }
	local missing = jsonArray()
	for _, statKey in ipairs(stats) do
		local value = scalarOrNil(getOutputPathValue(output, statKey))
		if value == nil then
			t_insert(missing, statKey)
		else
			values[statKey] = value
		end
	end
	return values, missing
end

local function lineList(value)
	local out = jsonArray()
	for _, line in ipairs(value or { }) do
		if type(line) == "table" then
			t_insert(out, stripEscapes(line.line or line[1] or ""))
		else
			t_insert(out, stripEscapes(line))
		end
	end
	return out
end

local function requirementList(item)
	local out = jsonArray()
	for _, req in ipairs(item.requirements or { }) do
		if type(req) == "table" then
			t_insert(out, {
				label = stripEscapes(req.label or req[1]),
				value = req.val or req.value or req[2],
			})
		else
			t_insert(out, stripEscapes(req))
		end
	end
	return out
end

local function itemSummary(item, includeRaw)
	if not item then
		return nil
	end
	local base = item.base or { }
	local out = {
		id = item.id,
		name = stripEscapes(item.name),
		title = stripEscapes(item.title),
		baseName = stripEscapes(item.baseName),
		type = stripEscapes(base.type or item.type),
		subType = stripEscapes(base.subType),
		rarity = item.rarity,
		itemLevel = item.itemLevel or item.ilvl,
		quality = item.quality,
		requirements = requirementList(item),
		mods = {
			enchant = lineList(item.enchantModLines),
			implicit = lineList(item.implicitModLines),
			explicit = lineList(item.explicitModLines),
			crafted = lineList(item.craftedModLines),
			fractured = lineList(item.fracturedModLines),
			archnemesis = lineList(item.archnemesisModLines),
		},
	}
	if includeRaw then
		out.raw = item.raw
	end
	return out
end

local function slotShown(slot)
	local ok, value = pcall(function()
		if slot.IsShown then
			return slot:IsShown()
		elseif slot.shown then
			return slot.shown()
		end
		return true
	end)
	return ok and value ~= false
end

local function equipmentState(build, args)
	local slots = jsonArray()
	for _, slot in ipairs(build.itemsTab.orderedSlots or { }) do
		local shown = slotShown(slot)
		if args.includeHiddenSlots or shown then
			local item = nil
			if slot.selItemId and slot.selItemId ~= 0 then
				item = build.itemsTab.items[slot.selItemId]
			end
			t_insert(slots, {
				slot = slot.slotName,
				label = stripEscapes(slot.label or slot.slotName),
				itemId = slot.selItemId or 0,
				nodeId = slot.nodeId,
				weaponSet = slot.weaponSet,
				inactive = slot.inactive and true or false,
				shown = shown,
				item = itemSummary(item, args.includeRawItems),
			})
		end
	end
	return {
		activeItemSetId = build.itemsTab.activeItemSetId,
		activeItemSetTitle = build.itemsTab.activeItemSet and stripEscapes(build.itemsTab.activeItemSet.title) or nil,
		useSecondWeaponSet = build.itemsTab.activeItemSet and build.itemsTab.activeItemSet.useSecondWeaponSet or nil,
		slots = slots,
	}
end

local function skillState(build)
	local groups = jsonArray()
	for index, group in ipairs(build.skillsTab.socketGroupList or { }) do
		local gems = jsonArray()
		for gemIndex, gem in ipairs(group.gemList or { }) do
			local effect = gem.grantedEffect or { }
			t_insert(gems, {
				index = gemIndex,
				name = stripEscapes(gem.nameSpec or effect.name or gem.gemId),
				gemId = gem.gemId,
				skillId = gem.skillId,
				level = gem.level,
				quality = gem.quality,
				enabled = gem.enabled,
				support = gem.support,
				count = gem.count,
				qualityId = gem.qualityId,
			})
		end
		local activeSkills = jsonArray()
		for activeIndex, active in ipairs(group.displaySkillList or { }) do
			local granted = active.activeEffect and active.activeEffect.grantedEffect or { }
			t_insert(activeSkills, {
				index = activeIndex,
				name = stripEscapes(granted.name or active.name),
				id = granted.id,
			})
		end
		t_insert(groups, {
			index = index,
			label = stripEscapes(group.displayLabel or group.label),
			enabled = group.enabled,
			includeInFullDPS = group.includeInFullDPS,
			mainActiveSkill = group.mainActiveSkill,
			mainActiveSkillCalcs = group.mainActiveSkillCalcs,
			gems = gems,
			activeSkills = activeSkills,
		})
	end
	return {
		mainSocketGroup = build.mainSocketGroup,
		groups = groups,
	}
end

local function configState(build)
	local configTab = build.configTab
	local configSet = configTab.configSets[configTab.activeConfigSetId] or { input = { }, placeholder = { } }
	return {
		activeConfigSetId = configTab.activeConfigSetId,
		input = shallowCopyScalars(configSet.input),
		placeholder = shallowCopyScalars(configSet.placeholder),
	}
end

local function sidebarState(build)
	local rows = jsonArray()
	for _, row in ipairs(build.controls.statBox.list or { }) do
		local entry = {
			height = row.height,
			align = row.align,
			x = row.x,
			left = stripEscapes(row[1]),
			right = stripEscapes(row[2]),
			text = stripEscapes(row[3]),
		}
		if entry.left or entry.right or entry.text then
			t_insert(rows, entry)
		end
	end
	return rows
end

local function warningsState(build)
	local out = jsonArray()
	for _, warning in ipairs(build.controls.warnings.lines or { }) do
		t_insert(out, stripEscapes(warning))
	end
	return out
end

local function statSchema(build)
	local out = jsonArray()
	for _, statData in ipairs(build.displayStats or { }) do
		if statData.stat or statData.label then
			t_insert(out, {
				stat = statData.stat,
				childStat = statData.childStat,
				label = statData.label,
				fmt = statData.fmt,
				compPercent = statData.compPercent and true or false,
				lowerIsBetter = statData.lowerIsBetter and true or false,
				hidden = statData.hideStat and true or false,
			})
		end
	end
	return out
end

local function configSchema()
	local out = jsonArray()
	local ok, varList = pcall(function()
		return LoadModule("Modules/ConfigOptions")
	end)
	if not ok then
		return out
	end
	for _, varData in ipairs(varList or { }) do
		if varData.var then
			local list = nil
			if type(varData.list) == "table" then
				list = jsonArray()
				for _, item in ipairs(varData.list) do
					t_insert(list, {
						label = stripEscapes(type(item) == "table" and item.label or item),
						value = type(item) == "table" and item.val or item,
					})
				end
			end
			t_insert(out, {
				var = varData.var,
				type = varData.type,
				label = stripEscapes(varData.label),
				section = stripEscapes(varData.section),
				defaultState = scalarOrNil(varData.defaultState),
				defaultPlaceholderState = scalarOrNil(varData.defaultPlaceholderState),
				list = list,
			})
		end
	end
	return out
end

local function schemasState(build)
	return {
		displayStats = statSchema(build),
		configOptions = configSchema(),
		itemSlots = equipmentState(build, { includeRawItems = false, includeHiddenSlots = true }).slots,
	}
end

function skillCalcsState(build, args)
	local options = args.skillCalcs or { }
	local targets = options.targets
	local maxTargets = tonumber(options.maxTargets or 30)
	local includeSidebar = options.includeSidebar and true or false
	local out = jsonArray()
	local originalGroup = build.mainSocketGroup
	local originalActive = { }
	for groupIndex, group in ipairs(build.skillsTab.socketGroupList or { }) do
		originalActive[groupIndex] = {
			mainActiveSkill = group.mainActiveSkill,
			mainActiveSkillCalcs = group.mainActiveSkillCalcs,
		}
	end

	if not targets then
		targets = jsonArray()
		for groupIndex, group in ipairs(build.skillsTab.socketGroupList or { }) do
			for activeIndex in ipairs(group.displaySkillList or { }) do
				t_insert(targets, {
					socketGroup = groupIndex,
					activeSkill = activeIndex,
				})
				if #targets >= maxTargets then
					break
				end
			end
			if #targets >= maxTargets then
				break
			end
		end
	end

	for _, target in ipairs(targets or { }) do
		local groupIndex = tonumber(target.socketGroup or target.mainSocketGroup)
		local activeIndex = tonumber(target.activeSkill or target.mainActiveSkill or 1)
		local group = groupIndex and build.skillsTab.socketGroupList[groupIndex] or nil
		if group then
			build.mainSocketGroup = groupIndex
			group.mainActiveSkill = activeIndex
			group.mainActiveSkillCalcs = activeIndex
			local ok, err = pcall(function()
				rebuild(build)
			end)
			local values, missing = outputStats(build, args.stats)
			local active = group.displaySkillList and group.displaySkillList[activeIndex] or nil
			local mainSkill = build.calcsTab.mainEnv and build.calcsTab.mainEnv.player and build.calcsTab.mainEnv.player.mainSkill or { }
			local row = {
				socketGroup = groupIndex,
				activeSkill = activeIndex,
				groupLabel = stripEscapes(group.displayLabel or group.label),
				skillName = skillDisplayName(active),
				ok = ok,
				error = (not ok) and tostring(err) or nil,
				disabled = mainSkill.disableReason and true or false,
				disableReason = stripEscapes(mainSkill.disableReason),
				infoMessage = stripEscapes(mainSkill.infoMessage),
				stats = values,
				missing = missing,
			}
			if includeSidebar then
				row.sidebar = sidebarState(build)
				row.warnings = warningsState(build)
			end
			t_insert(out, row)
		else
			t_insert(out, {
				socketGroup = target.socketGroup or target.mainSocketGroup,
				activeSkill = activeIndex,
				ok = false,
				error = "Unknown socket group",
			})
		end
	end

	build.mainSocketGroup = originalGroup
	for groupIndex, state in pairs(originalActive) do
		local group = build.skillsTab.socketGroupList[groupIndex]
		if group then
			group.mainActiveSkill = state.mainActiveSkill
			group.mainActiveSkillCalcs = state.mainActiveSkillCalcs
		end
	end
	pcall(function()
		rebuild(build)
	end)
	return out
end

local function metadataState(build)
	local source = bridgeState.source or { }
	return {
		generatedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		source = source,
		inputFile = bridgeState.request and bridgeState.request.inputFile or nil,
		character = bridgeState.character,
		buildName = stripEscapes(build.buildName),
		className = stripEscapes(build.spec and build.spec.curClassName),
		characterLevel = build.characterLevel,
		mainSocketGroup = build.mainSocketGroup,
		activeConfigSetId = build.configTab.activeConfigSetId,
		activeItemSetId = build.itemsTab.activeItemSetId,
		outputRevision = build.outputRevision,
	}
end

local function stateSnapshot(build, args)
	local result = {
		ok = true,
		tool = bridgeState.request and bridgeState.request.tool or nil,
	}
	if wants(args, "metadata") then
		result.metadata = metadataState(build)
	end
	if wants(args, "equipment") then
		result.equipment = equipmentState(build, args)
	end
	if wants(args, "skills") then
		result.skills = skillState(build)
	end
	if wants(args, "config") then
		result.config = configState(build)
	end
	if wants(args, "calcs") then
		local values, missing = outputStats(build, args.stats)
		result.calcs = {
			stats = values,
			missing = missing,
		}
	end
	if wants(args, "sidebar") then
		result.sidebar = sidebarState(build)
	end
	if wants(args, "warnings") then
		result.warnings = warningsState(build)
	end
	if wants(args, "skillCalcs") then
		result.skillCalcs = skillCalcsState(build, args)
	end
	if wants(args, "schemas") then
		result.schemas = schemasState(build)
	end
	return result
end

local function applyItemChange(build, change)
	local action = change.action or "replace_raw"
	if action == "set_active_item_set" then
		if not change.itemSetId then
			error("items.set_active_item_set requires itemSetId")
		end
		build.itemsTab:SetActiveItemSet(tonumber(change.itemSetId), true)
		return { action = action, itemSetId = build.itemsTab.activeItemSetId }
	end
	if not change.slot or change.slot == "" then
		error("Item change requires slot")
	end
	if action == "clear" then
		local slot = build.itemsTab.slots[change.slot]
		if not slot then
			error("Unknown item slot: " .. tostring(change.slot))
		end
		slot:SetSelItemId(0)
		build.itemsTab:PopulateSlots()
		build.buildFlag = true
		return { action = action, slot = change.slot, selectedItemId = 0 }
	end
	if not change.raw or change.raw == "" then
		error("Item change requires raw item text")
	end
	local slot = build.itemsTab.slots[change.slot]
	if not slot then
		error("Unknown item slot: " .. tostring(change.slot))
	end
	local ok, itemOrErr = pcall(function()
		local item = new("Item", change.raw)
		if item.NormaliseQuality then
			pcall(function()
				item:NormaliseQuality()
			end)
		end
		build.itemsTab:AddItem(item, true)
		slot:SetSelItemId(item.id)
		build.itemsTab:PopulateSlots()
		build.buildFlag = true
		return item
	end)
	if not ok then
		error("Could not parse/equip raw item for " .. tostring(change.slot) .. ": " .. tostring(itemOrErr))
	end
	return {
		action = action,
		slot = change.slot,
		itemId = itemOrErr.id,
		selectedItemId = slot.selItemId,
		selected = slot.selItemId == itemOrErr.id,
		item = itemSummary(itemOrErr, false),
	}
end

local function applyConfigChange(build, change)
	local configTab = build.configTab
	local configSetId = tonumber(change.configSetId or configTab.activeConfigSetId)
	local configSet = configTab.configSets[configSetId]
	if not configSet then
		error("Unknown configSetId: " .. tostring(configSetId))
	end
	local action = change.action or "set_input"
	if action == "set_active_config_set" then
		configTab:SetActiveConfigSet(configSetId)
		build.buildFlag = true
		return { action = action, activeConfigSetId = configTab.activeConfigSetId }
	end
	if not change.var then
		error("Config change requires var")
	end
	if action == "clear_input" then
		configSet.input[change.var] = nil
	elseif action == "set_placeholder" then
		configSet.placeholder[change.var] = change.value
	else
		configSet.input[change.var] = change.value
	end
	configTab.input = configTab.configSets[configTab.activeConfigSetId].input
	configTab.placeholder = configTab.configSets[configTab.activeConfigSetId].placeholder
	build.buildFlag = true
	return {
		action = action,
		configSetId = configSetId,
		var = change.var,
		value = change.value,
	}
end

local function applySkillChange(build, change)
	local action = change.action or "select_main"
	if action ~= "select_main" then
		error("Unsupported skills action: " .. tostring(action))
	end
	local socketGroupIndex = tonumber(change.socketGroup or change.mainSocketGroup or build.mainSocketGroup or 1)
	local group = build.skillsTab.socketGroupList[socketGroupIndex]
	if not group then
		error("Unknown socket group: " .. tostring(socketGroupIndex))
	end
	build.mainSocketGroup = socketGroupIndex
	if change.activeSkill or change.mainActiveSkill then
		group.mainActiveSkill = tonumber(change.activeSkill or change.mainActiveSkill)
	end
	if change.activeSkillCalcs or change.mainActiveSkillCalcs then
		group.mainActiveSkillCalcs = tonumber(change.activeSkillCalcs or change.mainActiveSkillCalcs)
	end
	build.buildFlag = true
	return {
		action = action,
		mainSocketGroup = build.mainSocketGroup,
		mainActiveSkill = group.mainActiveSkill,
		mainActiveSkillCalcs = group.mainActiveSkillCalcs,
	}
end

local function applyChanges(build, changes)
	local applied = jsonArray()
	for index, change in ipairs(changes or { }) do
		local domain = change.domain or "items"
		local result
		if domain == "items" then
			result = applyItemChange(build, change)
		elseif domain == "config" then
			result = applyConfigChange(build, change)
		elseif domain == "skills" then
			result = applySkillChange(build, change)
		else
			error("Unsupported change domain: " .. tostring(domain))
		end
		result.index = index
		result.domain = domain
		t_insert(applied, result)
	end
	build.itemsTab:PopulateSlots()
	rebuild(build)
	return applied
end

local function diffStats(before, after, stats)
	stats = stats or defaultStats
	local out = { }
	for _, statKey in ipairs(stats) do
		local beforeValue = before[statKey]
		local afterValue = after[statKey]
		if beforeValue ~= nil or afterValue ~= nil then
			local row = {
				before = beforeValue,
				after = afterValue,
			}
			if type(beforeValue) == "number" and type(afterValue) == "number" then
				row.delta = afterValue - beforeValue
				if beforeValue ~= 0 then
					row.percent = (afterValue / beforeValue - 1) * 100
				end
			end
			out[statKey] = row
		end
	end
	return out
end

local function simulateChanges(build, args)
	local before, beforeMissing = outputStats(build, args.stats)
	local applied = applyChanges(build, args.changes)
	local after, afterMissing = outputStats(build, args.stats)
	local snapshot = stateSnapshot(build, args)
	snapshot.appliedChanges = applied
	snapshot.committed = false
	snapshot.diff = diffStats(before, after, args.stats)
	snapshot.baseline = {
		stats = before,
		missing = beforeMissing,
	}
	snapshot.after = {
		stats = after,
		missing = afterMissing,
	}
	return snapshot
end

local function setState(build, args)
	args.mode = args.mode or "sandbox"
	if args.mode ~= "commit" then
		local result = simulateChanges(build, args)
		result.mode = "sandbox"
		return result
	end
	local applied = applyChanges(build, args.changes)
	if not args.outputPath or args.outputPath == "" then
		error("pob_set_state mode=commit requires outputPath. The MCP will not overwrite the source build implicitly.")
	end
	local xmlText = build:SaveDB(args.outputPath)
	if not xmlText then
		error("PoB SaveDB failed for " .. tostring(args.outputPath))
	end
	writeFile(args.outputPath, xmlText)
	local snapshot = stateSnapshot(build, args)
	snapshot.appliedChanges = applied
	snapshot.committed = true
	snapshot.outputPath = args.outputPath
	return snapshot
end

local function runRequest()
	local requestPath = os.getenv("POB_MCP_REQUEST")
	if not requestPath or requestPath == "" then
		error("POB_MCP_REQUEST is not set")
	end
	bridgeState.request = decodeJsonFile(requestPath)
	local request = bridgeState.request
	local args = request.args or { }
	local build = loadSource(args)
	selectMainSkill(build, args)
	local tool = request.tool
	if tool == "pob_get_state" or tool == "pob_import_current" then
		return stateSnapshot(build, args)
	elseif tool == "pob_simulate_changes" then
		return simulateChanges(build, args)
	elseif tool == "pob_set_state" then
		return setState(build, args)
	end
	error("Unsupported MCP bridge tool: " .. tostring(tool))
end

local function writeResult(result)
	local outputPath = os.getenv("POB_MCP_OUTPUT")
	if not outputPath or outputPath == "" then
		error("POB_MCP_OUTPUT is not set")
	end
	writeFile(outputPath, dkjson.encode(result, { indent = true }))
end

LoadModule("Launch")

local originalOnFrame = launch.OnFrame
local started = false

function launch:OnFrame(...)
	if originalOnFrame then
		originalOnFrame(self, ...)
	end
	if started then
		return
	end
	if not (self.main and self.main.modes and self.main.modes["BUILD"]) then
		return
	end
	started = true

	local ok, resultOrErr = pcall(runRequest)
	if ok then
		local okWrite, writeErr = pcall(writeResult, resultOrErr)
		if not okWrite then
			ConPrintf("MCP bridge write failed: %s", tostring(writeErr))
		end
	else
		local failure = {
			ok = false,
			error = tostring(resultOrErr),
		}
		local okWrite, writeErr = pcall(writeResult, failure)
		if not okWrite then
			ConPrintf("MCP bridge failed and could not write failure JSON: %s", tostring(writeErr))
		end
	end
	Exit()
end
