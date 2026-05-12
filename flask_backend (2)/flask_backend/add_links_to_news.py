"""
Script to add links column to news_items table
Adds a JSONB column to store social media and external links
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

def add_links_column():
    """Add links column to news_items table"""
    app = create_app()
    
    with app.app_context():
        try:
            from sqlalchemy import inspect, text
            inspector = inspect(db.engine)
            
            table = 'news_items'
            column_name = 'links'
            column_type = 'JSONB'
            
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
                    return
                
                print(f"  Adding column {column_name}...")
                try:
                    # Add column with default NULL
                    conn.execute(text(f"""
                        ALTER TABLE {table} 
                        ADD COLUMN {column_name} {column_type} DEFAULT NULL;
                    """))
                    
                    # Create GIN index for efficient JSONB queries
                    index_name = f"idx_{table}_{column_name}"
                    conn.execute(text(f"""
                        CREATE INDEX IF NOT EXISTS {index_name} 
                        ON {table} USING GIN ({column_name});
                    """))
                    
                    print(f"  ✓ Added {column_name} with GIN index")
                    conn.commit()
                except Exception as e:
                    print(f"  ✗ Error adding {column_name}: {e}")
                    raise
                
                print(f"  ✓ Completed table: {table}")
            
            print("\n" + "=" * 60)
            print("✓ Successfully added links column to news_items table")
            print("=" * 60)
            
        except Exception as e:
            print(f"\n✗ Error adding column: {e}")
            import traceback
            traceback.print_exc()
            raise

if __name__ == '__main__':
    print("Adding links column to news_items table...")
    print("=" * 60)
    add_links_column()
    print("=" * 60)
    print("✓ Migration completed!")

