"""
Widen voters.beneficiary_scheme to VARCHAR(500) if it is still VARCHAR(50).
MySQL (RDS) and PostgreSQL supported.

Run: python expand_beneficiary_scheme_column.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import create_app, db
from sqlalchemy import text
from dotenv import load_dotenv

load_dotenv()


def run():
    app = create_app()
    with app.app_context():
        dialect = db.engine.dialect.name
        inspector = db.inspect(db.engine)
        if "voters" not in inspector.get_table_names():
            print("No voters table.")
            return
        cols = {c["name"]: c for c in inspector.get_columns("voters")}
        if "beneficiary_scheme" not in cols:
            print("Column beneficiary_scheme missing; run add_voter_beneficiary_party_columns.py first.")
            return
        t = str(cols["beneficiary_scheme"]["type"]).upper()
        if "(50)" not in t:
            print(f"No widen needed (type={t}).")
            return
        with db.engine.connect() as conn:
            if dialect == "postgresql":
                conn.execute(
                    text(
                        "ALTER TABLE voters ALTER COLUMN beneficiary_scheme TYPE VARCHAR(500)"
                    )
                )
            elif dialect in ("mysql", "mariadb"):
                conn.execute(
                    text(
                        "ALTER TABLE voters MODIFY COLUMN beneficiary_scheme VARCHAR(500) NULL"
                    )
                )
            else:
                print(f"Unsupported dialect: {dialect}")
                return
            conn.commit()
        print("Widened beneficiary_scheme to VARCHAR(500).")


if __name__ == "__main__":
    run()
