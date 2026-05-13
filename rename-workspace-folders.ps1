# Renames top-level folders so paths have no spaces or "(2)" — fixes systemd 203/EXEC on Linux.
# Run from repo root:  cd "d:\tgts_apk" ; .\rename-workspace-folders.ps1
#
# After this:  git add -A && git commit -m "chore: rename folders (no spaces)" && git push
# On EC2 after pull: update tgts-api.service paths + fix ExecStart (see below).

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$root = $PSScriptRoot

function Rename-Folder {
    param([string]$LiteralPath, [string]$NewName)
    if (-not (Test-Path -LiteralPath $LiteralPath)) { return $false }
    $parent = Split-Path -LiteralPath $LiteralPath -Parent
    $target = Join-Path $parent $NewName
    if (Test-Path -LiteralPath $target) {
        Write-Host "Skip (target exists): $NewName"
        return $false
    }
    Rename-Item -LiteralPath $LiteralPath -NewName $NewName
    Write-Host "Renamed: $(Split-Path $LiteralPath -Leaf) -> $NewName"
    return $true
}

# Admin: inner folder first (still named "Admin Frontend"), then outer.
$adminInner = Join-Path $root "Admin Frontend\Admin Frontend"
$adminOuter = Join-Path $root "Admin Frontend"
if (Test-Path -LiteralPath $adminInner) {
    Rename-Folder -LiteralPath $adminInner -NewName "web"
}
if (Test-Path -LiteralPath $adminOuter) {
    Rename-Folder -LiteralPath $adminOuter -NewName "admin-frontend"
}

Rename-Folder -LiteralPath (Join-Path $root "flask_backend (2)") -NewName "tgts-flask"
Rename-Folder -LiteralPath (Join-Path $root "TGTS_Flutter (2)") -NewName "tgts-flutter"

Write-Host ""
Write-Host "Done. New layout:"
Write-Host "  tgts-flask/flask_backend       — Flask API"
Write-Host "  tgts-flutter/TGTS_Flutter      — Flutter app"
Write-Host "  admin-frontend/web             — Admin Vite app"
Write-Host ""
Write-Host "EC2: edit /etc/systemd/system/tgts-api.service — use a path WITHOUT spaces, e.g.:"
Write-Host "  WorkingDirectory=/home/ubuntu/tgts_new_module/tgts-flask/flask_backend"
Write-Host "  ExecStart=/home/ubuntu/tgts_new_module/tgts-flask/flask_backend/.venv/bin/gunicorn --bind 127.0.0.1:5000 wsgi:application"
Write-Host "(NOT app:create_app() — that causes ExecStart failures.)"
Write-Host ""
Write-Host "Then: sudo systemctl daemon-reload && sudo systemctl restart tgts-api && sudo systemctl enable tgts-api"
