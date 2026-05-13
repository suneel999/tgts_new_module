# """
# Activities Routes for Telangana Congress Communication App
# Production-grade Flask-RESTX implementation with comprehensive error handling
# """

# from flask import request, Response
# from flask_restx import Namespace, Resource, fields
# from flask_jwt_extended import jwt_required, verify_jwt_in_request, get_jwt_identity
# from app.models import Activity, User, UserRole, Member
# from app import db
# from app.utils.auth_utils import get_current_user
# from app.utils.error_handling import validate_required_fields, log_api_call, APIError
# from app.utils.timezone_utils import get_ist_now
# from app.services.s3_service import get_s3_service
# from werkzeug.utils import secure_filename
# import uuid
# import json
# import os
# import logging

# logger = logging.getLogger(__name__)

# # Create namespace for activities
# activities_ns = Namespace('activities', description='Activity management operations')

# # Define models
# activity_model = activities_ns.model('Activity', {
#     'id': fields.String(description='Activity ID'),
#     'userId': fields.String(description='User ID'),
#     'userName': fields.String(description='User name'),
#     'userDesignation': fields.String(description='User designation'),
#     'userRole': fields.String(description='User role'),
#     'title': fields.Nested(activities_ns.model('Title', {
#         'en': fields.String(description='Title in English'),
#         'te': fields.String(description='Title in Telugu')
#     })),
#     'description': fields.Nested(activities_ns.model('Description', {
#         'en': fields.String(description='Description in English'),
#         'te': fields.String(description='Description in Telugu')
#     })),
#     'location': fields.String(description='Location'),
#     'imageUrls': fields.List(fields.String, description='List of image URLs'),
#     'videoUrls': fields.List(fields.String, description='List of video URLs'),
#     'createdAt': fields.String(description='Creation timestamp'),
#     'date': fields.String(description='Creation timestamp (alias)'),
# })

# activity_create_model = activities_ns.model('Activity Create', {
#     'title': fields.Nested(activities_ns.model('Title Create', {
#         'en': fields.String(required=True, description='Title in English'),
#         'te': fields.String(required=True, description='Title in Telugu')
#     }), required=True),
#     'description': fields.Nested(activities_ns.model('Description Create', {
#         'en': fields.String(required=True, description='Description in English'),
#         'te': fields.String(required=True, description='Description in Telugu')
#     }), required=True),
#     'location': fields.String(description='Location (optional)'),
#     'imageUrls': fields.List(fields.String, description='List of image URLs (optional)'),
#     'videoUrls': fields.List(fields.String, description='List of video URLs (optional)'),
# })

# def can_user_see_activity(activity, current_user):
#     """
#     Check if current user can see an activity based on cadre-level hierarchy:
#     - Users can see their own activities
#     - Admin users can see all activities
#     - State-level cadre (1-7) can see all activities
#     - District-level (8) can see activities within their district + child mandals
#     - Mandal-level (9) can see activities within their mandal
#     - Booth-level (10) can see activities within their area
#     - Leaders (higher cadre level) can see subordinate activities in their jurisdiction
#     """
#     from app.utils.hierarchy_access import get_member_for_user, get_child_mandal_ids
    
#     if not current_user:
#         # Not logged in - can only see activities from public users
#         return activity.user.role == UserRole.PUBLIC if activity.user else False
    
#     # User can always see their own activities
#     if activity.user_id == current_user.id:
#         return True
    
#     # Admin sees everything
#     if current_user.role == UserRole.ADMIN:
#         return True
    
#     # Get current user's member record and cadre level
#     current_member = get_member_for_user(current_user)
#     current_cadre_level = current_member.cadre_level if current_member else None
#     if current_cadre_level is None:
#         current_cadre_level = 10  # Default to booth level
    
#     # State-level users (1-7) see all activities
#     if current_cadre_level <= 7:
#         return True
    
#     # Get activity creator's member record for geographic comparison
#     activity_member = get_member_for_user(activity.user) if activity.user else None
    
#     if not activity_member:
#         # If activity creator has no member record, show to all cadre users
#         return current_user.role in [UserRole.CADRE, UserRole.ADMIN]
    
#     # District-level (8): see activities within their district + child mandals
#     if current_cadre_level == 8:
#         current_district = current_member.district_id if current_member else None
#         activity_district = activity_member.district_id
#         activity_mandal = activity_member.mandal_id
        
