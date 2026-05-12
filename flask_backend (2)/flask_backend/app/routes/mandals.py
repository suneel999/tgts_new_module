"""
Mandals Routes for Telangana Congress Communication App
"""

from flask import request
from flask_restx import Namespace, Resource, fields
from flask_jwt_extended import verify_jwt_in_request
from sqlalchemy import or_
from app.models.mandal import Mandal
from app.models.district import District
from app import db
from app.utils.error_handling import APIError
from app.utils.auth_utils import require_admin

# Create namespace for mandals
mandals_ns = Namespace('mandals', description='Mandals operations')

# Define models
mandal_model = mandals_ns.model('Mandal', {
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

@mandals_ns.route('/')
class MandalsList(Resource):
    @mandals_ns.doc(
        summary='Get all mandals',
        description='Retrieves a list of all mandals with district information',
        params={
            'district_id': 'Filter by district ID',
            'is_active': 'Filter by active status (true/false)',
            'search': 'Search by name'
        },
        responses={
            200: 'Mandals retrieved successfully',
            500: 'Internal server error'
        }
    )
    @mandals_ns.marshal_list_with(mandal_model)
    def get(self):
        """Get all mandals"""
        try:
            district_id = request.args.get('district_id', type=int)
            is_active = request.args.get('is_active')
            search = request.args.get('search')
            
            query = Mandal.query
            
            # Apply filters
            if district_id:
                query = query.filter_by(district_id=district_id)
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
            mandals_ns.abort(500, f'Failed to retrieve mandals: {str(e)}')

@mandals_ns.route('/<int:mandal_id>')
class MandalDetail(Resource):
    @mandals_ns.doc(
        summary='Get specific mandal',
        description='Retrieves a specific mandal by ID',
        params={'mandal_id': 'Mandal ID'},
        responses={
            200: 'Mandal retrieved successfully',
            404: 'Mandal not found',
            500: 'Internal server error'
        }
    )
    @mandals_ns.marshal_with(mandal_model)
    def get(self, mandal_id):
        """Get specific mandal"""
        try:
            mandal = Mandal.query.get(mandal_id)
            if not mandal:
                mandals_ns.abort(404, 'Mandal not found')
            return mandal.to_dict()
        except Exception as e:
            mandals_ns.abort(500, f'Failed to retrieve mandal: {str(e)}')
    
    @mandals_ns.expect(mandal_model)
    @mandals_ns.doc(
        summary='Update mandal',
        description='Updates a mandal (admin only)',
        responses={
            200: 'Mandal updated successfully',
            400: 'Validation error',
            404: 'Mandal not found',
            409: 'Mandal with name already exists in this district',
            500: 'Internal server error'
        }
    )
    @mandals_ns.marshal_with(mandal_model)
    def put(self, mandal_id):
        """Update a mandal"""
        try:
            verify_jwt_in_request()
            require_admin()
            
            mandal = Mandal.query.get(mandal_id)
            if not mandal:
                raise APIError('Mandal not found', 404)
            
            data = request.get_json() or {}
            
            # Update fields if provided
            if 'name_en' in data:
                # Check if mandal with same name already exists in this district (excluding current mandal)
                existing = Mandal.query.filter_by(
                    district_id=mandal.district_id,
                    name_en=data['name_en']
                ).filter(Mandal.id != mandal_id).first()
                if existing:
                    raise APIError('Mandal with this name already exists in this district', 409)
                mandal.name_en = data['name_en']
            if 'name_te' in data:
                mandal.name_te = data['name_te']
            if 'description' in data:
                mandal.description = data['description']
            if 'isActive' in data:
                mandal.is_active = data['isActive']
            
            db.session.commit()
            
            return mandal.to_dict(), 200
            
        except APIError:
            raise
        except Exception as e:
            db.session.rollback()
            raise APIError(f'Failed to update mandal: {str(e)}', 500)

