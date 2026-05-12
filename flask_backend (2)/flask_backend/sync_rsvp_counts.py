"""
Utility script to sync RSVP counts for all events
This ensures the rsvp_count field in the events table matches the actual count in event_rsvps table
Run this if you need to fix any inconsistencies
"""

from app import create_app, db
from app.models import Event, EventRSVP

def sync_rsvp_counts():
    """Sync RSVP counts for all events"""
    app = create_app()
    with app.app_context():
        try:
            events = Event.query.all()
            updated_count = 0
            
            for event in events:
                actual_count = EventRSVP.query.filter_by(event_id=event.id).count()
                if event.rsvp_count != actual_count:
                    print(f"Updating event {event.id}: {event.rsvp_count} -> {actual_count}")
                    event.rsvp_count = actual_count
                    updated_count += 1
            
            if updated_count > 0:
                db.session.commit()
                print(f"\n✓ Updated RSVP counts for {updated_count} event(s)")
            else:
                print("\n✓ All RSVP counts are already in sync")
                
        except Exception as e:
            db.session.rollback()
            print(f"✗ Error syncing RSVP counts: {str(e)}")
            raise

if __name__ == '__main__':
    sync_rsvp_counts()

