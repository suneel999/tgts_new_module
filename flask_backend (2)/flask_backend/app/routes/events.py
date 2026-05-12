"""
Events Routes for Telangana Congress Communication App
Production-grade Flask-RESTX implementation with comprehensive error handling
"""

from flask import request, Response
from flask_restx import Namespace, Resource, fields
from flask_jwt_extended import jwt_required, verify_jwt_in_request, get_jwt_identity
from app.models import Event, User, UserRole, EventRSVP
from app import db
from app.utils.auth_utils import get_current_user, require_admin, require_cadre_or_admin, check_cadre_or_admin
from app.utils.error_handling import validate_required_fields, log_api_call, APIError
from app.utils.timezone_utils import get_ist_now, parse_to_ist, ensure_ist_aware
from app.utils.geographic_access import filter_content_by_geographic_access, get_user_geographic_info, can_user_access_content
from app.utils.hierarchy_access import filter_content_by_hierarchy, get_member_for_user, get_member_cadre_level, get_geographic_scope_for_level
from datetime import datetime
import uuid
import json

# Create namespace for events
events_ns = Namespace('events', description='Event management operations')

# Define models directly in the namespace
event_model = events_ns.model('Event', {
    'id': fields.String(description='Event ID'),
    'title_en': fields.String(description='Title in English'),
    'title_te': fields.String(description='Title in Telugu'),
    'description_en': fields.String(description='Description in English'),
    'description_te': fields.String(description='Description in Telugu'),
    'event_date': fields.String(description='Event date'),
    'event_time': fields.String(description='Event time'),
    'location_en': fields.String(description='Location in English'),
    'location_te': fields.String(description='Location in Telugu'),
    'image_url': fields.String(description='Image URL'),
    'rsvp_count': fields.Integer(description='RSVP count'),
    'is_published': fields.Boolean(description='Published status'),
    'created_at': fields.String(description='Creation timestamp'),
    'updated_at': fields.String(description='Last update timestamp')
})

event_create_model = events_ns.model('Event Create', {
    'title_en': fields.String(required=True, description='Title in English', example='Congress Rally'),
    'title_te': fields.String(required=True, description='Title in Telugu', example='కాంగ్రెస్ ర్యాలీ'),
    'description_en': fields.String(required=True, description='Description in English', example='Join us for a grand rally'),
    'description_te': fields.String(required=True, description='Description in Telugu', example='గ్రాండ్ ర్యాలీలో మాతో చేరండి'),
    'event_date': fields.String(required=True, description='Event date (ISO format)', example='2024-01-15'),
    'event_time': fields.String(required=True, description='Event time', example='10:00 AM'),
    'location_en': fields.String(required=True, description='Location in English', example='Hyderabad, Telangana'),
    'location_te': fields.String(required=True, description='Location in Telugu', example='హైదరాబాద్, తెలంగాణ'),
    'image_url': fields.String(description='Image URL', example='https://example.com/image.jpg'),
    'is_published': fields.Boolean(description='Published status', default=False),
    'districtIds': fields.List(fields.Integer, description='List of district IDs for geographic access'),
    'mandalIds': fields.List(fields.Integer, description='List of mandal IDs for geographic access'),
    'assemblyConstituencyIds': fields.List(fields.Integer, description='List of assembly constituency IDs for geographic access'),
    'parliamentaryConstituencyIds': fields.List(fields.Integer, description='List of parliamentary constituency IDs for geographic access')
})

