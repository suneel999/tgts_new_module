"""
Script to migrate districts and mandals from string columns to integer foreign keys.
This script:
1. Creates districts and mandals tables
2. Extracts unique districts and mandals from existing members.district and members.mandal columns
3. Populates districts and mandals tables
4. Adds district_id and mandal_id columns to members table
5. Migrates existing data to use integer foreign keys
"""
import os
import sys
from pathlib import Path
from sqlalchemy import text

# Add the parent directory to the path so we can import app
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import create_app, db
from app.models.district import District
from app.models.mandal import Mandal
from app.models.member import Member
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def create_tables():
    """Create districts and mandals tables if they don't exist."""
    app = create_app()
    with app.app_context():
        print("[1/6] Creating districts and mandals tables...")
        db.create_all()
        print("✓ Tables created/verified")

def extract_unique_districts_and_mandals():
    """Extract unique districts and mandals from existing members table."""
    app = create_app()
    with app.app_context():
        print("[2/6] Extracting unique districts and mandals from members table...")
        
        # Get unique districts
        districts_query = db.session.query(Member.district).distinct().filter(Member.district.isnot(None)).filter(Member.district != '')
        unique_districts = [row[0] for row in districts_query.all()]
        
        # Get unique mandals with their districts
        mandals_query = db.session.query(Member.mandal, Member.district).distinct().filter(Member.mandal.isnot(None)).filter(Member.mandal != '')
        unique_mandals = [(row[0], row[1]) for row in mandals_query.all() if row[1]]  # (mandal_name, district_name)
        
        print(f"  Found {len(unique_districts)} unique districts")
        print(f"  Found {len(unique_mandals)} unique mandals")
        
        return unique_districts, unique_mandals

def populate_districts(district_names):
    """Populate districts table with unique district names."""
    app = create_app()
    with app.app_context():
        print("[3/6] Populating districts table...")
        
        added_count = 0
        updated_count = 0
        
        for district_name in district_names:
            if not district_name or district_name.strip() == '':
                continue
                
            # Check if district already exists
            existing = District.query.filter_by(name_en=district_name.strip()).first()
            
            if existing:
                updated_count += 1
            else:
                new_district = District(
                    name_en=district_name.strip(),
                    name_te=district_name.strip(),  # Default to English name
                    state='Telangana',
                    is_active=True
                )
                db.session.add(new_district)
                added_count += 1
        
        try:
            db.session.commit()
            print(f"✓ Added {added_count} districts, updated {updated_count} districts")
        except Exception as e:
            db.session.rollback()
            print(f"✗ Error populating districts: {e}")
            raise

def populate_mandals(mandals_data):
    """Populate mandals table with mandal names linked to districts."""
    app = create_app()
    with app.app_context():
        print("[4/6] Populating mandals table...")
        
        added_count = 0
        skipped_count = 0
        
        for mandal_name, district_name in mandals_data:
            if not mandal_name or mandal_name.strip() == '':
                continue
            if not district_name or district_name.strip() == '':
                skipped_count += 1
                continue
            
            # Find the district
            district = District.query.filter_by(name_en=district_name.strip()).first()
            if not district:
                print(f"  Warning: District '{district_name}' not found for mandal '{mandal_name}', skipping...")
                skipped_count += 1
                continue
            
            # Check if mandal already exists for this district
            existing = Mandal.query.filter_by(district_id=district.id, name_en=mandal_name.strip()).first()
            
            if not existing:
                new_mandal = Mandal(
                    district_id=district.id,
                    name_en=mandal_name.strip(),
                    name_te=mandal_name.strip(),  # Default to English name
                    is_active=True
                )
                db.session.add(new_mandal)
                added_count += 1
        
        try:
            db.session.commit()
            print(f"✓ Added {added_count} mandals, skipped {skipped_count} mandals")
        except Exception as e:
            db.session.rollback()
            print(f"✗ Error populating mandals: {e}")
            raise

