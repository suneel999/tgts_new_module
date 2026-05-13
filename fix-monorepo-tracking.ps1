# Fix: GitHub shows folders but no files inside — usually nested .git in subprojects.
# Run from repo root:  cd "d:\tgts_apk" ; .\fix-monorepo-tracking.ps1

$ErrorActionPreference = "Continue"
Set-Location $PSScriptRoot

$rootGit = Join-Path (Resolve-Path ".") ".git"
Write-Host "Root repo: $rootGit`n"

$nested = Get-ChildItem -LiteralPath . -Force -Recurse -Filter ".git" -ErrorAction SilentlyContinue |
    Where-Object {
        $full = $_.FullName
        $full -ne $rootGit -and -not $full.StartsWith((Join-Path $rootGit ""), [System.StringComparison]::OrdinalIgnoreCase)
    }

if (-not $nested) {
    Write-Host "No nested .git entries found under project folders."
    Write-Host "Checking tracked file counts (expect hundreds for Flutter):"
    foreach ($pair in @(
            @("tgts-flutter", "TGTS_Flutter (2)"),
            @("admin-frontend", "Admin Frontend"),
            @("tgts-flask", "flask_backend (2)")
        )) {
        $new, $old = $pair[0], $pair[1]
        $path = if (Test-Path -LiteralPath $new) { $new } elseif (Test-Path -LiteralPath $old) { $old } else { $new }
        git ls-files -- "$path" | Measure-Object -Line | ForEach-Object { "$path tracked lines: $($_.Lines)" }
    }
    exit 0
}

Write-Host "Found nested Git metadata (will remove so parent repo can track files):"
$nested | ForEach-Object { Write-Host "  $($_.FullName)" }
$confirm = Read-Host "Delete these and re-track all files? [y/N]"
if ($confirm -ne "y" -and $confirm -ne "Y") { exit 1 }

foreach ($item in $nested) {
    Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
    Write-Host "Removed: $($item.FullName)"
}

Write-Host "`nClearing cache for subfolders and re-adding..."
foreach ($p in @(
        "TGTS_Flutter (2)", "tgts-flutter",
        "Admin Frontend", "admin-frontend",
        "flask_backend (2)", "tgts-flask"
    )) {
    git rm -r --cached $p 2>$null
}

git add -A
git status

$msg = "Track monorepo files (remove nested git)"
git commit -m $msg

Write-Host "`nNow push:  git push origin main"
Write-Host "On EC2:     git pull origin main"
