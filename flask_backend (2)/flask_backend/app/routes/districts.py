"""
Districts and Mandals Routes for Telangana Congress Communication App
"""

from flask import request
from flask_restx import Namespace, Resource, fields
from flask_jwt_extended import verify_jwt_in_request
from sqlalchemy import or_
from app.models.district import District
from app.models.mandal import Mandal
from app import db
from app.utils.error_handling import APIError
from app.utils.auth_utils import require_admin

# Create namespace for districts
districts_ns = Namespace('districts', description='Districts and mandals operations')

# Define models
district_model = districts_ns.model('District', {
    'id': fields.Integer(description='District ID'),
    'name': fields.Raw(description='District name (en/te)'),
    'name_en': fields.String(description='District name in English'),
    'name_te': fields.String(description='District name in Telugu'),
    'state': fields.String(description='State'),
    'description': fields.String(description='Description'),
    'isActive': fields.Boolean(description='Is active'),
    'createdAt': fields.String(description='Creation timestamp'),
    'updatedAt': fields.String(description='Last update timestamp')
})

mandal_model = districts_ns.model('Mandal', {
    'id': fields.Integer(description='Mandal ID'),
    'districtId': fields.Integer(description='District ID'),
    'districtRef': fields.Raw(description='District reference'),
    'name': fields.Raw(description='Mandal name (en/te)'),
    'name_en': fields.String(description='Mandal name in English'),
    'name_te': fields.String(description='Mandal name in Telugu'),
    'description': fields.String(description='Description'),
    'isActive': fields.Boolean(description='Is active'),
    'createdAt': fields.String(description='Creation timestamp'),
    'updatedAt': fields.String(description='Last update timestamp')
})

@districts_ns.route('/')
class DistrictsList(Resource):
    @districts_ns.doc(
        summary='Get all districts',
        description='Retrieves a list of all districts',
        params={
            'state': 'Filter by state (default: Telangana)',
            'is_active': 'Filter by active status (true/false)',
            'search': 'Search by name'
        },
        responses={
            200: 'Districts retrieved successfully',
            500: 'Internal server error'
        }
    )
    @districts_ns.marshal_list_with(district_model)
    def get(self):
        """Get all districts"""
        try:
            state = request.args.get('state', 'Telangana')
            is_active = request.args.get('is_active')
            search = request.args.get('search')
            
            query = District.query
            
            # Apply filters
            if state:
                query = query.filter_by(state=state)
            if is_active is not None:
                is_active_bool = is_active.lower() == 'true'
                query = query.filter_by(is_active=is_active_bool)
            if search:
                search_term = f'%{search}%'
                query = query.filter(
                    or_(
                        District.name_en.ilike(search_term),
                        District.name_te.ilike(search_term)
                    )
                )
            
            districts = query.order_by(District.name_en).all()
            return [district.to_dict() for district in districts]
            
        except Exception as e:
            districts_ns.abort(500, f'Failed to retrieve districts: {str(e)}')
    
    @districts_ns.expect(district_model)
    @districts_ns.doc(
        summary='Create district',
        description='Creates a new district (admin only)',
        responses={
            201: 'District created successfully',
            400: 'Validation error',
            409: 'District with name already exists',
            500: 'Internal server error'
        }
    )
    @districts_ns.marshal_with(district_model)
    def post(self):
        """Create a new district"""
        try:
            verify_jwt_in_request()
            require_admin()
            
            data = request.get_json() or {}
            
            # Validate required fields
            if not data.get('name_en'):
                raise APIError('name_en is required', 400)
            
            # Check if district with same name already exists
            existing = District.query.filter_by(name_en=data['name_en']).first()
            if existing:
                raise APIError('District with this name already exists', 409)
            
            # Create new district
            district = District(
                name_en=data['name_en'],
                name_te=data.get('name_te') or data.get('name_en'),
                state=data.get('state', 'Telangana'),
                description=data.get('description'),
                is_active=data.get('isActive', True)
            )
            
            db.session.add(district)
            db.session.commit()
            
            return district.to_dict(), 201
            
        except APIError:
            raise
        except Exception as e:
            db.session.rollback()
            raise APIError(f'Failed to create district: {str(e)}', 500)

