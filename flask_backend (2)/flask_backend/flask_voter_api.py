"""
Flask Backend — Voter Mapping API
Handles CSV/PDF upload, voter filtering, duplicate/vote-theft detection
"""

import os, io, re, json
from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import or_, and_
import pandas as pd
import pdfplumber

app = Flask(__name__)
CORS(app)

# ─── CONFIG ──────────────────────────────────────────────────────────────────
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('DATABASE_URL', 'sqlite:///voters.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['MAX_CONTENT_LENGTH'] = 50 * 1024 * 1024  # 50 MB
db = SQLAlchemy(app)

UPLOAD_FOLDER = 'uploads'
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# ─── MODELS ──────────────────────────────────────────────────────────────────

class Voter(db.Model):
    __tablename__ = 'voters'
    id              = db.Column(db.Integer, primary_key=True)
    serial_no       = db.Column(db.String(20))
    name            = db.Column(db.String(200), nullable=False)
    father_husband_name = db.Column(db.String(200))
    age             = db.Column(db.Integer)
    gender          = db.Column(db.String(10))
    address         = db.Column(db.Text)
    booth_no        = db.Column(db.String(20))
    caste           = db.Column(db.String(100))
    phone_no        = db.Column(db.String(20))
    color           = db.Column(db.String(20), default='white')   # party color
    is_duplicate    = db.Column(db.Boolean, default=False)
    is_effective    = db.Column(db.Boolean, default=True)
    voter_id_card   = db.Column(db.String(50))                     # EPIC number
    upload_batch    = db.Column(db.String(50))                     # which upload

    def to_dict(self):
        return {
            'id': self.id,
            'serial_no': self.serial_no,
            'name': self.name,
            'father_husband_name': self.father_husband_name,
            'age': self.age,
            'gender': self.gender,
            'address': self.address,
            'booth_no': self.booth_no,
            'caste': self.caste,
            'phone_no': self.phone_no or '',
            'color': self.color,
            'is_duplicate': self.is_duplicate,
            'is_effective': self.is_effective,
            'voter_id_card': self.voter_id_card or '',
        }

with app.app_context():
    db.create_all()

# ─── HELPERS ─────────────────────────────────────────────────────────────────

COLUMN_ALIASES = {
    'serial_no':    ['serial_no', 'sl_no', 'sr no', 'serial', 'sno', 'क्र.सं'],
    'name':         ['name', 'voter name', 'full name', 'नाम'],
    'father_husband_name': ['father_husband_name', "father's name", "husband's name", 'f/h name', 'relative name'],
    'age':          ['age', 'उम्र', 'age (years)'],
    'gender':       ['gender', 'sex', 'लिंग'],
    'address':      ['address', 'addr', 'house no', 'door no', 'पता'],
    'booth_no':     ['booth_no', 'booth number', 'booth', 'polling station'],
    'caste':        ['caste', 'community', 'religion', 'जाति'],
    'phone_no':     ['phone_no', 'phone', 'mobile', 'contact no', 'mob no'],
    'voter_id_card':['voter_id_card', 'epic', 'voter id', 'id card no'],
    'color':        ['color', 'party color', 'colour'],
}

def _normalize_columns(df: pd.DataFrame) -> pd.DataFrame:
    """Map arbitrary column names in uploaded CSV to our canonical names."""
    rename_map = {}
    for canonical, aliases in COLUMN_ALIASES.items():
        for col in df.columns:
            if col.strip().lower() in aliases:
                rename_map[col] = canonical
    return df.rename(columns=rename_map)


def _extract_csv(file_bytes: bytes) -> pd.DataFrame:
    return _normalize_columns(pd.read_csv(io.BytesIO(file_bytes)))


def _extract_pdf(file_bytes: bytes) -> pd.DataFrame:
    """Extract tabular voter data from a PDF using pdfplumber."""
    rows = []
    with pdfplumber.open(io.BytesIO(file_bytes)) as pdf:
        for page in pdf.pages:
            table = page.extract_table()
            if table:
                rows.extend(table)
    if not rows:
        raise ValueError("No tables found in PDF")
    header = [str(h).strip().lower() if h else '' for h in rows[0]]
    df = pd.DataFrame(rows[1:], columns=header)
    return _normalize_columns(df)


def _mark_duplicates():
    """Detect voters with the same voter_id_card as duplicates."""
    Voter.query.update({'is_duplicate': False})
    db.session.commit()

    voters = Voter.query.filter(
        Voter.voter_id_card.isnot(None),
        Voter.voter_id_card != ''
    ).all()

    from collections import defaultdict
    groups = defaultdict(list)
    for v in voters:
        key = v.voter_id_card.strip().upper()
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


# ─── ROUTES ───────────────────────────────────────────────────────────────────

@app.route('/api/health')
def health():
    return jsonify({'status': 'ok'})


# ── UPLOAD (Admin → Flutter data source) ─────────────────────────────────────

@app.route('/api/upload', methods=['POST'])
def upload_voters():
    """
    Accept CSV or PDF from admin panel.
    Parses, normalises, stores voters, then runs duplicate detection.
    """
    if 'file' not in request.files:
        return jsonify({'error': 'No file part'}), 400

    f = request.files['file']
    ext = os.path.splitext(f.filename)[1].lower()
    batch_id = f.filename  # use filename as batch identifier

    try:
        raw = f.read()
        if ext == '.csv':
            df = _extract_csv(raw)
        elif ext == '.pdf':
            df = _extract_pdf(raw)
        else:
            return jsonify({'error': 'Only CSV or PDF supported'}), 400
    except Exception as e:
        return jsonify({'error': f'Parse error: {str(e)}'}), 422

    inserted = 0
    skipped  = 0
    for _, row in df.iterrows():
        name = str(row.get('name', '')).strip()
        if not name or name.lower() in ('nan', ''):
            skipped += 1
            continue

        # Avoid exact duplicates within same batch
        existing = Voter.query.filter_by(
            name=name,
            serial_no=str(row.get('serial_no', '')).strip(),
            upload_batch=batch_id
        ).first()
        if existing:
            skipped += 1
            continue

        age_raw = row.get('age', 0)
        try:
            age = int(float(str(age_raw)))
        except (ValueError, TypeError):
            age = 0

        voter = Voter(
            serial_no=str(row.get('serial_no', '')).strip(),
            name=name,
            father_husband_name=str(row.get('father_husband_name', '')).strip(),
            age=age,
            gender=str(row.get('gender', '')).strip(),
            address=str(row.get('address', '')).strip(),
            booth_no=str(row.get('booth_no', '')).strip(),
            caste=str(row.get('caste', '')).strip(),
            phone_no=str(row.get('phone_no', '')).strip(),
            voter_id_card=str(row.get('voter_id_card', '')).strip(),
            color=str(row.get('color', 'white')).strip().lower(),
            upload_batch=batch_id,
        )
        db.session.add(voter)
        inserted += 1

    db.session.commit()

    # Run vote-theft / duplicate detection after every upload
    dup_count = _mark_duplicates()

    return jsonify({
        'success': True,
        'inserted': inserted,
        'skipped': skipped,
        'duplicates_detected': dup_count,
        'batch_id': batch_id,
    })


# ── GET VOTERS with filters ────────────────────────────────────────────────────

@app.route('/api/voters', methods=['GET'])
def get_voters():
    q = Voter.query

    search = request.args.get('search')
    if search:
        like = f'%{search}%'
        q = q.filter(or_(
            Voter.name.ilike(like),
            Voter.address.ilike(like),
            Voter.serial_no.ilike(like),
        ))

    booth = request.args.get('booth_no')
    if booth:
        q = q.filter(Voter.booth_no == booth)

    caste = request.args.get('caste')
    if caste:
        q = q.filter(Voter.caste.ilike(f'%{caste}%'))

    color = request.args.get('color')
    if color:
        q = q.filter(Voter.color.ilike(color))

    age_min = request.args.get('age_min', type=int)
    age_max = request.args.get('age_max', type=int)
    if age_min is not None:
        q = q.filter(Voter.age >= age_min)
    if age_max is not None:
        q = q.filter(Voter.age <= age_max)

    if request.args.get('has_phone') == 'true':
        q = q.filter(Voter.phone_no != None, Voter.phone_no != '')

    if request.args.get('effective') == 'true':
        q = q.filter(Voter.is_effective == True)

    if request.args.get('duplicate') == 'true':
        q = q.filter(Voter.is_duplicate == True)

    # Polling day — return only effective, non-duplicate voters
    if request.args.get('polling_day') == 'true':
        q = q.filter(Voter.is_effective == True, Voter.is_duplicate == False)

    sort = request.args.get('sort', 'serial')
    sort_map = {
        'name':    Voter.name,
        'age':     Voter.age,
        'booth':   Voter.booth_no,
        'address': Voter.address,
        'phone':   Voter.phone_no,
        'caste':   Voter.caste,
        'serial':  Voter.serial_no,
    }
    q = q.order_by(sort_map.get(sort, Voter.serial_no))

    # Pagination
    page  = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 100, type=int)
    paginated = q.paginate(page=page, per_page=per_page, error_out=False)

    return jsonify({
        'voters': [v.to_dict() for v in paginated.items],
        'total':  paginated.total,
        'page':   paginated.page,
        'pages':  paginated.pages,
    })


