"""
Documents Routes for Telangana Congress Communication App
Production-grade Flask-RESTX implementation with comprehensive error handling
"""

from flask import request
from flask_restx import Namespace, Resource, fields
from flask_jwt_extended import verify_jwt_in_request, get_jwt_identity
from app.models import Document, User, UserRole
from app import db
from app.utils.auth_utils import get_current_user, require_admin, require_cadre_or_admin
from app.utils.error_handling import validate_required_fields, log_api_call
from app.utils.geographic_access import filter_content_by_geographic_access, get_user_geographic_info, can_user_access_content
from app.services.s3_service import get_s3_service
from werkzeug.utils import secure_filename
from werkzeug.exceptions import HTTPException
from datetime import datetime
import uuid
import json
import os

# Create namespace for documents
documents_ns = Namespace('documents', description='Document management operations')

# Define models directly in the namespace
document_model = documents_ns.model('Document', {
    'id': fields.String(description='Document ID'),
    'title_en': fields.String(description='Title in English'),
    'title_te': fields.String(description='Title in Telugu'),
    'category': fields.String(description='Document category'),
    'file_url': fields.String(description='File URL'),
    'access_level': fields.Raw(description='Access levels'),
    'is_published': fields.Boolean(description='Published status'),
    'created_at': fields.String(description='Creation timestamp'),
    'updated_at': fields.String(description='Last update timestamp')
})

document_create_model = documents_ns.model('Document Create', {
    'title_en': fields.String(required=True, description='Title in English', example='Party Constitution'),
    'title_te': fields.String(required=True, description='Title in Telugu', example='పార్టీ రాజ్యాంగం'),
    'category': fields.String(required=True, description='Document category', example='Official'),
    'file_url': fields.String(required=True, description='File URL', example='https://example.com/document.pdf'),
    'access_level': fields.Raw(required=True, description='Access levels (JSON array)', example=['public', 'cadre', 'admin']),
    'is_published': fields.Boolean(description='Published status', default=False),
    'districtIds': fields.List(fields.Integer, description='List of district IDs for geographic access'),
    'mandalIds': fields.List(fields.Integer, description='List of mandal IDs for geographic access'),
    'assemblyConstituencyIds': fields.List(fields.Integer, description='List of assembly constituency IDs for geographic access'),
    'parliamentaryConstituencyIds': fields.List(fields.Integer, description='List of parliamentary constituency IDs for geographic access')
})

