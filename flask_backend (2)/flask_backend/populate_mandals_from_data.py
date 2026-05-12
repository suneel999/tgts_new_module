"""
Script to populate mandals table from provided district-mandal data.
"""
import os
import sys
from pathlib import Path

# Add the current directory to the path so we can import app
current_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, current_dir)

from app import create_app, db
from app.models.district import District
from app.models.mandal import Mandal
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Raw data provided by user
MANDALS_DATA = """District,Mandal Name
Adilabad,Adilabad Rural
Adilabad,Adilabad Urban
Adilabad,Bazarhatnoor
Adilabad,Bela
Adilabad,Bheempur
Adilabad,Bhoraj
Adilabad,Boath
Adilabad,Gadiguda
Adilabad,Gudihatnoor
Adilabad,Ichoda
Adilabad,Inderavelly
Adilabad,Jainath
Adilabad,Mavala
Adilabad,Narnoor
Adilabad,Neradigonda
Adilabad,Sathnala
Adilabad,Sirikonda
Adilabad,Sonala
Adilabad,Talamadugu
Adilabad,Tamsi
Adilabad,Utnoor
Bhadradri Kothagudem,Allapalli
Bhadradri Kothagudem,Annapureddypalli
Bhadradri Kothagudem,Aswapuram
Bhadradri Kothagudem,Aswaraopeta
Bhadradri Kothagudem,Bhadrachalam
Bhadradri Kothagudem,Burgampahad
Bhadradri Kothagudem,Chandrugonda
Bhadradri Kothagudem,Cherla
Bhadradri Kothagudem,Chunchupalle
Bhadradri Kothagudem,Dammapeta
Bhadradri Kothagudem,Dummugudem
Bhadradri Kothagudem,Gundala
Bhadradri Kothagudem,Julurpadu
Bhadradri Kothagudem,Karakagudem
Bhadradri Kothagudem,Kothagudem
Bhadradri Kothagudem,Laxmidevipalli
Bhadradri Kothagudem,Manuguru
Bhadradri Kothagudem,Mulakalapalli
Bhadradri Kothagudem,Palwancha
Bhadradri Kothagudem,Pinapaka
Bhadradri Kothagudem,Sujathanagar
Bhadradri Kothagudem,Tekulapalli
Bhadradri Kothagudem,Yellandu
Hanumakonda,Bheemadevarpalli
Hanumakonda,Dharmasagar
Hanumakonda,Elkathurthy
Hanumakonda,Inavole
Hanumakonda,Hanumakonda
Hanumakonda,Hasanparthy
Hanumakonda,Kamalapur
Hanumakonda,Kazipet
Hanumakonda,Khila Warangal
Hanumakonda,Velair
Hanumakonda,Warangal
Hyderabad,Amberpet
Hyderabad,Asif Nagar
Hyderabad,Bahadurpura
Hyderabad,Bandlaguda
Hyderabad,Charminar
Hyderabad,Golkonda
Hyderabad,Himayathnagar
Hyderabad,Nampally
Hyderabad,Saidabad
Hyderabad,Ameerpet
Hyderabad,Khairtabad
Hyderabad,Maredpally
Hyderabad,Musheerabad
Hyderabad,Secunderabad
Hyderabad,Shaikpet
Hyderabad,Tirumalagiri
Jagtial,Beerpur
Jagtial,Buggaram
Jagtial,Dharmapuri
Jagtial,Gollapalli
Jagtial,Ibrahimpatnam
Jagtial,Jagitial
Jagtial,Jagitial Rural
Jagtial,Kodimial
Jagtial,Korutla
Jagtial,Kathlapur
Jagtial,Mallial
Jagtial,Mallapur
Jagtial,Medipalli
Jagtial,Metpalli
Jagtial,Pegadapalli
Jagtial,Raikal
Jagtial,Sarangapur
Jagtial,Velgatur
Jangaon,Bachannapeta
Jangaon,Chilpur
Jangaon,Devaruppala
Jangaon,Gundala
Jangaon,Jangaon
Jangaon,Kodakandla
Jangaon,Lingalaghanpur
Jangaon,Narmetta
Jangaon,Palakurthi
Jangaon,Raghunathapalle
Jangaon,Station Ghanpur
Jangaon,Tarigoppula
Jangaon,Zaffergadh
Jayashankar Bhupalpally,Bhupalpalle
Jayashankar Bhupalpally,Chityal
Jayashankar Bhupalpally,Ghanpur
Jayashankar Bhupalpally,Kataram
Jayashankar Bhupalpally,Mahadevpur
Jayashankar Bhupalpally,Maha Mutharam
Jayashankar Bhupalpally,Malharrao
Jayashankar Bhupalpally,Mogullapalle
Jayashankar Bhupalpally,Palimela
Jayashankar Bhupalpally,Regonda
Jayashankar Bhupalpally,Tekumatla
Jogulamba Gadwal,Alamur (Alampur)
Jogulamba Gadwal,Dharoor (Dharur)
Jogulamba Gadwal,Gadwal
Jogulamba Gadwal,Ghattu
Jogulamba Gadwal,Itikyal
Jogulamba Gadwal,Maldakal
Jogulamba Gadwal,Manopad
Jogulamba Gadwal,Rajoli
Jogulamba Gadwal,Undavelli
Jogulamba Gadwal,Waddepally
Jogulamba Gadwal,Yerravally
Kamareddy,Banswada
Kamareddy,Bhiknoor
Kamareddy,Bibipet
Kamareddy,Bichkunda
Kamareddy,Birkur
Kamareddy,Domakonda
Kamareddy,Dongargaon (Dongli)
Kamareddy,Gandhari
Kamareddy,Jukkal
Kamareddy,Kamareddy
Kamareddy,Lingampet
Kamareddy,Machareddy
Kamareddy,Madnoor
Kamareddy,Mohammadnagar
Kamareddy,Nagireddypet
Kamareddy,Nasrullabad (Nasurullabad)
Kamareddy,Nizamsagar
Kamareddy,Palwancha
Kamareddy,Pedda Kodapally
Kamareddy,Pitlam
Kamareddy,Rajampet
Kamareddy,Ramareddy
Kamareddy,Sadashivanagar
Kamareddy,Tadwai
Kamareddy,Yellareddy
Karimnagar,Chigurumamidi
Karimnagar,Choppadandi
Karimnagar,Ellandakunta
Karimnagar,Gangadhara
Karimnagar,Ganneruvaram
Karimnagar,Huzurabad
Karimnagar,Jammikunta
Karimnagar,Karimnagar
Karimnagar,Karimnagar Rural
Karimnagar,Kothapally
Karimnagar,Manakondur
Karimnagar,Ramadugu
Karimnagar,Shankarapatnam
Karimnagar,Thimmapur
Karimnagar,V. Saidapur
Karimnagar,Veenavanka
Khammam,Bonakal
Khammam,Chinthakani
Khammam,Enkoor
Khammam,Kalluru
Khammam,Kamepalli
Khammam,Khammam Rural
Khammam,Khammam Urban
Khammam,Konijerla
Khammam,Kusumanchi
Khammam,Madhira
Khammam,Mudigonda
Khammam,Nelakondapalli
Khammam,Penuballi
Khammam,Raghunadhapalem
Khammam,Sathupalli
Khammam,Singareni
Khammam,Thallada
Khammam,Tirumalayapalem
Khammam,Vemsoor
Khammam,Wyra
Khammam,Yerrupalem
Kumuram Bheem Asifabad,Asifabad
Kumuram Bheem Asifabad,Bejjur
Kumuram Bheem Asifabad,Chintalmanepally
Kumuram Bheem Asifabad,Dahegaon
Kumuram Bheem Asifabad,Jainoor
Kumuram Bheem Asifabad,Kagaznagar
Kumuram Bheem Asifabad,Kerameri
Kumuram Bheem Asifabad,Koutala
Kumuram Bheem Asifabad,Lingapur
Kumuram Bheem Asifabad,Luxettipet
Kumuram Bheem Asifabad,Manyam
Kumuram Bheem Asifabad,Potkapally
Kumuram Bheem Asifabad,Sirpur (U)
Kumuram Bheem Asifabad,Tiryani
Mahabubabad,Bayyaram
Mahabubabad,Chinnagudur
Mahabubabad,Danthalapalle
Mahabubabad,Dornakal
Mahabubabad,Gangaram
Mahabubabad,Garla
Mahabubabad,Gudur
Mahabubabad,Inugurthy
Mahabubabad,Kesamudram
Mahabubabad,Kothaguda
Mahabubabad,Kuravi
Mahabubabad,Mahabubabad
Mahabubabad,Maripeda
Mahabubabad,Narsimhulapet
Mahabubabad,Nellikudur
Mahabubabad,Peddavangara
Mahabubabad,Seerole
Mahabubabad,Thorrur
Mahabubnagar,Addakal
Mahabubnagar,Balanagar
Mahabubnagar,Bhoothpur
Mahabubnagar,Chinna Chintakunta
Mahabubnagar,Devarakadra
Mahabubnagar,Gandeed
Mahabubnagar,Hanwada
Mahabubnagar,Jadcherla
Mahabubnagar,Koilkonda
Mahabubnagar,Koukuntla
Mahabubnagar,Mahabubnagar (Rural)
Mahabubnagar,Mahabubnagar (Urban)
Mahabubnagar,Midjil
Mahabubnagar,Moosapet
Mahabubnagar,Mohammadabad
Mahabubnagar,Nawabpet
Mahabubnagar,Rajapur
Mancherial,Bellampally
Mancherial,Bheemaram
Mancherial,Bheemini
Mancherial,Chennur
Mancherial,Dandepally
Mancherial,Hajipur
Mancherial,Jaipur
Mancherial,Jannaram
Mancherial,Kannepally
Mancherial,Kasipet
Mancherial,Kotapally
Mancherial,Luxettipet
Mancherial,Mancherial
Mancherial,Mandamarri
Mancherial,Naspur
Mancherial,Nennel
Mancherial,Tandur
Mancherial,Vemanpally
Medak,Alladurg
Medak,Chegunta
Medak,Chilpched
Medak,Havelighanapur
Medak,Kowdipally
Medak,Kulcharam
Medak,Manoharabad
Medak,Masaipet
Medak,Medak
Medak,Narsapur
Medak,Narsingi
Medak,Nizampet
Medak,Papannapet
Medak,Ramayampet
Medak,Regode
Medak,Shankarampet (A)
Medak,Shankarampet (R)
Medak,Shivampet
Medak,Tekmal
Medak,Toopran
Medak,Yeldurthy
Medchal-Malkajgiri,Alwal
Medchal-Malkajgiri,Bachupally
Medchal-Malkajgiri,Balanagar
Medchal-Malkajgiri,Dundigal
Medchal-Malkajgiri,Ghatkesar
Medchal-Malkajgiri,Kapra
Medchal-Malkajgiri,Keesara
Medchal-Malkajgiri,Kukatpally
Medchal-Malkajgiri,Malkajgiri
Medchal-Malkajgiri,Medchal
Medchal-Malkajgiri,Medipally
Medchal-Malkajgiri,Muduchinthalapally
Medchal-Malkajgiri,Quthbullapur
Medchal-Malkajgiri,Shamirpet
Medchal-Malkajgiri,Uppal
Mulugu,Eturnagaram
Mulugu,Govindaraopet
Mulugu,Kannaigudem
Mulugu,Mallampalli
Mulugu,Mangapet
Mulugu,Mulugu
Mulugu,Tadvai
Mulugu,Venkatapur
Mulugu,Venkatapuram
Mulugu,Wajedu
Nagarkurnool,Achampet
Nagarkurnool,Amrabad
Nagarkurnool,Balamoor
Nagarkurnool,Bijinapally
Nagarkurnool,Charakonda
Nagarkurnool,Kalwakurthy
Nagarkurnool,Kodair
Nagarkurnool,Kollapur
Nagarkurnool,Lingal
Nagarkurnool,Nagarkurnool
Nagarkurnool,Padara
Nagarkurnool,Peddakothapally
Nagarkurnool,Pentlavelli
Nagarkurnool,Tadoor
Nagarkurnool,Telkapally
Nagarkurnool,Thimmajipet
Nagarkurnool,Uppununthala
Nagarkurnool,Urkonda
Nagarkurnool,Vangoor
Nagarkurnool,Veldanda
Nalgonda,Adavidevulapalli
Nalgonda,Anumula
Nalgonda,Chandampeta
Nalgonda,Chandur
Nalgonda,Chinthapally
Nalgonda,Chityal
Nalgonda,Dameracherla
Nalgonda,Devarakonda
Nalgonda,Gattuppal
Nalgonda,Gudipally
Nalgonda,Gundlapally
Nalgonda,Gurrampode
Nalgonda,Kanagal
Nalgonda,Kattangur
Nalgonda,Kethepally
Nalgonda,Kondamallepally
Nalgonda,Madugulapally
Nalgonda,Marriguda
Nalgonda,Miryalaguda
Nalgonda,Munugode
Nalgonda,Nakrekal
Nalgonda,Nalgonda
Nalgonda,Nampally
Nalgonda,Narketpally
Nalgonda,Neredugommu
Narayanpet,Damargidda
Narayanpet,Dhanwada
Narayanpet,Gundumal
Narayanpet,Kosgi
Narayanpet,Kothapally (15)
Narayanpet,Krishna
Narayanpet,Maddur
Narayanpet,Maganoor
Narayanpet,Makthal
Narayanpet,Marikal
Narayanpet,Narayanpet
Narayanpet,Narwa
Narayanpet,Utkoor
Nirmal,Basar
Nirmal,Bhainsa
Nirmal,Dasturabad
Nirmal,Dilawarpur
Nirmal,Kaddam
Nirmal,Peddur
Nirmal,Khanapur
Nirmal,Kubeer
Nirmal,Kuntala
Nirmal,Laxmanchanda
Nirmal,Lokeswaram
Nirmal,Mamada
Nirmal,Mudhole
Nirmal,Narsapur (G)
Nirmal,Nirmal (Rural)
Nirmal,Nirmal (Urban)
Nirmal,Pembi
Nirmal,Sarangapur
Nirmal,Soan
Nirmal,Tanoor
Nizamabad,Aloor
Nizamabad,Armoor
Nizamabad,Balkonda
Nizamabad,Bheemgal
Nizamabad,Bodhan
Nizamabad,Chandur
Nizamabad,Dharpally
Nizamabad,Dichpally
Nizamabad,Donkeshwar
Nizamabad,Indalwai
Nizamabad,Jakranpally
Nizamabad,Kammarpally
Nizamabad,Kotagiri
Nizamabad,Makloor
Nizamabad,Mendora
Nizamabad,Morthad
Nizamabad,Mosara
Nizamabad,Mugpal
Nizamabad,Mupkal
Nizamabad,Nandipet
Nizamabad,Navipet
Nizamabad,Nizamabad North
Nizamabad,Nizamabad Rural
Nizamabad,Nizamabad South
Nizamabad,Pothangal
Peddapalli,Anthargaon
Peddapalli,Dharmaram
Peddapalli,Eligaid
Peddapalli,Julapalli
Peddapalli,Kamanpur
Peddapalli,Manthani
Peddapalli,Mutharam (Manthani)
Peddapalli,Odela
Peddapalli,Palakurthy
Peddapalli,Peddapalli
Peddapalli,Ramagiri
Peddapalli,Ramagundam
Peddapalli,Srirampur
Peddapalli,Sulthanabad
Rajanna Sircilla,Boinpalli
Rajanna Sircilla,Chandurthy
Rajanna Sircilla,Gambhiraopet
Rajanna Sircilla,Illanthakunta
Rajanna Sircilla,Konaraopet
Rajanna Sircilla,Mustabad
Rajanna Sircilla,Rudrangi
Rajanna Sircilla,Sircilla
Rajanna Sircilla,Thangallapalli
Rajanna Sircilla,Veernapalli
Rajanna Sircilla,Vemulawada
Rajanna Sircilla,Vemulawada (Rural)
Rajanna Sircilla,Yellareddipet
Rangareddy,Chevella
Rangareddy,Ibrahimpatnam
Rangareddy,Kandukur
Rangareddy,Rajendranagar
Rangareddy,Shadnagar
Rangareddy,Abdullapurmet
Rangareddy,Adibatla
Rangareddy,Amangal
Rangareddy,Chevella
Rangareddy,Hayathnagar
Rangareddy,Gandipet
Rangareddy,Hyderabad (parts)
Rangareddy,Kothur
Rangareddy,Kulukacharla
Rangareddy,L.B. Nagar
Rangareddy,Maheshwaram
Rangareddy,Manikonda
Rangareddy,Masjid Banda
Rangareddy,Meerpet-Jillelaguda
Rangareddy,Nacharam
Rangareddy,Pambour
Rangareddy,Pedda Amberpet
Rangareddy,Pothur
Rangareddy,Pocharam (H)
Rangareddy,Serilingampally
Rangareddy,Shamshabad
Rangareddy,Shankarpally
Rangareddy,Turkayamjal
Sangareddy,Ameenpur
Sangareddy,Andole
Sangareddy,Gummadidala
Sangareddy,Hathnoora
Sangareddy,Jinnaram
Sangareddy,Kandanda
Sangareddy,Kondapur
Sangareddy,Manoor
Sangareddy,Manopad
Sangareddy,Nagar
Sangareddy,Narayankhed
Sangareddy,Nagilgidda
Sangareddy,Patancheru
Sangareddy,Pulkal
Sangareddy,Ramchandrapuram
Sangareddy,Sadasivpet
Sangareddy,Sangareddy
Sangareddy,Sirgapur
Sangareddy,Vatpally
Sangareddy,Jharasangam
Sangareddy,Kohir
Sangareddy,Mogudampally
Sangareddy,Nyalkal
Sangareddy,Raikode
Sangareddy,Zaheerabad
Siddipet,Siddipet (Urban)
Siddipet,Siddipet (Rural)
Siddipet,Nangnoor
Siddipet,Chinnakodur
Siddipet,Thoguta
Siddipet,Doultabad
Siddipet,Mirdoddi
Siddipet,Dubbak
Siddipet,Cherial
Siddipet,Komuravelli
Siddipet,Gajwel
Siddipet,Jagdevpur
Siddipet,Kondapak
Siddipet,Mulug
Siddipet,Markook
Siddipet,Wargal
Siddipet,Raipole
Siddipet,Husnabad
Siddipet,Akkannapet
Siddipet,Koheda
Siddipet,Bejjanki
Siddipet,Maddur
Suryapet,Atmakur
Suryapet,Chivvemla
Suryapet,Jajireddygudem
Suryapet,Mothey
Suryapet,Nuthankal
Suryapet,Penpahad
Suryapet,Suryapet
Suryapet,Thirumalagiri
Suryapet,Thungathurthy
Suryapet,Garidepally
Suryapet,Neredcherla
Suryapet,Nagaram
Suryapet,Maddirala
Suryapet,Palakeedu
Suryapet,Chilkur
Suryapet,Huzurnagar
Suryapet,Kodad
Suryapet,Mattampally
Suryapet,Mellachervu
Suryapet,Munagala
Suryapet,Nadigudem
Suryapet,Ananthagiri
Suryapet,Mallareddygudem
Vikarabad,Basheerabad
Vikarabad,Bommaraspet
Vikarabad,Doultabad
Vikarabad,Kodangal
Vikarabad,Peddemul
Vikarabad,Tandur
Vikarabad,Yelal
Vikarabad,Doma
Vikarabad,Dharur
Vikarabad,Bantwaram
Vikarabad,Kulkacherla
Vikarabad,Kotepally
Vikarabad,Marpalle
Vikarabad,Mominpet
Vikarabad,Nawabpet
Vikarabad,Pudur
Vikarabad,Pargi
Vikarabad,Vikarabad
Wanaparthy,Amarchinta
Wanaparthy,Atmakur
Wanaparthy,Chinnambavi
Wanaparthy,Ghanpur (Khilla)
Wanaparthy,Gopalpeta
Wanaparthy,Kothakota
Wanaparthy,Madanapur
Wanaparthy,Pangal
Wanaparthy,Pebbair
Wanaparthy,Peddamandadi
Wanaparthy,Revally
Wanaparthy,Srirangapur
Wanaparthy,Veepanagandla
Wanaparthy,Wanaparthy
Warangal,Atmakur
Warangal,Damera
Warangal,Geesugonda
Warangal,Parkal
Warangal,Nadikuda
Warangal,Parvathagiri
Warangal,Rayaparthy
Warangal,Sangem
Warangal,Shayampet
Warangal,Wardhannapet
Warangal,Chennaraopet
Warangal,Duggondi
Warangal,Khanapur
Warangal,Narsampet
Warangal,Nallabelly
Warangal,Nekkonda
Yadadri Bhuvanagiri,Addaguduru
Yadadri Bhuvanagiri,Alair
Yadadri Bhuvanagiri,Atmakur (M)
Yadadri Bhuvanagiri,Bibinagar
Yadadri Bhuvanagiri,Bhongir
Yadadri Bhuvanagiri,Bommalaramaram
Yadadri Bhuvanagiri,Motakondur
Yadadri Bhuvanagiri,Mothkur
Yadadri Bhuvanagiri,Rajapet
Yadadri Bhuvanagiri,Turkapally
Yadadri Bhuvanagiri,Yadagirigutta
Yadadri Bhuvanagiri,Bhoodan Pochampally
Yadadri Bhuvanagiri,Choutuppal
Yadadri Bhuvanagiri,Narayanapur
Yadadri Bhuvanagiri,Ramannapet
Yadadri Bhuvanagiri,Valigonda"""