# ── STATS / SUMMARY ───────────────────────────────────────────────────────────

@app.route('/api/stats', methods=['GET'])
def stats():
    total       = Voter.query.count()
    duplicates  = Voter.query.filter_by(is_duplicate=True).count()
    effective   = Voter.query.filter_by(is_effective=True).count()

    # Caste breakdown
    from sqlalchemy import func
    caste_data = db.session.query(
        Voter.caste, func.count(Voter.id).label('count')
    ).group_by(Voter.caste).order_by(db.desc('count')).all()

    # Booth breakdown
    booth_data = db.session.query(
        Voter.booth_no, func.count(Voter.id).label('count')
    ).group_by(Voter.booth_no).order_by(Voter.booth_no).all()

    # Age groups
    age_groups = {
        '18-25': Voter.query.filter(Voter.age >= 18, Voter.age <= 25).count(),
        '26-40': Voter.query.filter(Voter.age >= 26, Voter.age <= 40).count(),
        '41-60': Voter.query.filter(Voter.age >= 41, Voter.age <= 60).count(),
        '60+':   Voter.query.filter(Voter.age > 60).count(),
    }

    return jsonify({
        'total': total,
        'duplicates': duplicates,
        'effective': effective,
        'caste_breakdown': [{'caste': r.caste or 'Unknown', 'count': r.count} for r in caste_data],
        'booth_breakdown': [{'booth': r.booth_no or '?', 'count': r.count} for r in booth_data],
        'age_groups': age_groups,
    })


