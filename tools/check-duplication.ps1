param([string]$BaseRef = 'origin/main')

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
Push-Location $Root
try {
    $baseCommit = git merge-base HEAD $BaseRef
    if ($LASTEXITCODE -ne 0 -or -not $baseCommit) {
	throw "Cannot find merge base for '$BaseRef'; duplication check was not completed."
    }
    Write-Host "Comparing duplication against merge base $baseCommit (from $BaseRef)."
    & npm exec --yes --package=jscpd@5.3.2 -- jscpd `
	'Contents/mods/EmberUI/42/media/lua' `
	--format lua --min-lines 6 --min-tokens 60 --baseline-from-ref $baseCommit `
	--fail-on-empty --no-tips --no-colors
    if ($LASTEXITCODE -ne 0) {
	throw "jscpd failed (exit $LASTEXITCODE); duplication check was not completed."
    }
    Write-Host 'Duplication findings are advisory; review new matches in the PR.'
} finally {
    Pop-Location
}
