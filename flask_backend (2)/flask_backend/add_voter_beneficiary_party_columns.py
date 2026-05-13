"""
One-shot migration: add beneficiary_scheme + voter_party on voters (RDS MySQL / Postgres).
Startup also runs ensure_voter_columns() in app.utils.db_migrations.

Run: python add_voter_beneficiary_party_columns.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import create_app
from app.utils.db_migrations import ensure_voter_columns
from dotenv import load_dotenv

load_dotenv()


def run():
    app = create_app()
    with app.app_context():
        ensure_voter_columns()
    print("Done.")


if __name__ == "__main__":
    run()
