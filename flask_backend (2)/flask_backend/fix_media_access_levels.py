"""
Script to fix existing media items that have access_level stored as JSON array string
Converts '["public"]' to 'public', '["cadre"]' to 'cadre', etc.
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

def fix_media_access_levels():
    """Fix existing media items that have access_level stored as JSON array string"""
    app = create_app()
    
    with app.app_context():
        try:
            from sqlalchemy import inspect, text
            inspector = inspect(db.engine)
            
            table = 'media_items'
            column_name = 'access_level'
            
            with db.engine.connect() as conn:
                print(f"\nProcessing table: {table}")
                
                # Check existing columns
                try:
                    columns = [col['name'] for col in inspector.get_columns(table)]
                except Exception as e:
                    print(f"  ✗ Error: Could not inspect table {table}: {e}")
                    return
                
                if column_name not in columns:
                    print(f"  ⚠ Column {column_name} does not exist")
                    return
                
                # Get all media items with their access_level values
                result = conn.execute(text(f"""
                    SELECT id, {column_name} 
                    FROM {table}
                """))
                rows = result.fetchall()
                
                updated_count = 0
                for row_id, access_level_value in rows:
                    if not access_level_value:
                        continue
                    
                    # Check if it's a JSON array string like '["public"]'
                    if access_level_value.startswith('[') and access_level_value.endswith(']'):
                        try:
                            # Parse the JSON array
                            parsed = json.loads(access_level_value)
                            if isinstance(parsed, list) and len(parsed) > 0:
                                # Get the highest role from the array
                                role = parsed[0]  # For now, just take first
                                if 'admin' in parsed:
                                    role = 'admin'
                                elif 'cadre' in parsed:
                                    role = 'cadre'
                                else:
                                    role = 'public'
                                
                                # Update to single role string
                                conn.execute(text(f"""
                                    UPDATE {table} 
                                    SET {column_name} = :role 
                                    WHERE id = :id
                                """), {"role": role, "id": row_id})
                                updated_count += 1
                                print(f"  Updated {row_id}: '{access_level_value}' -> '{role}'")
                        except json.JSONDecodeError:
                            # If it's not valid JSON, set to 'public'
                            conn.execute(text(f"""
                                UPDATE {table} 
                                SET {column_name} = 'public' 
                                WHERE id = :id
                            """), {"id": row_id})
                            updated_count += 1
                            print(f"  Updated {row_id}: '{access_level_value}' -> 'public' (invalid JSON)")
                
                if updated_count > 0:
                    conn.commit()
                    print(f"\n  ✓ Updated {updated_count} media items")
                else:
                    print(f"\n  ✓ No updates needed - all values are already in correct format")
            
            print("\n" + "=" * 60)
            print("✓ Successfully fixed media items access levels")
            print("=" * 60)
            
        except Exception as e:
            print(f"\n✗ Error fixing access levels: {e}")
            import traceback
            traceback.print_exc()
            raise

if __name__ == '__main__':
    print("Fixing media items access levels...")
    print("=" * 60)
    fix_media_access_levels()
    print("=" * 60)
    print("✓ Fix completed!")