#         if current_district:
#             # Direct district match
#             if activity_district == current_district:
#                 return True
#             # Check if activity's mandal is in user's district
#             if activity_mandal:
#                 child_mandals = get_child_mandal_ids(current_district)
#                 if activity_mandal in child_mandals:
#                     return True
#         return False
    
#     # Mandal-level (9) and Booth-level (10): see activities within their mandal/district
#     current_district = current_member.district_id if current_member else None
#     current_mandal = current_member.mandal_id if current_member else None
#     activity_district = activity_member.district_id
#     activity_mandal = activity_member.mandal_id
    
#     # Same mandal
#     if current_mandal and activity_mandal and current_mandal == activity_mandal:
#         return True
    
#     # Same district (content from district-level leaders flows down)
#     if current_district and activity_district and current_district == activity_district:
#         return True
    
#     return False

# @activities_ns.route('/')
# class ActivitiesList(Resource):
#     @activities_ns.doc(
#         summary='Get all activities',
#         description='Retrieves a paginated list of activities with role-based visibility filtering',
#         params={
#             'page': 'Page number (default: 1)',
#             'per_page': 'Items per page (default: 20)',
#         },
#         responses={
#             200: 'Activities retrieved successfully',
#             500: 'Internal server error'
#         }
#     )
#     def get(self):
#         """Get all activities with role-based filtering"""
#         try:
#             log_api_call('/api/activities/', 'GET')
            
#             page = request.args.get('page', 1, type=int)
#             per_page = min(request.args.get('per_page', 20, type=int), 100)
            
#             # Get current user (optional authentication)
#             current_user = None
#             try:
#                 verify_jwt_in_request(optional=True)
#                 user_id = get_jwt_identity()
#                 if user_id:
#                     current_user = User.query.get(user_id)
#             except Exception:
#                 pass
            
#             # Get all activities
#             all_activities = Activity.query.order_by(Activity.created_at.desc()).all()
            
#             # Filter by role-based visibility
#             filtered_activities = [
#                 activity for activity in all_activities
#                 if can_user_see_activity(activity, current_user)
#             ]
            
#             # Manual pagination after filtering
#             total = len(filtered_activities)
#             pages = (total + per_page - 1) // per_page
#             start = (page - 1) * per_page
#             end = start + per_page
#             paginated_activities = filtered_activities[start:end]
            
#             # Return activities using to_dict()
#             response_data = {
#                 'activities': [activity.to_dict(current_user=current_user) for activity in paginated_activities],
#                 'total': total,
#                 'pages': pages,
#                 'current_page': page
#             }
            
#             return Response(
#                 response=json.dumps(response_data),
#                 status=200,
#                 mimetype='application/json'
#             )
            
#         except Exception as e:
#             logger.error(f"Error fetching activities: {str(e)}", exc_info=True)
#             activities_ns.abort(500, str(e))
    
#     @jwt_required()
#     @activities_ns.expect(activity_create_model)
#     @activities_ns.doc(
#         security='Bearer',
#         summary='Create activity',
#         description='Creates a new activity (authenticated users only)',
#         responses={
#             201: 'Activity created successfully',
#             400: 'Validation error',
#             401: 'Authentication required',
#             500: 'Internal server error'
#         }
#     )
#     def post(self):
#         """Create activity (authenticated users only)"""
#         try:
#             current_user = get_current_user()
#             log_api_call('/api/activities/', 'POST', current_user.id)
            
#             data = request.get_json()
#             if not data:
#                 activities_ns.abort(400, 'Request body is required')
            
#             # Validate title and description
#             if 'title' not in data or not isinstance(data['title'], dict):
#                 activities_ns.abort(400, 'Title is required and must be an object with "en" and "te" keys')
            
#             if 'description' not in data or not isinstance(data['description'], dict):
#                 activities_ns.abort(400, 'Description is required and must be an object with "en" and "te" keys')
            
#             title = data['title']
#             description = data['description']
            
#             if 'en' not in title or not title['en']:
#                 activities_ns.abort(400, 'Title in English is required')
#             if 'te' not in title or not title['te']:
#                 activities_ns.abort(400, 'Title in Telugu is required')
#             if 'en' not in description or not description['en']:
#                 activities_ns.abort(400, 'Description in English is required')
#             if 'te' not in description or not description['te']:
#                 activities_ns.abort(400, 'Description in Telugu is required')
            
