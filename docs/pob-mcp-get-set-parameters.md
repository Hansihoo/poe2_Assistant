# PoB MCP Get/Set Parameters

This document defines the first MCP surface for reading and changing a Path of Building-PoE2 build. The MCP server must wrap existing PoB code paths. It must not reimplement POE item, passive, DPS, EHP, resistance, requirement, or skill rules.

## Source Map

PoB state is split across these existing modules:

| Area | Owner | Existing paths to reuse |
| --- | --- | --- |
| Build metadata and save/load sections | `src/Modules/Build.lua` | `buildMode:Load`, `buildMode:Save`, `buildMode:SaveDB`, `build.savers` |
| Character import | `src/Classes/PoEAPI.lua`, `src/Classes/ImportTab.lua` | `DownloadCharacter`, `DownloadItems`, `DownloadPassiveTree`, `ImportItemsAndSkills`, `ImportPassiveTreeAndJewels`, `ImportItem` |
| Configuration inputs | `src/Classes/ConfigTab.lua`, `src/Modules/ConfigOptions.lua` | `configSets`, `activeConfigSetId`, `input`, `placeholder`, `BuildModList`, `UpdateControls` |
| Items and equipment | `src/Classes/ItemsTab.lua`, `src/Classes/ItemSlotControl.lua` | `items`, `itemSets`, `activeItemSet`, `AddItem`, `EquipItemInSet`, `SetActiveItemSet`, `SetSelItemId`, `PopulateSlots` |
| Passive tree | `src/Classes/TreeTab.lua`, `src/Classes/PassiveSpec.lua` | `specList`, `activeSpec`, `ImportFromNodeList`, `allocNodes`, `masterySelections`, `hashOverrides`, `jewels` |
| Skills and gems | `src/Classes/SkillsTab.lua` | `skillSets`, `activeSkillSetId`, `socketGroupList`, `SetActiveSkillSet`, `ProcessSocketGroup` |
| Calc-tab inputs and outputs | `src/Classes/CalcsTab.lua`, `src/Modules/Calcs.lua` | `input`, `BuildOutput`, `mainOutput`, `calcsOutput`, `GetMiscCalculator`, `GetNodeCalculator` |
| Sidebar stats and warnings | `src/Modules/BuildDisplayStats.lua`, `src/Modules/Build.lua` | `displayStats`, `minionDisplayStats`, `RefreshStatList`, `AddDisplayStatList`, `controls.warnings.lines` |
| Stat weights | `src/Modules/StatWeightReport.lua`, `src/Classes/TradeQueryGenerator.lua` | `StatWeightReport.Generate`, `WeightedRatioOutputs`, `GenerateModWeights` |
| Notes and party buffs | `src/Classes/NotesTab.lua`, `src/Classes/PartyTab.lua` | `Load`, `Save`, imported buff text parsers |

## Managed Value Model

### Build

Stored by the `Build` XML section.

| Field | Read | Set | Notes |
| --- | --- | --- | --- |
| `buildName`, `dbFileName`, `dbFileSubPath` | yes | no in v1 | File identity. Do not use for gameplay decisions. |
| `viewMode` | yes | optional | UI-only. Not needed for headless MCP. |
| `characterLevel` | yes | yes | Use `configTab:UpdateLevel()` and rebuild after setting. |
| `characterLevelAutoMode` | yes | yes | Boolean. |
| `mainSocketGroup` | yes | yes | Sidebar main-skill selector. Separate from Calcs-tab `input.skill_number`. |
| `spectreList`, `beastList` | yes | no in v1 | Managed by import/library UI. |
| `timelessData` | yes | no in v1 | Timeless search UI state. |

### Import

Stored by the `Import` XML section and runtime API state.

| Field/action | Read | Set | Notes |
| --- | --- | --- | --- |
| `lastRealm`, `lastLeague`, `lastAccountHash`, `lastCharacterHash`, `importLink` | yes | no in v1 | Safe hashes only. Never expose tokens or `Settings.xml`. |
| `import_current` | action | action | Calls existing `PoEAPI`/`ImportTab` path. |
| `import_cached_json` | action | action | Decodes existing character JSON and calls `ImportItemsAndSkills` / `ImportPassiveTreeAndJewels`. |
| `clearItems`, `clearSkills`, `clearJewels`, `ignoreWeaponSwap` | yes | yes per import | Existing import checkboxes. |

### Config

Stored by the `Config` XML section.

