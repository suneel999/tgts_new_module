# Replaces local branch history with ONE new commit (no parent), then you force-push.
# Required after secrets were committed — deleting files is not enough.
#
# Usage:
#   cd "d:\tgts_apk"
#   powershell -ExecutionPolicy Bypass -File .\clean-git-history.ps1
#   powershell -ExecutionPolicy Bypass -File .\clean-git-history.ps1 -Yes   # skip prompt
#
param([switch]$Yes)

Set-Location $PSScriptRoot

$remote = git remote get-url origin 2>$null
if (-not $remote) {
    Write-Host "ERROR: No origin remote."
    exit 1
}

Write-Host "Remote: $remote"
Write-Host "Old tip (will be discarded locally): $(git rev-parse HEAD 2>$null)"

if (-not $Yes) {
    Write-Host ""
    Write-Host "This creates a NEW Git history (orphan commit) and renames it to 'main'."
    Write-Host "Then run: git push -f origin main"
    $ok = Read-Host "Continue? [y/N]"
    if ($ok -ne "y" -and $ok -ne "Y") { exit 1 }
}

git checkout --orphan __tgts_clean__
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: orphan checkout failed. Commit or stash changes first."
    exit $LASTEXITCODE
}

git add -A
git commit -m "Initial commit: TGTS monorepo (secrets removed from tracked files)"
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: commit failed (nothing to commit?)"
    exit $LASTEXITCODE
}

# Drop old main (still points at leaked commits) if it exists
git branch -D main 2>$null

# Current orphan branch becomes main
git branch -m main

$newHead = git rev-parse HEAD
Write-Host ""
Write-Host "NEW main tip: $newHead"
Write-Host "If this still equals an old blocked SHA, something went wrong."
Write-Host ""
Write-Host "Next command:"
Write-Host "  git push -f origin main"
Write-Host ""
Write-Host "Rotate AWS + Twilio credentials — they existed in old commits."
