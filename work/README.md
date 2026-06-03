# Local Work Directory

This directory is the approved place for local POE2 assistant scratch outputs
from tests, trade checks, PoB comparisons, MCP request/response files,
screenshots, and generated stat-weight reports.

Keep generated contents out of git. The repo tracks only this README.

Recommended layout:

```text
work/
  legacy-root/          old root-level work_* artifacts moved here
  mcp/tmp/              MCP bridge request/output scratch files
  pob/                  temporary PoB XML/build comparison outputs
  screenshots/          local screenshots
  stat-weight-reports/  latest.json and latest.md from stat weights
  tmp/                  one-off scratch files
  trade/                trade query/search/fetch snapshots
```

Use:

```powershell
.\tools\ensure-workdirs.ps1
.\tools\clean-local-artifacts.ps1 -WhatIf
.\tools\clean-local-artifacts.ps1
.\tools\ensure-workdirs.ps1
```

Do not write new `work_*` files into the repository root. If a quick script
needs an output path, use `work/tmp/<name>` or a more specific `work/` subfolder.
