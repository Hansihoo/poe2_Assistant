# Chat Memory

This file is a rolling, concise memory of user questions, assistant answers,
decisions, and project flow for this repository.

Use it so another Codex chat can quickly understand what happened recently
without reading full chat transcripts.

Rules:

- Keep at most the latest 150 entries.
- Keep entries short: question, answer/decision, touched files, and follow-up.
- Do not store secrets, cookies, tokens, PoB `Settings.xml`, or private account
  data.
- Store reusable POE2 game/build/trade knowledge in the external POE2 warehouse;
  use this file for conversation flow and repo/project decisions.
- Update this file after meaningful repo changes, setup decisions, or POE2
  assistant workflow decisions.

Use:

```powershell
.\tools\update-chat-memory.ps1 `
  -Topic "short topic" `
  -Question "what the user asked" `
  -Answer "what was decided or done" `
  -Files "important files changed" `
  -Next "next thing to remember"
```

<!-- CHAT_MEMORY_ENTRY -->
## 2026-06-03 - Personal PoB2 Fork Strategy

- Q: The user asked whether a separate repo is better when keeping custom PoB2 changes while merging official PoB2 updates.
- A: Recommended a personal fork as `origin` and the official PoB2 repo as `upstream`, with local custom work on a separate branch and `git rerere` enabled.
- Files: none.
- Next: Keep official updates coming from `upstream/dev`; keep local custom changes on the personal branch.

<!-- CHAT_MEMORY_ENTRY -->
## 2026-06-03 - Hansihoo/POB2 Fork Setup

- Q: The user created `https://github.com/Hansihoo/POB2` and asked to reflect this project there with README information for POE2 assistant usage.
- A: Added repository identity/docs, Codex project instructions, Korean overlay sources, ignore rules for local artifacts, configured `origin=Hansihoo/POB2`, `upstream=PathOfBuildingCommunity/PathOfBuilding-PoE2`, and pushed `custom` as the default branch.
- Files: `README.md`, `AGENTS.md`, `.gitignore`, `.gitattributes`, Korean overlay files, localization generators, SimpleGraphic patch.
- Next: Merge official PoB2 changes from `upstream/dev` into `custom` when needed.

<!-- CHAT_MEMORY_ENTRY -->
## 2026-06-03 - Local Artifact Folder Policy

- Q: The user noticed tests and POE2 assistant outputs were being written anywhere and asked to manage them in a specific folder with deletion support.
- A: Standardized generated local outputs under `work/`, changed stat-weight defaults to `work/stat-weight-reports`, changed MCP scratch output to `work/mcp/tmp`, added `ensure-workdirs` and cleanup scripts, and documented the policy in `AGENTS.md`.
- Files: `AGENTS.md`, `README.md`, `.gitignore`, `work/README.md`, `tools/ensure-workdirs.ps1`, `tools/clean-local-artifacts.ps1`, `PathOfBuilding-PoE2-StatWeights.cmd`, `tools/pob-mcp/server.js`.
- Next: Do not create new root-level `work_*` files; preview cleanup with `.\tools\clean-local-artifacts.ps1 -WhatIf`.

<!-- CHAT_MEMORY_ENTRY -->
## 2026-06-03 - Rolling Chat Memory

- Q: The user asked to briefly summarize recent questions and answers, around the latest 150, so other chat windows can follow the same conversation flow.
- A: Created this rolling chat memory file and a PowerShell updater that appends concise entries while pruning to the latest 150.
- Files: `docs/chat-memory.md`, `tools/update-chat-memory.ps1`, `AGENTS.md`.
- Next: Read this file at the start of future project chats and update it after meaningful decisions or repo changes.
