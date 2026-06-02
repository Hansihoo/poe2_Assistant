# PoB Git Management

This repository tracks the official Path of Building-PoE2 repository while carrying local Theo/Codex changes. Treat the official remote as read-only and keep local changes on named patch branches.

## Current Local Shape

As of 2026-06-03:

- `origin` points to the official repository: `https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2.git`
- `origin/HEAD` points to `origin/dev`
- Current local branch: `codex/poe2-import-fixes-20260601`
- This branch is ahead of `origin/dev` by local commits and is intended to carry local fixes.

Because `origin` is the official repo, do not push local work to `origin`.

## Remote Policy

Use one of these setups.

Recommended safest setup:

```powershell
git remote set-url --push origin DISABLED
git remote add theo <your-fork-url>
git fetch origin
git fetch theo
```

Then push personal branches only to the fork:

```powershell
git push -u theo codex/poe2-import-fixes-20260601
```

Alternative if there is no fork:

```powershell
git remote set-url --push origin DISABLED
```

This still allows official updates with `git fetch origin`, but makes accidental `git push origin ...` fail.

## Branch Roles

Use these branch roles:

| Branch | Role | Rule |
| --- | --- | --- |
| `dev` | local mirror of official `origin/dev` | Do not edit manually. Fast-forward/reset only after confirming no local work. |
| `codex/base-sync-*` | temporary merge/rebase branch | Used only while resolving official updates. |
| `codex/poe2-import-fixes-*` | durable local patch branch | Local import fixes and reusable PoB tooling. |
| `codex/ko-runtime-*` | durable local Korean overlay branch | Korean launch/runtime/localization files. |
| `codex/mcp-*` | MCP implementation branch | PoB MCP wrapper work. |
| `codex/experiment-*` | disposable branch | Trade tests, harnesses, one-off probes. |

Avoid committing unrelated work into one branch. Import fixes, Korean overlay, MCP server, and generated trade/test files should stay separate.

## Update Workflow

Before updating:

```powershell
git status --short
```

If the tree is dirty, either commit intentional source/docs changes or stash/discard generated work files. Do not update while important untracked files are mixed with source changes.

Fetch official updates:

```powershell
git fetch origin
```

Update the local official mirror:

```powershell
git switch dev
git merge --ff-only origin/dev
```

Update a local patch branch:

```powershell
git switch codex/poe2-import-fixes-20260601
git merge origin/dev
```

Prefer merge for long-lived local branches. It preserves the fact that local changes were carried across official updates. Use rebase only for short-lived branches or before opening a clean PR.

After resolving conflicts:

```powershell
git status --short
git diff --check
```

Run the relevant verification command for the touched area.

## Keeping Local Changes Portable

Keep local changes in small commits by topic:

```text
fix(import): handle transformed POE2 items
data(bases): add Fists of Stone glove base
tool(stat-weights): add current-character stat weight report
docs(mcp): document PoB get/set MCP parameters
local(ko): add Korean launch overlay
```

Useful audit commands:

```powershell
git log --oneline --left-right --cherry-pick origin/dev...HEAD
git diff --stat origin/dev...HEAD
git diff --name-status origin/dev...HEAD
```

These show exactly what local work must survive the next official update.

## Generated Files

Do not commit routine generated files unless they are intentional fixtures or documentation inputs.

Usually ignore or keep out of commits:

```text
work_*.json
work_*.txt
work_*.png
work_*_tests/
stat-weight-reports/latest.*
```

If a generated file becomes a durable calibration or fixture, move it to a clear docs/data path and commit it intentionally.

## Conflict Policy

When official updates conflict with local work:

1. Prefer official upstream code for core POE rules and data.
2. Re-apply only local compatibility wrappers, Korean overlay hooks, MCP wrappers, or documented user-specific tooling.
3. Do not silently keep local POE mechanics if upstream has changed the same mechanic.
4. Re-run PoB import/calculation checks after conflict resolution.

## Safe Default Commands

Daily status:

```powershell
git status --short
git branch -vv
git log --oneline --left-right --cherry-pick origin/dev...HEAD
```

Official update:

```powershell
git fetch origin
git switch dev
git merge --ff-only origin/dev
git switch codex/poe2-import-fixes-20260601
git merge origin/dev
```

Push local branch to fork:

```powershell
git push -u theo HEAD
```

Never use these unless explicitly intended:

```powershell
git reset --hard
git checkout -- .
git clean -fd
git push origin HEAD
```