@events_ns.route('/')
class EventsList(Resource):
    # Removed marshal_with to use to_dict() output directly (which uses 'date' not 'event_date')
    # @events_ns.marshal_with(events_ns.model('Events Response', {
    #     'events': fields.List(fields.Nested(event_model)),
    #     'total': fields.Integer,
    #     'pages': fields.Integer,
    #     'current_page': fields.Integer
    # }))
    @events_ns.doc(
        summary='Get all published events',
        description='Retrieves a paginated list of all published events (or all events if admin and published_only=false)',
        params={
            'page': 'Page number (default: 1)',
            'per_page': 'Items per page (default: 20)',
            'upcoming_only': 'Show only upcoming events (true/false)',
            'published_only': 'Show only published events (true/false, default: true). Admin can set to false to see all events'
        },
        responses={
            200: 'Events retrieved successfully',
            500: 'Internal server error'
        }
    )
    def get(self):
        """Get all published events (or all events if admin)"""
        try:
            log_api_call('/api/events/', 'GET')
            
            page = request.args.get('page', 1, type=int)
            per_page = min(request.args.get('per_page', 20, type=int), 100)
            upcoming_only = request.args.get('upcoming_only', 'false').lower() == 'true'
            published_only = request.args.get('published_only', 'true').lower() == 'true'
            
            # Check if user is authenticated admin (optional authentication)
            is_admin = False
            try:
                # Try to verify JWT token (optional - won't fail if no token)
                verify_jwt_in_request(optional=True)
                user_id = get_jwt_identity()
                if user_id:
                    current_user = User.query.get(user_id)
                    if current_user and current_user.role in [UserRole.ADMIN, UserRole.CADRE]:
                        is_admin = True
            except Exception:
                # Not authenticated or invalid token - show only published events
                pass
            
            # Get current user for geographic filtering
            current_user = None
            try:
                verify_jwt_in_request(optional=True)
                user_id = get_jwt_identity()
                if user_id:
                    current_user = User.query.get(user_id)
            except Exception:
                pass
            
            # Build query - show all if admin and not filtering by published_only
            if is_admin and not published_only:
                query = Event.query
            else:
                query = Event.query.filter_by(is_published=True)
            
            if upcoming_only:
                # Compare with current IST time (as naive datetime for database comparison)
                now_ist = get_ist_now().replace(tzinfo=None)
                query = query.filter(Event.event_date >= now_ist)
            
            # Get all items first (before pagination)
            all_events = query.order_by(Event.event_date.asc()).all()
            
            # Apply hierarchy-based filtering (cadre level + geographic cascade)
            filtered_events = filter_content_by_hierarchy(all_events, current_user)
            
            # Manual pagination after filtering
            total = len(filtered_events)
            pages = (total + per_page - 1) // per_page
            start = (page - 1) * per_page
            end = start + per_page
            paginated_events = filtered_events[start:end]
            
            # Return events using to_dict() directly (not marshaled) to match frontend expectations
            # Use Flask Response to completely bypass Flask-RESTX automatic marshaling
            response_data = {
                'events': [event.to_dict(current_user=current_user) for event in paginated_events],
                'total': total,
                'pages': pages,
                'current_page': page
            }
            
            # Create a raw Flask Response to bypass Flask-RESTX marshaling
            return Response(
                response=json.dumps(response_data),
                status=200,
                mimetype='application/json'
            )
            
        except Exception as e:
            events_ns.abort(500, str(e))
    
    @jwt_required()
    @events_ns.expect(event_create_model)
    @events_ns.marshal_with(event_model)
    @events_ns.doc(
        security='Bearer',
        summary='Create event',
        description='Creates a new event (admin/cadre only)',
        responses={
            201: 'Event created successfully',
            400: 'Validation error',
            401: 'Authentication required',
            403: 'Admin or Cadre access required',
            500: 'Internal server error'
        }
    )
    def post(self):
        """Create event (admin/cadre only)"""
        try:
            # @jwt_required() decorator ensures JWT is verified before this method runs
            # Get current authenticated user
            current_user = get_current_user()
            log_api_call('/api/events/', 'POST', current_user.id)
            
            if current_user.role not in [UserRole.ADMIN, UserRole.CADRE]:
                events_ns.abort(403, 'Admin or Cadre access required')
            
            data = request.get_json()
            if not data:
                events_ns.abort(400, 'Request body is required')
            
            validate_required_fields(data, [
                'title_en', 'description_en', 'event_date', 'event_time', 'location_en'
            ])

            # Parse event date to IST
            try:
                event_date_str = data['event_date']
                # Parse and convert to IST, then get naive datetime for database storage
                event_date_ist = parse_to_ist(event_date_str)
                event_date = event_date_ist.replace(tzinfo=None)  # Store as naive datetime (IST time)
            except (ValueError, AttributeError) as e:
                events_ns.abort(400, f'Invalid event date format. Use ISO format (YYYY-MM-DD). Error: {str(e)}')

            # Handle geographic access fields (may be overridden by auto-scope)
            district_ids = data.get('districtIds') or data.get('district_ids')
            mandal_ids = data.get('mandalIds') or data.get('mandal_ids')
            assembly_constituency_ids = data.get('assemblyConstituencyIds') or data.get('assembly_constituency_ids')
            parliamentary_constituency_ids = data.get('parliamentaryConstituencyIds') or data.get('parliamentary_constituency_ids')

            # Handle access level
            access_level = data.get('accessLevel') or data.get('access_level') or 'public'
            if access_level not in ['public', 'cadre', 'admin']:
                access_level = 'public'

            # Auto-set creator_cadre_level and geographic scope based on hierarchy
            creator_cadre_level = None
            member = get_member_for_user(current_user)
            if member and member.cadre_level:
                creator_cadre_level = member.cadre_level
                # Auto-populate geographic scope if not explicitly provided
                if not any([district_ids, mandal_ids, assembly_constituency_ids, parliamentary_constituency_ids]):
                    auto_scope = get_geographic_scope_for_level(creator_cadre_level, member)
                    district_ids = auto_scope['district_ids']
                    mandal_ids = auto_scope['mandal_ids']
                    assembly_constituency_ids = auto_scope['assembly_constituency_ids']
                    parliamentary_constituency_ids = auto_scope['parliamentary_constituency_ids']

            event = Event(
                id=str(uuid.uuid4()),
                title_en=data['title_en'],
                title_te=data.get('title_te', data['title_en']),
                description_en=data['description_en'],
                description_te=data.get('description_te', data['description_en']),
                event_date=event_date,
                event_time=data['event_time'],
                location_en=data['location_en'],
                location_te=data.get('location_te', data['location_en']),
                image_url=data.get('image_url'),
                is_published=data.get('is_published', False),
                access_level=access_level,
                creator_cadre_level=creator_cadre_level,
                district_ids=district_ids if district_ids else None,
                mandal_ids=mandal_ids if mandal_ids else None,
                assembly_constituency_ids=assembly_constituency_ids if assembly_constituency_ids else None,
                parliamentary_constituency_ids=parliamentary_constituency_ids if parliamentary_constituency_ids else None
            )
            
            db.session.add(event)
            db.session.commit()
            
            return event.to_dict(), 201
            
        except APIError as e:
            # Preserve APIError status codes
            events_ns.abort(e.status_code, e.message)
        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.error(f"Error creating event: {str(e)}", exc_info=True)
            events_ns.abort(400, f'Failed to create event: {str(e)}')

