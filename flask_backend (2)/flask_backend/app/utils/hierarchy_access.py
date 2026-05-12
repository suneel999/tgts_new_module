"""
Hierarchy Access Control Utility
Provides cadre-level-based and geographic-cascade access control for content.

Access Rules:
- Content created by cadre level X is visible to levels X through 10 (same + subordinates) within geographic scope
- Leaders (lower level number = higher rank) can view all content from subordinate levels within their jurisdiction
- State-level (1-7): see all content statewide
- District-level (8): see all content in their district (including child mandals/booths)
- Mandal-level (9): see all content in their mandal (including child booths)
- Booth-level (10): see content in their booth/village area only
- Admin role sees everything regardless
- Public role sees only access_level='public' content
"""

from typing import Optional, List, Any, Dict
import logging

logger = logging.getLogger(__name__)

# Cache for geographic child lookups (cleared on app restart)
_geo_cache: Dict[str, List[int]] = {}


def get_member_cadre_level(user) -> Optional[int]:
    """
    Get the cadre level for a user by looking up their Member record.
    Returns None if the user has no member record or no cadre level assigned.
    Defaults to 10 (Booth level) for cadre users without explicit assignment.
    """
    if not user:
        return None
    
    try:
        from app.models.member import Member
        phone = getattr(user, 'phone', None)
        if not phone:
            return None
        
        member = Member.query.filter_by(phone=phone).first()
        if member:
            return member.cadre_level  # May be None if not assigned
        return None
    except Exception as e:
        logger.error(f"Error getting member cadre level: {e}")
        return None


def get_member_for_user(user):
    """
    Get the Member record associated with a user.
    """
    if not user:
        return None
    try:
        from app.models.member import Member
        phone = getattr(user, 'phone', None)
        if not phone:
            return None
        return Member.query.filter_by(phone=phone).first()
    except Exception:
        return None


def get_geographic_scope_for_level(cadre_level: int, member) -> dict:
    """
    Determine the automatic geographic scope when creating content,
    based on the creator's cadre level and their geographic assignment.
    
    Returns dict with keys: district_ids, mandal_ids, assembly_constituency_ids, parliamentary_constituency_ids
    All values are lists (may be empty for state-level = post to all).
    """
    result = {
        'district_ids': None,
        'mandal_ids': None,
        'assembly_constituency_ids': None,
        'parliamentary_constituency_ids': None,
    }
    
    if not cadre_level or not member:
        return result
    
    # State-level (1-7): No geographic restriction -> content goes to everyone
    if cadre_level <= 7:
        return result  # All None = post to all
    
    # District-level (8): Scope to their district
    if cadre_level == 8:
        district_id = getattr(member, 'district_id', None)
        if district_id:
            result['district_ids'] = [district_id]
        # Also include parliamentary/assembly if available
        parliament_id = getattr(member, 'parliament_constituency_id', None)
        if parliament_id:
            result['parliamentary_constituency_ids'] = [parliament_id]
        assembly_id = getattr(member, 'assembly_constituency_id', None)
        if assembly_id:
            result['assembly_constituency_ids'] = [assembly_id]
        return result
    
    # Mandal-level (9): Scope to their mandal
    if cadre_level == 9:
        district_id = getattr(member, 'district_id', None)
        mandal_id = getattr(member, 'mandal_id', None)
        if district_id:
            result['district_ids'] = [district_id]
        if mandal_id:
            result['mandal_ids'] = [mandal_id]
        return result
    
    # Booth-level (10): Scope to their mandal (finest granularity we have)
    if cadre_level >= 10:
        district_id = getattr(member, 'district_id', None)
        mandal_id = getattr(member, 'mandal_id', None)
        if district_id:
            result['district_ids'] = [district_id]
        if mandal_id:
            result['mandal_ids'] = [mandal_id]
        return result
    
    return result


def get_child_mandal_ids(district_id: int) -> List[int]:
    """
    Get all mandal IDs that belong to a given district.
    Results are cached for performance.
    """
    cache_key = f'district_{district_id}_mandals'
    if cache_key in _geo_cache:
        return _geo_cache[cache_key]
    
    try:
        from app.models.mandal import Mandal
        mandals = Mandal.query.filter_by(district_id=district_id).all()
        mandal_ids = [m.id for m in mandals]
        _geo_cache[cache_key] = mandal_ids
        return mandal_ids
    except Exception as e:
        logger.error(f"Error getting child mandals for district {district_id}: {e}")
        return []


