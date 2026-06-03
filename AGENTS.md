# Hansihoo POB2 Codex Notes

This repository is Theo/Hansihoo's personal fork of
`PathOfBuildingCommunity/PathOfBuilding-PoE2`.

Use it as a local PoB2 calculation/import engine for the Korean POE2 assistant,
not as a plain upstream-only PoB2 checkout.

## POE2 Assistant Context

- For POE2 build, item, trade, Korean translation, poe.ninja, or current
  character questions, use the local `poe2-assistant` skill when available.
- Answer user-facing POE2 results in Korean.
- Treat prices, exchange rates, trade listings, league state, and meta/ranking
  data as volatile. Refresh live data or state the snapshot date.
- Keep reusable POE2 findings in the external knowledge warehouse instead of
  relying on chat memory.

Current local warehouse paths:

```text
C:\Users\Theo\Documents\0_MD_Data\poe\poe2
C:\Users\Theo\Documents\0_MD_Data\poe\poe2\current-character
C:\Users\Theo\Documents\0_MD_Data\poe\poe2\trade-locale
```

If this repo is moved to another computer, update the local Codex
`poe2-assistant` skill paths to match the new PoB2 checkout and warehouse
location.

## Safety

- Never read, print, commit, or summarize PoB `Settings.xml`.
- Never store OAuth tokens, cookies, POESESSID, account secrets, or browser
  session data in this repo.
- Do not commit `src/poe_api_response.json`, generated `work/` contents,
  legacy root `stat-weight-reports/`, legacy root `work_*` files, or
  `runtime-ko/`.
- For official trade searches, prefer the user's already logged-in browser tab.
  Do not use direct trade search/fetch API calls unless the user explicitly asks
  and accepts rate-limit/account risk.

## Local Output Policy

- Put every local test, trade, PoB comparison, MCP scratch, screenshot, and
  generated report under `work/`.
- Use `work/stat-weight-reports/latest.json` for stat-weight output.
- Use `work/trade/` for trade search/fetch snapshots.
- Use `work/pob/` for temporary XML/build comparison outputs.
- Use `work/screenshots/` for local screenshots.
- Use `work/tmp/` for one-off scratch files.
- Use `work/mcp/tmp/` for MCP request/response scratch files.
- Do not create new root-level `work_*` files.
- Before deleting local artifacts, preview with
  `.\tools\clean-local-artifacts.ps1 -WhatIf`; then run
  `.\tools\clean-local-artifacts.ps1`.
- Use `.\tools\ensure-workdirs.ps1` to recreate the standard `work/` subfolders.

## Local Tools

- PoB2 MCP bridge: `PathOfBuilding-PoE2-MCP.cmd`
- MCP server source: `tools/pob-mcp/server.js`
- MCP usage notes: `tools/pob-mcp/README.md`
- Stat weights launcher: `PathOfBuilding-PoE2-StatWeights.cmd`
- Work directory setup: `tools/ensure-workdirs.ps1`
- Local artifact cleanup: `tools/clean-local-artifacts.ps1`
- Korean display launcher: `PathOfBuilding-PoE2-KR.cmd`
- Korean localization notes: `docs/korean-render-localization.md`

The Korean overlay is display-only. It must not alter PoB's internal English
build data, item parser, calculations, or saved build files.

## Git

- `origin` should point to `https://github.com/Hansihoo/POB2.git`.
- `upstream` should point to
  `https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2.git`.
- The official default branch is `upstream/dev`.
- Keep local assistant/custom patches on a custom branch and merge
  `upstream/dev` into it when official PoB2 updates are needed.
- Enable conflict reuse with `git config rerere.enabled true`.
