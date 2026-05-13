"""
Voter List Routes for Telangana Congress Communication App
Handles voter data upload (CSV/PDF), filtering, and management.
"""

import os
import io
from collections import defaultdict
from flask import request
from flask_restx import Namespace, Resource
from flask_jwt_extended import verify_jwt_in_request
from sqlalchemy import func, or_
from app.models.voter import Voter
from app import db
from app.utils.auth_utils import require_admin

voter_list_ns = Namespace('voter-list', description='Voter list management')

# Maps common CSV column header variations to canonical model field names
COLUMN_ALIASES = {
    'serial_no':       ['serial_no', 'sl_no', 'sr no', 'serial', 'sno', 'slno', 'sr.no'],
    'voter_name':      ['voter_name', 'name', 'voter name', 'full name', 'voternm'],
    'relative_type':   ['relative_type', 'relation', 'rel_type'],
    'relative_name':   ['relative_name', "father's name", "husband's name", 'f/h name',
                        'father_husband_name', 'relative name', 'reln_name'],
    'house_number':    ['house_number', 'house no', 'door no', 'house_no', 'hhno'],
    'age':             ['age', 'age (years)'],
    'date_of_birth':   ['date_of_birth', 'dob', 'birth date', 'date of birth'],
    'gender':          ['gender', 'sex'],
    'voter_id_number': ['voter_id_number', 'voter_id_card', 'epic', 'voter id',
                        'id card no', 'epicno', 'voter_id'],
    'part_number':     ['part_number', 'part no', 'part_no', 'partno'],
    'booth_number':    ['booth_number', 'booth_no', 'booth number', 'booth',
                        'polling station', 'boothno'],
    'booth_name':      ['booth_name', 'booth_nm', 'polling station name'],
    'address':         ['address', 'addr', 'full_address'],
    'phone':           ['phone', 'phone_no', 'mobile', 'contact no', 'mob no', 'phone no'],
    'caste':           ['caste', 'community', 'religion'],
    'color':           ['color', 'party color', 'colour'],
}


def _normalize_columns(df):
    rename_map = {}
    for canonical, aliases in COLUMN_ALIASES.items():
        for col in df.columns:
            if col.strip().lower() in aliases:
                rename_map[col] = canonical
    return df.rename(columns=rename_map)


def _mark_duplicates():
    """Detect voters with the same voter_id_number as duplicates."""
    Voter.query.update({'is_duplicate': False})
    db.session.commit()

    voters = Voter.query.filter(
        Voter.voter_id_number.isnot(None),
        Voter.voter_id_number != ''
    ).all()

    groups = defaultdict(list)
    for v in voters:
        key = v.voter_id_number.strip().upper()
        if key:
            groups[key].append(v.id)

    dup_ids = set()
    for ids in groups.values():
        if len(ids) > 1:
            dup_ids.update(ids)

    if dup_ids:
        Voter.query.filter(Voter.id.in_(list(dup_ids))).update(
            {'is_duplicate': True}, synchronize_session='fetch'
        )
        db.session.commit()

    return len(dup_ids)