@documents_ns.route('/')
class DocumentsList(Resource):
    @documents_ns.marshal_with(documents_ns.model('Documents Response', {
        'documents': fields.List(fields.Nested(document_model)),
        'total': fields.Integer,
        'pages': fields.Integer,
        'current_page': fields.Integer
    }))
    @documents_ns.doc(
        summary='Get documents accessible to current user',
        description='Retrieves published documents. Public documents are accessible to everyone. Role-specific documents require authentication.',
        params={
            'page': 'Page number (default: 1)',
            'per_page': 'Items per page (default: 20)',
            'category': 'Filter by category'
        },
        responses={
            200: 'Documents retrieved successfully',
            500: 'Internal server error'
        }
    )
    def get(self):
        """Get documents accessible to current user (public documents accessible without auth)"""
        try:
            log_api_call('/api/documents/', 'GET')
            
            page = request.args.get('page', 1, type=int)
            per_page = min(request.args.get('per_page', 20, type=int), 100)
            category = request.args.get('category')
            all_items = request.args.get('all', 'false').lower() == 'true'  # Admin can request all items
            
            # Check if user is authenticated (optional)
            current_user = None
            user_role = None
            is_admin = False
            try:
                verify_jwt_in_request(optional=True)
                user_id = get_jwt_identity()
                if user_id:
                    current_user = User.query.get(user_id)
                    if current_user:
                        user_role = current_user.role
                        is_admin = user_role == UserRole.ADMIN
            except Exception:
                # Not authenticated - will only show public documents
                pass
            
            # Build query - show all if admin requests it, otherwise only published
            if all_items and is_admin:
                query = Document.query
            else:
                query = Document.query.filter_by(is_published=True)
            
            if category:
                query = query.filter_by(category=category)
            
            # Filter by access level first
            accessible_docs = []
            for doc in query.all():
                access_levels = json.loads(doc.access_level) if doc.access_level else []
                
                # Public documents are accessible to everyone
                if 'public' in access_levels:
                    accessible_docs.append(doc)
                # Role-specific documents require authentication
                elif current_user and user_role:
                    if user_role.value in access_levels or user_role == UserRole.ADMIN:
                        accessible_docs.append(doc)
            
            # Apply geographic filtering (skip for admins requesting all items)
            if not (all_items and is_admin):
                accessible_docs = filter_content_by_geographic_access(accessible_docs, current_user)
            
            # Simple pagination
            start = (page - 1) * per_page
            end = start + per_page
            paginated_docs = accessible_docs[start:end]
            
            return {
                'documents': [doc.to_dict() for doc in paginated_docs],
                'total': len(accessible_docs),
                'pages': (len(accessible_docs) + per_page - 1) // per_page,
                'current_page': page
            }
            
        except HTTPException:
            # Re-raise HTTP exceptions (like abort) to preserve status codes
            raise
        except Exception as e:
            documents_ns.abort(500, str(e))
    
    @documents_ns.expect(document_create_model)
    @documents_ns.marshal_with(document_model)
    @documents_ns.doc(
        security='Bearer',
        summary='Upload document',
        description='Uploads a new document (admin/cadre only)',
        responses={
            201: 'Document created successfully',
            400: 'Validation error',
            401: 'Authentication required',
            403: 'Admin or Cadre access required',
            500: 'Internal server error'
        }
    )
    def post(self):
        """Upload document (admin/cadre only)"""
        try:
            log_api_call('/api/documents/', 'POST')
            
            # Verify JWT token first
            try:
                verify_jwt_in_request(optional=False)
            except Exception as e:
                documents_ns.abort(401, f'Authentication required: {str(e)}')
            
            # Check authentication and authorization
            current_user = get_current_user()
            if current_user.role not in [UserRole.ADMIN, UserRole.CADRE]:
                documents_ns.abort(403, 'Admin or Cadre access required')
            
            data = request.get_json()
            validate_required_fields(data, ['title_en', 'title_te', 'category', 'file_url', 'access_level'])
            
            # Validate access level format
            if not isinstance(data['access_level'], list):
                documents_ns.abort(400, 'Access level must be an array of role names')
            
            # Handle geographic access fields
            district_ids = data.get('districtIds') or data.get('district_ids')
            mandal_ids = data.get('mandalIds') or data.get('mandal_ids')
            assembly_constituency_ids = data.get('assemblyConstituencyIds') or data.get('assembly_constituency_ids')
            parliamentary_constituency_ids = data.get('parliamentaryConstituencyIds') or data.get('parliamentary_constituency_ids')
            
            document = Document(
                id=str(uuid.uuid4()),
                title_en=data['title_en'],
                title_te=data['title_te'],
                category=data['category'],
                file_url=data['file_url'],
                access_level=json.dumps(data['access_level']),
                is_published=data.get('is_published', False),
                district_ids=district_ids if district_ids else None,
                mandal_ids=mandal_ids if mandal_ids else None,
                assembly_constituency_ids=assembly_constituency_ids if assembly_constituency_ids else None,
                parliamentary_constituency_ids=parliamentary_constituency_ids if parliamentary_constituency_ids else None
            )
            
            db.session.add(document)
            db.session.commit()
            
            return document.to_dict(), 201
            
        except HTTPException:
            # Re-raise HTTP exceptions (like abort) to preserve status codes
            raise
        except Exception as e:
            documents_ns.abort(400, str(e))

