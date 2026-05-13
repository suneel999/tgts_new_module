"""
Script to extract parliamentary constituencies from PDF and populate the database.
"""
import os
import sys
import re
from pathlib import Path

# Add the parent directory to the path so we can import app
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# PDF libraries are optional - we have manual data
USE_PDFPLUMBER = False
try:
    import pdfplumber
    USE_PDFPLUMBER = True
except ImportError:
    try:
        import PyPDF2
        USE_PDFPLUMBER = False
    except ImportError:
        pass  # Will use manual data instead

from app import create_app, db
from app.models.parliamentary_constituency import ParliamentaryConstituency
from app.seed_constituencies import MANUAL_CONSTITUENCIES
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def extract_text_with_pdfplumber(pdf_path):
    """Extract text from PDF using pdfplumber."""
    constituencies = []
    with pdfplumber.open(pdf_path) as pdf:
        for page_num, page in enumerate(pdf.pages, 1):
            text = page.extract_text()
            if text:
                # Try to extract constituency information
                lines = text.split('\n')
                for line in lines:
                    line = line.strip()
                    if line:
                        # Try to match patterns like "1. Constituency Name" or "1 Constituency Name"
                        match = re.match(r'^(\d+)\.?\s+(.+)$', line)
                        if match:
                            number = int(match.group(1))
                            name = match.group(2).strip()
                            if name and len(name) > 2:  # Basic validation
                                constituencies.append({
                                    'number': number,
                                    'name': name
                                })
    return constituencies

def extract_text_with_pypdf2(pdf_path):
    """Extract text from PDF using PyPDF2."""
    constituencies = []
    with open(pdf_path, 'rb') as file:
        pdf_reader = PyPDF2.PdfReader(file)
        for page_num, page in enumerate(pdf_reader.pages, 1):
            text = page.extract_text()
            if text:
                lines = text.split('\n')
                for line in lines:
                    line = line.strip()
                    if line:
                        # Try to match patterns like "1. Constituency Name" or "1 Constituency Name"
                        match = re.match(r'^(\d+)\.?\s+(.+)$', line)
                        if match:
                            number = int(match.group(1))
                            name = match.group(2).strip()
                            if name and len(name) > 2:  # Basic validation
                                constituencies.append({
                                    'number': number,
                                    'name': name
                                })
    return constituencies

def parse_manual_data():
    """Parse the manual constituency data provided by the user."""
    return MANUAL_CONSTITUENCIES

def extract_constituencies_from_pdf(pdf_path):
    """Extract constituency data from PDF file."""
    # If PDF libraries aren't available, use manual data
    if not USE_PDFPLUMBER:
        try:
            import PyPDF2
        except ImportError:
            print("PDF libraries not available. Using manual data...")
            return parse_manual_data()
    
    print(f"Extracting data from PDF: {pdf_path}")
    
    if not os.path.exists(pdf_path):
        print(f"Warning: PDF file not found at {pdf_path}")
        print("Using manual data instead...")
        return parse_manual_data()
    
    try:
        if USE_PDFPLUMBER:
            constituencies = extract_text_with_pdfplumber(pdf_path)
        else:
            import PyPDF2
            constituencies = extract_text_with_pypdf2(pdf_path)
        
        # If PDF extraction didn't work well, use manual data
        if len(constituencies) < 10:
            print("PDF extraction didn't find enough constituencies. Using manual data...")
            return parse_manual_data()
        
        # Remove duplicates based on constituency number
        seen = set()
        unique_constituencies = []
        for const in constituencies:
            if const['number'] not in seen:
                seen.add(const['number'])
                unique_constituencies.append(const)
        
        # Sort by number
        unique_constituencies.sort(key=lambda x: x['number'])
        
        print(f"Extracted {len(unique_constituencies)} unique constituencies from PDF")
        return unique_constituencies
    except Exception as e:
        print(f"Error extracting from PDF: {e}")
        print("Using manual data instead...")
        return parse_manual_data()

def populate_database(constituencies_data):
    """Populate the database with constituency data."""
    app = create_app()
    
    with app.app_context():
        # Create tables if they don't exist
        db.create_all()
        
        added_count = 0
        updated_count = 0
        skipped_count = 0
        
        for const_data in constituencies_data:
            constituency_number = const_data['number']
            name_en = const_data['name']
            
            # Check if constituency already exists
            existing = ParliamentaryConstituency.query.filter_by(
                constituency_number=constituency_number
            ).first()
            
            if existing:
                # Update existing record
                existing.name_en = name_en
                existing.name_te = name_en  # Default to English name if Telugu not available
                updated_count += 1
                print(f"Updated: {constituency_number}. {name_en}")
            else:
                # Create new record - using constituency_number as primary key
                new_constituency = ParliamentaryConstituency(
                    constituency_number=constituency_number,
                    name_en=name_en,
                    name_te=name_en,  # Default to English name if Telugu not available
                    state='Telangana',
                    is_active=True
                )
                db.session.add(new_constituency)
                added_count += 1
                print(f"Added: {constituency_number}. {name_en}")
        
        try:
            db.session.commit()
            print(f"\n✓ Successfully processed {len(constituencies_data)} constituencies")
            print(f"  - Added: {added_count}")
            print(f"  - Updated: {updated_count}")
            print(f"  - Skipped: {skipped_count}")
        except Exception as e:
            db.session.rollback()
            print(f"\n✗ Error committing to database: {e}")
            raise

def main():
    """Main function to run the script."""
    # Find the PDF file
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    pdf_path = project_root / "parlamentary constituencies list.pdf"
    
    # Try to extract from PDF, but use manual data as fallback
    constituencies = extract_constituencies_from_pdf(str(pdf_path))
    
    if not constituencies:
        print("No constituencies found. Using manual data...")
        constituencies = parse_manual_data()
    
    # Display extracted data
    print("\nConstituencies to be added/updated:")
    print("-" * 60)
    for const in constituencies:
        print(f"{const['number']:2d}. {const['name']}")
    print("-" * 60)
    print(f"Total: {len(constituencies)} constituencies")
    
    # Ask for confirmation
    response = input(f"\nProceed to populate database with {len(constituencies)} constituencies? (y/n): ")
    if response.lower() != 'y':
        print("Operation cancelled.")
        sys.exit(0)
    
    # Populate database
    populate_database(constituencies)
    print("\n✓ Database population completed!")

if __name__ == '__main__':
    main()
