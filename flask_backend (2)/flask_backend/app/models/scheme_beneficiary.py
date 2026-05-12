from app import db
from app.utils.timezone_utils import get_ist_now_naive, ensure_ist_aware, format_ist_iso

VALID_SCHEMES = ['maha_lakshmi', 'cheyutha', 'rythu_bharosa', 'indiramma_indlu']

SCHEME_DISPLAY_NAMES = {
    'maha_lakshmi':   'Maha Lakshmi',
    'cheyutha':       'Cheyutha',
    'rythu_bharosa':  'Rythu Bharosa',
    'indiramma_indlu': 'Indiramma Indlu',
}


class SchemeBeneficiary(db.Model):
    __tablename__ = 'scheme_beneficiaries'

    id               = db.Column(db.Integer, primary_key=True)
    scheme_name      = db.Column(db.String(50), nullable=False, index=True)
    upload_batch_id  = db.Column(db.String(200), index=True)
    name             = db.Column(db.String(200), nullable=False)
    phone            = db.Column(db.String(20))
    address          = db.Column(db.Text)
    village          = db.Column(db.String(200))
    mandal           = db.Column(db.String(200))
    district         = db.Column(db.String(200))
    aadhar_no        = db.Column(db.String(20))
    account_no       = db.Column(db.String(50))
    amount           = db.Column(db.String(30))
    created_at       = db.Column(db.DateTime, default=get_ist_now_naive)
    updated_at       = db.Column(db.DateTime, default=get_ist_now_naive, onupdate=get_ist_now_naive)

    def to_dict(self):
        return {
            'id':            self.id,
            'schemeName':    self.scheme_name,
            'schemeDisplay': SCHEME_DISPLAY_NAMES.get(self.scheme_name, self.scheme_name),
            'uploadBatchId': self.upload_batch_id or '',
            'name':          self.name,
            'phone':         self.phone or '',
            'address':       self.address or '',
            'village':       self.village or '',
            'mandal':        self.mandal or '',
            'district':      self.district or '',
            'aadharNo':      self.aadhar_no or '',
            'accountNo':     self.account_no or '',
            'amount':        self.amount or '',
            'createdAt':     format_ist_iso(ensure_ist_aware(self.created_at)) if self.created_at else None,
            'updatedAt':     format_ist_iso(ensure_ist_aware(self.updated_at)) if self.updated_at else None,
        }
