"""
Migration: add location columns to the users table so that public (non-member)
users can have a district/mandal/constituency assigned and receive local news.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import create_app, db
from dotenv import load_dotenv

load_dotenv()


def add_location_columns():
    app = create_app()

    with app.app_context():
        from sqlalchemy import inspect, text
        inspector = inspect(db.engine)
        existing = [col['name'] for col in inspector.get_columns('users')]

        columns = [
            ('district_id',              'INTEGER', 'districts',                   'id'),
            ('mandal_id',                'INTEGER', 'mandals',                     'id'),
            ('parliament_constituency_id','INTEGER', 'parliamentary_constituencies','constituency_number'),
            ('assembly_constituency_id', 'INTEGER', 'assembly_constituencies',     'constituency_number'),
        ]

        with db.engine.connect() as conn:
            for col_name, col_type, ref_table, ref_col in columns:
                if col_name in existing:
                    print(f'  ✓ {col_name} already exists — skipped')
                    continue

                print(f'  Adding {col_name} ...')
                conn.execute(text(
                    f'ALTER TABLE users ADD COLUMN {col_name} {col_type} '
                    f'REFERENCES {ref_table}({ref_col}) ON DELETE SET NULL;'
                ))
                print(f'  ✓ Added {col_name}')

            conn.commit()

        print('\n✓ Migration complete — users table now has location columns.')


if __name__ == '__main__':
    print('=' * 60)
    print('Adding location columns to users table...')
    print('=' * 60)
    add_location_columns()
    print('=' * 60)
