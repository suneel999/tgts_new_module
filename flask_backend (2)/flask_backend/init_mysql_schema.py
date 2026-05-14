#!/usr/bin/env python3
"""
Create all SQLAlchemy tables and seed roles + cadre levels on MySQL/RDS.

Use when production logs show: (1146, "Table '....' doesn't exist")

On EC2 (activate venv first):
  cd /path/to/flask_backend
  python init_mysql_schema.py
For Alembic-tracked DDL (e.g. voters columns), also:
  export FLASK_APP=app.py && flask db upgrade
Then:
  sudo systemctl restart tgts-api
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from dotenv import load_dotenv

load_dotenv()

from sqlalchemy import inspect

from app import create_app, db


def main() -> int:
    app = create_app()
    with app.app_context():
        print("Running db.create_all() …")
        db.create_all()

        from app.models import Role, CadreLevel
        from app.models.cadre_level import CADRE_LEVELS_SEED

        if Role.query.first() is None:
            for r in [
                Role(id=1, name="public", description="Public User"),
                Role(id=2, name="cadre", description="Party Cadre"),
                Role(id=3, name="admin", description="Administrator"),
            ]:
                db.session.add(r)
            db.session.commit()
            print("[✓] Roles seeded")

        if CadreLevel.query.first() is None:
            for row in CADRE_LEVELS_SEED:
                db.session.add(CadreLevel(**row))
            db.session.commit()
            print("[✓] Cadre levels seeded")

        from app.utils.db_migrations import ensure_all_columns

        ensure_all_columns()

        insp = inspect(db.engine)
        names = set(insp.get_table_names())
        required = {
            "users",
            "cadre_levels",
            "districts",
            "mandals",
            "parliamentary_constituencies",
            "assembly_constituencies",
            "members",
            "roles",
        }
        missing = sorted(required - names)
        if missing:
            print("ERROR: Tables still missing:", ", ".join(missing))
            return 1

        print("[✓] Schema OK — tables:", len(names))
        return 0


if __name__ == "__main__":
    sys.exit(main())