def parse_mandals_data():
    """Parse the mandals data from the string."""
    lines = MANDALS_DATA.strip().split('\n')
    mandals_list = []
    
    # Skip header line
    for line in lines[1:]:
        if not line.strip():
            continue
        # Split by comma, but handle cases where mandal name might contain commas
        parts = line.split(',', 1)  # Split only on first comma
        if len(parts) == 2:
            district_name = parts[0].strip()
            mandal_name = parts[1].strip()
            if district_name and mandal_name:
                mandals_list.append((district_name, mandal_name))
    
    return mandals_list

def populate_mandals():
    """Populate mandals table with the provided data."""
    app = create_app()
    
    with app.app_context():
        # Ensure districts are populated first
        district_count = District.query.count()
        if district_count == 0:
            print("⚠️  No districts found. Please run populate_districts_mandals.py first to populate districts.")
            return
        
        # Parse the data
        mandals_data = parse_mandals_data()
        print(f"Found {len(mandals_data)} mandals to populate")
        
        added_count = 0
        updated_count = 0
        skipped_count = 0
        district_not_found = []
        
        # Group by district for better error reporting
        district_mandals = {}
        for district_name, mandal_name in mandals_data:
            if district_name not in district_mandals:
                district_mandals[district_name] = []
            district_mandals[district_name].append(mandal_name)
        
        # Process each district
        for district_name, mandal_names in district_mandals.items():
            # Find district
            district = District.query.filter_by(name_en=district_name).first()
            if not district:
                print(f"⚠️  District '{district_name}' not found, skipping {len(mandal_names)} mandals")
                district_not_found.append(district_name)
                skipped_count += len(mandal_names)
                continue
            
            # Process mandals for this district
            for mandal_name in mandal_names:
                # Check if mandal already exists
                existing = Mandal.query.filter_by(district_id=district.id, name_en=mandal_name).first()
                
                if existing:
                    # Update if needed
                    if existing.name_te != mandal_name:
                        existing.name_te = mandal_name
                        updated_count += 1
                else:
                    # Create new mandal
                    new_mandal = Mandal(
                        district_id=district.id,
                        name_en=mandal_name,
                        name_te=mandal_name,  # Default to English name
                        is_active=True
                    )
                    db.session.add(new_mandal)
                    added_count += 1
        
        try:
            db.session.commit()
            print(f"\n✓ Successfully processed {len(mandals_data)} mandals")
            print(f"  - Added: {added_count}")
            print(f"  - Updated: {updated_count}")
            print(f"  - Skipped: {skipped_count}")
            
            if district_not_found:
                print(f"\n⚠️  Districts not found: {', '.join(district_not_found)}")
                print("   Please ensure districts are populated first using populate_districts_mandals.py")
        except Exception as e:
            db.session.rollback()
            print(f"\n✗ Error committing to database: {e}")
            import traceback
            traceback.print_exc()
            raise

def main():
    """Main function to run the script."""
    print("=" * 60)
    print("Populating Mandals Table")
    print("=" * 60)
    
    try:
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

