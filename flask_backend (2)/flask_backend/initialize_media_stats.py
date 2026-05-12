#!/usr/bin/env python3
"""
Script to initialize media statistics with current counts from the database.
Run this script once after deploying the media stats feature to populate
the initial counts.
"""

from app import create_app, db
from app.models import MediaItem, MediaStats
from app.utils.media_stats_utils import recalculate_media_counts

def initialize_media_stats():
    """Initialize media stats with current counts from database"""
    app = create_app()
    with app.app_context():
        try:
            print("Initializing media statistics...")
            
            # Recalculate counts from database
            stats = recalculate_media_counts()
            
            print(f"✓ Media statistics initialized successfully!")
            print(f"  Published Photos: {stats.photo_count}")
            print(f"  Published Videos: {stats.video_count}")
            print(f"  Total Published: {stats.photo_count + stats.video_count}")
            
        except Exception as e:
            print(f"✗ Error initializing media statistics: {str(e)}")
            raise

if __name__ == '__main__':
    initialize_media_stats()

