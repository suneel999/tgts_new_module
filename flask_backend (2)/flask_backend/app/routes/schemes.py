"""
Schemes Routes — CRUD for government scheme information cards.
Admin: full CRUD + image upload. Public: list/get published schemes.
"""

import uuid
import os
from flask import request
from flask_restx import Namespace, Resource
from flask_jwt_extended import verify_jwt_in_request, get_jwt_identity
from werkzeug.utils import secure_filename
from werkzeug.exceptions import HTTPException

from app import db
from app.models.scheme import Scheme, SCHEME_CATEGORIES
from app.models import User, UserRole
from app.services.s3_service import get_s3_service

schemes_ns = Namespace('schemes', description='Government scheme information management')


def _require_admin():
    """Verify JWT and confirm the caller is an admin. Aborts 401/403 otherwise."""
    try:
        verify_jwt_in_request()
    except Exception:
        schemes_ns.abort(401, 'Authentication required')
    uid = get_jwt_identity()
    user = User.query.get(uid)
    if not user or user.role != UserRole.ADMIN:
        schemes_ns.abort(403, 'Admin access required')
    return user


def _optional_admin():
    """Return True if the request carries a valid admin JWT, False otherwise."""
    try:
        verify_jwt_in_request(optional=True)
        uid = get_jwt_identity()
        if uid:
            u = User.query.get(uid)
            return u and u.role == UserRole.ADMIN
    except Exception:
        pass
    return False


# ─── LIST / CREATE ────────────────────────────────────────────────────────────

@schemes_ns.route('/', strict_slashes=False)
class SchemeList(Resource):
    def get(self):
        """List schemes. ?all=true (admin only) returns unpublished as well."""
        try:
            all_flag = request.args.get('all', 'false').lower() == 'true'
            is_admin = _optional_admin()

            q = Scheme.query
            if not (is_admin and all_flag):
                q = q.filter_by(is_published=True)

            category = request.args.get('category')
            if category:
                q = q.filter_by(category=category)

            schemes = q.order_by(Scheme.created_at.desc()).all()
            return {'success': True, 'data': [s.to_dict() for s in schemes], 'total': len(schemes)}, 200
        except HTTPException:
            raise
        except Exception as e:
            return {'success': False, 'message': str(e)}, 500

    def post(self):
        """Create a new scheme. Admin only."""
        try:
            _require_admin()
            data = request.get_json()
            if not data:
                schemes_ns.abort(400, 'No JSON body provided')

            for field in ('title_en', 'title_te', 'description_en', 'description_te'):
                if not (data.get(field) or '').strip():
                    schemes_ns.abort(400, f'Field "{field}" is required')

            scheme = Scheme(
                id=str(uuid.uuid4()),
                title_en=data['title_en'].strip(),
                title_te=data['title_te'].strip(),
                description_en=data['description_en'].strip(),
                description_te=data['description_te'].strip(),
                category=(data.get('category') or 'welfare').strip(),
                image_url=(data.get('image_url') or '').strip() or None,
                eligibility_en=(data.get('eligibility_en') or '').strip() or None,
                eligibility_te=(data.get('eligibility_te') or '').strip() or None,
                benefits_en=(data.get('benefits_en') or '').strip() or None,
                benefits_te=(data.get('benefits_te') or '').strip() or None,
                apply_link=(data.get('apply_link') or '').strip() or None,
                is_published=bool(data.get('is_published', False)),
            )
            db.session.add(scheme)
            db.session.commit()
            return {'success': True, 'data': scheme.to_dict()}, 201
        except HTTPException:
            raise
        except Exception as e:
            db.session.rollback()
            return {'success': False, 'message': str(e)}, 500


# ─── GET / UPDATE / DELETE ────────────────────────────────────────────────────

@schemes_ns.route('/<string:scheme_id>', strict_slashes=False)
class SchemeDetail(Resource):
    def get(self, scheme_id):
        """Get one scheme by ID. Unpublished schemes are admin-only."""
        try:
            scheme = Scheme.query.get(scheme_id)
            if not scheme:
                return {'success': False, 'message': 'Scheme not found'}, 404
            if not scheme.is_published and not _optional_admin():
                return {'success': False, 'message': 'Scheme not found'}, 404
            return {'success': True, 'data': scheme.to_dict()}, 200
        except HTTPException:
            raise
        except Exception as e:
            return {'success': False, 'message': str(e)}, 500

    def put(self, scheme_id):
        """Update a scheme. Admin only."""
        try:
            _require_admin()
            scheme = Scheme.query.get(scheme_id)
            if not scheme:
                return {'success': False, 'message': 'Scheme not found'}, 404

            data = request.get_json() or {}
            text_fields = [
                'title_en', 'title_te', 'description_en', 'description_te',
                'category', 'image_url', 'eligibility_en', 'eligibility_te',
                'benefits_en', 'benefits_te', 'apply_link',
            ]
            for f in text_fields:
                if f in data:
                    val = (data[f] or '').strip()
                    setattr(scheme, f, val or None)

            if 'is_published' in data:
                scheme.is_published = bool(data['is_published'])

            db.session.commit()
            return {'success': True, 'data': scheme.to_dict()}, 200
        except HTTPException:
            raise
        except Exception as e:
            db.session.rollback()
            return {'success': False, 'message': str(e)}, 500

    def delete(self, scheme_id):
        """Delete a scheme. Admin only."""
        try:
            _require_admin()
            scheme = Scheme.query.get(scheme_id)
            if not scheme:
                return {'success': False, 'message': 'Scheme not found'}, 404
            db.session.delete(scheme)
            db.session.commit()
            return {'success': True, 'message': 'Scheme deleted'}, 200
        except HTTPException:
            raise
        except Exception as e:
            db.session.rollback()
            return {'success': False, 'message': str(e)}, 500


# ─── IMAGE UPLOAD ─────────────────────────────────────────────────────────────

@schemes_ns.route('/upload-image', strict_slashes=False)
class SchemeImageUpload(Resource):
    def post(self):
        """Upload a scheme banner image. Admin only. Returns the image URL."""
        try:
            _require_admin()
            if 'file' not in request.files:
                return {'success': False, 'message': 'No file provided'}, 400

            file = request.files['file']
            if not file.filename:
                return {'success': False, 'message': 'No file selected'}, 400

            allowed_exts = {'.jpg', '.jpeg', '.png', '.webp', '.gif'}
            filename = secure_filename(file.filename)
            ext = os.path.splitext(filename)[1].lower()
            if ext not in allowed_exts:
                return {
                    'success': False,
                    'message': f'Invalid image type. Allowed: {", ".join(sorted(allowed_exts))}',
                }, 400

            from app.utils.timezone_utils import get_ist_now
            timestamp = get_ist_now().strftime('%Y%m%d_%H%M%S')
            unique_name = f"{timestamp}_{uuid.uuid4().hex[:8]}{ext}"

            s3 = get_s3_service()
            url = s3.upload_file(file, unique_name, 'schemes')
            return {'success': True, 'url': url}, 200
        except HTTPException:
            raise
        except Exception as e:
            return {'success': False, 'message': str(e)}, 500


# ─── CATEGORIES ───────────────────────────────────────────────────────────────

@schemes_ns.route('/categories', strict_slashes=False)
class SchemeCategoriesList(Resource):
    def get(self):
        """Return the list of valid scheme categories."""
        return {'success': True, 'data': SCHEME_CATEGORIES}, 200
