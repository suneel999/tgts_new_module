"""
News Routes for Telangana Congress Communication App
Production-grade Flask-RESTX implementation with comprehensive error handling
"""

from flask import request
from flask_restx import Namespace, Resource, fields
from flask_jwt_extended import verify_jwt_in_request, get_jwt_identity
from app.models import NewsItem, User, UserRole
from app import db
from app.utils.auth_utils import get_current_user, require_admin, require_cadre_or_admin
from app.utils.error_handling import validate_required_fields, log_api_call
from app.utils.geographic_access import filter_content_by_geographic_access, get_user_geographic_info
import uuid
import json

# Create namespace for news
news_ns = Namespace('news', description='News management operations')

# Define models directly in the namespace
news_model = news_ns.model('News Item', {
    'id': fields.String(description='News ID'),
    'title_en': fields.String(description='Title in English'),
    'title_te': fields.String(description='Title in Telugu'),
    'description_en': fields.String(description='Description in English'),
    'description_te': fields.String(description='Description in Telugu'),
    'image_url': fields.String(description='Image URL'),
    'category': fields.String(description='News category'),
    'is_published': fields.Boolean(description='Published status'),
    'created_at': fields.String(description='Creation timestamp'),
    'updated_at': fields.String(description='Last update timestamp')
})

news_create_model = news_ns.model('News Create', {
    'title_en': fields.String(required=True, description='Title in English', example='Congress Rally'),
    'title_te': fields.String(required=True, description='Title in Telugu', example='కాంగ్రెస్ ర్యాలీ'),
    'description_en': fields.String(required=True, description='Description in English', example='Join us for a grand rally'),
    'description_te': fields.String(required=True, description='Description in Telugu', example='గ్రాండ్ ర్యాలీలో మాతో చేరండి'),
    'image_url': fields.String(description='Image URL', example='https://example.com/image.jpg'),
    'category': fields.String(required=True, description='News category', example='General'),
    'is_published': fields.Boolean(description='Published status', default=False),
    'districtIds': fields.List(fields.Integer, description='List of district IDs for geographic access'),
    'mandalIds': fields.List(fields.Integer, description='List of mandal IDs for geographic access'),
    'assemblyConstituencyIds': fields.List(fields.Integer, description='List of assembly constituency IDs for geographic access'),
    'parliamentaryConstituencyIds': fields.List(fields.Integer, description='List of parliamentary constituency IDs for geographic access'),
    'links': fields.List(fields.Raw, description='List of links with platform and url', example=[{'platform': 'Facebook', 'url': 'https://facebook.com/...'}])
})

def _filter_news_by_explicit_geo(items, district_id, mandal_id, assembly_constituency_id, parliament_constituency_id=None):
    """
    Return only news items specifically targeted at the provided geographic IDs.
    Excludes "post to all" items (those have no geographic restrictions).
    Used for the home screen "local news" section.
    """
    result = []
    for item in items:
        item_districts   = getattr(item, 'district_ids',                   None) or []
        item_mandals     = getattr(item, 'mandal_ids',                      None) or []
        item_assemblies  = getattr(item, 'assembly_constituency_ids',       None) or []
        item_parliaments = getattr(item, 'parliamentary_constituency_ids',  None) or []

        # Skip items with no geographic restrictions ("post to all")
        if not item_districts and not item_mandals and not item_assemblies and not item_parliaments:
            continue

        if district_id and district_id in item_districts:
            result.append(item)
        elif mandal_id and mandal_id in item_mandals:
            result.append(item)
        elif assembly_constituency_id and assembly_constituency_id in item_assemblies:
            result.append(item)
        elif parliament_constituency_id and parliament_constituency_id in item_parliaments:
            result.append(item)

    return result