| Field | Read | Set | Notes |
| --- | --- | --- | --- |
| `activeConfigSetId` | yes | yes | Use `SetActiveConfigSet`. |
| `configSets[].title` | yes | optional | Existing set manager owns create/copy/delete. |
| `configSets[].input[var]` | yes | yes | Validate `var` against `Modules/ConfigOptions.lua`. |
| `configSets[].placeholder[var]` | yes | yes | Placeholder values are used by enemy/boss defaults. |
| `schema` | yes | no | Built from `varList`: `var`, `type`, `label`, `list`, visibility flags, default state. |

Important examples from `ConfigOptions.lua`: `resistancePenalty`, `enemyLevel`, `enemyIsBoss`, `enemyFireResist`, `enemyColdResist`, `enemyLightningResist`, `enemyChaosResist`, `customMods`.

### Items

Stored by the `Items` XML section.

Base slots from `ItemsTab.lua`:

```text
Weapon 1, Weapon 2, Helmet, Body Armour, Gloves, Boots, Amulet,
Ring 1, Ring 2, Ring 3, Belt, Charm 1, Charm 2, Charm 3,
Flask 1, Flask 2, Arm 1, Arm 2, Leg 1, Leg 2
```

Weapon swap and jewel socket slots are also managed:

```text
Weapon 1 Swap, Weapon 2 Swap,
<equipment slot> Jewel Socket 1..6
```

| Field/action | Read | Set | Notes |
| --- | --- | --- | --- |
| `activeItemSetId` | yes | yes | Use `SetActiveItemSet`. |
| `itemSets[].title` | yes | optional | Existing set manager owns create/copy/delete. |
| `itemSets[].useSecondWeaponSet` | yes | yes | Rebuild after setting. |
| `items[]` raw and parsed item fields | yes | yes via existing item parser | Use `new("Item", raw)` or `ImportItem`, then `AddItem`. |
| `slot.selItemId` | yes | yes | Use `ItemSlotControl:SetSelItemId`; never assign only the table field. |
| flask/charm active flags | yes | yes | Use slot `active` and `activeItemSet[slot].active`. |
| `showStatDifferences` | yes | optional | UI-only. |
| `tradeQuery.statSortSelectionList` | yes | no in PoB MCP v1 | Trade search belongs outside the core MCP. |

### Tree

Stored by `Tree` and `Spec` XML sections.

| Field/action | Read | Set | Notes |
| --- | --- | --- | --- |
| `activeSpec` | yes | yes | Use `TreeTab:SetActiveSpec`. |
| `specList[].title`, `treeVersion` | yes | optional | Do not silently convert tree versions. |
| class and ascendancy IDs | yes | yes via spec import | Prefer `ImportFromNodeList`; do not patch fields one by one. |
| `allocNodes` / node hash list | yes | sandbox first | Use existing tree import/add/remove functions. |
| weapon-set node allocation | yes | sandbox first | Existing `weaponSets` map. |
| `masterySelections` | yes | sandbox first | Existing `masteryEffects`. |
| `hashOverrides` attribute choices | yes | sandbox first | Use existing attribute override methods. |
| `jewels[nodeId]` | yes | yes via item slots | Jewel socket item IDs must refer to real `ItemsTab.items`. |

### Skills

Stored by the `Skills` XML section.

| Field/action | Read | Set | Notes |
| --- | --- | --- | --- |
| `activeSkillSetId` | yes | yes | Use `SkillsTab:SetActiveSkillSet`. |
| `skillSets[].title` | yes | optional | Existing set manager owns create/copy/delete. |
| `socketGroupList[]` | yes | limited in v1 | Includes group `enabled`, `includeInFullDPS`, `groupCount`, `label`, `slot`, `source`. |
| `socketGroup.mainActiveSkill` | yes | yes | Sidebar selector. |
| `socketGroup.mainActiveSkillCalcs` | yes | yes | Calcs-tab selector. |
| gem instance fields | yes | limited in v1 | `level`, `quality`, `enabled`, `count`, `corrupted`, `corruptLevel`, minion fields. |
| `statSet`, `skillPart`, `skillStageCount`, `skillMineCount` | yes | yes | Sidebar skill detail selection. |
| `statSetCalcs`, `skillPartCalcs`, `skillStageCountCalcs`, `skillMineCountCalcs` | yes | yes | Calcs-tab skill detail selection. |

### Calcs

Stored by the `Calcs` XML section for inputs only. Outputs are recalculated.

| Field | Read | Set | Notes |
| --- | --- | --- | --- |
| `calcsTab.input.skill_number` | yes | yes | Calcs-tab socket group. |
| `calcsTab.input.misc_buffMode` | yes | yes | One of `UNBUFFED`, `BUFFED`, `COMBAT`, `EFFECTIVE`. |
| `calcsTab.input.showMinion` | yes | yes | Whether Calcs tab displays minion output. |
| section collapsed flags | yes | no in v1 | UI-only. |
| `mainOutput` | yes | no | Result of `buildOutput(build, "MAIN")`. |
| `calcsOutput` | yes | no | Result of `buildOutput(build, "CALCS")`. |
| `mainEnv`, `calcsEnv` derived maps | selected read | no | Conditions, multipliers, warnings, mod sources. |