@documents_ns.route('/<document_id>')
class DocumentDetail(Resource):
    @documents_ns.marshal_with(document_model)
    @documents_ns.doc(
        summary='Get specific document',
        description='Retrieves a specific document by ID. Public documents are accessible to everyone. Role-specific documents require authentication.',
        params={'document_id': 'Document ID'},
        responses={
            200: 'Document retrieved successfully',
            403: 'Access denied',
            404: 'Document not found',
            500: 'Internal server error'
        }
    )
    def get(self, document_id):
        """Get specific document (public documents accessible without auth)"""
        try:
            log_api_call(f'/api/documents/{document_id}', 'GET')
            
            document = Document.query.get(document_id)
            if not document or not document.is_published:
                documents_ns.abort(404, 'Document not found')
            
            # Check access level
            access_levels = json.loads(document.access_level) if document.access_level else []
            
            # Check access level first
            has_access = False
            current_user = None
            
            # Public documents are accessible to everyone
            if 'public' in access_levels:
                has_access = True
            else:
                # Role-specific documents require authentication
                try:
                    verify_jwt_in_request(optional=True)
                    user_id = get_jwt_identity()
                    if user_id:
                        current_user = User.query.get(user_id)
                        if current_user and (current_user.role.value in access_levels or current_user.role == UserRole.ADMIN):
                            has_access = True
                except Exception:
                    pass
            
            if not has_access:
                documents_ns.abort(403, 'Access denied. This document requires authentication.')
            
            # Check geographic access
            user_geo_info = get_user_geographic_info(current_user)
            user_obj = user_geo_info.get('member') if user_geo_info.get('member') else current_user
            if not can_user_access_content(user_obj, document):
                documents_ns.abort(404, 'Document not found')
            
            return document.to_dict()
            
        except HTTPException:
            # Re-raise HTTP exceptions (like abort) to preserve status codes
            raise
        except Exception as e:
            documents_ns.abort(500, str(e))
    
    @documents_ns.expect(document_create_model)
    @documents_ns.marshal_with(document_model)
    @documents_ns.doc(
        security='Bearer',
        summary='Update document',
        description='Updates a document (admin/cadre only)',
        responses={
            200: 'Document updated successfully',
            400: 'Validation error',
            401: 'Authentication required',
            403: 'Admin or Cadre access required',
            404: 'Document not found',
            500: 'Internal server error'
        }
    )
    def put(self, document_id):
        """Update document (admin/cadre only)"""
        try:
            log_api_call(f'/api/documents/{document_id}', 'PUT')
            
            # Verify JWT token first
            try:
                verify_jwt_in_request(optional=False)
            except Exception as e:
                documents_ns.abort(401, f'Authentication required: {str(e)}')
            
            # Check authentication and authorization
            current_user = get_current_user()
            if current_user.role not in [UserRole.ADMIN, UserRole.CADRE]:
                documents_ns.abort(403, 'Admin or Cadre access required')
            
            document = Document.query.get(document_id)
            if not document:
                documents_ns.abort(404, 'Document not found')
            
            data = request.get_json()
            
            if 'title_en' in data:
                document.title_en = data['title_en']
            if 'title_te' in data:
                document.title_te = data['title_te']
            if 'category' in data:
                document.category = data['category']
            if 'file_url' in data:
                document.file_url = data['file_url']
            if 'access_level' in data:
                if not isinstance(data['access_level'], list):
                    documents_ns.abort(400, 'Access level must be an array of role names')
                document.access_level = json.dumps(data['access_level'])
            if 'is_published' in data:
                document.is_published = data['is_published']
            
            # Update geographic access fields (use hasattr for backward compatibility)
            if ('districtIds' in data or 'district_ids' in data) and hasattr(document, 'district_ids'):
                document.district_ids = data.get('districtIds') or data.get('district_ids') or None
            if ('mandalIds' in data or 'mandal_ids' in data) and hasattr(document, 'mandal_ids'):
                document.mandal_ids = data.get('mandalIds') or data.get('mandal_ids') or None
            if ('assemblyConstituencyIds' in data or 'assembly_constituency_ids' in data) and hasattr(document, 'assembly_constituency_ids'):
                document.assembly_constituency_ids = data.get('assemblyConstituencyIds') or data.get('assembly_constituency_ids') or None
            if ('parliamentaryConstituencyIds' in data or 'parliamentary_constituency_ids' in data) and hasattr(document, 'parliamentary_constituency_ids'):
                document.parliamentary_constituency_ids = data.get('parliamentaryConstituencyIds') or data.get('parliamentary_constituency_ids') or None
            
            document.updated_at = datetime.utcnow()
            db.session.commit()
            
            return document.to_dict()
            
        except HTTPException:
            # Re-raise HTTP exceptions (like abort) to preserve status codes
            raise
        except Exception as e:
            documents_ns.abort(400, str(e))
    
    @documents_ns.doc(
        security='Bearer',
        summary='Delete document',
        description='Deletes a document (admin/cadre only)',
        responses={
            200: 'Document deleted successfully',
            401: 'Authentication required',
            403: 'Admin or Cadre access required',
            404: 'Document not found',
            500: 'Internal server error'
        }
    )
    def delete(self, document_id):
        """Delete document (admin/cadre only)"""
        try:
            log_api_call(f'/api/documents/{document_id}', 'DELETE')
            
            # Verify JWT token first
            try:
                verify_jwt_in_request(optional=False)
            except Exception as e:
                documents_ns.abort(401, f'Authentication required: {str(e)}')
            
            # Check authentication and authorization
            current_user = get_current_user()
            if current_user.role not in [UserRole.ADMIN, UserRole.CADRE]:
                documents_ns.abort(403, 'Admin or Cadre access required')
            
            document = Document.query.get(document_id)
            if not document:
                documents_ns.abort(404, 'Document not found')
            
            # Optionally delete the file from storage
            # For now, we'll just delete the database record
            # TODO: Add file deletion from S3/local storage
            
            db.session.delete(document)
            db.session.commit()
            
            return {'message': 'Document deleted successfully'}, 200
            
        except HTTPException:
            # Re-raise HTTP exceptions (like abort) to preserve status codes
            raise
        except Exception as e:
            documents_ns.abort(500, str(e))

