"""
Script to add geographic access control columns to news_items, events, media_items, and documents tables
Adds 4 JSONB columns per table: district_ids, mandal_ids, assembly_constituency_ids, parliamentary_constituency_ids
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

def add_geographic_access_columns():
    """Add geographic access control columns to content tables"""
    app = create_app()
    
    with app.app_context():
        try:
            from sqlalchemy import inspect, text
            inspector = inspect(db.engine)
            
            # Tables to update
            tables = ['news_items', 'events', 'media_items', 'documents']
            
            # Columns to add (4 per table)
            columns_to_add = [
                ('district_ids', 'JSONB'),
                ('mandal_ids', 'JSONB'),
                ('assembly_constituency_ids', 'JSONB'),
                ('parliamentary_constituency_ids', 'JSONB')
            ]
            
            with db.engine.connect() as conn:
                for table in tables:
                    print(f"\nProcessing table: {table}")
                    
                    # Check existing columns
                    try:
                        columns = [col['name'] for col in inspector.get_columns(table)]
                    except Exception as e:
                        print(f"  ⚠ Warning: Could not inspect table {table}: {e}")
                        continue
                    
                    for col_name, col_type in columns_to_add:
                        if col_name in columns:
                            print(f"  ✓ Column {col_name} already exists")
                            continue
                        
                        print(f"  Adding column {col_name}...")
                        try:
                            # Add column with default NULL
                            conn.execute(text(f"""
                                ALTER TABLE {table} 
                                ADD COLUMN {col_name} {col_type} DEFAULT NULL;
                            """))
                            
                            # Create GIN index for efficient JSONB queries
                            index_name = f"idx_{table}_{col_name}"
                            conn.execute(text(f"""
                                CREATE INDEX IF NOT EXISTS {index_name} 
                                ON {table} USING GIN ({col_name});
                            """))
                            
                            print(f"  ✓ Added {col_name} with GIN index")
                        except Exception as e:
                            print(f"  ✗ Error adding {col_name}: {e}")
                            # Continue with other columns
                    
                    conn.commit()
                    print(f"  ✓ Completed table: {table}")
            
            print("\n" + "=" * 60)
            print("✓ Successfully added geographic access columns to all tables")
            print("=" * 60)
            
        except Exception as e:
            print(f"\n✗ Error adding columns: {e}")
            import traceback
            traceback.print_exc()
            raise

if __name__ == '__main__':
    print("Adding geographic access control columns...")
    print("=" * 60)
    add_geographic_access_columns()
    print("=" * 60)
    print("✓ Migration completed!")