@events_ns.route('/my')
class MyEventsList(Resource):
    @jwt_required()
    @events_ns.doc(
        security='Bearer',
        summary='Get my submitted events',
        description='Retrieves events submitted by the current user (pending and published)',
        responses={
            200: 'Events retrieved successfully',
            401: 'Authentication required',
            500: 'Internal server error'
        }
    )
    def get(self):
        """Get events submitted by current user"""
        try:
            current_user = get_current_user()
            log_api_call('/api/events/my', 'GET', current_user.id)

            page = request.args.get('page', 1, type=int)
            per_page = min(request.args.get('per_page', 50, type=int), 100)

            query = Event.query.filter_by(submitted_by_user_id=current_user.id)
            all_events = query.order_by(Event.event_date.asc()).all()

            total = len(all_events)
            pages = (total + per_page - 1) // per_page
            start = (page - 1) * per_page
            paginated = all_events[start:start + per_page]

            response_data = {
                'events': [e.to_dict(current_user=current_user) for e in paginated],
                'total': total,
                'pages': pages,
                'current_page': page
            }
            return Response(
                response=json.dumps(response_data),
                status=200,
                mimetype='application/json'
            )
        except Exception as e:
            events_ns.abort(500, str(e))


@events_ns.route('/user-submit')
class UserEventSubmit(Resource):
    @jwt_required()
    @events_ns.doc(
        security='Bearer',
        summary='Submit event',
        description='Any authenticated user can submit an event. It is published immediately (is_published=True).',
        responses={
            201: 'Event submitted successfully',
            400: 'Validation error',
            401: 'Authentication required',
            500: 'Internal server error'
        }
    )
    def post(self):
        """Submit event (any authenticated user, published immediately)"""
        try:
            current_user = get_current_user()
            log_api_call('/api/events/user-submit', 'POST', current_user.id)

            data = request.get_json()
            if not data:
                events_ns.abort(400, 'Request body is required')

            validate_required_fields(data, [
                'title_en', 'description_en', 'event_date', 'event_time', 'location_en'
            ])

            try:
                event_date_ist = parse_to_ist(data['event_date'])
                event_date = event_date_ist.replace(tzinfo=None)
            except (ValueError, AttributeError) as e:
                events_ns.abort(400, f'Invalid date format. Use YYYY-MM-DD. Error: {str(e)}')

            event = Event(
                id=str(uuid.uuid4()),
                title_en=data['title_en'].strip(),
                title_te=data.get('title_te', data['title_en']).strip(),
                description_en=data['description_en'].strip(),
                description_te=data.get('description_te', data['description_en']).strip(),
                event_date=event_date,
                event_time=data['event_time'],
                location_en=data['location_en'].strip(),
                location_te=data.get('location_te', data['location_en']).strip(),
                image_url=data.get('image_url'),
                is_published=True,
                access_level='public',
                submitted_by_user_id=current_user.id,
            )

            db.session.add(event)
            db.session.commit()

            return Response(
                response=json.dumps({
                    'message': 'Event submitted successfully.',
                    'event': event.to_dict(current_user=current_user)
                }),
                status=201,
                mimetype='application/json'
            )
        except APIError as e:
            events_ns.abort(e.status_code, e.message)
        except Exception as e:
            db.session.rollback()
            import logging
            logging.getLogger(__name__).error(f"Error submitting event: {str(e)}", exc_info=True)
            events_ns.abort(400, f'Failed to submit event: {str(e)}')


