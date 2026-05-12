"""
Script to optimize constituency foreign key columns from VARCHAR(50) to VARCHAR(36)
UUIDs are 36 characters, so VARCHAR(50) is wasteful
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

def optimize_columns():
    """Optimize foreign key columns from VARCHAR(50) to VARCHAR(36) for UUIDs"""
    app = create_app()
    
    with app.app_context():
        try:
            from sqlalchemy import inspect, text
            
            print("Optimizing foreign key columns...")
            print("-" * 60)
            
            with db.engine.connect() as conn:
                # Check current column types
                inspector = inspect(db.engine)
                
                # Get current column info
                columns = inspector.get_columns('members')
                parliament_col = next((c for c in columns if c['name'] == 'parliament_constituency_id'), None)
                assembly_col = next((c for c in columns if c['name'] == 'assembly_constituency_id'), None)
                
                if parliament_col:
                    current_type = str(parliament_col['type'])
                    print(f"Current parliament_constituency_id type: {current_type}")
                    if '50' in current_type or 'VARCHAR(50)' in current_type.upper():
                        print("Optimizing parliament_constituency_id to VARCHAR(36)...")
                        # Drop foreign key constraint first
                        conn.execute(text("""
                            ALTER TABLE members 
                            DROP CONSTRAINT IF EXISTS fk_members_parliament_constituency;
                        """))
                        # Alter column type
                        conn.execute(text("""
                            ALTER TABLE members 
                            ALTER COLUMN parliament_constituency_id TYPE VARCHAR(36);
                        """))
                        # Re-add foreign key constraint
                        conn.execute(text("""
                            ALTER TABLE members 
                            ADD CONSTRAINT fk_members_parliament_constituency 
                            FOREIGN KEY (parliament_constituency_id) 
                            REFERENCES parliamentary_constituencies(id);
                        """))
                        print("✓ Optimized parliament_constituency_id to VARCHAR(36)")
                    else:
                        print("✓ parliament_constituency_id already optimized")
                
                if assembly_col:
                    current_type = str(assembly_col['type'])
                    print(f"Current assembly_constituency_id type: {current_type}")
                    if '50' in current_type or 'VARCHAR(50)' in current_type.upper():
                        print("Optimizing assembly_constituency_id to VARCHAR(36)...")
                        # Drop foreign key constraint first
                        conn.execute(text("""
                            ALTER TABLE members 
                            DROP CONSTRAINT IF EXISTS fk_members_assembly_constituency;
                        """))
                        # Alter column type
                        conn.execute(text("""
                            ALTER TABLE members 
                            ALTER COLUMN assembly_constituency_id TYPE VARCHAR(36);
                        """))
                        # Re-add foreign key constraint
                        conn.execute(text("""
                            ALTER TABLE members 
                            ADD CONSTRAINT fk_members_assembly_constituency 
                            FOREIGN KEY (assembly_constituency_id) 
                            REFERENCES assembly_constituencies(id);
                        """))
                        print("✓ Optimized assembly_constituency_id to VARCHAR(36)")
                    else:
                        print("✓ assembly_constituency_id already optimized")
                
                conn.commit()
            
            print("\n✓ Column optimization completed!")
            
        except Exception as e:
            print(f"\n✗ Error optimizing columns: {e}")
            import traceback
            traceback.print_exc()
            raise

if __name__ == '__main__':
    print("Optimizing foreign key columns for UUID storage...")
    print("UUIDs are 36 characters, so VARCHAR(50) is wasteful")
    print("-" * 60)
    optimize_columns()
    print("-" * 60)
    print("✓ Optimization completed!")

