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
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Assembly constituencies data organized by parliamentary constituency
ASSEMBLY_CONSTITUENCIES = {
    1: [  # Adilabad (ST)
        {"number": 5, "name": "Asifabad(ST)"},
        {"number": 6, "name": "Khanapur(ST)"},
        {"number": 7, "name": "Adilabad"},
        {"number": 8, "name": "Boath(ST)"},
        {"number": 9, "name": "Nirmal"},
        {"number": 10, "name": "Mudhole"},
        {"number": 1, "name": "Sirpur"},
    ],
    2: [  # Peddapalle (SC)
        {"number": 2, "name": "Chennur(SC)"},
        {"number": 3, "name": "Bellampalli(SC)"},
        {"number": 4, "name": "Mancherial"},
        {"number": 22, "name": "Dharmapuri(SC)"},
        {"number": 23, "name": "Ramagundam"},
        {"number": 24, "name": "Manthani"},
        {"number": 25, "name": "Peddapalle"},
    ],
    3: [  # Karimnagar
        {"number": 26, "name": "Karimnagar"},
        {"number": 27, "name": "Choppadandi(SC)"},
        {"number": 28, "name": "Vemulawada"},
        {"number": 29, "name": "Sircilla"},
        {"number": 30, "name": "Manakondur(SC)"},
        {"number": 31, "name": "Huzurabad"},
        {"number": 32, "name": "Husnabad"},
    ],
    4: [  # Nizamabad
        {"number": 17, "name": "Nizamabad (Urban)"},
        {"number": 18, "name": "Nizamabad (Rural)"},
        {"number": 19, "name": "Balkonda"},
        {"number": 20, "name": "Koratla"},
        {"number": 21, "name": "Jagtial"},
        {"number": 11, "name": "Armur"},
        {"number": 12, "name": "Bodhan"},
    ],
    5: [  # Zaheerabad
        {"number": 13, "name": "Jukkal(SC)"},
        {"number": 14, "name": "Banswada"},
        {"number": 15, "name": "Yellareddy"},
        {"number": 16, "name": "Kamareddy"},
        {"number": 38, "name": "Zaheerabad(SC)"},
        {"number": 35, "name": "Narayankhed"},
        {"number": 36, "name": "Andole(SC)"},
    ],
    6: [  # Medak
        {"number": 37, "name": "Narsapur"},
        {"number": 39, "name": "Sangareddy"},
        {"number": 40, "name": "Patancheru"},
        {"number": 41, "name": "Dubbak"},
        {"number": 42, "name": "Gajwel"},
        {"number": 33, "name": "Siddipet"},
        {"number": 34, "name": "Medak"},
    ],
    7: [  # Malkajgiri
        {"number": 43, "name": "Medchai"},
        {"number": 44, "name": "Malkajgiri"},
        {"number": 45, "name": "Outhbullapur"},
        {"number": 46, "name": "Kukatpally"},
        {"number": 47, "name": "Uppal"},
    ],
    8: [  # Secunderabad
        {"number": 57, "name": "Musheerabad"},
        {"number": 70, "name": "Secunderabad"},
        {"number": 59, "name": "Amberpet"},
        {"number": 60, "name": "Khairatabad"},
        {"number": 61, "name": "Jubilee Hills"},
        {"number": 62, "name": "Sanathnagar"},
        {"number": 63, "name": "Nampally"},
    ],
    9: [  # Hyderabad
        {"number": 64, "name": "Karwan"},
        {"number": 65, "name": "Goshamahal"},
        {"number": 66, "name": "Charminar"},
        {"number": 67, "name": "Chandrayangutta"},
        {"number": 68, "name": "Yakutpura"},
        {"number": 69, "name": "Bahadurpura"},
        {"number": 58, "name": "Malakpet"},
    ],
    10: [  # Chevella
        {"number": 50, "name": "Maheswaram"},
        {"number": 51, "name": "Rajendranagar"},
        {"number": 52, "name": "Serilingampally"},
        {"number": 53, "name": "Chevella(SC)"},
        {"number": 54, "name": "Pargi"},
        {"number": 55, "name": "Vicarabad(SC)"},
        {"number": 56, "name": "Tandur"},
    ],
    11: [  # Mahbubnagar
        {"number": 84, "name": "Shadnagar"},
        {"number": 72, "name": "Kodangal"},
        {"number": 73, "name": "Narayappet"},
        {"number": 74, "name": "Mahbubnagar"},
        {"number": 75, "name": "Jadcherla"},
        {"number": 76, "name": "Devarkadra"},
        {"number": 77, "name": "Makthal"},
    ],
    12: [  # Nagarkurnool (SC)
        {"number": 78, "name": "Wanaparthy"},
        {"number": 79, "name": "Gadwal"},
        {"number": 80, "name": "Alampur(SC)"},
        {"number": 81, "name": "Nagarkurnool"},
        {"number": 82, "name": "Achampet(SC)"},
        {"number": 83, "name": "Kalwakurthy"},
        {"number": 85, "name": "Kollapur"},
    ],
    13: [  # Nalgonda
        {"number": 86, "name": "Devarakonda(ST)"},
        {"number": 87, "name": "Nagarjuna Sagar"},
        {"number": 88, "name": "Miryalaguda"},
        {"number": 89, "name": "Huzurnagar"},
        {"number": 90, "name": "Kodad"},
        {"number": 91, "name": "Suryapet"},
        {"number": 92, "name": "Nalgonda"},
    ],
    14: [  # Bhuvangiri
        {"number": 93, "name": "Munugode"},
        {"number": 94, "name": "Bhongir"},
        {"number": 95, "name": "Nakrekal(SC)"},
        {"number": 96, "name": "Thungathurthi(SC)"},
        {"number": 97, "name": "Alair"},
        {"number": 98, "name": "Jangoon"},
        {"number": 48, "name": "Ibrahimpatnam"},
        {"number": 99, "name": "Ghanpur (Station)(SC)"},
        {"number": 100, "name": "Palakurthi"},
        {"number": 104, "name": "Parkal"},
    ],
    15: [  # Warangal (SC)
        {"number": 105, "name": "Warangal West"},
        {"number": 106, "name": "Warangal East"},
        {"number": 107, "name": "Waradhanapet(SC)"},
        {"number": 108, "name": "Bhupalpalle"},
    ],
    16: [  # Mahaboobabad (ST)
        {"number": 109, "name": "Mulugu(ST)"},
        {"number": 110, "name": "Pinapaka(ST)"},
        {"number": 111, "name": "Yellandu(ST)"},
        {"number": 119, "name": "Bhadrachalam(ST)"},
        {"number": 101, "name": "Dornakal(ST)"},
        {"number": 102, "name": "Mahabubabad(ST)"},
        {"number": 103, "name": "Narsampet"},
    ],
    17: [  # Khammam
        {"number": 112, "name": "Khammam"},
        {"number": 113, "name": "Palair"},
        {"number": 114, "name": "Madhira(SC)"},
        {"number": 115, "name": "Wyra(ST)"},
        {"number": 116, "name": "Sathupalle(SC)"},
        {"number": 117, "name": "Kothagudem"},
        {"number": 118, "name": "Aswaraopeta(ST)"},
    ],
}

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

