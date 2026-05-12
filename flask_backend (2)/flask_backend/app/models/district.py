from app import db
from app.utils.timezone_utils import get_ist_now_naive, ensure_ist_aware, format_ist_iso

class District(db.Model):
    __tablename__ = 'districts'
    
    # District Information - using id as primary key (auto-increment integer)
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    name_en = db.Column(db.String(200), unique=True, nullable=False)
    name_te = db.Column(db.String(200))  # Telugu name if available
    state = db.Column(db.String(100), default='Telangana')
    
    # Additional Information
    description = db.Column(db.Text)
    
    # Status
    is_active = db.Column(db.Boolean, default=True)
    
    # Timestamps
    created_at = db.Column(db.DateTime, default=get_ist_now_naive)
    updated_at = db.Column(db.DateTime, default=get_ist_now_naive, onupdate=get_ist_now_naive)
    
    # Relationship to Mandals
    mandals = db.relationship('Mandal', backref='district_ref', lazy='dynamic', cascade='all, delete-orphan')
    
    # Relationship to Members
    members = db.relationship('Member', backref='district_ref', lazy='dynamic')
    
    def to_dict(self):
        return {
            'id': self.id,
            'name': {
                'en': self.name_en,
                'te': self.name_te or self.name_en
            },
            'name_en': self.name_en,
            'name_te': self.name_te or self.name_en,
            'state': self.state,
            'description': self.description,
            'isActive': self.is_active,
            'createdAt': format_ist_iso(ensure_ist_aware(self.created_at)) if self.created_at else None,
            'updatedAt': format_ist_iso(ensure_ist_aware(self.updated_at)) if self.updated_at else None
        }