## MCP Tools

Keep the tool count small. Rich behavior belongs in parameters and returned metadata.

## Implemented v0.1 Surface

The local implementation lives in:

```text
PathOfBuilding-PoE2-MCP.cmd
tools/pob-mcp/server.js
src/LaunchMcpBridge.lua
```

The server is a dependency-free stdio MCP JSON-RPC server. Each tool call starts
the bundled PoB runtime, executes `LaunchMcpBridge.lua`, writes one JSON result,
and exits. This keeps each calculation isolated and prevents a temporary
simulation from mutating an already open PoB window.

Implemented tools:

- `pob_import_current`
- `pob_get_state`
- `pob_simulate_changes`
- `pob_set_state`
- `pob_stat_weights`

Implemented state sections:

```json
["metadata", "equipment", "skills", "config", "calcs", "sidebar", "warnings", "schemas", "skillCalcs"]
```

Important implementation limits:

- `source=live` intentionally returns an error in v0.1. The bridge does not read
  `Settings.xml` or OAuth/session tokens.
- `source=cached_json` defaults to `src/poe_api_response.json`.
- `pob_set_state` defaults to sandbox behavior. `mode=commit` writes XML only
  when `outputPath` is explicit.
- Item simulations mutate the transient in-process build by calling
  `new("Item", raw)`, `ItemsTab:AddItem`, `ItemSlotControl:SetSelItemId`,
  `ItemsTab:PopulateSlots`, then `CalcsTab:BuildOutput`. The source build is
  not saved unless `pob_set_state mode=commit` is used with `outputPath`.

### `pob_import_current`

Refreshes the build through existing import paths.

```json
{
  "source": "live|cached_json|xml",
  "inputPath": "optional path for cached_json or xml",
  "includeItemsAndSkills": true,
  "includePassives": true,
  "clear": {
    "items": true,
    "skills": true,
    "jewels": true
  },
  "mainSkillName": "Whirling Assault",
  "sections": ["metadata", "equipment", "skills", "sidebar", "warnings"]
}
```

Rules:

- `live` must use `PoEAPI` and `ImportTab`; never read `Settings.xml`.
- `cached_json` must require an explicit path or use the known `poe_api_response.json` path and return file mtime.
- Return `source`, `characterName`, `league`, `level`, `importTime`, `cachePath`, and item name signatures.

### `pob_get_state`

Reads build state and calculated output.

```json
{
  "sections": [
    "metadata",
    "import",
    "equipment",
    "skills",
    "tree",
    "config",
    "calcs",
    "sidebar",
    "warnings",
    "schemas",
    "skillCalcs"
  ],
  "stats": ["AverageDamage", "Speed", "PreEffectiveCritChance", "TotalEHP", "Str", "ReqStr"],
  "mainSkillName": "Whirling Assault",
  "mainSocketGroup": 5,
  "activeSkill": 1,
  "skillCalcs": {
    "targets": [
      { "socketGroup": 1, "activeSkill": 1 },
      { "socketGroup": 5, "activeSkill": 1 }
    ],
    "includeSidebar": false
  },
  "includeRawItems": false,
  "includeHiddenSlots": false
}
```

Recommended default sections for current-character questions:

```json
["metadata", "equipment", "skills", "config", "calcs", "sidebar", "warnings"]
```

Important `get` behavior:

- `sidebar` must be generated from `BuildDisplayStats.lua` metadata and `mainOutput`, matching `RefreshStatList`.
- `warnings` must come from existing warning generation, including requirement warnings like `ReqStr > Str`.
- `schemas.config` must be generated from `Modules/ConfigOptions.lua`.
- `schemas.stat` should include `BuildDisplayStats.lua` and `Data.powerStatList` entries.
- `equipment` may return all equipment at once; it is small enough and avoids stale slot assumptions.
- `mainSkillName` selects the highest-scored active skill match. If the name is ambiguous, pass `mainSocketGroup` and `activeSkill` explicitly.
- `skillCalcs` loops over requested skill targets and returns per-skill output/warnings without implementing skill rules outside PoB.

### `pob_simulate_changes`

Applies temporary changes through existing calculators and returns diffs. It must not mutate the active build.

