"""
Utility functions for managing media statistics (photo and video counts)
"""
from app import db
from app.models import MediaStats, MediaItem
from app.utils.timezone_utils import get_ist_now_naive
import logging

logger = logging.getLogger(__name__)

def get_or_create_media_stats():
    """Get or create the singleton MediaStats record"""
    stats = MediaStats.query.get('media_stats_singleton')
    if not stats:
        stats = MediaStats(
            id='media_stats_singleton',
            photo_count=0,
            video_count=0
        )
        db.session.add(stats)
        db.session.commit()
        logger.info("Created new MediaStats record")
    return stats

def recalculate_media_counts():
    """Recalculate media counts from the database and update MediaStats (only published items)"""
    try:
        photo_count = MediaItem.query.filter_by(type='photo', is_published=True).count()
        video_count = MediaItem.query.filter_by(type='video', is_published=True).count()
        
        stats = get_or_create_media_stats()
        stats.photo_count = photo_count
        stats.video_count = video_count
        stats.updated_at = get_ist_now_naive()
        
        db.session.commit()
        logger.info(f"Recalculated media counts: {photo_count} published photos, {video_count} published videos")
        return stats
    except Exception as e:
        logger.error(f"Error recalculating media counts: {str(e)}")
        db.session.rollback()
        raise

def increment_media_count(media_type, is_published=False):
    """Increment the count for the given media type (photo or video) - only if published"""
    try:
        if media_type not in ['photo', 'video']:
            logger.warning(f"Invalid media type for count increment: {media_type}")
            return
        
        # Only increment if the media is published
        if not is_published:
            logger.debug(f"Skipping count increment for unpublished {media_type}")
            return
        
        stats = get_or_create_media_stats()
        
        if media_type == 'photo':
            stats.photo_count += 1
        elif media_type == 'video':
            stats.video_count += 1
        
        stats.updated_at = get_ist_now_naive()
        db.session.commit()
        logger.debug(f"Incremented {media_type} count (published)")
    except Exception as e:
        logger.error(f"Error incrementing {media_type} count: {str(e)}")
        db.session.rollback()
        # Don't raise - allow the operation to continue even if stats update fails

def decrement_media_count(media_type, was_published=False):
    """Decrement the count for the given media type (photo or video) - only if it was published"""
    try:
        if media_type not in ['photo', 'video']:
            logger.warning(f"Invalid media type for count decrement: {media_type}")
            return
        
        # Only decrement if the media was published
        if not was_published:
            logger.debug(f"Skipping count decrement for unpublished {media_type}")
            return
        
        stats = get_or_create_media_stats()
        
        if media_type == 'photo':
            stats.photo_count = max(0, stats.photo_count - 1)
        elif media_type == 'video':
            stats.video_count = max(0, stats.video_count - 1)
        
        stats.updated_at = get_ist_now_naive()
        db.session.commit()
        logger.debug(f"Decremented {media_type} count (was published)")
    except Exception as e:
        logger.error(f"Error decrementing {media_type} count: {str(e)}")
        db.session.rollback()
        # Don't raise - allow the operation to continue even if stats update fails

def update_media_count_on_publish_change(media_type, was_published, is_now_published):
    """Update count when publish status changes"""
    try:
        if media_type not in ['photo', 'video']:
            logger.warning(f"Invalid media type for publish status change: {media_type}")
            return
        
        # If status didn't change, do nothing
        if was_published == is_now_published:
            return
        
        stats = get_or_create_media_stats()
        
        # If being published, increment
        if is_now_published and not was_published:
            if media_type == 'photo':
                stats.photo_count += 1
            elif media_type == 'video':
                stats.video_count += 1
            logger.debug(f"Incremented {media_type} count (published)")
        # If being unpublished, decrement
        elif not is_now_published and was_published:
            if media_type == 'photo':
                stats.photo_count = max(0, stats.photo_count - 1)
            elif media_type == 'video':
                stats.video_count = max(0, stats.video_count - 1)
            logger.debug(f"Decremented {media_type} count (unpublished)")
        
        stats.updated_at = get_ist_now_naive()
        db.session.commit()
    except Exception as e:
        logger.error(f"Error updating {media_type} count on publish change: {str(e)}")
        db.session.rollback()
        # Don't raise - allow the operation to continue even if stats update fails

def get_media_stats():
    """Get current media statistics - auto-recalculates if counts are 0 but published items exist"""
    stats = get_or_create_media_stats()
    
    # If counts are 0, check if there are actually published items in the database
    # If so, recalculate to ensure accuracy
    if stats.photo_count == 0 and stats.video_count == 0:
        actual_photo_count = MediaItem.query.filter_by(type='photo', is_published=True).count()
        actual_video_count = MediaItem.query.filter_by(type='video', is_published=True).count()
        
        # If there are published items but counts are 0, recalculate
        if actual_photo_count > 0 or actual_video_count > 0:
            logger.info("Stats show 0 but published items exist - recalculating counts")
            return recalculate_media_counts().to_dict()
    
    return stats.to_dict()