@documents_ns.route('/upload')
class DocumentUpload(Resource):
    @documents_ns.doc(
        security='Bearer',
        summary='Upload document file',
        description='Uploads a document file and returns the URL (admin/cadre only)',
        responses={
            200: 'File uploaded successfully',
            400: 'Validation error',
            401: 'Authentication required',
            403: 'Admin or Cadre access required',
            500: 'Internal server error'
        }
    )
    def post(self):
        """Upload document file (admin/cadre only)"""
        try:
            log_api_call('/api/documents/upload', 'POST')
            
            # Verify JWT token first
            try:
                verify_jwt_in_request(optional=False)
            except Exception as e:
                documents_ns.abort(401, f'Authentication required: {str(e)}')
            
            # Check authentication and authorization
            try:
                current_user = get_current_user()
                if current_user.role not in [UserRole.ADMIN, UserRole.CADRE]:
                    documents_ns.abort(403, 'Admin or Cadre access required')
            except Exception as e:
                if 'Authentication required' in str(e):
                    documents_ns.abort(401, str(e))
                else:
                    documents_ns.abort(403, 'Admin or Cadre access required')
            
            # Check if file is present
            if 'file' not in request.files:
                documents_ns.abort(400, 'No file provided')
            
            file = request.files['file']
            if file.filename == '':
                documents_ns.abort(400, 'No file selected')
            
            # Validate file type
            allowed_document_extensions = {'.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.txt', '.rtf', '.odt', '.ods', '.odp'}
            
            filename = secure_filename(file.filename)
            file_ext = os.path.splitext(filename)[1].lower()
            
            if file_ext not in allowed_document_extensions:
                documents_ns.abort(400, f'Invalid document format. Allowed: {", ".join(allowed_document_extensions)}')
            
            # Generate unique filename using IST
            from app.utils.timezone_utils import get_ist_now
            timestamp = get_ist_now().strftime('%Y%m%d_%H%M%S')
            unique_filename = f"{timestamp}_{uuid.uuid4().hex[:8]}{file_ext}"
            
            # Get file size before upload
            file.seek(0, os.SEEK_END)
            file_size = file.tell()
            file.seek(0)  # Reset to beginning
            
            # Upload to S3 or local storage
            folder = 'documents'
            s3_service = get_s3_service()
            file_url = s3_service.upload_file(file, unique_filename, folder)
            
            response = {
                'url': file_url,
                'filename': unique_filename,
                'file_size': file_size,
                'file_type': file_ext[1:] if file_ext.startswith('.') else file_ext,
                'message': 'File uploaded successfully'
            }
            
            return response, 200
            
        except HTTPException:
            # Re-raise HTTP exceptions (like abort) to preserve status codes
            raise
        except Exception as e:
            print(f"[ERROR] Document upload failed: {str(e)}")
            documents_ns.abort(500, f'Failed to upload file: {str(e)}')