#             # Get optional fields
#             location = data.get('location')
#             image_urls = data.get('imageUrls', [])
#             video_urls = data.get('videoUrls', [])
            
#             # Create activity
#             activity = Activity(
#                 id=str(uuid.uuid4()),
#                 user_id=current_user.id,
#                 title_en=title['en'],
#                 title_te=title['te'],
#                 description_en=description['en'],
#                 description_te=description['te'],
#                 location=location,
#                 image_urls=image_urls if image_urls else None,
#                 video_urls=video_urls if video_urls else None,
#             )
            
#             db.session.add(activity)
#             db.session.commit()
            
#             return activity.to_dict(current_user=current_user), 201
            
#         except APIError as e:
#             activities_ns.abort(e.status_code, e.message)
#         except Exception as e:
#             db.session.rollback()
#             logger.error(f"Error creating activity: {str(e)}", exc_info=True)
#             activities_ns.abort(400, f'Failed to create activity: {str(e)}')

# @activities_ns.route('/my')
# class MyActivities(Resource):
#     @jwt_required()
#     @activities_ns.doc(
#         security='Bearer',
#         summary='Get my activities',
#         description='Retrieves a paginated list of activities created by the current user',
#         params={
#             'page': 'Page number (default: 1)',
#             'per_page': 'Items per page (default: 20)',
#         },
#         responses={
#             200: 'Activities retrieved successfully',
#             401: 'Authentication required',
#             500: 'Internal server error'
#         }
#     )
#     def get(self):
#         """Get current user's activities"""
#         try:
#             current_user = get_current_user()
#             log_api_call('/api/activities/my', 'GET', current_user.id)
            
#             page = request.args.get('page', 1, type=int)
#             per_page = min(request.args.get('per_page', 20, type=int), 100)
            
#             # Get user's activities
#             query = Activity.query.filter_by(user_id=current_user.id)
#             total = query.count()
#             pages = (total + per_page - 1) // per_page
            
#             activities = query.order_by(Activity.created_at.desc()).paginate(
#                 page=page, per_page=per_page, error_out=False
#             ).items
            
#             response_data = {
#                 'activities': [activity.to_dict(current_user=current_user) for activity in activities],
#                 'total': total,
#                 'pages': pages,
#                 'current_page': page
#             }
            
#             return Response(
#                 response=json.dumps(response_data),
#                 status=200,
#                 mimetype='application/json'
#             )
            
#         except APIError as e:
#             activities_ns.abort(e.status_code, e.message)
#         except Exception as e:
#             logger.error(f"Error fetching my activities: {str(e)}", exc_info=True)
#             activities_ns.abort(500, str(e))

# @activities_ns.route('/upload')
# class ActivityUpload(Resource):
#     @jwt_required()
#     @activities_ns.doc(
#         security='Bearer',
#         summary='Upload activity with media files',
#         description='Uploads an activity with images and/or videos (multipart/form-data)',
#         responses={
#             201: 'Activity created successfully',
#             400: 'Validation error',
#             401: 'Authentication required',
#             500: 'Internal server error'
#         }
#     )
#     def post(self):
#         """Upload activity with media files (multipart/form-data)"""
#         try:
#             current_user = get_current_user()
#             log_api_call('/api/activities/upload', 'POST', current_user.id)
            
#             # Parse form data
#             title_json = request.form.get('title')
#             description_json = request.form.get('description')
#             location = request.form.get('location')
            
#             if not title_json or not description_json:
#                 activities_ns.abort(400, 'Title and description are required')
            
#             try:
#                 title = json.loads(title_json)
#                 description = json.loads(description_json)
#             except json.JSONDecodeError:
#                 activities_ns.abort(400, 'Title and description must be valid JSON')
            
#             # Validate title and description
#             if 'en' not in title or not title['en']:
#                 activities_ns.abort(400, 'Title in English is required')
#             if 'te' not in title or not title['te']:
#                 activities_ns.abort(400, 'Title in Telugu is required')
#             if 'en' not in description or not description['en']:
#                 activities_ns.abort(400, 'Description in English is required')
#             if 'te' not in description or not description['te']:
#                 activities_ns.abort(400, 'Description in Telugu is required')
            
