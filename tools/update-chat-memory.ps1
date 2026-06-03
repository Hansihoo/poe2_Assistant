[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [int]$Limit = 150,
    [string]$Topic,
    [string]$Question,
    [string]$Answer,
    [string]$Files = 'none',
    [string]$Next = 'none',
    [switch]$PruneOnly
)

$repoRootPath = (Resolve-Path -LiteralPath $RepoRoot).Path
$memoryPath = Join-Path $repoRootPath 'docs\chat-memory.md'
$marker = '<!-- CHAT_MEMORY_ENTRY -->'

if (-not (Test-Path -LiteralPath $memoryPath)) {
    throw "Missing chat memory file: $memoryPath"
}

if (-not $PruneOnly) {
    foreach ($required in @('Topic', 'Question', 'Answer')) {
        if ([string]::IsNullOrWhiteSpace((Get-Variable -Name $required).Value)) {
            throw "Missing required parameter: -$required"
        }
    }
}

$content = Get-Content -LiteralPath $memoryPath -Raw
$parts = [regex]::Split($content, "(?m)^$([regex]::Escape($marker))\r?\n")
$header = $parts[0].TrimEnd()
$entries = @()
if ($parts.Count -gt 1) {
    $entries = $parts[1..($parts.Count - 1)] |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { $_.Trim() }
}

if (-not $PruneOnly) {
    $date = Get-Date -Format 'yyyy-MM-dd'
    $entry = @"
## $date - $Topic

- Q: $Question
- A: $Answer
- Files: $Files
- Next: $Next
"@.Trim()

    $entries += $entry
}

if ($entries.Count -gt $Limit) {
    $entries = $entries | Select-Object -Last $Limit
}

$body = if ($entries.Count -gt 0) {
    ($entries | ForEach-Object { "$marker`r`n$_" }) -join "`r`n`r`n"
} else {
    ''
}

$newContent = if ($body) {
    "$header`r`n`r`n$body`r`n"
} else {
    "$header`r`n"
}

Set-Content -LiteralPath $memoryPath -Value $newContent -Encoding UTF8 -NoNewline
Write-Output ("Chat memory now has {0} entr{1}." -f $entries.Count, $(if ($entries.Count -eq 1) { 'y' } else { 'ies' }))