def add_foreign_key_columns():
    """Add district_id and mandal_id columns to members table if they don't exist."""
    app = create_app()
    with app.app_context():
        print("[5/6] Adding foreign key columns to members table...")
        
        try:
            # Check if columns already exist
            inspector = db.inspect(db.engine)
            columns = [col['name'] for col in inspector.get_columns('members')]
            
            if 'district_id' not in columns:
                db.session.execute(text('ALTER TABLE members ADD COLUMN district_id INTEGER'))
                db.session.execute(text('ALTER TABLE members ADD CONSTRAINT fk_members_district FOREIGN KEY (district_id) REFERENCES districts(id)'))
                print("  ✓ Added district_id column")
            else:
                print("  ✓ district_id column already exists")
            
            if 'mandal_id' not in columns:
                db.session.execute(text('ALTER TABLE members ADD COLUMN mandal_id INTEGER'))
                db.session.execute(text('ALTER TABLE members ADD CONSTRAINT fk_members_mandal FOREIGN KEY (mandal_id) REFERENCES mandals(id)'))
                print("  ✓ Added mandal_id column")
            else:
                print("  ✓ mandal_id column already exists")
            
            db.session.commit()
        except Exception as e:
            db.session.rollback()
            # If error is about column already existing, that's okay
            if 'already exists' in str(e).lower() or 'duplicate' in str(e).lower():
                print(f"  Note: {e}")
            else:
                print(f"✗ Error adding columns: {e}")
                raise

def migrate_member_data():
    """Migrate existing member data to use integer foreign keys."""
    app = create_app()
    with app.app_context():
        print("[6/6] Migrating member data to use integer foreign keys...")
        
        members = Member.query.all()
        updated_count = 0
        skipped_count = 0
        
        for member in members:
            updated = False
            
            # Migrate district
            if member.district and member.district.strip():
                district = District.query.filter_by(name_en=member.district.strip()).first()
                if district:
                    member.district_id = district.id
                    updated = True
                else:
                    skipped_count += 1
            
            # Migrate mandal
            if member.mandal and member.mandal.strip():
                # First try to find mandal by name and district
                if member.district_id:
                    district = District.query.get(member.district_id)
                    if district:
                        mandal = Mandal.query.filter_by(district_id=district.id, name_en=member.mandal.strip()).first()
                        if mandal:
                            member.mandal_id = mandal.id
                            updated = True
                else:
                    # If no district_id, try to find mandal by name only (might match multiple)
                    mandal = Mandal.query.filter_by(name_en=member.mandal.strip()).first()
                    if mandal:
                        member.mandal_id = mandal.id
                        updated = True
            
            if updated:
                updated_count += 1
        
        try:
            db.session.commit()
            print(f"✓ Updated {updated_count} members, skipped {skipped_count} members")
        except Exception as e:
            db.session.rollback()
            print(f"✗ Error migrating member data: {e}")
            raise

def main():
    """Main function to run the migration."""
    print("=" * 60)
    print("Migrating Districts and Mandals to Integer Foreign Keys")
    print("=" * 60)
    print("\n⚠️  WARNING: This script modifies the database structure.")
    print("⚠️  Make sure you have a backup before proceeding.\n")
    
    try:
        # Step 1: Create tables
        create_tables()
        
        # Step 2: Extract unique districts and mandals
        unique_districts, unique_mandals = extract_unique_districts_and_mandals()
        
        # Step 3: Populate districts
        if unique_districts:
            populate_districts(unique_districts)
        else:
            print("[3/6] No districts found in members table, skipping...")
        
        # Step 4: Populate mandals
        if unique_mandals:
            populate_mandals(unique_mandals)
        else:
            print("[4/6] No mandals found in members table, skipping...")
        
        # Step 5: Add foreign key columns
        add_foreign_key_columns()
        
        # Step 6: Migrate member data
        migrate_member_data()
        
        print("\n" + "=" * 60)
        print("✓ Migration completed successfully!")
        print("=" * 60)
        print("\nNote: Old string columns (district, mandal) are kept for backward compatibility.")
        print("You can drop them later after verifying the migration is successful.")
        
    except Exception as e:
        print(f"\n✗ Migration failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == '__main__':
    main()