#             # Handle image uploads
#             image_urls = []
#             if 'images' in request.files:
#                 files = request.files.getlist('images')
#                 s3_service = get_s3_service()
                
#                 for file in files:
#                     if file.filename:
#                         # Validate file type
#                         filename = secure_filename(file.filename)
#                         file_ext = os.path.splitext(filename)[1].lower()
#                         allowed_image_extensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp'}
                        
#                         if file_ext not in allowed_image_extensions:
#                             activities_ns.abort(400, f'Invalid image format: {file_ext}. Allowed: {", ".join(allowed_image_extensions)}')
                        
#                         # Generate unique filename
#                         timestamp = get_ist_now().strftime('%Y%m%d_%H%M%S')
#                         unique_filename = f"activity_image_{timestamp}_{uuid.uuid4().hex[:8]}{file_ext}"
                        
#                         # Upload to S3 or local storage
#                         file_url = s3_service.upload_file(file, unique_filename, 'activities/images')
#                         image_urls.append(file_url)
            
#             # Handle video uploads
#             video_urls = []
#             if 'videos' in request.files:
#                 files = request.files.getlist('videos')
#                 s3_service = get_s3_service()
                
#                 for file in files:
#                     if file.filename:
#                         # Validate file type
#                         filename = secure_filename(file.filename)
#                         file_ext = os.path.splitext(filename)[1].lower()
#                         allowed_video_extensions = {'.mp4', '.mov', '.avi', '.mkv', '.webm'}
                        
#                         if file_ext not in allowed_video_extensions:
#                             activities_ns.abort(400, f'Invalid video format: {file_ext}. Allowed: {", ".join(allowed_video_extensions)}')
                        
#                         # Generate unique filename
#                         timestamp = get_ist_now().strftime('%Y%m%d_%H%M%S')
#                         unique_filename = f"activity_video_{timestamp}_{uuid.uuid4().hex[:8]}{file_ext}"
                        
#                         # Upload to S3 or local storage
#                         file_url = s3_service.upload_file(file, unique_filename, 'activities/videos')
#                         video_urls.append(file_url)
            
#             # Create activity
#             activity = Activity(
#                 id=str(uuid.uuid4()),
#                 user_id=current_user.id,
#                 title_en=title['en'],
#                 title_te=title['te'],
#                 description_en=description['en'],
#                 description_te=description['te'],
#                 location=location if location else None,
#                 image_urls=image_urls if image_urls else None,
#                 video_urls=video_urls if video_urls else None,
#             )
            
#             db.session.add(activity)
#             db.session.commit()
            
#             return activity.to_dict(current_user=current_user), 201
            
#         except APIError as e:
#             db.session.rollback()
#             activities_ns.abort(e.status_code, e.message)
#         except Exception as e:
#             db.session.rollback()
#             logger.error(f"Error uploading activity: {str(e)}", exc_info=True)
#             activities_ns.abort(500, f'Failed to upload activity: {str(e)}')


"""
Activities Routes for Telangana Congress Communication App
Production-grade Flask-RESTX implementation with comprehensive error handling
"""

from flask import request, Response
from flask_restx import Namespace, Resource, fields
from flask_jwt_extended import jwt_required, verify_jwt_in_request, get_jwt_identity
from app.models import Activity, User, UserRole, Member
from app import db
from app.utils.auth_utils import get_current_user
from app.utils.error_handling import validate_required_fields, log_api_call, APIError
from app.utils.timezone_utils import get_ist_now
from app.utils.media_urls import absolute_media_url
from app.services.s3_service import get_s3_service
from werkzeug.utils import secure_filename
import uuid
import json
import os
import logging

logger = logging.getLogger(__name__)

# Create namespace for activities
activities_ns = Namespace('activities', description='Activity management operations')

# Define models
activity_model = activities_ns.model('Activity', {
    'id': fields.String(description='Activity ID'),
    'userId': fields.String(description='User ID'),
    'userName': fields.String(description='User name'),
    'userDesignation': fields.String(description='User designation'),
    'userRole': fields.String(description='User role'),
    'title': fields.Nested(activities_ns.model('Title', {
        'en': fields.String(description='Title in English'),
        'te': fields.String(description='Title in Telugu')
    })),
    'description': fields.Nested(activities_ns.model('Description', {
        'en': fields.String(description='Description in English'),
        'te': fields.String(description='Description in Telugu')
    })),
    'location': fields.String(description='Location'),
    'imageUrls': fields.List(fields.String, description='List of image URLs'),
    'videoUrls': fields.List(fields.String, description='List of video URLs'),
    'createdAt': fields.String(description='Creation timestamp'),
    'date': fields.String(description='Creation timestamp (alias)'),
})

