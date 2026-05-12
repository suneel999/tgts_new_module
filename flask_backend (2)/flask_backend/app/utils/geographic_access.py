"""
Geographic Access Control Utility
Provides efficient filtering of content based on user's geographic location.
Supports cascading access: higher geographic levels see subordinate content.
"""
from typing import Optional, List, Any


def can_user_access_content(user: Optional['User'], content_item: Any, cascade: bool = False) -> bool:
    """
    Check if a user can access a content item based on geographic restrictions.
    
    Access Logic:
    1. If all geographic fields are NULL/empty: visible to everyone (post to all)
    2. Districts/Mandals Group (AND within group):
       - If both district_ids and mandal_ids are non-empty: user must match district_id AND mandal_id
       - If only district_ids is non-empty: check district_id only
       - If only mandal_ids is non-empty: check mandal_id only
    3. Constituencies Group (AND within group):
       - If both constituency arrays are non-empty: user must match parliament AND assembly
       - If only one is non-empty: check that one only
    4. Between Groups (OR logic):
       - User sees content if they match Districts/Mandals group OR Constituencies group
    
    Args:
        user: User or Member object with geographic info (district_id, mandal_id, etc.)
        content_item: Content item (NewsItem, Event, MediaItem, Document) with geographic restrictions
    
    Returns:
        bool: True if user can access the content, False otherwise
    """
    # If no user, only show content with no restrictions (post to all)
    if not user:
        return _is_post_to_all(content_item)
    
    # Get user's geographic info
    user_district_id = getattr(user, 'district_id', None)
    user_mandal_id = getattr(user, 'mandal_id', None)
    user_parliament_id = getattr(user, 'parliament_constituency_id', None)
    user_assembly_id = getattr(user, 'assembly_constituency_id', None)
    
    # If user has no geographic info, only show post to all content
    if not any([user_district_id, user_mandal_id, user_parliament_id, user_assembly_id]):
        return _is_post_to_all(content_item)
    
    # Get content restrictions (use getattr for backward compatibility with old records)
    district_ids = getattr(content_item, 'district_ids', None) or []
    mandal_ids = getattr(content_item, 'mandal_ids', None) or []
    assembly_constituency_ids = getattr(content_item, 'assembly_constituency_ids', None) or []
    parliamentary_constituency_ids = getattr(content_item, 'parliamentary_constituency_ids', None) or []
    
    # Check if post to all (all restrictions empty)
    if _is_post_to_all(content_item):
        return True
    
    # Check Districts/Mandals group
    district_mandal_match = _check_district_mandal_access(
        user_district_id, user_mandal_id, district_ids, mandal_ids
    )
    
    # Check Constituencies group
    constituency_match = _check_constituency_access(
        user_parliament_id, user_assembly_id,
        parliamentary_constituency_ids, assembly_constituency_ids
    )
    
    # OR logic between groups
    if district_mandal_match or constituency_match:
        return True
    
    # If cascade is enabled, check if user's area contains the content's area
    if cascade:
        cascade_match = _check_cascade_access(
            user_district_id, user_mandal_id,
            user_parliament_id, user_assembly_id,
            district_ids, mandal_ids,
            parliamentary_constituency_ids, assembly_constituency_ids
        )
        if cascade_match:
            return True
    
    return False


def _is_post_to_all(content_item: Any) -> bool:
    """Check if content is posted to all (no geographic restrictions)"""
    # Use getattr for backward compatibility with old records that don't have these columns
    district_ids = getattr(content_item, 'district_ids', None) or []
    mandal_ids = getattr(content_item, 'mandal_ids', None) or []
    assembly_constituency_ids = getattr(content_item, 'assembly_constituency_ids', None) or []
    parliamentary_constituency_ids = getattr(content_item, 'parliamentary_constituency_ids', None) or []
    
    return (
        not district_ids and
        not mandal_ids and
        not assembly_constituency_ids and
        not parliamentary_constituency_ids
    )


def _check_district_mandal_access(
    user_district_id: Optional[int],
    user_mandal_id: Optional[int],
    district_ids: List[int],
    mandal_ids: List[int]
) -> bool:
    """
    Check if user matches district/mandal restrictions.
    AND logic within group: if both are specified, user must match both.
    """
    has_district_restriction = bool(district_ids)
    has_mandal_restriction = bool(mandal_ids)
    
    # If no restrictions in this group, return False (don't match this group)
    if not has_district_restriction and not has_mandal_restriction:
        return False
    
    # If both restrictions exist, user must match both
    if has_district_restriction and has_mandal_restriction:
        district_match = user_district_id and user_district_id in district_ids
        mandal_match = user_mandal_id and user_mandal_id in mandal_ids
        return district_match and mandal_match
    
    # If only district restriction exists
    if has_district_restriction:
        return user_district_id and user_district_id in district_ids
    
    # If only mandal restriction exists
    if has_mandal_restriction:
        return user_mandal_id and user_mandal_id in mandal_ids
    
    return False


