"""
Migration script to add profile_picture_url column to members table
Run this script to add the profile_picture_url column to the members table
"""

from app import create_app, db
from app.models.member import Member

def add_profile_picture_column():
    """Add profile_picture_url column to members table"""
    app = create_app()
    
    with app.app_context():
        try:
            # Check if column already exists
            inspector = db.inspect(db.engine)
            columns = [col['name'] for col in inspector.get_columns('members')]
            
            if 'profile_picture_url' in columns:
                print("Column 'profile_picture_url' already exists in members table")
                return
            
            # Add the column using raw SQL
            with db.engine.connect() as conn:
                conn.execute(db.text("""
                    ALTER TABLE members 
                    ADD COLUMN profile_picture_url VARCHAR(500)
                """))
                conn.commit()
            
            print("Successfully added 'profile_picture_url' column to members table")
            
        except Exception as e:
            print(f"Error adding column: {str(e)}")
            raise

if __name__ == '__main__':
    add_profile_picture_column()