```json
{
  "baseSnapshotId": "optional",
  "changes": [
    {
      "domain": "items",
      "action": "replace_raw",
      "slot": "Ring 1",
      "raw": "Rarity: RARE\n..."
    },
    {
      "domain": "config",
      "action": "set_input",
      "var": "enemyIsBoss",
      "value": "Pinnacle"
    },
    {
      "domain": "tree",
      "action": "add_nodes",
      "nodeIds": [12345]
    }
  ],
  "stats": ["AverageDamage", "CombinedDPS", "TotalEHP", "Str", "FireResist", "ColdResist", "LightningResist"],
  "mainSkillName": "Whirling Assault",
  "sections": ["metadata", "equipment", "calcs", "sidebar", "warnings"]
}
```

Implementation rules:

- Item replacement uses existing item parsing/equipment APIs in a transient runtime: `new("Item", raw)`, `ItemsTab:AddItem`, `ItemSlotControl:SetSelItemId`, `ItemsTab:PopulateSlots`.
- Node add/remove is not implemented in v0.1.
- For config simulation, set existing `configSets[activeConfigSetId].input[var]`, rebuild, and return the transient diff.
- Return base value, new value, absolute delta, and percent delta for every requested stat.

### `pob_set_state`

Commits existing PoB state changes. Default mode should still be `sandbox`; actual commit must be explicit.

```json
{
  "mode": "sandbox|commit",
  "changes": [
    {
      "domain": "items",
      "action": "replace_raw",
      "slot": "Ring 2",
      "raw": "Rarity: RARE\n..."
    },
    {
      "domain": "skills",
      "action": "select_main",
      "socketGroup": 1,
      "activeSkill": 1
    },
    {
      "domain": "config",
      "action": "set_input",
      "var": "enemyIsBoss",
      "value": "Pinnacle",
      "configSetId": 1
    }
  ],
  "outputPath": "required only for mode=commit",
  "sections": ["metadata", "equipment", "calcs", "sidebar", "warnings"]
}
```

Implemented actions for v0.1:

| Domain | Action | Existing method/path |
| --- | --- | --- |
| `config` | `set_active_config_set`, `set_input`, `set_placeholder` | `SetActiveConfigSet`, `configSets[id].input`, `BuildModList` |
| `items` | `set_active_item_set`, `replace_raw`, `equip_raw`, `clear` | `SetActiveItemSet`, `AddItem`, `SetSelItemId`, `PopulateSlots` |
| `skills` | `select_main` | existing socket group `mainActiveSkill` fields |

Defer these until separately implemented and tested:

- Build-level setters such as character level.
- Calcs-tab-only inputs such as buff mode and show minion.
- Tree allocation edits.
- Creating/deleting skill sets, item sets, or passive specs.
- Editing raw passive tree allocation in a committed build.
- Creating gems from scratch.
- Editing notes and party buffs.
- Writing or reading auth settings.

### `pob_stat_weights`

Wraps existing stat weight generation.

```json
{
  "inputPath": "optional cached character JSON path",
  "outputDir": "stat-weight-reports",
  "mainSkill": "optional skill name",
  "dpsMetric": "CombinedDPS",
  "calibrationPath": "optional",
  "returnRows": 20
}
```

Rules:

- Use `Modules/StatWeightReport.lua` when possible.
- This tool returns PoB/build weights only. Trade search and seller filtering are outside PoB MCP.

## Rebuild And Save Rules

After any committed state change:

1. Use the owning tab method when it exists.
2. Set `build.buildFlag = true`.
3. Rebuild by following the existing frame path or explicitly call:

```lua
build.configTab:BuildModList()
build.calcsTab:BuildOutput()
build:RefreshStatList()
```

4. Return the changed state and warnings.
5. Save only when `save: true`. Saving must use `buildMode:SaveDBFile()` or `SaveDB`, not hand-written XML.

## Freshness And Refusal Rules

Every response must include:

- `sourceType`: `live`, `cached_json`, `xml`, or `current_memory`.
- `sourcePath` when file-based.
- `sourceMTime` when file-based.
- `characterName`, `league`, `level` when known.
- `equipmentSignature`: slot names and item names for equipped items.
- `outputRevision` when available.

The MCP server should refuse or mark results stale when:

- The user says the character changed but no successful import happened after that.
- The current equipment signature does not match the user's described current gear.
- The source is `cached_json` or XML and the user asked for "current" without accepting cache.
- Required slot names or config vars do not exist in current PoB schema.

## Non-Goals

- Do not call trade search APIs from PoB MCP.
- Do not whisper, price check, or select sellers.
- Do not implement independent POE calculations.
- Do not parse or expose OAuth tokens, cookies, `Settings.xml`, or account secrets.
- Do not mutate Lua tables by arbitrary JSON path from the MCP client.
