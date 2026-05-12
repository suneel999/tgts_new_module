"""
Migration script to add access_level column to events table
Run this script to update your database schema
"""

from app import create_app, db
from sqlalchemy import text

def add_access_level_column():
    """Add access_level column to events table"""
    app = create_app()
    
    with app.app_context():
        try:
            # Check if column already exists
            result = db.session.execute(text("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name='events' AND column_name='access_level'
            """))
            
            if result.fetchone():
                print("✓ access_level column already exists in events table")
                return
            
            # Add the column
            db.session.execute(text("""
                ALTER TABLE events 
                ADD COLUMN access_level VARCHAR(20) NOT NULL DEFAULT 'public'
            """))
            
            db.session.commit()
            print("✓ Successfully added access_level column to events table")
            print("  Default value: 'public'")
            print("  Allowed values: 'public', 'cadre', 'admin'")
            
        except Exception as e:
            db.session.rollback()
            print(f"✗ Error adding access_level column: {str(e)}")
            raise

if __name__ == '__main__':
    print("Adding access_level column to events table...")
    add_access_level_column()
    print("\nMigration completed successfully!")
