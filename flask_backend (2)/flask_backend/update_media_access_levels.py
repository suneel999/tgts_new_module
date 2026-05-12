"""
Script to update existing media items to have access_level='public' if NULL or missing
This ensures backward compatibility with existing media items
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

def update_media_access_levels():
    """Update existing media items to have access_level='public' if NULL or missing"""
    app = create_app()
    
    with app.app_context():
        try:
            from sqlalchemy import inspect, text
            from app.models import MediaItem
            
            inspector = inspect(db.engine)
            table = 'media_items'
            column_name = 'access_level'
            
            # Check if column exists
            try:
                columns = [col['name'] for col in inspector.get_columns(table)]
            except Exception as e:
                print(f"  ✗ Error: Could not inspect table {table}: {e}")
                print("  Please run the migration script first: python add_access_level_to_media.py")
                return
            
            if column_name not in columns:
                print(f"  ⚠ Column {column_name} does not exist in {table}")
                print("  Please run the migration script first: python add_access_level_to_media.py")
                return
            
            # Check for NULL or empty values
            with db.engine.connect() as conn:
                result = conn.execute(text(f"""
                    SELECT COUNT(*) as count 
                    FROM {table} 
                    WHERE {column_name} IS NULL OR {column_name} = '';
                """))
                null_count = result.fetchone()[0]
                
                if null_count == 0:
                    print(f"  ✓ All media items already have {column_name} set")
                    return
                
                print(f"  Found {null_count} media items with NULL or empty {column_name}")
                print(f"  Updating to 'public'...")
                
                # Update NULL or empty values to 'public'
                conn.execute(text(f"""
                    UPDATE {table} 
                    SET {column_name} = 'public' 
                    WHERE {column_name} IS NULL OR {column_name} = '';
                """))
                conn.commit()
                
                print(f"  ✓ Updated {null_count} media items to access_level='public'")
            
            print("\n" + "=" * 60)
            print("✓ Successfully updated media items access levels")
            print("=" * 60)
            
        except Exception as e:
            print(f"\n✗ Error updating access levels: {e}")
            import traceback
            traceback.print_exc()
            raise

if __name__ == '__main__':
    print("Updating media items access levels...")
    print("=" * 60)
    update_media_access_levels()
    print("=" * 60)
    print("✓ Update completed!")