@events_ns.route('/<event_id>')
class EventDetail(Resource):
    # Removed marshal_with to use to_dict() output directly (which uses nested structure)
    @events_ns.doc(
        summary='Get specific event',
        description='Retrieves a specific event by ID',
        params={'event_id': 'Event ID'},
        responses={
            200: 'Event retrieved successfully',
            404: 'Event not found',
            500: 'Internal server error'
        }
    )
    def get(self, event_id):
        """Get specific event"""
        try:
            log_api_call(f'/api/events/{event_id}', 'GET')
            
            # Try to get current user (optional authentication)
            current_user = None
            is_admin_or_cadre = False
            try:
                verify_jwt_in_request(optional=True)
                user_id = get_jwt_identity()
                if user_id:
                    current_user = User.query.get(user_id)
                    if current_user and current_user.role in [UserRole.ADMIN, UserRole.CADRE]:
                        is_admin_or_cadre = True
            except Exception:
                pass
            
            event = Event.query.get(event_id)
            if not event:
                events_ns.abort(404, 'Event not found')
            
            # Allow admin/cadre to view unpublished events (for editing)
            # Regular users can only see published events
            if not event.is_published and not is_admin_or_cadre:
                events_ns.abort(404, 'Event not found')
            
            # Check hierarchy-based access (only for non-admin users)
            if not is_admin_or_cadre:
                from app.utils.hierarchy_access import can_user_view_hierarchical_content
                if not can_user_view_hierarchical_content(current_user, event):
                    events_ns.abort(404, 'Event not found')
            
            # Create a raw Flask Response to bypass Flask-RESTX marshaling
            response_data = event.to_dict(current_user=current_user)
            return Response(
                response=json.dumps(response_data),
                status=200,
                mimetype='application/json'
            )
            
        except Exception as e:
            events_ns.abort(404, str(e))
    
    @jwt_required()
    @events_ns.marshal_with(event_model)
    @events_ns.doc(
        security='Bearer',
        summary='Update event',
        description='Updates an existing event (admin/cadre only). All fields are optional.',
        params={'event_id': 'Event ID'},
        responses={
            200: 'Event updated successfully',
            400: 'Validation error',
            401: 'Authentication required',
            403: 'Admin or Cadre access required',
            404: 'Event not found',
            500: 'Internal server error'
        }
    )
    def put(self, event_id):
        """Update event (admin/cadre only)"""
        try:
            log_api_call(f'/api/events/{event_id}', 'PUT')
            
            # Check authentication and authorization
            current_user = get_current_user()
            if current_user.role not in [UserRole.ADMIN, UserRole.CADRE]:
                events_ns.abort(403, 'Admin or Cadre access required')
            
            event = Event.query.get(event_id)
            if not event:
                events_ns.abort(404, 'Event not found')
            
            data = request.get_json()
            if not data:
                events_ns.abort(400, 'Request body is required')
            
            # Update fields if provided
            if 'title_en' in data:
                event.title_en = data['title_en']
            if 'title_te' in data:
                event.title_te = data['title_te']
            if 'description_en' in data:
                event.description_en = data['description_en']
            if 'description_te' in data:
                event.description_te = data['description_te']
            if 'event_date' in data:
                try:
                    event_date_str = data['event_date']
                    event_date_ist = parse_to_ist(event_date_str)
                    event.event_date = event_date_ist.replace(tzinfo=None)
                except (ValueError, AttributeError) as e:
                    events_ns.abort(400, f'Invalid event date format. Use ISO format (YYYY-MM-DD). Error: {str(e)}')
            if 'event_time' in data:
                event.event_time = data['event_time']
            if 'location_en' in data:
                event.location_en = data['location_en']
            if 'location_te' in data:
                event.location_te = data['location_te']
            if 'image_url' in data:
                event.image_url = data['image_url']
            if 'is_published' in data:
                event.is_published = data['is_published']
            
            # Update access level
            if 'accessLevel' in data or 'access_level' in data:
                access_level = data.get('accessLevel') or data.get('access_level')
                if access_level in ['public', 'cadre', 'admin']:
                    event.access_level = access_level
            
            # Update geographic access fields (use hasattr for backward compatibility)
            if ('districtIds' in data or 'district_ids' in data) and hasattr(event, 'district_ids'):
                event.district_ids = data.get('districtIds') or data.get('district_ids') or None
            if ('mandalIds' in data or 'mandal_ids' in data) and hasattr(event, 'mandal_ids'):
                event.mandal_ids = data.get('mandalIds') or data.get('mandal_ids') or None
            if ('assemblyConstituencyIds' in data or 'assembly_constituency_ids' in data) and hasattr(event, 'assembly_constituency_ids'):
                event.assembly_constituency_ids = data.get('assemblyConstituencyIds') or data.get('assembly_constituency_ids') or None
            if ('parliamentaryConstituencyIds' in data or 'parliamentary_constituency_ids' in data) and hasattr(event, 'parliamentary_constituency_ids'):
                event.parliamentary_constituency_ids = data.get('parliamentaryConstituencyIds') or data.get('parliamentary_constituency_ids') or None
            
            db.session.commit()
            return event.to_dict()
            
        except APIError as e:
            events_ns.abort(e.status_code, e.message)
        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.error(f"Error updating event: {str(e)}", exc_info=True)
            events_ns.abort(400, f'Failed to update event: {str(e)}')
    
    @jwt_required()
    @events_ns.doc(
        security='Bearer',
        summary='Delete event',
        description='Deletes an event and all associated RSVPs (admin/cadre only)',
        params={'event_id': 'Event ID'},
        responses={
            200: 'Event deleted successfully',
            401: 'Authentication required',
            403: 'Admin or Cadre access required',
            404: 'Event not found',
            500: 'Internal server error'
        }
    )
    def delete(self, event_id):
        """Delete event (admin/cadre only)"""
        try:
            log_api_call(f'/api/events/{event_id}', 'DELETE')
            
            # Check authentication and authorization
            current_user = get_current_user()
            if current_user.role not in [UserRole.ADMIN, UserRole.CADRE]:
                events_ns.abort(403, 'Admin or Cadre access required')
            
            event = Event.query.get(event_id)
            if not event:
                events_ns.abort(404, 'Event not found')
            
            # Delete the event (RSVPs will be automatically deleted due to CASCADE)
            db.session.delete(event)
            db.session.commit()
            
            return {'message': 'Event deleted successfully'}, 200
            
        except APIError as e:
            events_ns.abort(e.status_code, e.message)
        except Exception as e:
            db.session.rollback()
            import logging
            logger = logging.getLogger(__name__)
            logger.error(f"Error deleting event: {str(e)}", exc_info=True)
            if 'Authentication required' in str(e):
                events_ns.abort(401, str(e))
            elif 'Admin or Cadre access required' in str(e) or 'Access denied' in str(e):
                events_ns.abort(403, str(e))
            else:
                events_ns.abort(500, f'Failed to delete event: {str(e)}')