def get_child_assembly_ids(parliament_id: int) -> List[int]:
    """
    Get all assembly constituency IDs that belong to a given parliamentary constituency.
    Results are cached for performance.
    """
    cache_key = f'parliament_{parliament_id}_assemblies'
    if cache_key in _geo_cache:
        return _geo_cache[cache_key]
    
    try:
        from app.models.assembly_constituency import AssemblyConstituency
        assemblies = AssemblyConstituency.query.filter_by(
            parliament_constituency_id=parliament_id
        ).all()
        assembly_ids = [a.constituency_number for a in assemblies]
        _geo_cache[cache_key] = assembly_ids
        return assembly_ids
    except Exception as e:
        logger.error(f"Error getting child assemblies for parliament {parliament_id}: {e}")
        return []


def clear_geo_cache():
    """Clear the geographic hierarchy cache."""
    global _geo_cache
    _geo_cache = {}


def can_user_view_hierarchical_content(user, content_item, member=None) -> bool:
    """
    Check if a user can view content based on cadre-level hierarchy and geographic cascade.
    
    This function handles the cadre-level hierarchy logic. It should be called
    AFTER the basic access_level check (public/cadre/admin).
    
    Access Rules:
    1. Admin users see everything -> return True
    2. Public users only see access_level='public' -> handled by caller
    3. Cadre users:
       a. State-level (1-7): See all cadre content statewide
       b. District-level (8): See cadre content within their district + child mandals
       c. Mandal-level (9): See cadre content within their mandal + child booths
       d. Booth-level (10): See cadre content in their geographic area only
    
    Geographic cascade means higher-level users see content from subordinate areas.
    """
    from app.models import UserRole
    
    if not user:
        return False
    
    # Admin sees everything
    user_role = getattr(user, 'role', None)
    if user_role == UserRole.ADMIN or (hasattr(user_role, 'value') and user_role.value == 'admin'):
        return True
    
    # Get member record if not provided
    if member is None:
        member = get_member_for_user(user)
    
    if not member:
        # No member record - can only see unrestricted content
        return _is_content_unrestricted(content_item)
    
    user_cadre_level = member.cadre_level
    
    # If user has no cadre level assigned, treat as booth level (most restricted)
    if user_cadre_level is None:
        user_cadre_level = 10
    
    # State-level users (1-7) see all content
    if user_cadre_level <= 7:
        return True
    
    # For district/mandal/booth levels, check geographic cascade
    return _check_geographic_cascade_access(member, user_cadre_level, content_item)


def _is_content_unrestricted(content_item) -> bool:
    """Check if content has no geographic restrictions (post to all)."""
    district_ids = getattr(content_item, 'district_ids', None) or []
    mandal_ids = getattr(content_item, 'mandal_ids', None) or []
    assembly_ids = getattr(content_item, 'assembly_constituency_ids', None) or []
    parliament_ids = getattr(content_item, 'parliamentary_constituency_ids', None) or []
    return not district_ids and not mandal_ids and not assembly_ids and not parliament_ids


