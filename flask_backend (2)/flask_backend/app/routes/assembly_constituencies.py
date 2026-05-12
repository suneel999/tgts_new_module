"""
Assembly Constituencies Routes for Telangana Congress Communication App
"""

from flask import request
from flask_restx import Namespace, Resource, fields
from flask_jwt_extended import verify_jwt_in_request
from sqlalchemy import or_
from app.models.assembly_constituency import AssemblyConstituency
from app.models.parliamentary_constituency import ParliamentaryConstituency
from app import db
from app.utils.error_handling import APIError
from app.utils.auth_utils import require_admin

# Create namespace for assembly constituencies
assembly_constituencies_ns = Namespace('assembly-constituencies', description='Assembly constituencies operations')

# Define models
assembly_constituency_model = assembly_constituencies_ns.model('AssemblyConstituency', {
    'id': fields.String(description='Constituency ID'),
    'constituencyNumber': fields.Integer(description='Constituency number'),
    'name': fields.Raw(description='Constituency name (en/te)'),
    'name_en': fields.String(description='Constituency name in English'),
    'name_te': fields.String(description='Constituency name in Telugu'),
    'state': fields.String(description='State'),
    'parliamentConstituencyId': fields.String(description='Parliamentary constituency ID'),
    'parliamentConstituencyRef': fields.Raw(description='Parliamentary constituency reference'),
    'description': fields.String(description='Description'),
    'isActive': fields.Boolean(description='Is active'),
    'createdAt': fields.String(description='Creation timestamp'),
    'updatedAt': fields.String(description='Last update timestamp')
})

@assembly_constituencies_ns.route('/')
class AssemblyConstituenciesList(Resource):
    @assembly_constituencies_ns.doc(
        summary='Get all assembly constituencies',
        description='Retrieves a list of all assembly constituencies',
        params={
            'parliament_constituency_id': 'Filter by parliamentary constituency ID (constituency number)',
            'state': 'Filter by state (default: Telangana)',
            'is_active': 'Filter by active status (true/false)',
            'search': 'Search by name'
        },
        responses={
            200: 'Constituencies retrieved successfully',
            500: 'Internal server error'
        }
    )
    @assembly_constituencies_ns.marshal_list_with(assembly_constituency_model)
    def get(self):
        """Get all assembly constituencies"""
        try:
            # Get query parameters
            parliament_constituency_id = request.args.get('parliament_constituency_id')
            state = request.args.get('state', 'Telangana')
            is_active = request.args.get('is_active')
            search = request.args.get('search', '').strip()
            
            # Build query
            query = AssemblyConstituency.query
            
            # Filter by parliamentary constituency
            if parliament_constituency_id:
                try:
                    # Convert to integer if it's a string
                    pc_id = int(parliament_constituency_id)
                    query = query.filter(AssemblyConstituency.parliament_constituency_id == pc_id)
                except (ValueError, TypeError):
                    pass  # Invalid ID, skip filter
            
            # Filter by state
            if state:
                query = query.filter(AssemblyConstituency.state == state)
            
            # Filter by active status
            if is_active is not None:
                is_active_bool = is_active.lower() == 'true'
                query = query.filter(AssemblyConstituency.is_active == is_active_bool)
            
            # Search by name
            if search:
                query = query.filter(
                    or_(
                        AssemblyConstituency.name_en.ilike(f'%{search}%'),
                        AssemblyConstituency.name_te.ilike(f'%{search}%')
                    )
                )
            
            # Order by constituency number
            query = query.order_by(AssemblyConstituency.constituency_number)
            
            # Execute query
            constituencies = query.all()
            
            return [const.to_dict() for const in constituencies], 200
            
        except Exception as e:
            raise APIError(f'Failed to retrieve assembly constituencies: {str(e)}', 500)
    
    @assembly_constituencies_ns.expect(assembly_constituency_model)
    @assembly_constituencies_ns.doc(
        summary='Create assembly constituency',
        description='Creates a new assembly constituency (admin only)',
        responses={
            201: 'Assembly constituency created successfully',
            400: 'Validation error',
            404: 'Parliamentary constituency not found',
            409: 'Assembly constituency with number already exists',
            500: 'Internal server error'
        }
    )
    @assembly_constituencies_ns.marshal_with(assembly_constituency_model)
    def post(self):
        """Create a new assembly constituency"""
        try:
            verify_jwt_in_request()
            require_admin()
            
            data = request.get_json() or {}
            
            # Validate required fields
            if not data.get('constituencyNumber') and not data.get('constituency_number'):
                raise APIError('constituencyNumber is required', 400)
            if not data.get('name_en'):
                raise APIError('name_en is required', 400)
            if not data.get('parliamentConstituencyId') and not data.get('parliament_constituency_id'):
                raise APIError('parliamentConstituencyId is required', 400)
            
            constituency_number = data.get('constituencyNumber') or data.get('constituency_number')
            parliament_constituency_id = data.get('parliamentConstituencyId') or data.get('parliament_constituency_id')
            
            # Check if parliamentary constituency exists
            parliament_constituency = ParliamentaryConstituency.query.get(parliament_constituency_id)
            if not parliament_constituency:
                raise APIError('Parliamentary constituency not found', 404)
            
            # Check if assembly constituency with same number already exists
            existing = AssemblyConstituency.query.filter_by(
                constituency_number=constituency_number
            ).first()
            if existing:
                raise APIError('Assembly constituency with this number already exists', 409)
            
            # Create new assembly constituency
            assembly_constituency = AssemblyConstituency(
                constituency_number=constituency_number,
                name_en=data['name_en'],
                name_te=data.get('name_te') or data.get('name_en'),
                state=data.get('state', 'Telangana'),
                parliament_constituency_id=parliament_constituency_id,
                description=data.get('description'),
                is_active=data.get('isActive', True)
            )
            
            db.session.add(assembly_constituency)
            db.session.commit()
            
            return assembly_constituency.to_dict(), 201
            
        except APIError:
            raise
        except Exception as e:
            db.session.rollback()
            raise APIError(f'Failed to create assembly constituency: {str(e)}', 500)