@news_ns.route('/')
class NewsList(Resource):
    # Removed marshal_with to use to_dict() output directly (which uses nested title/description structure)
    # @news_ns.marshal_with(news_ns.model('News Response', {
    #     'news': fields.List(fields.Nested(news_model)),
    #     'total': fields.Integer,
    #     'pages': fields.Integer,
    #     'current_page': fields.Integer
    # }))
    @news_ns.doc(
        summary='Get all published news items',
        description='Retrieves a paginated list of all published news items',
        params={
            'page': 'Page number (default: 1)',
            'per_page': 'Items per page (default: 20)',
            'category': 'Filter by category',
            'district_id': 'Filter by specific district ID (local news)',
            'mandal_id': 'Filter by specific mandal ID (local news)',
            'assembly_constituency_id': 'Filter by specific assembly constituency ID (local news)',
            'parliament_constituency_id': 'Filter by specific parliament constituency ID (local news)',
        },
        responses={
            200: 'News items retrieved successfully',
            500: 'Internal server error'
        }
    )
    def get(self):
        """Get all published news items"""
        try:
            log_api_call('/api/news/', 'GET')

            page = request.args.get('page', 1, type=int)
            per_page = min(request.args.get('per_page', 20, type=int), 100)
            category = request.args.get('category')
            district_id = request.args.get('district_id', type=int)
            mandal_id = request.args.get('mandal_id', type=int)
            assembly_constituency_id = request.args.get('assembly_constituency_id', type=int)
            parliament_constituency_id = request.args.get('parliament_constituency_id', type=int)

            # Try to get current user (optional authentication)
            current_user = None
            try:
                verify_jwt_in_request(optional=True)
                user_id = get_jwt_identity()
                if user_id:
                    current_user = User.query.get(user_id)
            except Exception:
                pass

            query = NewsItem.query.filter_by(is_published=True)

            if category:
                query = query.filter_by(category=category)

            # Get all items first (before pagination)
            all_items = query.order_by(NewsItem.created_at.desc()).all()

            # When explicit geographic params are provided, return only items
            # specifically targeted at those areas (local news — excludes "post to all")
            if district_id or mandal_id or assembly_constituency_id or parliament_constituency_id:
                filtered_items = _filter_news_by_explicit_geo(
                    all_items, district_id, mandal_id, assembly_constituency_id, parliament_constituency_id
                )
            else:
                # Default: filter by the authenticated user's geographic profile
                filtered_items = filter_content_by_geographic_access(all_items, current_user)

            # Manual pagination after filtering
            total = len(filtered_items)
            pages = (total + per_page - 1) // per_page
            start = (page - 1) * per_page
            end = start + per_page
            paginated_items = filtered_items[start:end]

            return {
                'news': [item.to_dict() for item in paginated_items],
                'total': total,
                'pages': pages,
                'current_page': page
            }

        except Exception as e:
            news_ns.abort(500, str(e))
    
    @news_ns.expect(news_create_model)
    # Removed marshal_with to use to_dict() output directly
    # @news_ns.marshal_with(news_model)
    @news_ns.doc(
        security='Bearer',
        summary='Create news article',
        description='Creates a new news article (admin/cadre only)',
        responses={
            201: 'News item created successfully',
            400: 'Validation error',
            401: 'Authentication required',
            403: 'Admin or Cadre access required',
            500: 'Internal server error'
        }
    )
    def post(self):
        """Create news article (admin/cadre only)"""
        try:
            log_api_call('/api/news/', 'POST')
            
            # Verify JWT first
            verify_jwt_in_request()
            
            # Check authentication and authorization
            current_user = get_current_user()
            if current_user.role not in [UserRole.ADMIN, UserRole.CADRE]:
                news_ns.abort(403, 'Admin or Cadre access required')
            
            data = request.get_json()
            validate_required_fields(data, ['title_en', 'title_te', 'description_en', 'description_te', 'category'])
            
            # Handle geographic access fields
            district_ids = data.get('districtIds') or data.get('district_ids')
            mandal_ids = data.get('mandalIds') or data.get('mandal_ids')
            assembly_constituency_ids = data.get('assemblyConstituencyIds') or data.get('assembly_constituency_ids')
            parliamentary_constituency_ids = data.get('parliamentaryConstituencyIds') or data.get('parliamentary_constituency_ids')
            
            # Handle links field
            links = data.get('links')
            # Filter out empty links (where url is empty or missing)
            if links:
                links = [link for link in links if link.get('url') and link.get('url').strip()]
                links = links if links else None
            
            news_item = NewsItem(
                id=str(uuid.uuid4()),
                title_en=data['title_en'],
                title_te=data['title_te'],
                description_en=data['description_en'],
                description_te=data['description_te'],
                category=data['category'],
                image_url=data.get('image_url'),
                is_published=data.get('is_published', False),
                district_ids=district_ids if district_ids else None,
                mandal_ids=mandal_ids if mandal_ids else None,
                assembly_constituency_ids=assembly_constituency_ids if assembly_constituency_ids else None,
                parliamentary_constituency_ids=parliamentary_constituency_ids if parliamentary_constituency_ids else None,
                links=links if links else None
            )
            
            db.session.add(news_item)
            db.session.commit()
            
            return news_item.to_dict(), 201
            
        except Exception as e:
            news_ns.abort(400, str(e))