activity_create_model = activities_ns.model('Activity Create', {
    'title': fields.Nested(activities_ns.model('Title Create', {
        'en': fields.String(required=True, description='Title in English'),
        'te': fields.String(required=True, description='Title in Telugu')
    }), required=True),
    'description': fields.Nested(activities_ns.model('Description Create', {
        'en': fields.String(required=True, description='Description in English'),
        'te': fields.String(required=True, description='Description in Telugu')
    }), required=True),
    'location': fields.String(description='Location (optional)'),
    'imageUrls': fields.List(fields.String, description='List of image URLs (optional)'),
    'videoUrls': fields.List(fields.String, description='List of video URLs (optional)'),
})


# ── Safe helper to convert activity to dict ───────────────────────────────────

def safe_activity_dict(activity, current_user=None):
    """
    Safely convert activity to dict.
    Handles both PostgreSQL ARRAY and MySQL comma-string image_urls.
    """
    try:
        # ── Safe image_urls conversion ──
        raw_image_urls = activity.image_urls
        if raw_image_urls is None:
            image_urls = []
        elif isinstance(raw_image_urls, list):
            image_urls = raw_image_urls
        elif isinstance(raw_image_urls, str):
            image_urls = [u for u in raw_image_urls.split(',') if u.strip()]
        else:
            image_urls = []

        image_urls = [absolute_media_url(u) or u for u in image_urls]

        # ── Safe video_urls conversion ──
        raw_video_urls = activity.video_urls
        if raw_video_urls is None:
            video_urls = []
        elif isinstance(raw_video_urls, list):
            video_urls = raw_video_urls
        elif isinstance(raw_video_urls, str):
            video_urls = [u for u in raw_video_urls.split(',') if u.strip()]
        else:
            video_urls = []

        video_urls = [absolute_media_url(u) or u for u in video_urls]

        # ── Safe user info ──
        user_name        = None
        user_designation = None
        user_role        = 'public'
        user_cadre_level = None

        if activity.user:
            user_name = activity.user.name
            user_role = activity.user.role.value if activity.user.role else 'public'
            try:
                if hasattr(activity.user, 'phone'):
                    member = Member.query.filter_by(
                        phone=activity.user.phone).first()
                    if member:
                        if member.party_designation:
                            user_designation = member.party_designation
                        user_cadre_level = member.cadre_level
            except Exception as e:
                logger.warning(f"Could not fetch member info: {e}")

        return {
            'id':              activity.id,
            'userId':          activity.user_id,
            'userName':        user_name,
            'userDesignation': user_designation,
            'userRole':        user_role,
            'title': {
                'en': activity.title_en,
                'te': activity.title_te,
            },
            'description': {
                'en': activity.description_en,
                'te': activity.description_te,
            },
            'location':          activity.location,
            'imageUrls':         image_urls,
            'videoUrls':         video_urls,
            'creatorCadreLevel': user_cadre_level,
            'createdAt': activity.created_at.isoformat() if activity.created_at else None,
            'date':      activity.created_at.isoformat() if activity.created_at else None,
        }
    except Exception as e:
        logger.error(f"Error converting activity {activity.id} to dict: {e}")
        # Return minimal safe response so one bad record doesn't crash the whole list
        return {
            'id':          activity.id,
            'userId':      activity.user_id,
            'userName':    None,
            'title':       {'en': activity.title_en, 'te': activity.title_te},
            'description': {'en': activity.description_en, 'te': activity.description_te},
            'location':    activity.location,
            'imageUrls':   [],
            'videoUrls':   [],
            'createdAt':   activity.created_at.isoformat() if activity.created_at else None,
            'date':        activity.created_at.isoformat() if activity.created_at else None,
        }


# ── Visibility logic ──────────────────────────────────────────────────────────

