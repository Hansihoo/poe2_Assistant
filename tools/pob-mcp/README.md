# PoB2 MCP Bridge

This is a small stdio MCP server for local Path of Building-PoE2 analysis.

It deliberately does not implement Path of Exile rules. It starts the bundled
PoB runtime, loads `src/LaunchMcpBridge.lua`, and uses existing PoB APIs for:

- importing cached character JSON or XML builds
- equipping temporary raw items
- changing config inputs
- selecting a main skill group
- rebuilding PoB calculations
- reading sidebar/calculation/warning state
- running the existing stat-weight report launcher

## Configure

Add this server command to your MCP client:

```json
{
  "mcpServers": {
    "pob2": {
      "command": "<this-repo>\\PathOfBuilding-PoE2-MCP.cmd"
    }
  }
}
```

No npm install is required. The server is dependency-free Node.js.

## Tools

- `pob_import_current`: imports a build and returns selected state. In v1,
  default source is the local cached `src/poe_api_response.json`; live OAuth
  import is not used because this bridge must not read PoB `Settings.xml`.
- `pob_get_state`: returns selected sections from a cached JSON or XML build.
- `pob_simulate_changes`: applies temporary changes and returns baseline,
  after, and diff values. The source build is not saved.
- `pob_set_state`: `mode=sandbox` behaves like simulation. `mode=commit`
  writes XML only when `outputPath` is explicitly supplied.
- `pob_stat_weights`: runs `PathOfBuilding-PoE2-StatWeights.cmd` and returns
  `work/stat-weight-reports/latest.json`.

MCP request/output scratch files are written under `work/mcp/tmp` by default.
Set `POB_MCP_TMP_DIR` if you need a different temporary directory.

## Common State Sections

Use `sections` to keep responses small:

```json
["metadata", "equipment", "skills", "calcs", "sidebar", "warnings", "config", "schemas", "skillCalcs"]
```

Use `stats` to request exact PoB output keys:

```json
[
  "AverageDamage",
  "Speed",
  "PreEffectiveCritChance",
  "CritMultiplier",
  "HitChance",
  "CombinedDPS",
  "Str",
  "ReqStr",
  "FireResist",
  "ColdResist",
  "LightningResist",
  "ChaosResist"
]
```

## Example: Get Current Cached State

```json
{
  "source": "cached_json",
  "mainSkillName": "Whirling Assault",
  "sections": ["metadata", "equipment", "calcs", "sidebar", "warnings"],
  "stats": ["AverageDamage", "CombinedDPS", "Str", "ReqStr", "FireResist", "ColdResist", "LightningResist"]
}
```

If the imported build has multiple skills with similar names, you can select
the exact PoB sidebar skill by index:

```json
{
  "source": "cached_json",
  "mainSocketGroup": 5,
  "activeSkill": 1,
  "sections": ["metadata", "calcs", "sidebar"],
  "stats": ["AverageDamage", "Speed", "PreEffectiveCritChance", "CritMultiplier", "HitChance"]
}
```

## Example: Compare Skill Outputs

```json
{
  "source": "cached_json",
  "sections": ["skillCalcs"],
  "skillCalcs": {
    "targets": [
      { "socketGroup": 1, "activeSkill": 1 },
      { "socketGroup": 5, "activeSkill": 1 }
    ]
  },
  "stats": ["AverageDamage", "CombinedDPS", "Speed", "Str", "ReqStr"]
}
```

## Example: Test Two Rings

```json
{
  "source": "cached_json",
  "mainSkillName": "Whirling Assault",
  "changes": [
    {
      "domain": "items",
      "action": "replace_raw",
      "slot": "Ring 1",
      "raw": "Rarity: Rare\nExample Ring\nAmethyst Ring\n--------\nRequires Level 65\n--------\n+13% to Chaos Resistance\n--------\n25% increased Rarity of Items found"
    },
    {
      "domain": "items",
      "action": "replace_raw",
      "slot": "Ring 2",
      "raw": "Rarity: Rare\nExample Band\nSapphire Ring\n--------\nRequires Level 65\n--------\n+20% to Cold Resistance\n--------\n25% increased Rarity of Items found"
    }
  ],
  "sections": ["metadata", "equipment", "calcs", "sidebar", "warnings"],
  "stats": ["AverageDamage", "CombinedDPS", "Str", "ReqStr", "FireResist", "ColdResist", "LightningResist", "ChaosResist"]
}
```
