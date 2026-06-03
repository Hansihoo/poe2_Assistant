# Hansihoo POB2

This repository is Theo/Hansihoo's personal Path of Building-PoE2 fork.

It is not meant to replace the official PoB2 project. The main use is to keep a
local PoB2 calculation/import engine that Codex can combine with Korean POE2
assistant notes, trade metadata, current-character snapshots, MCP tools, and
item-search workflows.

Official upstream:
[PathOfBuildingCommunity/PathOfBuilding-PoE2](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2)

Personal fork:
[Hansihoo/POB2](https://github.com/Hansihoo/POB2)

## Repository Role

This fork keeps:

- official PoB2 source and history;
- local PoB2 compatibility fixes used by the assistant;
- the PoB2 MCP bridge in `tools/pob-mcp`;
- stat-weight tooling for current-character item searches;
- Korean render-localization source, generators, and notes;
- Codex project instructions in `AGENTS.md`;
- documentation for recreating the POE2 assistant context on another computer.

This fork intentionally does not store:

- PoB `Settings.xml`, OAuth tokens, cookies, or account secrets;
- `src/poe_api_response.json` character API cache;
- local generated contents under `work/`;
- legacy root `work_*` trade/search/debug outputs;
- legacy root `stat-weight-reports/` generated reports;
- `runtime-ko/` binaries and generated font atlases.

## Git Remote Layout

Use this repository as `origin` and the official project as `upstream`:

```powershell
git remote add origin https://github.com/Hansihoo/POB2.git
git remote add upstream https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2.git
git fetch --all --prune
git config rerere.enabled true
```

If this checkout was cloned from the official repo first:

```powershell
git remote rename origin upstream
git remote add origin https://github.com/Hansihoo/POB2.git
git fetch --all --prune
```

The official default branch is `dev`. To bring official changes into the local
custom branch:

```powershell
git fetch upstream
git checkout custom
git merge upstream/dev
```

Keep official changes in `upstream/dev`; keep local assistant/PoB2 changes on a
custom branch such as `custom` and push that branch to `origin`.

## Setup On Another Computer

1. Clone this fork.

```powershell
git clone https://github.com/Hansihoo/POB2.git
cd POB2
git checkout custom
git remote add upstream https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2.git
git fetch --all --prune
git config rerere.enabled true
```

2. Configure Codex MCP for the PoB2 bridge.

```json
{
  "mcpServers": {
    "pob2": {
      "command": "D:\\path\\to\\POB2\\PathOfBuilding-PoE2-MCP.cmd"
    }
  }
}
```

3. Sync or recreate the POE2 assistant knowledge warehouse.

The current local warehouse lives outside this repo:

```text
C:\Users\Theo\Documents\0_MD_Data\poe\poe2
```

At minimum, another computer should provide these files or equivalent files and
update the local Codex `poe2-assistant` skill paths if the location changes:

- `poe2_assistant_data_warehouse.md`
- `poe2_codex_assist_skill_notes.md`
- `poe2_fast_item_weight_scoring.md`
- `current-character/current_account_profile.md`
- `current-character/current_character_snapshot.md`
- `current-character/current_import_status.md`
- `trade-locale/poe2-trade-locale-data.md`
- `trade-locale/references/trade-search-guide.md`
- `trade-locale/data/ko_aliases.json`
- `trade-locale/data/trade_request_guard.json`
- `build-calibrations/*.json`

Do not copy secrets, cookies, account tokens, or PoB `Settings.xml` contents
into the warehouse or this repo.

4. Configure the Codex `poe2-assistant` skill to point at:

```text
PoB2 project: <this repo path>
POE2 notes root: <your poe2 warehouse path>
Trade locale root: <your poe2 warehouse path>\trade-locale
Current character files: <your poe2 warehouse path>\current-character
```

5. Use the assistant workflow.

- For current-character analysis, refresh/import the character through local
  PoB2, then use `PathOfBuilding-PoE2-MCP.cmd`.
- For item upgrade searches, run `PathOfBuilding-PoE2-StatWeights.cmd`, read
  `work/stat-weight-reports/latest.json`, and build official trade weighted-sum
  filters from the useful stat weights.
- For live prices, exchange rates, poe.ninja meta, and trade listings, refresh
  the data and record the snapshot date.
- For official trade searches, prefer the already logged-in browser trade tab;
  do not store or read POESESSID/cookies.
- For Korean POE2 answers, normalize Korean terms to canonical English POE2
  names/stat IDs, then answer in Korean with assumptions and sources.

6. Keep local generated outputs in `work/`.

```powershell
.\tools\ensure-workdirs.ps1
.\tools\clean-local-artifacts.ps1 -WhatIf
.\tools\clean-local-artifacts.ps1
.\tools\ensure-workdirs.ps1
```

Do not write new `work_*` files into the repository root. Use `work/tmp`,
`work/trade`, `work/pob`, `work/screenshots`, `work/mcp/tmp`, or
`work/stat-weight-reports` depending on the output type.

## Cross-Chat Memory

Use `docs/chat-memory.md` to keep a short rolling summary of recent questions,
answers, decisions, and project flow. It is intended for continuity between
Codex chat windows, not as a full transcript.

Append a new entry after meaningful work:

```powershell
.\tools\update-chat-memory.ps1 `
  -Topic "short topic" `
  -Question "what the user asked" `
  -Answer "what was decided or done" `
  -Files "important files changed" `
  -Next "next thing to remember"
```

The file should stay at the latest 150 entries and must not contain secrets,
tokens, cookies, PoB `Settings.xml`, or private account data.

## Korean Display Overlay

The Korean overlay is display-only. It keeps PoB's internal build data,
modifier parser, calculations, and saved builds in English, then translates text
at render time.

Tracked source files:

- `PathOfBuilding-PoE2-KR.cmd`
- `src/LaunchKorean.lua`
- `src/Modules/Localization.lua`
- `src/Modules/Localization/ko.lua`
- `src/Modules/Localization/ko_official_generated.lua`
- `src/Modules/Localization/ko_user.lua`
- `tools/generate_korean_fonts.py`
- `tools/generate_official_korean_locale.py`
- `tools/patches/simplegraphic-unicode-glyphs.patch`
- `docs/korean-render-localization.md`

`runtime-ko/` is ignored because it contains local binaries and generated font
atlases. Rebuild or copy a trusted local Korean runtime before using:

```powershell
python .\tools\generate_official_korean_locale.py
python .\tools\generate_korean_fonts.py --output .\runtime-ko\SimpleGraphic\Fonts
```

Then launch with:

```powershell
.\PathOfBuilding-PoE2-KR.cmd
```

## Assistant Context To Keep Updated

For future questions to work on any computer, keep these facts current in the
warehouse, not in chat memory:

- current account, league, character, class, ascendancy, and active build;
- current gear, skills, passive/tree state, and import status;
- known PoB2 limitations and local compatibility patches;
- current build caveats, such as Martial Artist Hollow Form / Whirling Assault
  / Tempest Bell calculation gaps;
- measured stat weights and calibration JSON for the active build;
- Korean aliases, official Korean/English trade stat mappings, and item/base
  translations;
- trade-search templates, cooldown/rate-limit guard state, and dated market
  snapshots;
- poe.ninja or meta references with dates;
- reusable decisions from previous POE2 research.

After useful POE2 work, write reusable information to a Markdown or JSON file in
the warehouse. If the destination is unclear, append a short dated note to
`poe2_assistant_learning_log.md`.

# Path of Building 2 Community
## Welcome to Path of Building 2, an offline build planner for Path of Exile 2!

<p float="middle">
  <img alt="Tree tab" src="https://github.com/user-attachments/assets/225bf25f-1ac4-4639-b280-565a24d2a2fc" width="48%" />
  <img alt="Items tab" src="https://github.com/user-attachments/assets/de8e6dc0-1e1a-46c5-b8a4-18877e67d48d" width="48%" />
</p>

## Download
Head over to the [Releases](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/releases) page to download the install wizard or portable zip.

## Features
* Comprehensive offence + defence calculations:
  * Calculate your skill DPS, damage over time, life/mana/ES totals and much more!
  * Can factor in auras, buffs, charges, curses, monster resistances and more, to estimate your effective DPS
  * Also calculates life/mana reservations
  * Shows a summary of character stats in the side bar, as well as a detailed calculations breakdown tab which can show you how the stats were derived
  * Supports all skills and support gems, and most passives and item modifiers
    * Throughout the program, supported modifiers will show in blue and unsupported ones in red
  * Full support for minions
  * Support for party play and support builds
* Passive skill tree planner:
  * Support for jewels including most radius/conversion and timeless jewels
  * Features alternate path tracing (mouse over a sequence of nodes while holding shift, then click to allocate them all)
  * Fully integrated with the offence/defence calculations; see exactly how each node will affect your character!
  * Can import PathOfExile.com and PoEPlanner.com passive tree links; links shortened with PoEURL.com also work
* Skill planner:
  * Add any number of main or supporting skills to your build
  * Supporting skills (auras, curses, buffs) can be toggled on and off
  * Automatically applies Socketed Gem modifiers from the item a skill is socketed into
  * Automatically applies support gems granted by items
* Item planner:
  * Add items from in game by copying and pasting them straight into the program!
  * Automatically adds quality to non-corrupted items
  * Search the trade site for the most impactful items
  * Fully integrated with the offence/defence calculations; see exactly how much of an upgrade a given item is!
  * Contains a searchable database of all uniques that are currently in game (and some that aren't yet!)
    * You can choose the modifier rolls when you add a unique to your build
    * Includes all league-specific items and legacy variants
  * Features an item crafting system:
    * You can select from any of the game's base item types
    * You can select prefix/suffix modifiers from lists
    * Custom modifiers can be added, with Master and Essence modifiers available
  * Also contains a database of rare item templates:
    * Allows you to create rare items for your build to approximate the gear you will be using
    * Choose which modifiers appear on each item, and the rolls for each modifier, to suit your needs
    * Has templates that should cover the majority of builds
* Other features:
  * You can import passive tree, items, and skills from existing characters
  * Share builds with other users by generating a share code
  * Automatic updating; most updates will only take a couple of seconds to apply

## Changelog
You can find the full version history [here](CHANGELOG.md).

## Contribute
You can find instructions on how to contribute code and bug reports [here](CONTRIBUTING.md).

## Licence
[MIT](https://opensource.org/licenses/MIT)

For 3rd-party licences, see [LICENSE](LICENSE.md).
The licencing information is considered to be part of the documentation.