def can_user_see_activity(activity, current_user):
    """
    Feed shows ONLY other users posts.
    My Posts tab (/my) shows your own posts.
    New users with no member record see all posts.
    """
    try:
        from app.utils.hierarchy_access import get_member_for_user, get_child_mandal_ids

        # Not logged in
        if not current_user:
            return activity.user.role == UserRole.PUBLIC if activity.user else False

        # Own posts go to My Posts tab — NOT Feed
        if activity.user_id == current_user.id:
            return False

        # Admin sees all other users posts
        if current_user.role == UserRole.ADMIN:
            return True

        # Get member record safely
        try:
            current_member = get_member_for_user(current_user)
        except Exception:
            current_member = None

        # New user with no member record — show all posts
        if current_member is None:
            return True

        current_cadre_level = current_member.cadre_level
        if current_cadre_level is None:
            return True

        # State-level (1-7) see all
        if current_cadre_level <= 7:
            return True

        # Get activity creator member record safely
        try:
            activity_member = get_member_for_user(activity.user) if activity.user else None
        except Exception:
            activity_member = None

        if not activity_member:
            return current_user.role in [UserRole.CADRE, UserRole.ADMIN]

        # District-level (8)
        if current_cadre_level == 8:
            current_district  = current_member.district_id
            activity_district = activity_member.district_id
            activity_mandal   = activity_member.mandal_id
            if current_district:
                if activity_district == current_district:
                    return True
                if activity_mandal:
                    try:
                        child_mandals = get_child_mandal_ids(current_district)
                        if activity_mandal in child_mandals:
                            return True
                    except Exception:
                        pass
            return False

        # Mandal/Booth level (9-10)
        current_district  = current_member.district_id
        current_mandal    = current_member.mandal_id
        activity_district = activity_member.district_id
        activity_mandal   = activity_member.mandal_id

        if current_mandal and activity_mandal and current_mandal == activity_mandal:
            return True
        if current_district and activity_district and current_district == activity_district:
            return True

        return False

    except Exception as e:
        # If anything crashes, log and show the post anyway
        logger.error(f"Error in can_user_see_activity: {str(e)}", exc_info=True)
        return True


# ── GET / POST all activities ─────────────────────────────────────────────────

@activities_ns.route('/', strict_slashes=False)
class ActivitiesList(Resource):
    @activities_ns.doc(
        summary='Get all activities',
        description='Retrieves a paginated list of activities with role-based visibility filtering',
        params={
            'page': 'Page number (default: 1)',
            'per_page': 'Items per page (default: 20)',
        },
        responses={
            200: 'Activities retrieved successfully',
            500: 'Internal server error'
        }
    )
    def get(self):
        """Get all activities with role-based filtering"""
        try:
            log_api_call('/api/activities/', 'GET')

            page     = request.args.get('page', 1, type=int)
            per_page = min(request.args.get('per_page', 20, type=int), 100)

            # Get current user (optional authentication)
            current_user = None
            try:
                verify_jwt_in_request(optional=True)
                user_id = get_jwt_identity()
                if user_id:
                    current_user = User.query.get(user_id)
            except Exception:
                pass

            # Get all activities
            all_activities = Activity.query.order_by(
                Activity.created_at.desc()).all()

            # Filter by visibility
            filtered_activities = []
            for activity in all_activities:
                try:
                    if can_user_see_activity(activity, current_user):
                        filtered_activities.append(activity)
                except Exception as e:
                    logger.error(f"Error checking visibility for activity {activity.id}: {e}")
                    continue

            # Pagination
            total  = len(filtered_activities)
            pages  = (total + per_page - 1) // per_page
            start  = (page - 1) * per_page
            end    = start + per_page
            paged  = filtered_activities[start:end]

            # Convert to dict safely
            activities_data = []
            for activity in paged:
                try:
                    activities_data.append(safe_activity_dict(activity, current_user))
                except Exception as e:
                    logger.error(f"Skipping activity {activity.id} due to error: {e}")
                    continue

            response_data = {
                'activities':   activities_data,
                'total':        total,
                'pages':        pages,
                'current_page': page,
            }

            return Response(
                response=json.dumps(response_data),
                status=200,
                mimetype='application/json'
            )

        except Exception as e:
            logger.error(f"Error fetching activities: {str(e)}", exc_info=True)
            activities_ns.abort(500, str(e))

    @jwt_required()
    @activities_ns.expect(activity_create_model)
    @activities_ns.doc(
        security='Bearer',
        summary='Create activity',
        description='Creates a new activity (authenticated users only)',
        responses={
            201: 'Activity created successfully',
            400: 'Validation error',
            401: 'Authentication required',
            500: 'Internal server error'
        }
    )
    def post(self):
        """Create activity (authenticated users only)"""
        try:
            current_user = get_current_user()
            log_api_call('/api/activities/', 'POST', current_user.id)

            data = request.get_json()
            if not data:
                activities_ns.abort(400, 'Request body is required')

            if 'title' not in data or not isinstance(data['title'], dict):
                activities_ns.abort(400, 'Title is required')
            if 'description' not in data or not isinstance(data['description'], dict):
                activities_ns.abort(400, 'Description is required')

            title       = data['title']
            description = data['description']

            if not title.get('en'):
                activities_ns.abort(400, 'Title in English is required')
            if not title.get('te'):
                activities_ns.abort(400, 'Title in Telugu is required')
            if not description.get('en'):
                activities_ns.abort(400, 'Description in English is required')
            if not description.get('te'):
                activities_ns.abort(400, 'Description in Telugu is required')

            image_urls = data.get('imageUrls', [])
            video_urls = data.get('videoUrls', [])

            activity = Activity(
                id             = str(uuid.uuid4()),
                user_id        = current_user.id,
                title_en       = title['en'],
                title_te       = title['te'],
                description_en = description['en'],
                description_te = description['te'],
                location       = data.get('location'),
                image_urls     = image_urls if image_urls else None,
                video_urls     = video_urls if video_urls else None,
            )

            db.session.add(activity)
            db.session.commit()

            return safe_activity_dict(activity, current_user), 201

        except APIError as e:
            activities_ns.abort(e.status_code, e.message)
        except Exception as e:
            db.session.rollback()
            logger.error(f"Error creating activity: {str(e)}", exc_info=True)
            activities_ns.abort(400, f'Failed to create activity: {str(e)}')


