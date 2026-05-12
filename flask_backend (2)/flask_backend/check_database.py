#!/usr/bin/env python3
"""
Script to check current database type and configuration
"""
import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import create_app, db
from sqlalchemy import inspect
from dotenv import load_dotenv

load_dotenv()

def check_database():
    """Check current database type and schema"""
    app = create_app()
    
    with app.app_context():
        # Get database URL
        db_url = app.config.get('SQLALCHEMY_DATABASE_URI', '')
        print("=" * 70)
        print("DATABASE CONFIGURATION CHECK")
        print("=" * 70)
        print(f"\nDatabase URL: {db_url}")
        
        # Detect database type
        if 'sqlite' in db_url.lower():
            db_type = "SQLite"
        elif 'postgresql' in db_url.lower() or 'postgres' in db_url.lower():
            db_type = "PostgreSQL"
        elif 'mysql' in db_url.lower():
            db_type = "MySQL"
        else:
            db_type = "Unknown"
        
        print(f"Database Type: {db_type}")
        print("-" * 70)
        
        # Check if we can connect
        try:
            inspector = inspect(db.engine)
            print("✓ Database connection successful")
            
            # Check constituency tables
            tables = inspector.get_table_names()
            print(f"\nTables found: {len(tables)}")
            
            if 'parliamentary_constituencies' in tables:
                print("\n📊 Parliamentary Constituencies Table:")
                pc_cols = inspector.get_columns('parliamentary_constituencies')
                for col in pc_cols:
                    pk = " (PRIMARY KEY)" if col.get('primary_key') else ""
                    print(f"  - {col['name']}: {col['type']}{pk}")
                
                # Check if using UUID or integer
                col_names = [c['name'] for c in pc_cols]
                if 'id' in col_names and 'constituency_number' in col_names:
                    print("  ⚠️  Has both 'id' and 'constituency_number' columns")
                    print("  → Migration needed: migrate_constituencies_to_integer_ids.py")
                elif 'id' in col_names:
                    print("  ⚠️  Using UUID 'id' column as primary key")
                    print("  → Migration needed: migrate_constituencies_to_integer_ids.py")
                elif 'constituency_number' in col_names:
                    print("  ✅ Using 'constituency_number' as primary key (already migrated)")
                else:
                    print("  ⚠️  Unknown schema")
            
            if 'assembly_constituencies' in tables:
                print("\n📊 Assembly Constituencies Table:")
                ac_cols = inspector.get_columns('assembly_constituencies')
                for col in ac_cols:
                    pk = " (PRIMARY KEY)" if col.get('primary_key') else ""
                    print(f"  - {col['name']}: {col['type']}{pk}")
            
            if 'members' in tables:
                print("\n📊 Members Table:")
                members_cols = inspector.get_columns('members')
                constituency_cols = [c for c in members_cols if 'constituency' in c['name']]
                for col in constituency_cols:
                    print(f"  - {col['name']}: {col['type']}")
            
            print("\n" + "=" * 70)
            print("RECOMMENDATIONS:")
            print("=" * 70)
            
            if db_type == "SQLite":
                print("⚠️  Currently using SQLite")
                print("→ To switch to PostgreSQL (AWS RDS):")
                print("  1. Update .env file with PostgreSQL connection string")
                print("  2. Run: python3 migrate_to_postgres.py (if migrating data)")
                print("  3. Restart the application")
            elif db_type == "PostgreSQL":
                print("✅ Using PostgreSQL")
                if 'parliamentary_constituencies' in tables:
                    pc_cols = inspector.get_columns('parliamentary_constituencies')
                    col_names = [c['name'] for c in pc_cols]
                    if 'id' in col_names and 'constituency_number' not in [c['name'] for c in pc_cols if c.get('primary_key')]:
                        print("→ Migration needed: python3 migrate_constituencies_to_integer_ids.py")
                    else:
                        print("✅ Schema looks correct - no migration needed")
            
        except Exception as e:
            print(f"\n✗ Error connecting to database: {e}")
            print("\nCheck your .env file and DATABASE_URL configuration")
            return False
        
        return True

if __name__ == '__main__':
    check_database()