# ── DROPDOWN DATA ──────────────────────────────────────────────────────────────

@app.route('/api/booths')
def get_booths():
    from sqlalchemy import distinct
    booths = [r[0] for r in db.session.query(distinct(Voter.booth_no)).filter(
        Voter.booth_no != None, Voter.booth_no != '').order_by(Voter.booth_no).all()]
    return jsonify({'data': booths})


@app.route('/api/castes')
def get_castes():
    from sqlalchemy import distinct
    castes = [r[0] for r in db.session.query(distinct(Voter.caste)).filter(
        Voter.caste != None, Voter.caste != '').order_by(Voter.caste).all()]
    return jsonify({'data': castes})


# ── VOTE THEFT REPORT ─────────────────────────────────────────────────────────

@app.route('/api/vote-theft-report')
def vote_theft_report():
    """Returns all duplicate voter groups for the admin to review."""
    dups = Voter.query.filter_by(is_duplicate=True).order_by(Voter.name).all()
    from collections import defaultdict
    groups = defaultdict(list)
    for v in dups:
        key = f"{v.name.strip().lower()}_{v.booth_no}"
        groups[key].append(v.to_dict())
    return jsonify({
        'total_suspicious': len(dups),
        'groups': list(groups.values()),
    })


# ── RE-RUN DUPLICATE DETECTION ────────────────────────────────────────────────

@app.route('/api/detect-duplicates', methods=['POST'])
def detect_duplicates():
    count = _mark_duplicates()
    return jsonify({'duplicates_detected': count})


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
