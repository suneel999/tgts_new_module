"""
Parliamentary Constituencies Routes for Telangana Congress Communication App
"""

from flask import request
from flask_restx import Namespace, Resource, fields
from flask_jwt_extended import jwt_required, verify_jwt_in_request
from sqlalchemy import or_
from app.models.parliamentary_constituency import ParliamentaryConstituency
from app import db
from app.utils.auth_utils import get_current_user, require_admin
from app.utils.error_handling import log_api_call, APIError

# Create namespace for constituencies
constituencies_ns = Namespace('constituencies', description='Parliamentary constituencies operations')

# Define models
constituency_model = constituencies_ns.model('ParliamentaryConstituency', {
    'id': fields.String(description='Constituency ID'),
    'constituencyNumber': fields.Integer(description='Constituency number'),
    'name': fields.Raw(description='Constituency name (en/te)'),
    'name_en': fields.String(description='Constituency name in English'),
    'name_te': fields.String(description='Constituency name in Telugu'),
    'state': fields.String(description='State'),
    'description': fields.String(description='Description'),
    'isActive': fields.Boolean(description='Is active'),
    'createdAt': fields.String(description='Creation timestamp'),
    'updatedAt': fields.String(description='Last update timestamp')
})

@constituencies_ns.route('/')
class ConstituenciesList(Resource):
    @constituencies_ns.doc(
        summary='Get all parliamentary constituencies',
        description='Retrieves a list of all parliamentary constituencies',
        params={
            'state': 'Filter by state (default: Telangana)',
            'is_active': 'Filter by active status (true/false)',
            'search': 'Search by name'
        },
        responses={
            200: 'Constituencies retrieved successfully',
            500: 'Internal server error'
        }
    )
    @constituencies_ns.marshal_list_with(constituency_model)
    def get(self):
        """Get all parliamentary constituencies"""
        try:
            # Get query parameters
            state = request.args.get('state', 'Telangana')
            is_active = request.args.get('is_active')
            search = request.args.get('search', '').strip()
            
            # Build query
            query = ParliamentaryConstituency.query
            
            # Filter by state
            if state:
                query = query.filter(ParliamentaryConstituency.state == state)
            
            # Filter by active status
            if is_active is not None:
                is_active_bool = is_active.lower() == 'true'
                query = query.filter(ParliamentaryConstituency.is_active == is_active_bool)
            
            # Search by name
            if search:
                query = query.filter(
                    or_(
                        ParliamentaryConstituency.name_en.ilike(f'%{search}%'),
                        ParliamentaryConstituency.name_te.ilike(f'%{search}%')
                    )
                )
            
            # Order by constituency number
            query = query.order_by(ParliamentaryConstituency.constituency_number)
            
            # Execute query
            constituencies = query.all()
            
            return [const.to_dict() for const in constituencies], 200
            
        except Exception as e:
            raise APIError(f'Failed to retrieve constituencies: {str(e)}', 500)
    
    @constituencies_ns.expect(constituency_model)
    @constituencies_ns.doc(
        summary='Create parliamentary constituency',
        description='Creates a new parliamentary constituency (admin only)',
        responses={
            201: 'Constituency created successfully',
            400: 'Validation error',
            409: 'Constituency with number already exists',
            500: 'Internal server error'
        }
    )
    @constituencies_ns.marshal_with(constituency_model)
    def post(self):
        """Create a new parliamentary constituency"""
        try:
            verify_jwt_in_request()
            require_admin()
            
            data = request.get_json() or {}
            
            # Validate required fields
            if not data.get('constituencyNumber') and not data.get('constituency_number'):
                raise APIError('constituencyNumber is required', 400)
            if not data.get('name_en'):
                raise APIError('name_en is required', 400)
            
            constituency_number = data.get('constituencyNumber') or data.get('constituency_number')
            
            # Check if constituency with same number already exists
            existing = ParliamentaryConstituency.query.filter_by(
                constituency_number=constituency_number
            ).first()
            if existing:
                raise APIError('Constituency with this number already exists', 409)
            
            # Create new constituency
            constituency = ParliamentaryConstituency(
                constituency_number=constituency_number,
                name_en=data['name_en'],
                name_te=data.get('name_te') or data.get('name_en'),
                state=data.get('state', 'Telangana'),
                description=data.get('description'),
                is_active=data.get('isActive', True)
            )
            
            db.session.add(constituency)
            db.session.commit()
            
            return constituency.to_dict(), 201
            
        except APIError:
            raise
        except Exception as e:
            db.session.rollback()
            raise APIError(f'Failed to create constituency: {str(e)}', 500)

