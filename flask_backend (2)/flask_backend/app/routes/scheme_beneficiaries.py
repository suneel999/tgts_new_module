"""
Scheme Beneficiaries Routes
Handles upload and retrieval of government scheme beneficiary data:
  - Maha Lakshmi, Cheyutha, Rythu Bharosa, Indiramma Indlu
"""

import os
import io
import traceback
from flask import request
from flask_restx import Namespace, Resource
from flask_jwt_extended import verify_jwt_in_request, get_jwt_identity
from sqlalchemy import func, or_
from app.models.scheme_beneficiary import SchemeBeneficiary, VALID_SCHEMES, SCHEME_DISPLAY_NAMES
from app.models import User, UserRole
from app import db

scheme_beneficiaries_ns = Namespace(
    'scheme-beneficiaries',
    description='Government scheme beneficiary data management',
)

# CSV column aliases → canonical field names
_COL_ALIASES = {
    'name':       ['name', 'beneficiary name', 'applicant name', 'full name', 'beneficiary_name'],
    'phone':      ['phone', 'mobile', 'phone_no', 'mobile_no', 'contact', 'contact no'],
    'address':    ['address', 'addr', 'full address', 'full_address'],
    'village':    ['village', 'gram', 'grama', 'village_name'],
    'mandal':     ['mandal', 'mandal_name', 'mandal name'],
    'district':   ['district', 'dist', 'district_name', 'district name'],
    'aadhar_no':  ['aadhar_no', 'aadhar', 'aadhaar', 'aadhar number', 'uid', 'aadhar no'],
    'account_no': ['account_no', 'account', 'bank account', 'account number', 'acc_no', 'account no'],
    'amount':     ['amount', 'scheme amount', 'benefit amount', 'sanctioned amount', 'amt'],
}


def _normalize_columns(df):
    rename_map = {}
    for canonical, aliases in _COL_ALIASES.items():
        for col in df.columns:
            if col.strip().lower() in aliases:
                rename_map[col] = canonical
    return df.rename(columns=rename_map)


def _str(val):
    if val is None:
        return ''
    import pandas as pd
    if pd.isna(val):
        return ''
    return str(val).strip()


