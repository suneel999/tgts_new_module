"""
Script to populate assembly constituencies from the provided data.
"""
import os
import sys
from pathlib import Path

# Add the parent directory to the path so we can import app
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import create_app, db
from app.models.assembly_constituency import AssemblyConstituency
from app.models.parliamentary_constituency import ParliamentaryConstituency
from app.seed_constituencies import ASSEMBLY_CONSTITUENCIES
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def populate_database():
    """Populate the database with assembly constituency data."""
    app = create_app()
    
    with app.app_context():
        # Create tables if they don't exist
        db.create_all()
        
        added_count = 0
        updated_count = 0
        total_assembly = 0
        
        # Get all parliamentary constituencies
        # Now using constituency_number as the ID
        parliament_constituencies = {
            pc.constituency_number: pc.constituency_number 
            for pc in ParliamentaryConstituency.query.all()
        }
        
        for parliament_number, assembly_list in ASSEMBLY_CONSTITUENCIES.items():
            parliament_id = parliament_constituencies.get(parliament_number)
            if not parliament_id:
                print(f"Warning: Parliamentary constituency {parliament_number} not found, skipping assembly constituencies")
                continue
            
            for assembly_data in assembly_list:
                total_assembly += 1
                assembly_number = assembly_data['number']
                assembly_name = assembly_data['name']
                
                # Check if assembly constituency already exists
                existing = AssemblyConstituency.query.filter_by(
                    constituency_number=assembly_number
                ).first()
                
                if existing:
                    # Update existing record
                    existing.name_en = assembly_name
                    existing.name_te = assembly_name
                    existing.parliament_constituency_id = parliament_id
                    updated_count += 1
                    print(f"Updated: {assembly_number}. {assembly_name} (Parliament: {parliament_number})")
                else:
                    # Create new record - using constituency_number as primary key
                    new_assembly = AssemblyConstituency(
                        constituency_number=assembly_number,
                        name_en=assembly_name,
                        name_te=assembly_name,
                        state='Telangana',
                        parliament_constituency_id=parliament_id,
                        is_active=True
                    )
                    db.session.add(new_assembly)
                    added_count += 1
                    print(f"Added: {assembly_number}. {assembly_name} (Parliament: {parliament_number})")
        
        try:
            db.session.commit()
            print(f"\n✓ Successfully processed {total_assembly} assembly constituencies")
            print(f"  - Added: {added_count}")
            print(f"  - Updated: {updated_count}")
        except Exception as e:
            db.session.rollback()
            print(f"\n✗ Error committing to database: {e}")
            raise

def main():
    """Main function to run the script."""
    print("Assembly Constituencies to be added/updated:")
    print("-" * 70)
    total = 0
    for parliament_num, assemblies in ASSEMBLY_CONSTITUENCIES.items():
        print(f"\nParliamentary Constituency {parliament_num}:")
        for assembly in assemblies:
            print(f"  {assembly['number']:3d}. {assembly['name']}")
            total += 1
    print("-" * 70)
    print(f"Total: {total} assembly constituencies across 17 parliamentary constituencies")
    
    # Ask for confirmation
    response = input(f"\nProceed to populate database with {total} assembly constituencies? (y/n): ")
    if response.lower() != 'y':
        print("Operation cancelled.")
        sys.exit(0)
    
    # Populate database
    populate_database()
    print("\n✓ Database population completed!")

if __name__ == '__main__':
    main()

