"""
Script to create the event_rsvps table
Run this script to add the new table to your database
"""

from app import create_app, db
from app.models import EventRSVP

def create_rsvp_table():
    """Create the event_rsvps table"""
    app = create_app()
    with app.app_context():
        try:
            # Create the table
            db.create_all()
            print("✓ event_rsvps table created successfully!")
            print("\nTable structure:")
            print("  - id: String(50), Primary Key")
            print("  - event_id: String(50), Foreign Key to events.id")
            print("  - phone_number: String(15)")
            print("  - created_at: DateTime")
            print("  - Unique constraint on (event_id, phone_number)")
        except Exception as e:
            print(f"✗ Error creating table: {str(e)}")
            raise

if __name__ == '__main__':
    create_rsvp_table()

