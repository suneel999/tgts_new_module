"""
Script to remove textual district and mandal columns from members table.
This script:
1. Drops the 'district' and 'mandal' text columns from the members table
2. Verifies the columns have been removed

Note: This assumes all data has been migrated to use district_id and mandal_id foreign keys.
"""
import os
import sys
from pathlib import Path
from sqlalchemy import text, inspect

# Add the parent directory to the path so we can import app
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import create_app, db
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def check_columns_exist():
    """Check if the text columns exist in the members table."""
    app = create_app()
    with app.app_context():
        print("[1/3] Checking if columns exist...")
        
        inspector = inspect(db.engine)
        columns = [col['name'] for col in inspector.get_columns('members')]
        
        has_district = 'district' in columns
        has_mandal = 'mandal' in columns
        
        print(f"  district column exists: {has_district}")
        print(f"  mandal column exists: {has_mandal}")
        
        return has_district, has_mandal

def drop_columns():
    """Drop the district and mandal text columns from members table."""
    app = create_app()
    with app.app_context():
        print("[2/3] Dropping text columns from members table...")
        
        try:
            inspector = inspect(db.engine)
            columns = [col['name'] for col in inspector.get_columns('members')]
            
            # Drop district column if it exists
            if 'district' in columns:
                print("  Dropping 'district' column...")
                db.session.execute(text('ALTER TABLE members DROP COLUMN IF EXISTS district'))
                print("  ✓ Dropped 'district' column")
            else:
                print("  ✓ 'district' column does not exist, skipping")
            
            # Drop mandal column if it exists
            if 'mandal' in columns:
                print("  Dropping 'mandal' column...")
                db.session.execute(text('ALTER TABLE members DROP COLUMN IF EXISTS mandal'))
                print("  ✓ Dropped 'mandal' column")
            else:
                print("  ✓ 'mandal' column does not exist, skipping")
            
            db.session.commit()
            print("✓ Columns dropped successfully")
            
        except Exception as e:
            db.session.rollback()
            print(f"✗ Error dropping columns: {e}")
            raise

def verify_columns_removed():
    """Verify that the columns have been removed."""
    app = create_app()
    with app.app_context():
        print("[3/3] Verifying columns have been removed...")
        
        inspector = inspect(db.engine)
        columns = [col['name'] for col in inspector.get_columns('members')]
        
        has_district = 'district' in columns
        has_mandal = 'mandal' in columns
        
        if has_district or has_mandal:
            print("✗ Warning: Some columns still exist!")
            if has_district:
                print("  - 'district' column still exists")
            if has_mandal:
                print("  - 'mandal' column still exists")
            return False
        else:
            print("✓ Verified: Both 'district' and 'mandal' columns have been removed")
            print("✓ Migration completed successfully!")
            return True

def main():
    """Main migration function."""
    print("=" * 60)
    print("Removing Textual District and Mandal Columns from Members Table")
    print("=" * 60)
    print()
    
    try:
        # Check if columns exist
        has_district, has_mandal = check_columns_exist()
        
        if not has_district and not has_mandal:
            print("\n✓ Both columns already removed. Nothing to do.")
            return
        
        # Drop the columns
        drop_columns()
        
        # Verify removal
        verify_columns_removed()
        
        print()
        print("=" * 60)
        print("Migration Summary:")
        print("  - Removed 'district' text column from members table")
        print("  - Removed 'mandal' text column from members table")
        print("  - Members table now uses only district_id and mandal_id foreign keys")
        print("=" * 60)
        
    except Exception as e:
        print()
        print("=" * 60)
        print(f"✗ Migration failed: {e}")
        print("=" * 60)
        sys.exit(1)

if __name__ == '__main__':
    main()

