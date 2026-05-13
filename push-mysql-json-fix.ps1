# Push MySQL JSON model fixes — run: cd "d:\tgts_apk" ; .\push-mysql-json-fix.ps1
# Uses tgts-flask path after .\rename-workspace-folders.ps1, else legacy flask_backend (2).

Set-Location $PSScriptRoot

$fbRoot = if (Test-Path -LiteralPath "tgts-flask\flask_backend") {
    "tgts-flask/flask_backend"
} elseif (Test-Path -LiteralPath "flask_backend (2)\flask_backend") {
    "flask_backend (2)/flask_backend"
} else {
    Write-Error "Flask backend folder not found (expected tgts-flask/flask_backend or flask_backend (2)/flask_backend)."
    exit 1
}

git add -- `
  "$fbRoot/app/models/document.py" `
  "$fbRoot/app/models/media.py" `
  "$fbRoot/app/models/news.py" `
  "$fbRoot/app/models/event.py" `
  "$fbRoot/app/models/activity.py"

git status
git commit -m "fix(db): SQLAlchemy JSON for MySQL RDS (replace PostgreSQL JSONB/ARRAY)"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Nothing new to commit or commit failed."
    exit $LASTEXITCODE
}

git push origin main
Write-Host "Done. On EC2: cd ~/tgts_new_module && git pull && recreate DB tables + restart tgts-api"