@voter_list_ns.route('/', strict_slashes=False)
class VoterListResource(Resource):
    def get(self):
        """List voters with optional filters and pagination."""
        try:
            q = Voter.query

            search = request.args.get('search')
            if search:
                like = f'%{search}%'
                q = q.filter(or_(
                    Voter.voter_name.ilike(like),
                    Voter.address.ilike(like),
                    Voter.serial_no.ilike(like),
                    Voter.voter_id_number.ilike(like),
                ))

            booth = request.args.get('booth_number')
            if booth:
                q = q.filter(Voter.booth_number == booth)

            caste = request.args.get('caste')
            if caste:
                q = q.filter(Voter.caste.ilike(f'%{caste}%'))

            color = request.args.get('color')
            if color:
                q = q.filter(Voter.color.ilike(color))

            gender = request.args.get('gender')
            if gender:
                q = q.filter(Voter.gender.ilike(gender))

            age_min = request.args.get('age_min', type=int)
            age_max = request.args.get('age_max', type=int)
            if age_min is not None:
                q = q.filter(Voter.age >= age_min)
            if age_max is not None:
                q = q.filter(Voter.age <= age_max)

            has_phone = request.args.get('has_phone')
            if has_phone == 'true':
                q = q.filter(Voter.phone != None, Voter.phone != '')

            for flag, col in [
                ('is_effective', Voter.is_effective),
                ('is_duplicate', Voter.is_duplicate),
                ('is_beneficiary', Voter.is_beneficiary),
                ('has_voted', Voter.has_voted),
            ]:
                val = request.args.get(flag)
                if val == 'true':
                    q = q.filter(col == True)
                elif val == 'false':
                    q = q.filter(col == False)

            sort_by = request.args.get('sort_by', 'serial')
            sort_order = request.args.get('sort_order', 'asc')
            sort_map = {
                'name':    Voter.voter_name,
                'age':     Voter.age,
                'booth':   Voter.booth_number,
                'address': Voter.address,
                'phone':   Voter.phone,
                'caste':   Voter.caste,
                'color':   Voter.color,
                'serial':  Voter.serial_no,
            }
            sort_col = sort_map.get(sort_by, Voter.serial_no)
            q = q.order_by(sort_col.desc() if sort_order == 'desc' else sort_col)

            page = request.args.get('page', 1, type=int)
            per_page = request.args.get('per_page', 100, type=int)
            paginated = q.paginate(page=page, per_page=per_page, error_out=False)

            return {
                'success': True,
                'data': [v.to_dict() for v in paginated.items],
                'total': paginated.total,
                'page': paginated.page,
                'per_page': per_page,
                'total_pages': paginated.pages,
            }, 200
        except Exception as e:
            return {'success': False, 'message': str(e)}, 500


@voter_list_ns.route('/stats', strict_slashes=False)
class VoterStatsResource(Resource):
    def get(self):
        """Summary statistics for the voter list."""
        try:
            total = Voter.query.count()
            duplicates = Voter.query.filter_by(is_duplicate=True).count()
            beneficiaries = Voter.query.filter_by(is_beneficiary=True).count()
            voted = Voter.query.filter_by(has_voted=True).count()
            effective = Voter.query.filter_by(is_effective=True).count()
            with_phone = Voter.query.filter(Voter.phone != None, Voter.phone != '').count()
            male = Voter.query.filter(Voter.gender.ilike('male')).count()
            female = Voter.query.filter(Voter.gender.ilike('female')).count()

            color_rows = db.session.query(
                Voter.color, func.count(Voter.id).label('cnt')
            ).group_by(Voter.color).all()
            colors = {(r.color or 'white'): r.cnt for r in color_rows}

            caste_rows = db.session.query(
                Voter.caste, func.count(Voter.id).label('cnt')
            ).filter(Voter.caste != None, Voter.caste != '').group_by(Voter.caste)\
             .order_by(func.count(Voter.id).desc()).limit(10).all()
            top_castes = [{'caste': r.caste, 'count': r.cnt} for r in caste_rows]

            return {
                'success': True,
                'total': total,
                'duplicates': duplicates,
                'beneficiaries': beneficiaries,
                'voted': voted,
                'nonVoted': total - voted,
                'effective': effective,
                'withPhone': with_phone,
                'male': male,
                'female': female,
                'colors': colors,
                'topCastes': top_castes,
            }, 200
        except Exception as e:
            return {'success': False, 'message': str(e)}, 500


@voter_list_ns.route('/booths', strict_slashes=False)
class VoterBoothsResource(Resource):
    def get(self):
        """Return distinct booths with voter counts."""
        try:
            rows = db.session.query(
                Voter.booth_number,
                Voter.booth_name,
                func.count(Voter.id).label('cnt')
            ).filter(Voter.booth_number != None, Voter.booth_number != '')\
             .group_by(Voter.booth_number, Voter.booth_name)\
             .order_by(Voter.booth_number).all()

            return {
                'data': [
                    {'boothNumber': r.booth_number, 'boothName': r.booth_name or '', 'count': r.cnt}
                    for r in rows
                ]
            }, 200
        except Exception as e:
            return {'success': False, 'message': str(e)}, 500