def _check_constituency_access(
    user_parliament_id: Optional[int],
    user_assembly_id: Optional[int],
    parliamentary_constituency_ids: List[int],
    assembly_constituency_ids: List[int]
) -> bool:
    """
    Check if user matches constituency restrictions.
    AND logic within group: if both are specified, user must match both.
    """
    has_parliament_restriction = bool(parliamentary_constituency_ids)
    has_assembly_restriction = bool(assembly_constituency_ids)
    
    # If no restrictions in this group, return False (don't match this group)
    if not has_parliament_restriction and not has_assembly_restriction:
        return False
    
    # If both restrictions exist, user must match both
    if has_parliament_restriction and has_assembly_restriction:
        parliament_match = user_parliament_id and user_parliament_id in parliamentary_constituency_ids
        assembly_match = user_assembly_id and user_assembly_id in assembly_constituency_ids
        return parliament_match and assembly_match
    
    # If only parliament restriction exists
    if has_parliament_restriction:
        return user_parliament_id and user_parliament_id in parliamentary_constituency_ids
    
    # If only assembly restriction exists
    if has_assembly_restriction:
        return user_assembly_id and user_assembly_id in assembly_constituency_ids
    
    return False


def _check_cascade_access(
    user_district_id: Optional[int],
    user_mandal_id: Optional[int],
    user_parliament_id: Optional[int],
    user_assembly_id: Optional[int],
    content_district_ids: List[int],
    content_mandal_ids: List[int],
    content_parliamentary_ids: List[int],
    content_assembly_ids: List[int]
) -> bool:
    """
    Check cascade access: a district-level user can see content tagged with
    mandals within their district. A parliamentary constituency user can see
    content tagged with assembly constituencies within their PC.
    """
    from app.utils.hierarchy_access import get_child_mandal_ids, get_child_assembly_ids
    
    # District cascade: user's district contains content's mandals
    if user_district_id and content_mandal_ids:
        child_mandals = get_child_mandal_ids(user_district_id)
        if any(m_id in child_mandals for m_id in content_mandal_ids):
            return True
    
    # Parliamentary cascade: user's PC contains content's assembly constituencies
    if user_parliament_id and content_assembly_ids:
        child_assemblies = get_child_assembly_ids(user_parliament_id)
        if any(a_id in child_assemblies for a_id in content_assembly_ids):
            return True
    
    return False


def get_user_geographic_info(user: Optional['User']) -> dict:
    """
    Get user's geographic information, checking both User and Member objects.
    
    Returns:
        dict: {
            'district_id': int or None,
            'mandal_id': int or None,
            'parliament_constituency_id': int or None,
            'assembly_constituency_id': int or None,
            'is_admin': bool,
            'member': Member object or None
        }
    """
    result = {
        'district_id': None,
        'mandal_id': None,
        'parliament_constituency_id': None,
        'assembly_constituency_id': None,
        'is_admin': False,
        'member': None
    }
    
    if not user:
        return result
    
    # Check if user is admin
    try:
        result['is_admin'] = (user.role.value == 'admin' if hasattr(user.role, 'value') else user.role == 'admin')
    except:
        result['is_admin'] = False
    
    # Try to get from user object directly (might have member data merged)
    user_district_id = getattr(user, 'districtId', None) or getattr(user, 'district_id', None)
    user_mandal_id = getattr(user, 'mandalId', None) or getattr(user, 'mandal_id', None)
    user_parliament_id = getattr(user, 'parliamentConstituencyId', None) or getattr(user, 'parliament_constituency_id', None)
    user_assembly_id = getattr(user, 'assemblyConstituencyId', None) or getattr(user, 'assembly_constituency_id', None)
    
    # If user has geographic info, return it
    if any([user_district_id, user_mandal_id, user_parliament_id, user_assembly_id]):
        result['district_id'] = user_district_id
        result['mandal_id'] = user_mandal_id
        result['parliament_constituency_id'] = user_parliament_id
        result['assembly_constituency_id'] = user_assembly_id
        return result
    
    # Try to fetch member by phone (lazy import to avoid circular dependency)
    try:
        from app.models.member import Member
        member = Member.query.filter_by(phone=user.phone).first()
        if member:
            result['district_id'] = member.district_id
            result['mandal_id'] = member.mandal_id
            result['parliament_constituency_id'] = member.parliament_constituency_id
            result['assembly_constituency_id'] = member.assembly_constituency_id
            result['member'] = member
    except Exception:
        pass
    
    return result


def filter_content_by_geographic_access(items: List[Any], user: Optional['User']) -> List[Any]:
    """
    Filter a list of content items based on user's geographic access.
    This is a Python-based filter that works correctly with the access logic.
    
    For better performance with large datasets, consider using SQL-based filtering
    with proper JSONB operators in build_geographic_filter_query.
    
    Args:
        items: List of content items (NewsItem, Event, MediaItem, Document)
        user: User object (will fetch Member if needed)
    
    Returns:
        Filtered list of items the user can access
    """
    if not items:
        return items
    
    # Get user's geographic info (will fetch Member if needed)
    user_geo_info = get_user_geographic_info(user)
    user_district_id = user_geo_info.get('district_id')
    user_mandal_id = user_geo_info.get('mandal_id')
    user_parliament_id = user_geo_info.get('parliament_constituency_id')
    user_assembly_id = user_geo_info.get('assembly_constituency_id')
    member = user_geo_info.get('member')
    
    # Use member object if available, otherwise create a simple object with the IDs
    if member:
        user_obj = member
    elif user:
        # Create a simple object with geographic info
        class SimpleGeoUser:
            def __init__(self, d_id, m_id, p_id, a_id):
                self.district_id = d_id
                self.mandal_id = m_id
                self.parliament_constituency_id = p_id
                self.assembly_constituency_id = a_id
        user_obj = SimpleGeoUser(user_district_id, user_mandal_id, user_parliament_id, user_assembly_id)
    else:
        user_obj = None
    
    # Filter items
    accessible_items = []
    for item in items:
        if can_user_access_content(user_obj, item):
            accessible_items.append(item)
    
    return accessible_items