@scheme_beneficiaries_ns.route('/', strict_slashes=False)
class SchemeBeneficiaryList(Resource):
    def get(self):
        """List scheme beneficiaries with optional filters and pagination."""
        try:
            q = SchemeBeneficiary.query

            scheme = request.args.get('scheme_name')
            if scheme:
                q = q.filter(SchemeBeneficiary.scheme_name == scheme)

            search = request.args.get('search')
            if search:
                like = f'%{search}%'
                q = q.filter(or_(
                    SchemeBeneficiary.name.ilike(like),
                    SchemeBeneficiary.phone.ilike(like),
                    SchemeBeneficiary.address.ilike(like),
                    SchemeBeneficiary.mandal.ilike(like),
                    SchemeBeneficiary.district.ilike(like),
                    SchemeBeneficiary.aadhar_no.ilike(like),
                ))

            mandal = request.args.get('mandal')
            if mandal:
                q = q.filter(SchemeBeneficiary.mandal.ilike(f'%{mandal}%'))

            district = request.args.get('district')
            if district:
                q = q.filter(SchemeBeneficiary.district.ilike(f'%{district}%'))

            sort_by = request.args.get('sort_by', 'name')
            sort_map = {
                'name':     SchemeBeneficiary.name,
                'mandal':   SchemeBeneficiary.mandal,
                'district': SchemeBeneficiary.district,
                'amount':   SchemeBeneficiary.amount,
                'created':  SchemeBeneficiary.created_at,
            }
            sort_col = sort_map.get(sort_by, SchemeBeneficiary.name)
            q = q.order_by(sort_col.asc())

            total = q.count()

            page     = max(1, int(request.args.get('page',     1)))
            per_page = min(500, max(1, int(request.args.get('per_page', 50))))
            total_pages = max(1, (total + per_page - 1) // per_page)

            items = q.offset((page - 1) * per_page).limit(per_page).all()

            return {
                'success':     True,
                'data':        [i.to_dict() for i in items],
                'total':       total,
                'page':        page,
                'per_page':    per_page,
                'total_pages': total_pages,
            }, 200

        except Exception as e:
            return {'success': False, 'message': str(e)}, 500


@scheme_beneficiaries_ns.route('/schemes', strict_slashes=False)
class SchemeSummary(Resource):
    def get(self):
        """Return each scheme with its beneficiary count."""
        try:
            rows = (
                db.session.query(SchemeBeneficiary.scheme_name, func.count(SchemeBeneficiary.id))
                .group_by(SchemeBeneficiary.scheme_name)
                .all()
            )
            counts = {r[0]: r[1] for r in rows}
            data = [
                {
                    'schemeName':    s,
                    'displayName':   SCHEME_DISPLAY_NAMES[s],
                    'count':         counts.get(s, 0),
                }
                for s in VALID_SCHEMES
            ]
            return {'success': True, 'data': data}, 200
        except Exception as e:
            return {'success': False, 'message': str(e)}, 500


@scheme_beneficiaries_ns.route('/batches', strict_slashes=False)
class SchemeBatches(Resource):
    def get(self):
        """List all upload batches with scheme name, count, and date."""
        try:
            scheme = request.args.get('scheme_name')
            q = db.session.query(
                SchemeBeneficiary.upload_batch_id,
                SchemeBeneficiary.scheme_name,
                func.count(SchemeBeneficiary.id).label('count'),
                func.max(SchemeBeneficiary.created_at).label('uploaded_at'),
            ).group_by(SchemeBeneficiary.upload_batch_id, SchemeBeneficiary.scheme_name)
            if scheme:
                q = q.filter(SchemeBeneficiary.scheme_name == scheme)
            rows = q.order_by(func.max(SchemeBeneficiary.created_at).desc()).all()

            from app.utils.timezone_utils import ensure_ist_aware, format_ist_iso
            data = [
                {
                    'batchId':      r.upload_batch_id,
                    'schemeName':   r.scheme_name,
                    'displayName':  SCHEME_DISPLAY_NAMES.get(r.scheme_name, r.scheme_name),
                    'count':        r.count,
                    'uploadedAt':   format_ist_iso(ensure_ist_aware(r.uploaded_at)) if r.uploaded_at else None,
                }
                for r in rows
            ]
            return {'success': True, 'data': data}, 200
        except Exception as e:
            return {'success': False, 'message': str(e)}, 500


@scheme_beneficiaries_ns.route('/upload', strict_slashes=False)
class SchemeBeneficiaryUpload(Resource):
    def post(self):
        """Upload a CSV or Excel file of beneficiaries for a given scheme. Admin only."""
        # ── Auth (outside try so JWT errors return 401, not 500) ──────────────
        try:
            verify_jwt_in_request()
        except Exception as auth_err:
            return {'success': False, 'message': f'Authentication required: {str(auth_err)}'}, 401

        try:
            uid = get_jwt_identity()
            user = User.query.get(uid)
            if not user or user.role != UserRole.ADMIN:
                return {'success': False, 'message': 'Admin access required'}, 403
        except Exception as e:
            return {'success': False, 'message': f'Authorization error: {str(e)}'}, 403

        # ── Upload logic ──────────────────────────────────────────────────────
        try:
            import pandas as pd

            scheme_name = (request.form.get('scheme_name') or '').strip().lower()
            if scheme_name not in VALID_SCHEMES:
                return {
                    'success': False,
                    'message': f'Invalid scheme_name. Must be one of: {", ".join(VALID_SCHEMES)}',
                }, 400

            if 'file' not in request.files:
                return {'success': False, 'message': 'No file provided.'}, 400

            f = request.files['file']
            if not f or not f.filename:
                return {'success': False, 'message': 'Empty file.'}, 400

            filename = f.filename
            batch_id = os.path.splitext(filename)[0][:200]  # respect column length

            replace_all = (request.form.get('replace_all') or 'false').lower() == 'true'
            if replace_all:
                SchemeBeneficiary.query.filter_by(scheme_name=scheme_name).delete()
                db.session.commit()

            content = f.read()
            ext = os.path.splitext(filename)[1].lower()

            if ext in ('.xlsx', '.xls'):
                df = pd.read_excel(io.BytesIO(content), dtype=str)
            elif ext == '.csv':
                df = pd.read_csv(
                    io.StringIO(content.decode('utf-8', errors='replace')),
                    dtype=str,
                )
            else:
                return {'success': False, 'message': 'Unsupported file type. Use CSV or Excel (.csv/.xlsx/.xls).'}, 400

            df.columns = [str(c).strip().lower() for c in df.columns]
            df = _normalize_columns(df)
            df = df.fillna('')

            if 'name' not in df.columns:
                return {
                    'success': False,
                    'message': f'File must have a "name" column. Columns found: {", ".join(df.columns.tolist())}',
                }, 400

            imported = 0
            errors   = []

            for idx, row in df.iterrows():
                name = _str(row.get('name', ''))
                if not name:
                    errors.append({'row': idx + 2, 'error': 'Missing name'})
                    continue
                b = SchemeBeneficiary(
                    scheme_name     = scheme_name,
                    upload_batch_id = batch_id,
                    name            = name,
                    phone           = _str(row.get('phone', '')),
                    address         = _str(row.get('address', '')),
                    village         = _str(row.get('village', '')),
                    mandal          = _str(row.get('mandal', '')),
                    district        = _str(row.get('district', '')),
                    aadhar_no       = _str(row.get('aadhar_no', '')),
                    account_no      = _str(row.get('account_no', '')),
                    amount          = _str(row.get('amount', '')),
                )
                db.session.add(b)
                imported += 1

                if imported % 500 == 0:
                    db.session.flush()

            db.session.commit()

            return {
                'success':  True,
                'message':  f'Imported {imported} beneficiaries for {SCHEME_DISPLAY_NAMES[scheme_name]}.',
                'batchId':  batch_id,
                'imported': imported,
                'skipped':  len(errors),
                'errors':   errors[:20],
            }, 200

        except Exception as e:
            db.session.rollback()
            tb = traceback.format_exc()
            print(f'[ERROR] Scheme beneficiary upload failed:\n{tb}')
            return {'success': False, 'message': f'Upload failed: {str(e)}'}, 500


@scheme_beneficiaries_ns.route('/batch/<string:batch_id>', strict_slashes=False)
class SchemeBatchDelete(Resource):
    def delete(self, batch_id):
        """Delete all beneficiaries in a batch. Admin only."""
        try:
            verify_jwt_in_request()
            require_admin()
            deleted = SchemeBeneficiary.query.filter_by(upload_batch_id=batch_id).delete()
            db.session.commit()
            return {'success': True, 'deleted': deleted}, 200
        except Exception as e:
            db.session.rollback()
            return {'success': False, 'message': str(e)}, 500


@scheme_beneficiaries_ns.route('/scheme/<string:scheme_name>/clear', strict_slashes=False)
class SchemeDataClear(Resource):
    def delete(self, scheme_name):
        """Delete all beneficiaries for a scheme. Admin only."""
        try:
            verify_jwt_in_request()
            require_admin()
            if scheme_name not in VALID_SCHEMES:
                return {'success': False, 'message': 'Invalid scheme name.'}, 400
            deleted = SchemeBeneficiary.query.filter_by(scheme_name=scheme_name).delete()
            db.session.commit()
            return {'success': True, 'deleted': deleted}, 200
        except Exception as e:
            db.session.rollback()
            return {'success': False, 'message': str(e)}, 500