def _check_geographic_cascade_access(member, user_cadre_level: int, content_item) -> bool:
    """
    Check geographic access with cascade logic.
    
    A district-level user can see content tagged with their district OR
    any mandal within their district.
    
    A mandal-level user can see content tagged with their mandal.
    """
    # If content has no geographic restrictions, everyone can see it
    if _is_content_unrestricted(content_item):
        return True
    
    # Get content's geographic restrictions
    content_district_ids = getattr(content_item, 'district_ids', None) or []
    content_mandal_ids = getattr(content_item, 'mandal_ids', None) or []
    content_assembly_ids = getattr(content_item, 'assembly_constituency_ids', None) or []
    content_parliament_ids = getattr(content_item, 'parliamentary_constituency_ids', None) or []
    
    # Get user's geographic info
    user_district_id = getattr(member, 'district_id', None)
    user_mandal_id = getattr(member, 'mandal_id', None)
    user_parliament_id = getattr(member, 'parliament_constituency_id', None)
    user_assembly_id = getattr(member, 'assembly_constituency_id', None)
    
    # District-level (8): Can see content in their district + all child mandals
    if user_cadre_level == 8:
        # Direct district match
        if user_district_id and content_district_ids and user_district_id in content_district_ids:
            return True
        
        # Cascade: check if content's mandals are within user's district
        if user_district_id and content_mandal_ids:
            child_mandals = get_child_mandal_ids(user_district_id)
            if any(m_id in child_mandals for m_id in content_mandal_ids):
                return True
        
        # Parliamentary constituency match
        if user_parliament_id and content_parliament_ids and user_parliament_id in content_parliament_ids:
            return True
        
        # Cascade: check if content's assemblies are within user's parliamentary constituency
        if user_parliament_id and content_assembly_ids:
            child_assemblies = get_child_assembly_ids(user_parliament_id)
            if any(a_id in child_assemblies for a_id in content_assembly_ids):
                return True
        
        # Assembly match
        if user_assembly_id and content_assembly_ids and user_assembly_id in content_assembly_ids:
            return True
        
        return False
    
    # Mandal-level (9) and Booth-level (10): Check their specific area
    # Direct mandal match
    if user_mandal_id and content_mandal_ids and user_mandal_id in content_mandal_ids:
        return True
    
    # District match (content for the whole district is visible to mandal/booth users in that district)
    if user_district_id and content_district_ids and user_district_id in content_district_ids:
        return True
    
    # Assembly match
    if user_assembly_id and content_assembly_ids and user_assembly_id in content_assembly_ids:
        return True
    
    # Parliamentary constituency match
    if user_parliament_id and content_parliament_ids and user_parliament_id in content_parliament_ids:
        return True
    
    return False


def filter_content_by_hierarchy(items: list, user, member=None) -> list:
    """
    Filter a list of content items based on cadre-level hierarchy and geographic cascade.
    
    This is the main entry point for filtering content in route handlers.
    It combines:
    1. Basic access_level check (public/cadre/admin)
    2. Cadre-level hierarchy check
    3. Geographic cascade check
    
    Args:
        items: List of content items (Event, MediaItem, etc.)
        user: User object
        member: Optional pre-fetched Member object
        
    Returns:
        Filtered list of items the user can access
    """
    from app.models import UserRole
    
    if not items:
        return items
    
    # Admin sees everything
    if user:
        user_role = getattr(user, 'role', None)
        if user_role == UserRole.ADMIN or (hasattr(user_role, 'value') and user_role.value == 'admin'):
            return items
    
    # Get member record if not provided
    if member is None and user:
        member = get_member_for_user(user)
    
    user_role = getattr(user, 'role', None) if user else None
    is_cadre = False
    if user_role:
        if user_role == UserRole.CADRE or (hasattr(user_role, 'value') and user_role.value == 'cadre'):
            is_cadre = True
        elif user_role == UserRole.ADMIN or (hasattr(user_role, 'value') and user_role.value == 'admin'):
            is_cadre = True  # Admin can see cadre content too
    
    filtered = []
    for item in items:
        # Get item's access level
        access_level = getattr(item, 'access_level', 'public') or 'public'
        if isinstance(access_level, str):
            access_level = access_level.lower().strip()
        
        # Public content: visible to everyone
        if access_level == 'public':
            # Still apply geographic filtering for public content
            if can_user_view_hierarchical_content(user, item, member):
                filtered.append(item)
            elif _is_content_unrestricted(item):
                filtered.append(item)
            elif not user:
                # Unauthenticated users only see geographically unrestricted public content
                if _is_content_unrestricted(item):
                    filtered.append(item)
            continue
        
        # Admin-only content
        if access_level == 'admin':
            # Only admins can see admin content (already handled above with early return)
            continue
        
        # Cadre content: requires cadre or admin role + hierarchy check
        if access_level == 'cadre':
            if not is_cadre:
                continue
            if can_user_view_hierarchical_content(user, item, member):
                filtered.append(item)
            continue
    
    return filtered