@assembly_constituencies_ns.route('/<int:constituency_id>')
class AssemblyConstituencyDetail(Resource):
    @assembly_constituencies_ns.doc(
        summary='Get assembly constituency by ID',
        description='Retrieves a specific assembly constituency by ID (constituency number)',
        responses={
            200: 'Constituency retrieved successfully',
            404: 'Constituency not found',
            500: 'Internal server error'
        }
    )
    @assembly_constituencies_ns.marshal_with(assembly_constituency_model)
    def get(self, constituency_id):
        """Get a specific assembly constituency by ID (constituency number)"""
        try:
            constituency = AssemblyConstituency.query.get(constituency_id)
            
            if not constituency:
                raise APIError('Assembly constituency not found', 404)
            
            return constituency.to_dict(), 200
            
        except APIError:
            raise
        except Exception as e:
            raise APIError(f'Failed to retrieve assembly constituency: {str(e)}', 500)
    
    @assembly_constituencies_ns.expect(assembly_constituency_model)
    @assembly_constituencies_ns.doc(
        summary='Update assembly constituency',
        description='Updates an assembly constituency (admin only)',
        responses={
            200: 'Assembly constituency updated successfully',
            400: 'Validation error',
            404: 'Assembly constituency not found',
            500: 'Internal server error'
        }
    )
    @assembly_constituencies_ns.marshal_with(assembly_constituency_model)
    def put(self, constituency_id):
        """Update an assembly constituency"""
        try:
            verify_jwt_in_request()
            require_admin()
            
            constituency = AssemblyConstituency.query.get(constituency_id)
            
            if not constituency:
                raise APIError('Assembly constituency not found', 404)
            
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
            if 'parliamentConstituencyId' in data or 'parliament_constituency_id' in data:
                parliament_constituency_id = data.get('parliamentConstituencyId') or data.get('parliament_constituency_id')
                # Check if parliamentary constituency exists
                parliament_constituency = ParliamentaryConstituency.query.get(parliament_constituency_id)
                if not parliament_constituency:
                    raise APIError('Parliamentary constituency not found', 404)
                constituency.parliament_constituency_id = parliament_constituency_id
            
            db.session.commit()
            
            return constituency.to_dict(), 200
            
        except APIError:
            raise
        except Exception as e:
            db.session.rollback()
            raise APIError(f'Failed to update assembly constituency: {str(e)}', 500)

@assembly_constituencies_ns.route('/by-number/<int:constituency_number>')
class AssemblyConstituencyByNumber(Resource):
    @assembly_constituencies_ns.doc(
        summary='Get assembly constituency by number',
        description='Retrieves a specific assembly constituency by constituency number',
        responses={
            200: 'Constituency retrieved successfully',
            404: 'Constituency not found',
            500: 'Internal server error'
        }
    )
    @assembly_constituencies_ns.marshal_with(assembly_constituency_model)
    def get(self, constituency_number):
        """Get a specific assembly constituency by constituency number"""
        try:
            constituency = AssemblyConstituency.query.get(constituency_number)
            
            if not constituency:
                raise APIError('Assembly constituency not found', 404)
            
            return constituency.to_dict(), 200
            
        except APIError:
            raise
        except Exception as e:
            raise APIError(f'Failed to retrieve assembly constituency: {str(e)}', 500)

