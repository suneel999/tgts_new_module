"""
Script to add access_level column to media_items table
Adds access_level column (JSON string) with default value of ["public"]
"""
import os
import sys
import json
from pathlib import Path

# Add the parent directory to the path so we can import app
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import create_app, db
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def add_access_level_to_media():
    """Add access_level column to media_items table"""
    app = create_app()
    
    with app.app_context():
        try:
            from sqlalchemy import inspect, text
            inspector = inspect(db.engine)
            
            table = 'media_items'
            column_name = 'access_level'
            default_value = 'public'  # Default to "public" (single role string)
            
            with db.engine.connect() as conn:
                print(f"\nProcessing table: {table}")
                
                # Check existing columns
                try:
                    columns = [col['name'] for col in inspector.get_columns(table)]
                except Exception as e:
                    print(f"  ✗ Error: Could not inspect table {table}: {e}")
                    raise
                
                if column_name in columns:
                    print(f"  ✓ Column {column_name} already exists")
                    print(f"  Updating existing NULL values to default...")
                    
                    # Update any NULL values to default
                    try:
                        conn.execute(text(f"""
                            UPDATE {table} 
                            SET {column_name} = 'public' 
                            WHERE {column_name} IS NULL;
                        """))
                        conn.commit()
                        print(f"  ✓ Updated NULL values to default")
                    except Exception as e:
                        print(f"  ⚠ Warning: Could not update NULL values: {e}")
                else:
                    print(f"  Adding column {column_name}...")
                    try:
                        # Add column with default value (single role string, not JSON)
                        conn.execute(text(f"""
                            ALTER TABLE {table} 
                            ADD COLUMN {column_name} VARCHAR(20) DEFAULT 'public' NOT NULL;
                        """))
                        
                        print(f"  ✓ Added {column_name} with default value")
                        conn.commit()
                    except Exception as e:
                        print(f"  ✗ Error adding {column_name}: {e}")
                        raise
                
                print(f"  ✓ Completed table: {table}")
            
            print("\n" + "=" * 60)
            print("✓ Successfully added access_level column to media_items table")
            print("=" * 60)
            
        except Exception as e:
            print(f"\n✗ Error adding column: {e}")
            import traceback
            traceback.print_exc()
            raise

if __name__ == '__main__':
    print("Adding access_level column to media_items...")
    print("=" * 60)
    add_access_level_to_media()
    print("=" * 60)
    print("✓ Migration completed!")

