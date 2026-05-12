from app import db
from app.utils.timezone_utils import get_ist_now_naive, ensure_ist_aware, format_ist_iso
from sqlalchemy import UniqueConstraint

class Mandal(db.Model):
    __tablename__ = 'mandals'
    
    # Mandal Information - using id as primary key (auto-increment integer)
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    district_id = db.Column(db.Integer, db.ForeignKey('districts.id'), nullable=False)
    name_en = db.Column(db.String(200), nullable=False)
    name_te = db.Column(db.String(200))  # Telugu name if available
    
    # Additional Information
    description = db.Column(db.Text)
    
    # Status
    is_active = db.Column(db.Boolean, default=True)
    
    # Timestamps
    created_at = db.Column(db.DateTime, default=get_ist_now_naive)
    updated_at = db.Column(db.DateTime, default=get_ist_now_naive, onupdate=get_ist_now_naive)
    
    # Unique constraint: same mandal name can exist in different districts
    __table_args__ = (
        UniqueConstraint('district_id', 'name_en', name='uq_mandal_district_name'),
    )
    
    # Relationship to Members
    members = db.relationship('Member', backref='mandal_ref', lazy='dynamic')
    
    def to_dict(self):
        return {
            'id': self.id,
            'districtId': self.district_id,
            'districtRef': self.district_ref.to_dict() if self.district_ref else None,
            'name': {
                'en': self.name_en,
                'te': self.name_te or self.name_en
            },
            'name_en': self.name_en,
            'name_te': self.name_te or self.name_en,
            'description': self.description,
            'isActive': self.is_active,
            'createdAt': format_ist_iso(ensure_ist_aware(self.created_at)) if self.created_at else None,
            'updatedAt': format_ist_iso(ensure_ist_aware(self.updated_at)) if self.updated_at else None
        }

