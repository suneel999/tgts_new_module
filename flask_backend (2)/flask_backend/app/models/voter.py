from app import db
from app.utils.timezone_utils import get_ist_now_naive, ensure_ist_aware, format_ist_iso


class Voter(db.Model):
    __tablename__ = 'voters'

    id = db.Column(db.Integer, primary_key=True)
    upload_batch_id = db.Column(db.String(100), index=True)
    serial_no = db.Column(db.String(20))
    voter_name = db.Column(db.String(200), nullable=False)
    relative_type = db.Column(db.String(20))
    relative_name = db.Column(db.String(200))
    house_number = db.Column(db.String(100))
    age = db.Column(db.Integer)
    date_of_birth = db.Column(db.String(20))
    gender = db.Column(db.String(10))
    voter_id_number = db.Column(db.String(50))
    part_number = db.Column(db.String(20))
    booth_number = db.Column(db.String(20), index=True)
    booth_name = db.Column(db.String(200))
    address = db.Column(db.Text)
    phone = db.Column(db.String(20))
    caste = db.Column(db.String(100), index=True)
    color = db.Column(db.String(20), default='white')
    is_beneficiary = db.Column(db.Boolean, default=False)
    is_duplicate = db.Column(db.Boolean, default=False)
    has_voted = db.Column(db.Boolean, default=False)
    is_effective = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=get_ist_now_naive)
    updated_at = db.Column(db.DateTime, default=get_ist_now_naive, onupdate=get_ist_now_naive)

    def to_dict(self):
        return {
            'id': self.id,
            'uploadBatchId': self.upload_batch_id or '',
            'serialNo': self.serial_no or '',
            'voterName': self.voter_name,
            'relativeType': self.relative_type or '',
            'relativeName': self.relative_name or '',
            'houseNumber': self.house_number or '',
            'age': self.age,
            'dateOfBirth': self.date_of_birth or '',
            'gender': self.gender or '',
            'voterIdNumber': self.voter_id_number or '',
            'partNumber': self.part_number or '',
            'boothNumber': self.booth_number or '',
            'boothName': self.booth_name or '',
            'address': self.address or '',
            'phone': self.phone or '',
            'caste': self.caste or '',
            'color': self.color or 'white',
            'isBeneficiary': bool(self.is_beneficiary),
            'isDuplicate': bool(self.is_duplicate),
            'hasVoted': bool(self.has_voted),
            'isEffective': bool(self.is_effective),
            'createdAt': format_ist_iso(ensure_ist_aware(self.created_at)) if self.created_at else None,
            'updatedAt': format_ist_iso(ensure_ist_aware(self.updated_at)) if self.updated_at else None,
        }
