"""
Script to populate districts and mandals tables with Telangana data.
"""
import os
import sys
from pathlib import Path

# Add the parent directory to the path so we can import app
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import create_app, db
from app.models.district import District
from app.models.mandal import Mandal
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Telangana districts with English and Telugu names
TELANGANA_DISTRICTS = [
    {'en': 'Adilabad', 'te': 'ఆదిలాబాద్'},
    {'en': 'Bhadradri Kothagudem', 'te': 'భద్రాద్రి కొత్తగూడెం'},
    {'en': 'Hyderabad', 'te': 'హైదరాబాద్'},
    {'en': 'Jagtial', 'te': 'జగిత్యాల'},
    {'en': 'Jangaon', 'te': 'జంగాంవ్'},
    {'en': 'Jayashankar Bhupalpally', 'te': 'జయశంకర్ భూపాలపల్లి'},
    {'en': 'Jogulamba Gadwal', 'te': 'జోగులాంబ గద్వాల'},
    {'en': 'Kamareddy', 'te': 'కామారెడ్డి'},
    {'en': 'Karimnagar', 'te': 'కరీంనగర్'},
    {'en': 'Khammam', 'te': 'ఖమ్మం'},
    {'en': 'Kumuram Bheem', 'te': 'కుమురం భీమ్'},
    {'en': 'Mahabubabad', 'te': 'మహబూబాబాద్'},
    {'en': 'Mahbubnagar', 'te': 'మహబూబ్‌నగర్'},
    {'en': 'Mancherial', 'te': 'మంచిర్యాల'},
    {'en': 'Medak', 'te': 'మేడక్'},
    {'en': 'Medchal-Malkajgiri', 'te': 'మెడ్చల్-మల్కాజ్‌గిరి'},
    {'en': 'Mulugu', 'te': 'ములుగు'},
    {'en': 'Nagarkurnool', 'te': 'నాగర్‌కర్నూల్'},
    {'en': 'Nalgonda', 'te': 'నల్గొండ'},
    {'en': 'Narayanpet', 'te': 'నారాయణపేట'},
    {'en': 'Nirmal', 'te': 'నిర్మల్'},
    {'en': 'Nizamabad', 'te': 'నిజామాబాద్'},
    {'en': 'Peddapalli', 'te': 'పెద్దపల్లి'},
    {'en': 'Rajanna Sircilla', 'te': 'రాజన్న సిరిసిల్ల'},
    {'en': 'Rangareddy', 'te': 'రంగారెడ్డి'},
    {'en': 'Sangareddy', 'te': 'సంగారెడ్డి'},
    {'en': 'Siddipet', 'te': 'సిద్దిపేట'},
    {'en': 'Suryapet', 'te': 'సూర్యాపేట'},
    {'en': 'Vikarabad', 'te': 'వికారాబాద్'},
    {'en': 'Wanaparthy', 'te': 'వనపర్తి'},
    {'en': 'Warangal Rural', 'te': 'వరంగల్ రూరల్'},
    {'en': 'Warangal Urban', 'te': 'వరంగల్ అర్బన్'},
    {'en': 'Yadadri Bhuvanagiri', 'te': 'యాదాద్రి భువనగిరి'},
]

def populate_districts():
    """Populate the districts table with Telangana districts."""
    app = create_app()
    
    with app.app_context():
        # Create tables if they don't exist
        db.create_all()
        
        added_count = 0
        updated_count = 0
        skipped_count = 0
        
        for district_data in TELANGANA_DISTRICTS:
            name_en = district_data['en']
            name_te = district_data.get('te', name_en)
            
            # Check if district already exists
            existing = District.query.filter_by(name_en=name_en).first()
            
            if existing:
                # Update existing record
                existing.name_te = name_te
                existing.state = 'Telangana'
                existing.is_active = True
                updated_count += 1
                print(f"Updated: {name_en}")
            else:
                # Create new record
                new_district = District(
                    name_en=name_en,
                    name_te=name_te,
                    state='Telangana',
                    is_active=True
                )
                db.session.add(new_district)
                added_count += 1
                print(f"Added: {name_en}")
        
        try:
            db.session.commit()
            print(f"\n✓ Successfully processed {len(TELANGANA_DISTRICTS)} districts")
            print(f"  - Added: {added_count}")
            print(f"  - Updated: {updated_count}")
            print(f"  - Skipped: {skipped_count}")
        except Exception as e:
            db.session.rollback()
            print(f"\n✗ Error committing to database: {e}")
            raise

def populate_mandals():
    """Populate mandals table. This is a placeholder - mandals can be added later as needed."""
    app = create_app()
    
    with app.app_context():
        print("\nNote: Mandals can be populated dynamically as members are created.")
        print("Or you can add a mandals data file to populate them here.")
        # Mandals will be created on-demand when members are registered
        # or can be populated from a separate data source if available

def main():
    """Main function to run the script."""
    print("=" * 60)
    print("Populating Districts and Mandals Tables")
    print("=" * 60)
    
    try:
        print("\n[1/2] Populating districts...")
        populate_districts()
        
        print("\n[2/2] Mandals population (placeholder)...")
        populate_mandals()
        
        print("\n" + "=" * 60)
        print("✓ Population completed successfully!")
        print("=" * 60)
        
    except Exception as e:
        print(f"\n✗ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == '__main__':
    main()

