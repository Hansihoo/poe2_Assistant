[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [switch]$IncludeCharacterCache,
    [switch]$IncludeRuntimeKo
)

$repoRootPath = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $RepoRoot).Path)
$repoPrefix = $repoRootPath.TrimEnd('\') + '\'

function Resolve-ExistingSafePath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $resolved) {
        return $null
    }

    $fullPath = [System.IO.Path]::GetFullPath($resolved.Path)
    if ($fullPath -ne $repoRootPath -and -not $fullPath.StartsWith($repoPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove path outside repository: $fullPath"
    }
    return $fullPath
}

function Add-Target {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$Targets,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $safePath = Resolve-ExistingSafePath -Path $Path
    if ($safePath) {
        $Targets.Add($safePath)
    }
}

$targets = [System.Collections.Generic.List[string]]::new()

$rootArtifacts = Get-ChildItem -LiteralPath $repoRootPath -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like 'work_*' }
foreach ($item in $rootArtifacts) {
    Add-Target -Targets $targets -Path $item.FullName
}

$workRoot = Join-Path $repoRootPath 'work'
if (Test-Path -LiteralPath $workRoot) {
    $workChildren = Get-ChildItem -LiteralPath $workRoot -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne 'README.md' }
    foreach ($item in $workChildren) {
        Add-Target -Targets $targets -Path $item.FullName
    }
}

foreach ($relative in @(
    'stat-weight-reports',
    '.pytest_cache',
    'tests\__pycache__',
    'tools\__pycache__'
)) {
    Add-Target -Targets $targets -Path (Join-Path $repoRootPath $relative)
}

if ($IncludeCharacterCache) {
    Add-Target -Targets $targets -Path (Join-Path $repoRootPath 'src\poe_api_response.json')
}

if ($IncludeRuntimeKo) {
    Add-Target -Targets $targets -Path (Join-Path $repoRootPath 'runtime-ko')
}

$uniqueTargets = $targets | Sort-Object -Unique
if (-not $uniqueTargets) {
    Write-Output "No local artifacts found."
    return
}

foreach ($target in $uniqueTargets) {
    if ($PSCmdlet.ShouldProcess($target, 'Remove local generated artifact')) {
        Remove-Item -LiteralPath $target -Recurse -Force
    }
}

Write-Output ("Matched {0} local artifact path(s)." -f $uniqueTargets.Count)