@voter_list_ns.route('/castes', strict_slashes=False)
class VoterCastesResource(Resource):
    def get(self):
        """Return distinct castes with voter counts."""
        try:
            rows = db.session.query(
                Voter.caste, func.count(Voter.id).label('cnt')
            ).filter(Voter.caste != None, Voter.caste != '')\
             .group_by(Voter.caste).order_by(Voter.caste).all()

            return {
                'data': [{'caste': r.caste, 'count': r.cnt} for r in rows]
            }, 200
        except Exception as e:
            return {'success': False, 'message': str(e)}, 500


@voter_list_ns.route('/upload', strict_slashes=False)
class VoterUploadResource(Resource):
    def post(self):
        """Upload a CSV or PDF voter list file."""
        try:
            import pandas as pd
            import pdfplumber
        except ImportError as e:
            return {'success': False, 'message': f'Missing dependency: {e}. Run: pip install pandas pdfplumber'}, 500

        try:
            if 'file' not in request.files:
                return {'success': False, 'message': 'No file provided'}, 400

            f = request.files['file']
            replace_all = request.form.get('replace_all', 'false').lower() == 'true'
            ext = os.path.splitext(f.filename)[1].lower()
            batch_id = f.filename

            try:
                raw = f.read()
                if ext == '.csv':
                    df = _normalize_columns(pd.read_csv(io.BytesIO(raw)))
                elif ext == '.pdf':
                    rows = []
                    with pdfplumber.open(io.BytesIO(raw)) as pdf:
                        for page in pdf.pages:
                            table = page.extract_table()
                            if table:
                                rows.extend(table)
                    if not rows:
                        return {'success': False, 'message': 'No tables found in PDF'}, 422
                    header = [str(h).strip().lower() if h else '' for h in rows[0]]
                    df = _normalize_columns(pd.DataFrame(rows[1:], columns=header))
                else:
                    return {'success': False, 'message': 'Only CSV or PDF files are supported'}, 400
            except Exception as e:
                return {'success': False, 'message': f'File parse error: {str(e)}'}, 422

            if replace_all:
                Voter.query.delete()
                db.session.commit()

            imported = 0
            skipped = 0
            errors = []

            for idx, row in df.iterrows():
                voter_name = str(row.get('voter_name', '')).strip()
                if not voter_name or voter_name.lower() in ('nan', ''):
                    skipped += 1
                    continue

                if not replace_all:
                    existing = Voter.query.filter_by(
                        voter_name=voter_name,
                        serial_no=str(row.get('serial_no', '')).strip(),
                        upload_batch_id=batch_id
                    ).first()
                    if existing:
                        skipped += 1
                        continue

                age_raw = row.get('age', None)
                try:
                    age = int(float(str(age_raw))) if age_raw not in (None, '') else None
                except (ValueError, TypeError):
                    age = None

                voter = Voter(
                    upload_batch_id=batch_id,
                    serial_no=str(row.get('serial_no', '')).strip(),
                    voter_name=voter_name,
                    relative_type=str(row.get('relative_type', '')).strip(),
                    relative_name=str(row.get('relative_name', '')).strip(),
                    house_number=str(row.get('house_number', '')).strip(),
                    age=age,
                    date_of_birth=str(row.get('date_of_birth', '')).strip(),
                    gender=str(row.get('gender', '')).strip(),
                    voter_id_number=str(row.get('voter_id_number', '')).strip(),
                    part_number=str(row.get('part_number', '')).strip(),
                    booth_number=str(row.get('booth_number', '')).strip(),
                    booth_name=str(row.get('booth_name', '')).strip(),
                    address=str(row.get('address', '')).strip(),
                    phone=str(row.get('phone', '')).strip(),
                    caste=str(row.get('caste', '')).strip(),
                    color=str(row.get('color', 'white')).strip().lower() or 'white',
                )
                db.session.add(voter)
                imported += 1

            db.session.commit()
            dup_count = _mark_duplicates()

            return {
                'success': True,
                'message': f'Imported {imported} voters, skipped {skipped}. Detected {dup_count} duplicates.',
                'batchId': batch_id,
                'imported': imported,
                'skipped': skipped,
                'errors': errors,
                'replaceAll': replace_all,
            }, 200
        except Exception as e:
            db.session.rollback()
            return {'success': False, 'message': str(e)}, 500