# ── GET my activities ─────────────────────────────────────────────────────────

@activities_ns.route('/my')
class MyActivities(Resource):
    @jwt_required()
    @activities_ns.doc(
        security='Bearer',
        summary='Get my activities',
        description='Retrieves activities created by the current user',
        params={
            'page': 'Page number (default: 1)',
            'per_page': 'Items per page (default: 20)',
        },
        responses={
            200: 'Activities retrieved successfully',
            401: 'Authentication required',
            500: 'Internal server error'
        }
    )
    def get(self):
        """Get current user's own activities"""
        try:
            current_user = get_current_user()
            log_api_call('/api/activities/my', 'GET', current_user.id)

            page     = request.args.get('page', 1, type=int)
            per_page = min(request.args.get('per_page', 20, type=int), 100)

            query = Activity.query.filter_by(user_id=current_user.id)
            total = query.count()
            pages = (total + per_page - 1) // per_page

            activities = query.order_by(Activity.created_at.desc()).paginate(
                page=page, per_page=per_page, error_out=False
            ).items

            activities_data = []
            for activity in activities:
                try:
                    activities_data.append(safe_activity_dict(activity, current_user))
                except Exception as e:
                    logger.error(f"Skipping activity {activity.id}: {e}")
                    continue

            response_data = {
                'activities':   activities_data,
                'total':        total,
                'pages':        pages,
                'current_page': page,
            }

            return Response(
                response=json.dumps(response_data),
                status=200,
                mimetype='application/json'
            )

        except APIError as e:
            activities_ns.abort(e.status_code, e.message)
        except Exception as e:
            logger.error(f"Error fetching my activities: {str(e)}", exc_info=True)
            activities_ns.abort(500, str(e))


# ── UPLOAD activity with images ───────────────────────────────────────────────