@news_ns.route('/<news_id>')
class NewsDetail(Resource):
    # Removed marshal_with to use to_dict() output directly
    # @news_ns.marshal_with(news_model)
    @news_ns.doc(
        summary='Get specific news item',
        description='Retrieves a specific news item by ID',
        params={'news_id': 'News item ID'},
        responses={
            200: 'News item retrieved successfully',
            404: 'News item not found',
            500: 'Internal server error'
        }
    )
    def get(self, news_id):
        """Get specific news item"""
        try:
            log_api_call(f'/api/news/{news_id}', 'GET')
            
            # Try to get current user (optional authentication)
            current_user = None
            try:
                verify_jwt_in_request(optional=True)
                user_id = get_jwt_identity()
                if user_id:
                    current_user = User.query.get(user_id)
            except Exception:
                pass
            
            news_item = NewsItem.query.get(news_id)
            if not news_item or not news_item.is_published:
                news_ns.abort(404, 'News item not found')
            
            # Check geographic access
            from app.utils.geographic_access import can_user_access_content, get_user_geographic_info
            user_geo_info = get_user_geographic_info(current_user)
            user_obj = user_geo_info.get('member') if user_geo_info.get('member') else current_user
            if not can_user_access_content(user_obj, news_item):
                news_ns.abort(404, 'News item not found')
            
            return news_item.to_dict()
            
        except Exception as e:
            news_ns.abort(404, str(e))
    
    @news_ns.expect(news_create_model)
    # Removed marshal_with to use to_dict() output directly
    # @news_ns.marshal_with(news_model)
    @news_ns.doc(
        security='Bearer',
        summary='Update news article',
        description='Updates an existing news article (admin/cadre only)',
        params={'news_id': 'News item ID'},
        responses={
            200: 'News item updated successfully',
            400: 'Validation error',
            401: 'Authentication required',
            403: 'Admin or Cadre access required',
            404: 'News item not found',
            500: 'Internal server error'
        }
    )
    def put(self, news_id):
        """Update news article (admin/cadre only)"""
        try:
            log_api_call(f'/api/news/{news_id}', 'PUT')
            
            # Verify JWT first
            verify_jwt_in_request()
            
            # Check authentication and authorization
            current_user = get_current_user()
            if current_user.role not in [UserRole.ADMIN, UserRole.CADRE]:
                news_ns.abort(403, 'Admin or Cadre access required')
            
            news_item = NewsItem.query.get(news_id)
            if not news_item:
                news_ns.abort(404, 'News item not found')
            
            data = request.get_json()
            
            if 'title_en' in data:
                news_item.title_en = data['title_en']
            if 'title_te' in data:
                news_item.title_te = data['title_te']
            if 'description_en' in data:
                news_item.description_en = data['description_en']
            if 'description_te' in data:
                news_item.description_te = data['description_te']
            if 'category' in data:
                news_item.category = data['category']
            if 'image_url' in data:
                news_item.image_url = data['image_url']
            if 'is_published' in data:
                news_item.is_published = data['is_published']
            
            # Update geographic access fields (use hasattr for backward compatibility)
            if ('districtIds' in data or 'district_ids' in data) and hasattr(news_item, 'district_ids'):
                news_item.district_ids = data.get('districtIds') or data.get('district_ids') or None
            if ('mandalIds' in data or 'mandal_ids' in data) and hasattr(news_item, 'mandal_ids'):
                news_item.mandal_ids = data.get('mandalIds') or data.get('mandal_ids') or None
            if ('assemblyConstituencyIds' in data or 'assembly_constituency_ids' in data) and hasattr(news_item, 'assembly_constituency_ids'):
                news_item.assembly_constituency_ids = data.get('assemblyConstituencyIds') or data.get('assembly_constituency_ids') or None
            if ('parliamentaryConstituencyIds' in data or 'parliamentary_constituency_ids' in data) and hasattr(news_item, 'parliamentary_constituency_ids'):
                news_item.parliamentary_constituency_ids = data.get('parliamentaryConstituencyIds') or data.get('parliamentary_constituency_ids') or None
            
            # Update links field
            if 'links' in data:
                links = data.get('links')
                # Filter out empty links (where url is empty or missing)
                if links:
                    links = [link for link in links if link.get('url') and link.get('url').strip()]
                    news_item.links = links if links else None
                else:
                    news_item.links = None
            
            db.session.commit()
            return news_item.to_dict()
            
        except Exception as e:
            news_ns.abort(400, str(e))
    
    @news_ns.doc(
        security='Bearer',
        summary='Delete news article',
        description='Deletes a news article (admin only)',
        params={'news_id': 'News item ID'},
        responses={
            200: 'News item deleted successfully',
            401: 'Authentication required',
            403: 'Admin access required',
            404: 'News item not found',
            500: 'Internal server error'
        }
    )
    def delete(self, news_id):
        """Delete news article (admin only)"""
        try:
            log_api_call(f'/api/news/{news_id}', 'DELETE')
            
            # Verify JWT first
            verify_jwt_in_request()
            
            # Check authentication and authorization
            current_user = get_current_user()
            if current_user.role != UserRole.ADMIN:
                news_ns.abort(403, 'Admin access required')
            
            news_item = NewsItem.query.get(news_id)
            if not news_item:
                news_ns.abort(404, 'News item not found')
            
            db.session.delete(news_item)
            db.session.commit()
            
            return {'message': 'News item deleted successfully'}
            
        except Exception as e:
            news_ns.abort(400, str(e))

