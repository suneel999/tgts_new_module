#!/usr/bin/env python3
"""
Script to remove unwanted media items from database
Use this to keep only the media items you want
"""

from app import create_app, db
from app.models import MediaItem

def cleanup_media():
    """Remove unwanted media items"""
    
    app = create_app()
    with app.app_context():
        # Get all media items
        all_items = MediaItem.query.all()
        photos = [item for item in all_items if item.type == 'photo']
        videos = [item for item in all_items if item.type == 'video']
        
        print(f'Current database:')
        print(f'  Photos: {len(photos)}')
        print(f'  Videos: {len(videos)}')
        print(f'  Total: {len(all_items)}')
        print()
        
        print('Photos:')
        for i, photo in enumerate(photos, 1):
            print(f'  {i}. {photo.title_en} (ID: {photo.id[:8]}...)')
        print()
        
        print('Videos:')
        for i, video in enumerate(videos, 1):
            print(f'  {i}. {video.title_en} (ID: {video.id[:8]}...)')
        print()
        
        # Option 1: Keep only the most recent 6 photos
        print('Option 1: Keep only the 6 most recent photos')
        photos_sorted = sorted(photos, key=lambda x: x.created_at, reverse=True)
        photos_to_keep = photos_sorted[:6]
        photos_to_remove = photos_sorted[6:]
        
        print(f'  Photos to keep ({len(photos_to_keep)}):')
        for photo in photos_to_keep:
            print(f'    - {photo.title_en}')
        
        print(f'\\n  Photos to remove ({len(photos_to_remove)}):')
        for photo in photos_to_remove:
            print(f'    - {photo.title_en}')
        
        response = input('\\nRemove these photos? (yes/no): ')
        if response.lower() == 'yes':
            for photo in photos_to_remove:
                print(f'Removing: {photo.title_en}')
                db.session.delete(photo)
            
            db.session.commit()
            print(f'\\n✓ Removed {len(photos_to_remove)} photos')
            print(f'✓ Kept {len(photos_to_keep)} photos and {len(videos)} videos')
        else:
            print('Cancelled. No changes made.')

if __name__ == '__main__':
    cleanup_media()