@districts_ns.route('/<int:district_id>/mandals')
class DistrictMandals(Resource):
    @districts_ns.doc(
        summary='Get mandals for a district',
        description='Retrieves a list of all mandals for a specific district',
        params={
            'district_id': 'District ID',
            'is_active': 'Filter by active status (true/false)',
            'search': 'Search by name'
        },
        responses={
            200: 'Mandals retrieved successfully',
            404: 'District not found',
            500: 'Internal server error'
        }
    )
    @districts_ns.marshal_list_with(mandal_model)
    def get(self, district_id):
        """Get mandals for a specific district"""
        try:
            # Check if district exists
            district = District.query.get(district_id)
            if not district:
                districts_ns.abort(404, 'District not found')
            
            is_active = request.args.get('is_active')
            search = request.args.get('search')
            
            query = Mandal.query.filter_by(district_id=district_id)
            
            # Apply filters
            if is_active is not None:
                is_active_bool = is_active.lower() == 'true'
                query = query.filter_by(is_active=is_active_bool)
            if search:
                search_term = f'%{search}%'
                query = query.filter(
                    or_(
                        Mandal.name_en.ilike(search_term),
                        Mandal.name_te.ilike(search_term)
                    )
                )
            
            mandals = query.order_by(Mandal.name_en).all()
            return [mandal.to_dict() for mandal in mandals]
            
        except Exception as e:
            districts_ns.abort(500, f'Failed to retrieve mandals: {str(e)}')
    
    @districts_ns.expect(mandal_model)
    @districts_ns.doc(
        summary='Create mandal',
        description='Creates a new mandal for a district (admin only)',
        responses={
            201: 'Mandal created successfully',
            400: 'Validation error',
            404: 'District not found',
            409: 'Mandal with name already exists in this district',
            500: 'Internal server error'
        }
    )
    @districts_ns.marshal_with(mandal_model)
    def post(self, district_id):
        """Create a new mandal for a district"""
        try:
            verify_jwt_in_request()
            require_admin()
            
            # Check if district exists
            district = District.query.get(district_id)
            if not district:
                raise APIError('District not found', 404)
            
            data = request.get_json() or {}
            
            # Validate required fields
            if not data.get('name_en'):
                raise APIError('name_en is required', 400)
            
            # Check if mandal with same name already exists in this district
            existing = Mandal.query.filter_by(
                district_id=district_id,
                name_en=data['name_en']
            ).first()
            if existing:
                raise APIError('Mandal with this name already exists in this district', 409)
            
            # Create new mandal
            mandal = Mandal(
                district_id=district_id,
                name_en=data['name_en'],
                name_te=data.get('name_te') or data.get('name_en'),
                description=data.get('description'),
                is_active=data.get('isActive', True)
            )
            
            db.session.add(mandal)
            db.session.commit()
            
            return mandal.to_dict(), 201
            
        except APIError:
            raise
        except Exception as e:
            db.session.rollback()
            raise APIError(f'Failed to create mandal: {str(e)}', 500)

@districts_ns.route('/<int:district_id>')
class DistrictDetail(Resource):
    @districts_ns.doc(
        summary='Get specific district',
        description='Retrieves a specific district by ID',
        params={'district_id': 'District ID'},
        responses={
            200: 'District retrieved successfully',
            404: 'District not found',
            500: 'Internal server error'
        }
    )
    @districts_ns.marshal_with(district_model)
    def get(self, district_id):
        """Get specific district"""
        try:
            district = District.query.get(district_id)
            if not district:
                districts_ns.abort(404, 'District not found')
            return district.to_dict()
        except Exception as e:
            districts_ns.abort(500, f'Failed to retrieve district: {str(e)}')
    
    @districts_ns.doc(
        summary='Update district',
        description='Updates a district (admin only)',
        responses={
            200: 'District updated successfully',
            404: 'District not found',
            500: 'Internal server error'
        }
    )
    @districts_ns.marshal_with(district_model)
    def put(self, district_id):
        """Update a district"""
        try:
            verify_jwt_in_request()
            require_admin()
            
            district = District.query.get(district_id)
            
            if not district:
                raise APIError('District not found', 404)
            
            data = request.get_json() or {}
            
            # Update fields if provided
            if 'name_en' in data:
                district.name_en = data['name_en']
            if 'name_te' in data:
                district.name_te = data['name_te']
            if 'state' in data:
                district.state = data['state']
            if 'description' in data:
                district.description = data['description']
            if 'isActive' in data:
                district.is_active = data['isActive']
            
            db.session.commit()
            
            return district.to_dict(), 200
            
        except APIError:
            raise
        except Exception as e:
            db.session.rollback()
            raise APIError(f'Failed to update district: {str(e)}', 500)