@activities_ns.route('/upload')
class ActivityUpload(Resource):
    @jwt_required()
    @activities_ns.doc(
        security='Bearer',
        summary='Upload activity with media files',
        description='Uploads an activity with images/videos (multipart/form-data)',
        responses={
            201: 'Activity created successfully',
            400: 'Validation error',
            401: 'Authentication required',
            500: 'Internal server error'
        }
    )
    def post(self):
        """Upload activity with media files (multipart/form-data)"""
        try:
            current_user     = get_current_user()
            log_api_call('/api/activities/upload', 'POST', current_user.id)

            title_json       = request.form.get('title')
            description_json = request.form.get('description')
            location         = request.form.get('location')

            if not title_json or not description_json:
                activities_ns.abort(400, 'Title and description are required')

            try:
                title       = json.loads(title_json)
                description = json.loads(description_json)
            except json.JSONDecodeError:
                activities_ns.abort(400, 'Title and description must be valid JSON')

            if not title.get('en'):
                activities_ns.abort(400, 'Title in English is required')
            if not title.get('te'):
                activities_ns.abort(400, 'Title in Telugu is required')
            if not description.get('en'):
                activities_ns.abort(400, 'Description in English is required')
            if not description.get('te'):
                activities_ns.abort(400, 'Description in Telugu is required')

            # Handle image uploads
            image_urls = []
            if 'images' in request.files:
                s3_service  = get_s3_service()
                allowed_img = {'.jpg', '.jpeg', '.png', '.gif', '.webp'}
                for file in request.files.getlist('images'):
                    if not file.filename:
                        continue
                    filename = secure_filename(file.filename)
                    file_ext = os.path.splitext(filename)[1].lower()
                    if file_ext not in allowed_img:
                        activities_ns.abort(400, f'Invalid image format: {file_ext}')
                    timestamp       = get_ist_now().strftime('%Y%m%d_%H%M%S')
                    unique_filename = f"activity_image_{timestamp}_{uuid.uuid4().hex[:8]}{file_ext}"
                    file_url        = s3_service.upload_file(file, unique_filename, 'activities/images')
                    image_urls.append(file_url)

            # Handle video uploads
            video_urls = []
            if 'videos' in request.files:
                s3_service  = get_s3_service()
                allowed_vid = {'.mp4', '.mov', '.avi', '.mkv', '.webm'}
                for file in request.files.getlist('videos'):
                    if not file.filename:
                        continue
                    filename = secure_filename(file.filename)
                    file_ext = os.path.splitext(filename)[1].lower()
                    if file_ext not in allowed_vid:
                        activities_ns.abort(400, f'Invalid video format: {file_ext}')
                    timestamp       = get_ist_now().strftime('%Y%m%d_%H%M%S')
                    unique_filename = f"activity_video_{timestamp}_{uuid.uuid4().hex[:8]}{file_ext}"
                    file_url        = s3_service.upload_file(file, unique_filename, 'activities/videos')
                    video_urls.append(file_url)

            activity = Activity(
                id             = str(uuid.uuid4()),
                user_id        = current_user.id,
                title_en       = title['en'],
                title_te       = title['te'],
                description_en = description['en'],
                description_te = description['te'],
                location       = location if location else None,
                image_urls     = image_urls if image_urls else None,
                video_urls     = video_urls if video_urls else None,
            )

            db.session.add(activity)
            db.session.commit()

            logger.info(f"Activity saved: id={activity.id}, user={current_user.id}, images={len(image_urls)}")
            return safe_activity_dict(activity, current_user), 201

        except APIError as e:
            db.session.rollback()
            activities_ns.abort(e.status_code, e.message)
        except Exception as e:
            db.session.rollback()
            logger.error(f"Error uploading activity: {str(e)}", exc_info=True)
            activities_ns.abort(500, f'Failed to upload activity: {str(e)}')


# ── DELETE activity ───────────────────────────────────────────────────────────

@activities_ns.route('/<string:activity_id>')
class ActivityDetail(Resource):
    @jwt_required()
    def delete(self, activity_id):
        """Delete activity — only owner or admin"""
        try:
            current_user = get_current_user()
            activity     = Activity.query.get(activity_id)

            if not activity:
                activities_ns.abort(404, 'Activity not found')
            if activity.user_id != current_user.id and \
               current_user.role != UserRole.ADMIN:
                activities_ns.abort(403, 'Not authorized to delete this activity')

            db.session.delete(activity)
            db.session.commit()
            return {'message': 'Activity deleted successfully'}, 200

        except APIError as e:
            activities_ns.abort(e.status_code, e.message)
        except Exception as e:
            db.session.rollback()
            logger.error(f"Error deleting activity: {e}", exc_info=True)
            activities_ns.abort(500, str(e))