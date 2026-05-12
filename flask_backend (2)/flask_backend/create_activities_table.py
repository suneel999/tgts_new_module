"""
Script to create the activities table in the database
Run this script to add the activities table to your database
"""

from app import create_app, db
from app.models import Activity
import sys

def create_activities_table():
    """Create the activities table"""
    app = create_app()
    
    with app.app_context():
        try:
            # Create the table
            Activity.__table__.create(db.engine, checkfirst=True)
            print("[✓] Activities table created successfully")
            
            # Verify the table was created
            from sqlalchemy import inspect
            inspector = inspect(db.engine)
            tables = inspector.get_table_names()
            
            if 'activities' in tables:
                print("[✓] Activities table verified in database")
                print(f"[✓] Total tables in database: {len(tables)}")
                return True
            else:
                print("[✗] Error: Activities table not found after creation")
                return False
                
        except Exception as e:
            print(f"[✗] Error creating activities table: {str(e)}")
            import traceback
            traceback.print_exc()
            return False

if __name__ == '__main__':
    success = create_activities_table()
    sys.exit(0 if success else 1)





