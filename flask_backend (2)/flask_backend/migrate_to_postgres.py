#!/usr/bin/env python3
"""
Script to migrate media items from SQLite to PostgreSQL
Run this after updating .env to use PostgreSQL
"""

import sqlite3
from app import create_app, db
from app.models import MediaItem
from datetime import datetime

def migrate_media_items():
    """Migrate media items from SQLite to PostgreSQL"""
    
    # Read from SQLite
    sqlite_conn = sqlite3.connect('instance/telangana_congress_prod.db')
    sqlite_cursor = sqlite_conn.cursor()
    sqlite_cursor.execute('''
        SELECT id, type, url, thumbnail_url, title_en, title_te, 
               is_published, created_at, updated_at 
        FROM media_items
    ''')
    sqlite_items = sqlite_cursor.fetchall()
    sqlite_conn.close()
    
    print(f'Found {len(sqlite_items)} items in SQLite')
    
    # Write to PostgreSQL
    app = create_app()
    with app.app_context():
        # Check current PostgreSQL count
        pg_count = MediaItem.query.count()
        print(f'Current PostgreSQL count: {pg_count}')
        
        if pg_count > 0:
            print('⚠ PostgreSQL already has data. Skipping migration.')
            return
        
        if len(sqlite_items) == 0:
            print('⚠ SQLite database is empty. Nothing to migrate.')
            return
        
        print('Migrating data from SQLite to PostgreSQL...')
        migrated = 0
        skipped = 0
        
        for item in sqlite_items:
            # Check if exists
            existing = MediaItem.query.filter_by(id=item[0]).first()
            if existing:
                skipped += 1
                continue
            
            # Parse datetime strings if they exist
            created_at = None
            updated_at = None
            if item[7]:
                try:
                    created_at = datetime.fromisoformat(item[7].replace('Z', '+00:00'))
                except:
                    created_at = datetime.utcnow()
            if item[8]:
                try:
                    updated_at = datetime.fromisoformat(item[8].replace('Z', '+00:00'))
                except:
                    updated_at = datetime.utcnow()
            
            media_item = MediaItem(
                id=item[0],
                type=item[1],
                url=item[2],
                thumbnail_url=item[3],
                title_en=item[4],
                title_te=item[5],
                is_published=bool(item[6]),
                created_at=created_at or datetime.utcnow(),
                updated_at=updated_at or datetime.utcnow()
            )
            db.session.add(media_item)
            migrated += 1
        
        try:
            db.session.commit()
            print(f'✓ Successfully migrated {migrated} items to PostgreSQL')
            if skipped > 0:
                print(f'  (Skipped {skipped} items that already existed)')
        except Exception as e:
            db.session.rollback()
            print(f'✗ Error migrating data: {str(e)}')
            return
        
        # Verify
        final_count = MediaItem.query.count()
        print(f'Final PostgreSQL count: {final_count}')

if __name__ == '__main__':
    migrate_media_items()

