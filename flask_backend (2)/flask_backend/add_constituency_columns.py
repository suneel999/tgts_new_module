"""
Script to add parliament_constituency_id and assembly_constituency_id columns to members table
"""
import os
import sys
from pathlib import Path

# Add the parent directory to the path so we can import app
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import create_app, db
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def add_constituency_columns():
    """Add parliament_constituency_id and assembly_constituency_id columns to members table"""
    app = create_app()
    
    with app.app_context():
        try:
            # Check if columns already exist
            from sqlalchemy import inspect, text
            inspector = inspect(db.engine)
            columns = [col['name'] for col in inspector.get_columns('members')]
            
            has_parliament_id = 'parliament_constituency_id' in columns
            has_assembly_id = 'assembly_constituency_id' in columns
            
            if has_parliament_id and has_assembly_id:
                print("✓ Columns already exist. No changes needed.")
                return
            
            # Add columns if they don't exist
            with db.engine.connect() as conn:
                if not has_parliament_id:
                    print("Adding parliament_constituency_id column...")
                    conn.execute(text("""
                        ALTER TABLE members 
                        ADD COLUMN parliament_constituency_id VARCHAR(50);
                    """))
                    conn.execute(text("""
                        ALTER TABLE members 
                        ADD CONSTRAINT fk_members_parliament_constituency 
                        FOREIGN KEY (parliament_constituency_id) 
                        REFERENCES parliamentary_constituencies(id);
                    """))
                    print("✓ Added parliament_constituency_id column")
                
                if not has_assembly_id:
                    print("Adding assembly_constituency_id column...")
                    conn.execute(text("""
                        ALTER TABLE members 
                        ADD COLUMN assembly_constituency_id VARCHAR(50);
                    """))
                    conn.execute(text("""
                        ALTER TABLE members 
                        ADD CONSTRAINT fk_members_assembly_constituency 
                        FOREIGN KEY (assembly_constituency_id) 
                        REFERENCES assembly_constituencies(id);
                    """))
                    print("✓ Added assembly_constituency_id column")
                
                conn.commit()
            
            print("\n✓ Successfully added constituency ID columns to members table")
            
        except Exception as e:
            print(f"\n✗ Error adding columns: {e}")
            import traceback
            traceback.print_exc()
            raise

if __name__ == '__main__':
    print("Adding constituency ID columns to members table...")
    print("-" * 60)
    add_constituency_columns()
    print("-" * 60)
    print("✓ Migration completed!")

