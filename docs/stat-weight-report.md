# Stat Weight Report

Generate a current-character DPS/EHP stat-weight report with:

```bat
PathOfBuilding-PoE2-StatWeights.cmd
```

The launcher starts the normal runtime, imports `src/poe_api_response.json`, adds one temporary custom modifier at a time, and writes:

```text
stat-weight-reports/latest.md
stat-weight-reports/latest.json
```

Optional environment variables:

```bat
set POB_STAT_INPUT=D:\path\to\poe_api_response.json
set POB_STAT_OUTPUT_DIR=D:\path\to\reports
set POB_STAT_MAIN_SKILL=Whirling Assault
set POB_STAT_DPS_METRIC=CombinedDPS
set POB_STAT_CALIBRATION=D:\path\to\calibration.json
PathOfBuilding-PoE2-StatWeights.cmd
```

`CombinedDPS` is the default DPS metric because it matches the currently selected main skill. `TotalEHP` is used for defensive weight output.

The report values are relative gains:

```text
1% increased Attack Damage -> +0.23% CombinedDPS
```

Flat stats use the unit shown in the report, such as `+10 Life` or `+5 Strength`.

Known limitation: if PoB2 does not fully support the selected skill's mechanic, the measured DPS weights inherit that limitation. For the current Hollow Form / Whirling setup, use the existing cached calibration as a cross-check until direct skill calculation support is complete.

If direct PoB DPS is zero because the imported skill is not supported, the launcher automatically tries Theo's current Hollow/Whirling calibration JSON and marks DPS rows as `calibration`.
