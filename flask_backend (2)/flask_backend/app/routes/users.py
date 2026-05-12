"""
Users Routes for Telangana Congress Communication App
Production-grade Flask-RESTX implementation with comprehensive error handling
"""

from flask import request
from flask_restx import Namespace, Resource, fields
from app.models import User, UserRole
from app import db
from app.utils.auth_utils import get_current_user, require_admin
from app.utils.error_handling import log_api_call
import uuid

# Create namespace for users
users_ns = Namespace('users', description='User management operations')

# Define models directly in the namespace
user_model = users_ns.model('User', {
    'id': fields.String(description='User ID'),
    'phone': fields.String(description='Phone number'),
    'name': fields.String(description='User name'),
    'role': fields.String(description='User role (public, cadre, admin)'),
    'region': fields.String(description='User region'),
    'is_active': fields.Boolean(description='User active status'),
    'created_at': fields.String(description='Creation timestamp'),
    'updated_at': fields.String(description='Last update timestamp')
})

@users_ns.route('/')
class UsersList(Resource):
    @users_ns.marshal_with(users_ns.model('Users Response', {
        'data': fields.List(fields.Nested(user_model)),
        'page': fields.Integer,
        'per_page': fields.Integer,
        'total': fields.Integer,
        'total_pages': fields.Integer
    }))
    @users_ns.doc(
        security='Bearer',
        summary='Get all users (admin only)',
        description='Retrieves a paginated list of all users (admin only)',
        params={
            'page': 'Page number (default: 1)',
            'per_page': 'Items per page (default: 20)',
            'role': 'Filter by role (public, cadre, admin)',
            'search': 'Search by name or phone'
        },
        responses={
            200: 'Users retrieved successfully',
            401: 'Authentication required',
            403: 'Admin access required',
            500: 'Internal server error'
        }
    )
    def get(self):
        """Get all users (admin only)"""
        try:
            log_api_call('/api/users/', 'GET')
            
            # Check authentication and authorization
            current_user = get_current_user()
            if current_user.role != UserRole.ADMIN:
                users_ns.abort(403, 'Admin access required')
            
            page = request.args.get('page', 1, type=int)
            per_page = min(request.args.get('per_page', 20, type=int), 100)
            role_filter = request.args.get('role')
            search = request.args.get('search', '')
            
            query = User.query
            
            if role_filter and role_filter != 'all':
                try:
                    query = query.filter_by(role=UserRole(role_filter))
                except ValueError:
                    users_ns.abort(400, 'Invalid role filter')
            
            if search:
                query = query.filter(
                    (User.name.contains(search)) | 
                    (User.phone.contains(search))
                )
            
            users = query.order_by(User.created_at.desc()).paginate(
                page=page, per_page=per_page, error_out=False
            )
            
            # Return format matching frontend expectations
            return {
                'data': [user.to_dict() for user in users.items],
                'page': page,
                'per_page': per_page,
                'total': users.total,
                'total_pages': users.pages
            }
            
        except Exception as e:
            users_ns.abort(500, str(e))

@users_ns.route('/stats')
class UserStats(Resource):
    @users_ns.doc(
        security='Bearer',
        summary='Get user statistics',
        description='Retrieves user statistics (admin only)',
        responses={
            200: 'User statistics retrieved successfully',
            401: 'Authentication required',
            403: 'Admin access required',
            500: 'Internal server error'
        }
    )
    def get(self):
        """Get user statistics (admin only)"""
        try:
            log_api_call('/api/users/stats', 'GET')
            
            # Check authentication and authorization
            current_user = get_current_user()
            if current_user.role != UserRole.ADMIN:
                users_ns.abort(403, 'Admin access required')
            
            total_users = User.query.count()
            active_users = User.query.filter_by(is_active=True).count()
            
            # Count users by role
            role_counts = {}
            for role in UserRole:
                role_counts[role.value] = User.query.filter_by(role=role).count()
            
            return {
                'total_users': total_users,
                'active_users': active_users,
                'role_distribution': role_counts
            }
            
        except Exception as e:
            users_ns.abort(500, str(e))