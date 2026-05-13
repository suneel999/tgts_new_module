#!/usr/bin/env bash
# Run on EC2 (Ubuntu) after one-time Git install: sudo apt install -y git
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/suneel999/tgts_new_module.git}"
DEST="${DEST:-$HOME/tgts_new_module}"

if [[ -d "$DEST/.git" ]]; then
  echo "Updating existing repo in $DEST"
  cd "$DEST"
  git fetch origin
  git checkout main
  git pull origin main
else
  echo "Cloning into $DEST"
  git clone "$REPO_URL" "$DEST"
  cd "$DEST"
fi

echo ""
echo "Repo ready at: $DEST"
echo "Backend path (no spaces — recommended after rename-workspace-folders.ps1):"
echo "  cd \"$DEST/tgts-flask/flask_backend\""
echo "Then: python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt"
echo "Copy .env.example to .env and edit secrets on the server only."