@news_ns.route('/local')
class LocalNews(Resource):
    @news_ns.doc(
        security='Bearer',
        summary='Get local news for the authenticated user',
        description=(
            'Returns news items targeted at the user\'s district/mandal/constituency. '
            'Location is read from the database — no query params needed. '
            'Includes a debug block showing what location was resolved and why.'
        ),
        params={
            'page': 'Page number (default: 1)',
            'per_page': 'Items per page (default: 20)',
        },
        responses={
            200: 'Local news retrieved',
            401: 'Authentication required',
        }
    )
    def get(self):
        """Get local news for the authenticated user (JWT-authenticated)"""
        try:
            log_api_call('/api/news/local', 'GET')

            # --- resolve user -----------------------------------------------
            verify_jwt_in_request(optional=True)
            current_user = None
            try:
                user_id = get_jwt_identity()
                if user_id:
                    current_user = User.query.get(user_id)
            except Exception:
                pass

            if current_user is None:
                return {
                    'news': [], 'total': 0, 'pages': 0, 'current_page': 1,
                    'debug': {'reason': 'unauthenticated'}
                }

            # --- resolve location -------------------------------------------
            # First try member table (cadre/admin users have richer location data)
            from app.models.member import Member
            from sqlalchemy.orm import selectinload
            member = Member.query.options(
                selectinload(Member.district_ref),
                selectinload(Member.mandal_ref),
                selectinload(Member.parliamentary_constituency_ref),
                selectinload(Member.assembly_constituency_ref),
            ).filter_by(phone=current_user.phone).first()

            if member and any([member.district_id, member.mandal_id,
                               member.parliament_constituency_id, member.assembly_constituency_id]):
                district_id    = member.district_id
                mandal_id      = member.mandal_id
                assembly_id    = member.assembly_constituency_id
                parliament_id  = member.parliament_constituency_id
                location_source = 'member_table'
            else:
                # Fall back to user table (public users who set location in profile)
                district_id    = current_user.district_id
                mandal_id      = current_user.mandal_id
                assembly_id    = current_user.assembly_constituency_id
                parliament_id  = current_user.parliament_constituency_id
                location_source = 'user_table'

            debug = {
                'location_source': location_source,
                'district_id':   district_id,
                'mandal_id':     mandal_id,
                'assembly_constituency_id':    assembly_id,
                'parliament_constituency_id':  parliament_id,
            }

            if not any([district_id, mandal_id, assembly_id, parliament_id]):
                return {
                    'news': [], 'total': 0, 'pages': 0, 'current_page': 1,
                    'debug': {**debug, 'reason': 'no_location_set'}
                }

            # --- filter news -----------------------------------------------
            page     = request.args.get('page', 1, type=int)
            per_page = min(request.args.get('per_page', 20, type=int), 100)

            all_items = (
                NewsItem.query
                .filter_by(is_published=True)
                .order_by(NewsItem.created_at.desc())
                .all()
            )

            filtered = _filter_news_by_explicit_geo(
                all_items, district_id, mandal_id, assembly_id, parliament_id
            )

            total  = len(filtered)
            pages  = max(1, (total + per_page - 1) // per_page)
            start  = (page - 1) * per_page
            paged  = filtered[start: start + per_page]

            debug['total_published_news']    = len(all_items)
            debug['local_news_count']        = total
            debug['reason'] = 'ok' if total > 0 else 'no_news_targeted_at_user_location'

            return {
                'news':         [item.to_dict() for item in paged],
                'total':        total,
                'pages':        pages,
                'current_page': page,
                'debug':        debug,
            }

        except Exception as e:
            news_ns.abort(500, str(e))


@news_ns.route('/admin/all')
class AdminNewsList(Resource):
    # Removed marshal_with to use to_dict() output directly
    # @news_ns.marshal_with(news_ns.model('Admin News Response', {
    #     'news': fields.List(fields.Nested(news_model)),
    #     'total': fields.Integer,
    #     'pages': fields.Integer,
    #     'current_page': fields.Integer
    # }))
    @news_ns.doc(
        security='Bearer',
        summary='Get all news items (admin only)',
        description='Retrieves all news items including unpublished ones (admin only)',
        params={
            'page': 'Page number (default: 1)',
            'per_page': 'Items per page (default: 20)',
            'category': 'Filter by category',
            'published_only': 'Show only published items (true/false)'
        },
        responses={
            200: 'News items retrieved successfully',
            401: 'Authentication required',
            403: 'Admin access required',
            500: 'Internal server error'
        }
    )
    def get(self):
        """Get all news items including unpublished (admin only)"""
        try:
            log_api_call('/api/news/admin/all', 'GET')
            
            # Verify JWT first
            verify_jwt_in_request()
            
            # Check authentication and authorization
            current_user = get_current_user()
            if current_user.role != UserRole.ADMIN:
                news_ns.abort(403, 'Admin access required')
            
            page = request.args.get('page', 1, type=int)
            per_page = min(request.args.get('per_page', 20, type=int), 100)
            category = request.args.get('category')
            published_only = request.args.get('published_only', 'false').lower() == 'true'
            
            query = NewsItem.query
            
            if published_only:
                query = query.filter_by(is_published=True)
            
            if category:
                query = query.filter_by(category=category)
            
            news_items = query.order_by(NewsItem.created_at.desc()).paginate(
                page=page, per_page=per_page, error_out=False
            )
            
            # Use to_dict() to get the proper nested structure
            return {
                'news': [item.to_dict() for item in news_items.items],
                'total': news_items.total,
                'pages': news_items.pages,
                'current_page': page
            }
            
        except Exception as e:
            news_ns.abort(500, str(e))