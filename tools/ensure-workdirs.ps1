[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$repoRootPath = (Resolve-Path -LiteralPath $RepoRoot).Path
$workRoot = Join-Path $repoRootPath 'work'

$dirs = @(
    'mcp',
    'mcp\tmp',
    'pob',
    'screenshots',
    'stat-weight-reports',
    'tmp',
    'trade'
)

New-Item -ItemType Directory -Path $workRoot -Force | Out-Null
foreach ($dir in $dirs) {
    New-Item -ItemType Directory -Path (Join-Path $workRoot $dir) -Force | Out-Null
}

Write-Output "Work directories are ready under $workRoot"