@events_ns.route('/<event_id>/rsvp')
class EventRSVPResource(Resource):
    @jwt_required()
    @events_ns.doc(
        security='Bearer',
        summary='RSVP to event',
        description='RSVPs to an event. Stores phone number in event_rsvps table with unique constraint.',
        params={'event_id': 'Event ID'},
        responses={
            200: 'RSVP successful',
            400: 'Already RSVP\'d to this event',
            401: 'Authentication required',
            404: 'Event not found',
            500: 'Internal server error'
        }
    )
    def post(self, event_id):
        """RSVP to event"""
        try:
            # @jwt_required() decorator ensures JWT is verified before this method runs
            current_user = get_current_user()
            log_api_call(f'/api/events/{event_id}/rsvp', 'POST', current_user.id)
            
            event = Event.query.get(event_id)
            if not event or not event.is_published:
                events_ns.abort(404, 'Event not found')
            
            # Check if user has already RSVP'd
            existing_rsvp = EventRSVP.query.filter_by(
                event_id=event_id,
                phone_number=current_user.phone
            ).first()
            
            if existing_rsvp:
                # User has already RSVP'd
                return {
                    'message': 'Already RSVP\'d to this event',
                    'rsvp_count': event.rsvp_count,
                    'already_rsvpd': True
                }, 200
            
            # Create new RSVP record
            rsvp_id = str(uuid.uuid4())
            new_rsvp = EventRSVP(
                id=rsvp_id,
                event_id=event_id,
                phone_number=current_user.phone
            )
            db.session.add(new_rsvp)
            db.session.flush()  # Flush to get the new RSVP in the session
            
            # Update event RSVP count (count from table for accuracy)
            event.rsvp_count = EventRSVP.query.filter_by(event_id=event_id).count()
            
            db.session.commit()
            
            return {
                'message': 'RSVP successful',
                'rsvp_count': event.rsvp_count,
                'already_rsvpd': False
            }
            
        except Exception as e:
            db.session.rollback()
            # Check for unique constraint violation
            if 'unique_event_phone' in str(e) or 'UNIQUE constraint failed' in str(e):
                events_ns.abort(400, 'Already RSVP\'d to this event')
            events_ns.abort(401 if 'Authentication required' in str(e) else 500, str(e))
    
    @jwt_required()
    @events_ns.doc(
        security='Bearer',
        summary='Get RSVP list for event',
        description='Get list of phone numbers who RSVP\'d to an event (Admin/Cadre only)',
        params={'event_id': 'Event ID'},
        responses={
            200: 'RSVP list retrieved successfully',
            401: 'Authentication required',
            403: 'Admin/Cadre access required',
            404: 'Event not found',
            500: 'Internal server error'
        }
    )
    def get(self, event_id):
        """Get RSVP list for event (Admin/Cadre only)"""
        try:
            current_user = get_current_user()
            check_cadre_or_admin(current_user)
            log_api_call(f'/api/events/{event_id}/rsvp', 'GET', current_user.id)
            
            event = Event.query.get(event_id)
            if not event:
                events_ns.abort(404, 'Event not found')
            
            # Get all RSVPs for this event
            rsvps = EventRSVP.query.filter_by(event_id=event_id).order_by(EventRSVP.created_at.desc()).all()
            
            return {
                'event_id': event_id,
                'event_title': {
                    'en': event.title_en,
                    'te': event.title_te
                },
                'rsvp_count': len(rsvps),
                'rsvps': [rsvp.to_dict() for rsvp in rsvps]
            }
            
        except APIError as e:
            events_ns.abort(e.status_code, e.message)
        except Exception as e:
            events_ns.abort(401 if 'Authentication required' in str(e) else 403 if 'Access denied' in str(e) or 'Cadre or Admin access required' in str(e) else 404, str(e))
