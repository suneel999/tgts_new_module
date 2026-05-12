# Push MySQL JSON model fixes — run: cd "d:\tgts_apk" ; .\push-mysql-json-fix.ps1

Set-Location $PSScriptRoot

git add -- `
  "flask_backend (2)/flask_backend/app/models/document.py" `
  "flask_backend (2)/flask_backend/app/models/media.py" `
  "flask_backend (2)/flask_backend/app/models/news.py" `
  "flask_backend (2)/flask_backend/app/models/event.py" `
  "flask_backend (2)/flask_backend/app/models/activity.py"

git status
git commit -m "fix(db): SQLAlchemy JSON for MySQL RDS (replace PostgreSQL JSONB/ARRAY)"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Nothing new to commit or commit failed."
    exit $LASTEXITCODE
}

git push origin main
Write-Host "Done. On EC2: cd ~/tgts_new_module && git pull && recreate DB tables + restart tgts-api"