@constituencies_ns.route('/<int:constituency_id>')
class ConstituencyDetail(Resource):
    @constituencies_ns.doc(
        summary='Get constituency by ID',
        description='Retrieves a specific parliamentary constituency by ID (constituency number)',
        responses={
            200: 'Constituency retrieved successfully',
            404: 'Constituency not found',
            500: 'Internal server error'
        }
    )
    @constituencies_ns.marshal_with(constituency_model)
    def get(self, constituency_id):
        """Get a specific parliamentary constituency by ID (constituency number)"""
        try:
            constituency = ParliamentaryConstituency.query.get(constituency_id)
            
            if not constituency:
                raise APIError('Constituency not found', 404)
            
            return constituency.to_dict(), 200
            
        except APIError:
            raise
        except Exception as e:
            raise APIError(f'Failed to retrieve constituency: {str(e)}', 500)
    
    @constituencies_ns.doc(
        summary='Update constituency',
        description='Updates a parliamentary constituency (admin only)',
        responses={
            200: 'Constituency updated successfully',
            404: 'Constituency not found',
            500: 'Internal server error'
        }
    )
    @constituencies_ns.marshal_with(constituency_model)
    def put(self, constituency_id):
        """Update a parliamentary constituency"""
        try:
            verify_jwt_in_request()
            require_admin()
            
            constituency = ParliamentaryConstituency.query.get(constituency_id)
            
            if not constituency:
                raise APIError('Constituency not found', 404)
            
            data = request.get_json() or {}
            
            # Update fields if provided (cannot update constituency_number as it's the primary key)
            if 'name_en' in data:
                constituency.name_en = data['name_en']
            if 'name_te' in data:
                constituency.name_te = data['name_te']
            if 'state' in data:
                constituency.state = data['state']
            if 'description' in data:
                constituency.description = data['description']
            if 'isActive' in data:
                constituency.is_active = data['isActive']
            
            db.session.commit()
            
            return constituency.to_dict(), 200
            
        except APIError:
            raise
        except Exception as e:
            db.session.rollback()
            raise APIError(f'Failed to update constituency: {str(e)}', 500)

# Note: /by-number/<int:constituency_number> is now redundant since ID is the constituency number
# Keeping it for backward compatibility, but it just calls the main route
@constituencies_ns.route('/by-number/<int:constituency_number>')
class ConstituencyByNumber(Resource):
    @constituencies_ns.doc(
        summary='Get constituency by number',
        description='Retrieves a specific parliamentary constituency by constituency number (same as /<id>)',
        responses={
            200: 'Constituency retrieved successfully',
            404: 'Constituency not found',
            500: 'Internal server error'
        }
    )
    @constituencies_ns.marshal_with(constituency_model)
    def get(self, constituency_number):
        """Get a specific parliamentary constituency by constituency number"""
        try:
            constituency = ParliamentaryConstituency.query.get(constituency_number)
            
            if not constituency:
                raise APIError('Constituency not found', 404)
            
            return constituency.to_dict(), 200
            
        except APIError:
            raise
        except Exception as e:
            raise APIError(f'Failed to retrieve constituency: {str(e)}', 500)


