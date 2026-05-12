# Run on YOUR Windows PC in PowerShell (from repo root):
#   Set-Location "d:\tgts_apk"
#   .\push-github.ps1

Set-Location $PSScriptRoot

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Install Git first: https://git-scm.com/download/win"
    exit 1
}

if (-not (Test-Path .git)) { git init }
git branch -M main 2>$null

$repoUrl = "https://github.com/suneel999/tgts_new_module.git"
$remotes = @(git remote 2>$null)
if ($remotes -contains "origin") {
    git remote set-url origin $repoUrl
} else {
    git remote add origin $repoUrl
}
git add -A
git status

$changes = git status --porcelain
if (-not $changes) {
    Write-Host "No changes to commit. Attempting push anyway..."
} else {
    $msg = "TGTS monorepo: prod api.tgtccon2025.com, env examples, RDS endpoint template"
    git commit -m $msg
}

git push -u origin main
Write-Host "Done. On EC2 run: bash ec2-pull.sh   (or clone manually)"