@events_ns.route('/upload-image')
class EventImageUpload(Resource):
    @jwt_required()
    @events_ns.doc(
        security='Bearer',
        summary='Upload event image',
        description='Uploads an event image file and returns the URL (admin/cadre only)',
        responses={
            200: 'File uploaded successfully',
            400: 'Validation error',
            401: 'Authentication required',
            403: 'Admin or Cadre access required',
            500: 'Internal server error'
        }
    )
    def post(self):
        """Upload event image file (any authenticated user)"""
        try:
            from werkzeug.utils import secure_filename
            from app.services.s3_service import get_s3_service
            import os
            import logging

            logger = logging.getLogger(__name__)
            log_api_call('/api/events/upload-image', 'POST')

            # Any authenticated user may upload an event image
            current_user = get_current_user()
            
            # Check if file is present
            if 'file' not in request.files:
                logger.error(f"No 'file' in request.files. Available keys: {list(request.files.keys())}")
                events_ns.abort(400, 'No file provided. Make sure the form field is named "file"')
            
            file = request.files['file']
            if file.filename == '':
                events_ns.abort(400, 'No file selected')
            
            # Validate file type (images only for events)
            allowed_extensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp'}
            filename = secure_filename(file.filename)
            file_ext = os.path.splitext(filename)[1].lower()
            
            if file_ext not in allowed_extensions:
                events_ns.abort(400, f'Invalid image format. Allowed: {", ".join(allowed_extensions)}')
            
            # Generate unique filename
            from app.utils.timezone_utils import get_ist_now
            timestamp = get_ist_now().strftime('%Y%m%d_%H%M%S')
            unique_filename = f"event_{timestamp}_{uuid.uuid4().hex[:8]}{file_ext}"
            
            # Upload to S3 or local storage
            s3_service = get_s3_service()
            file_url = s3_service.upload_file(file, unique_filename, 'events')
            
            response = {
                'url': file_url,
                'filename': unique_filename,
                'message': 'Event image uploaded successfully'
            }
            
            return response, 200
            
        except APIError as e:
            events_ns.abort(e.status_code, e.message)
        except Exception as e:
            import traceback
            import logging
            logger = logging.getLogger(__name__)
            error_trace = traceback.format_exc()
            logger.error(f"Event image upload failed: {str(e)}")
            logger.error(f"Error traceback: {error_trace}")
            events_ns.abort(500, f'Failed to upload event image: {str(e)}')
