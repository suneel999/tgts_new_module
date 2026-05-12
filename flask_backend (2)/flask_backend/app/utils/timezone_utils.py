"""
Timezone utilities for centralized IST (Indian Standard Time) handling
All datetime operations should use IST timezone consistently across the application
"""

from datetime import datetime
import pytz

# IST timezone (UTC+5:30)
IST = pytz.timezone('Asia/Kolkata')

def get_ist_now():
    """
    Get current datetime in IST timezone
    Returns: datetime object with IST timezone info
    """
    return datetime.now(IST)

def utc_to_ist(utc_dt):
    """
    Convert UTC datetime to IST
    Args:
        utc_dt: datetime object (assumed to be UTC if naive, or UTC timezone aware)
    Returns: datetime object in IST timezone
    """
    if utc_dt is None:
        return None
    
    # If naive datetime, assume it's UTC
    if utc_dt.tzinfo is None:
        utc_dt = pytz.UTC.localize(utc_dt)
    
    # Convert to IST
    return utc_dt.astimezone(IST)

def ist_to_utc(ist_dt):
    """
    Convert IST datetime to UTC
    Args:
        ist_dt: datetime object in IST timezone
    Returns: datetime object in UTC timezone
    """
    if ist_dt is None:
        return None
    
    # If naive datetime, assume it's IST
    if ist_dt.tzinfo is None:
        ist_dt = IST.localize(ist_dt)
    
    # Convert to UTC
    return ist_dt.astimezone(pytz.UTC)

def parse_to_ist(date_string):
    """
    Parse ISO format date string and convert to IST
    Args:
        date_string: ISO format date string (e.g., "2024-01-15T00:00:00" or "2024-01-15")
    Returns: datetime object in IST timezone
    """
    if not date_string:
        return None
    
    try:
        # Handle both YYYY-MM-DD and ISO format
        if 'T' in date_string or 'Z' in date_string:
            # Parse ISO format
            dt = datetime.fromisoformat(date_string.replace('Z', '+00:00'))
        else:
            # Just date, add time component at midnight IST
            dt = datetime.fromisoformat(date_string + 'T00:00:00')
            dt = IST.localize(dt)
            return dt
        
        # If timezone aware, convert to IST
        if dt.tzinfo is not None:
            return dt.astimezone(IST)
        else:
            # Naive datetime, assume it's in IST
            return IST.localize(dt)
    except (ValueError, AttributeError) as e:
        raise ValueError(f'Invalid date format: {date_string}. Error: {str(e)}')

def format_ist_iso(dt):
    """
    Format datetime in IST to ISO format string
    Args:
        dt: datetime object (will be converted to IST if not already)
    Returns: ISO format string with IST timezone
    """
    if dt is None:
        return None
    
    # Ensure datetime is in IST
    if dt.tzinfo is None:
        dt = IST.localize(dt)
    else:
        dt = dt.astimezone(IST)
    
    return dt.isoformat()

def format_ist_for_display(dt, format_string='%Y-%m-%d %H:%M:%S %Z'):
    """
    Format datetime in IST for display
    Args:
        dt: datetime object (will be converted to IST if not already)
        format_string: strftime format string
    Returns: Formatted string
    """
    if dt is None:
        return None
    
    # Ensure datetime is in IST
    if dt.tzinfo is None:
        dt = IST.localize(dt)
    else:
        dt = dt.astimezone(IST)
    
    return dt.strftime(format_string)

def get_ist_now_naive():
    """
    Get current datetime in IST timezone as naive datetime
    This is for SQLAlchemy DateTime columns which store naive datetimes
    The datetime is in IST but without timezone info (assumed IST when read)
    Returns: naive datetime object (IST time, no timezone info)
    """
    return datetime.now(IST).replace(tzinfo=None)

def ensure_ist_aware(dt):
    """
    Ensure datetime is IST-aware. If naive, assume it's already in IST.
    Args:
        dt: datetime object (naive or timezone-aware)
    Returns: timezone-aware datetime in IST
    """
    if dt is None:
        return None
    
    if dt.tzinfo is None:
        # Naive datetime - assume it's in IST
        return IST.localize(dt)
    else:
        # Already timezone-aware, convert to IST
        return dt.astimezone(IST)