@voter_list_ns.route('/<int:voter_id>', strict_slashes=False)
class VoterDetailResource(Resource):
    def put(self, voter_id):
        """Update color, caste, phone, flags on a single voter."""
        try:
            voter = Voter.query.get(voter_id)
            if not voter:
                return {'success': False, 'message': 'Voter not found'}, 404

            data = request.get_json() or {}
            field_map = {
                'color': 'color',
                'caste': 'caste',
                'phone': 'phone',
                'isBeneficiary': 'is_beneficiary',
                'beneficiaryScheme': 'beneficiary_scheme',
                'voterParty': 'voter_party',
                'hasVoted': 'has_voted',
                'isEffective': 'is_effective',
                'isDuplicate': 'is_duplicate',
            }
            for json_key, model_attr in field_map.items():
                if json_key in data:
                    setattr(voter, model_attr, data[json_key])

            db.session.commit()
            return {'success': True, 'data': voter.to_dict()}, 200
        except Exception as e:
            db.session.rollback()
            return {'success': False, 'message': str(e)}, 500


@voter_list_ns.route('/batch/<string:batch_id>', strict_slashes=False)
class VoterBatchResource(Resource):
    def delete(self, batch_id):
        """Delete all voters belonging to a specific upload batch."""
        try:
            deleted = Voter.query.filter_by(upload_batch_id=batch_id).delete()
            db.session.commit()
            return {'deleted': deleted}, 200
        except Exception as e:
            db.session.rollback()
            return {'success': False, 'message': str(e)}, 500


@voter_list_ns.route('/clear', strict_slashes=False)
class VoterClearResource(Resource):
    def delete(self):
        """Delete every voter record from the database."""
        try:
            deleted = Voter.query.delete()
            db.session.commit()
            return {'deleted': deleted}, 200
        except Exception as e:
            db.session.rollback()
            return {'success': False, 'message': str(e)}, 500


@voter_list_ns.route('/batches', strict_slashes=False)
class VoterBatchListResource(Resource):
    def get(self):
        """List all upload batches with voter counts and upload timestamps."""
        try:
            rows = db.session.query(
                Voter.upload_batch_id,
                func.count(Voter.id).label('cnt'),
                func.min(Voter.created_at).label('uploaded_at'),
            ).group_by(Voter.upload_batch_id)\
             .order_by(func.min(Voter.created_at).desc()).all()

            return {
                'success': True,
                'data': [
                    {
                        'batchId': r.upload_batch_id or '',
                        'count': r.cnt,
                        'uploadedAt': r.uploaded_at.isoformat() if r.uploaded_at else None,
                    }
                    for r in rows
                ],
            }, 200
        except Exception as e:
            return {'success': False, 'message': str(e)}, 500


@voter_list_ns.route('/compare', strict_slashes=False)
class VoterCompareResource(Resource):
    def get(self):
        """Compare two upload batches and return added/removed voter lists."""
        try:
            batch_old = request.args.get('batch_old', '').strip()
            batch_new = request.args.get('batch_new', '').strip()

            if not batch_old or not batch_new:
                return {'success': False, 'message': 'batch_old and batch_new params are required'}, 400

            old_voters = [
                v for v in Voter.query.filter_by(upload_batch_id=batch_old).all()
                if (v.voter_id_number or '').strip()
            ]
            new_voters = [
                v for v in Voter.query.filter_by(upload_batch_id=batch_new).all()
                if (v.voter_id_number or '').strip()
            ]

            def _key(v):
                return v.voter_id_number.strip().upper()

            old_map = {_key(v): v for v in old_voters}
            new_map = {_key(v): v for v in new_voters}

            old_keys     = set(old_map.keys())
            new_keys     = set(new_map.keys())
            added_keys   = new_keys - old_keys
            deleted_keys = old_keys - new_keys
            common_keys  = new_keys & old_keys

            return {
                'success': True,
                'oldBatch':        batch_old,
                'newBatch':        batch_new,
                'oldCount':        len(old_voters),
                'newCount':        len(new_voters),
                'addedCount':      len(added_keys),
                'deletedCount':    len(deleted_keys),
                'duplicatedCount': len(common_keys),
                'added':       [new_map[k].to_dict() for k in added_keys],
                'deleted':     [old_map[k].to_dict() for k in deleted_keys],
                'duplicated':  [new_map[k].to_dict() for k in common_keys],
            }, 200
        except Exception as e:
            return {'success': False, 'message': str(e)}, 500
