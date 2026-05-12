#!/usr/bin/env python3
"""
Script to populate existing media items with content from S3
Run this to download and store media file content in the database
"""

from app import create_app, db
from app.models import MediaItem
from app.services.s3_service import get_s3_service

def populate_media_content():
    """Download and store content for all media items that don't have it"""
    
    app = create_app()
    with app.app_context():
        s3_service = get_s3_service()
        
        # Get all media items without content
        items_without_content = MediaItem.query.filter(
            (MediaItem.content == None) | (MediaItem.content == b'')
        ).all()
        
        print(f'Found {len(items_without_content)} media items without content')
        
        if len(items_without_content) == 0:
            print('All media items already have content!')
            return
        
        updated = 0
        failed = 0
        
        for item in items_without_content:
            try:
                print(f'Downloading content for: {item.title_en} ({item.url})')
                
                # Download file content
                content, content_type, size = s3_service.download_file(item.url)
                
                if content:
                    item.content = content
                    item.content_type = content_type
                    item.content_size = size
                    updated += 1
                    print(f'  ✓ Downloaded {size} bytes ({content_type})')
                else:
                    print(f'  ✗ Failed to download content')
                    failed += 1
                    
            except Exception as e:
                print(f'  ✗ Error: {str(e)}')
                failed += 1
                continue
        
        # Commit all updates
        try:
            db.session.commit()
            print(f'\n✓ Successfully updated {updated} media items with content')
            if failed > 0:
                print(f'  (Failed to update {failed} items)')
        except Exception as e:
            db.session.rollback()
            print(f'\n✗ Error committing changes: {str(e)}')

if __name__ == '__main__':
    populate_media_content()

