from app import db
from datetime import datetime
from enum import Enum
from app.utils.timezone_utils import get_ist_now_naive, ensure_ist_aware, format_ist_iso

class UserRole(Enum):
    PUBLIC = 'public'
    CADRE = 'cadre'
    ADMIN = 'admin'

class Language(Enum):
    EN = 'en'
    TE = 'te'

class User(db.Model):
    __tablename__ = 'users'
    
    id = db.Column(db.String(50), primary_key=True)
    phone = db.Column(db.String(15), unique=True, nullable=False)
    name = db.Column(db.String(100), nullable=False)
    role = db.Column(db.Enum(UserRole), default=UserRole.PUBLIC)
    region = db.Column(db.String(100))
    enrollment_date = db.Column(db.DateTime, default=get_ist_now_naive)
    is_active = db.Column(db.Boolean, default=True)
    fcm_token = db.Column(db.String(500))  # FCM token for push notifications
    created_at = db.Column(db.DateTime, default=get_ist_now_naive)
    updated_at = db.Column(db.DateTime, default=get_ist_now_naive, onupdate=get_ist_now_naive)
    
    def to_dict(self):
        return {
            'id': self.id,
            'phone': self.phone,
            'name': self.name,
            'role': self.role.value,
            'region': self.region,
            'enrollmentDate': format_ist_iso(ensure_ist_aware(self.enrollment_date)) if self.enrollment_date else None,
            'isActive': self.is_active,
            'createdAt': format_ist_iso(ensure_ist_aware(self.created_at)),
            'updatedAt': format_ist_iso(ensure_ist_aware(self.updated_at))
        }

class EventRSVP(db.Model):
    __tablename__ = 'event_rsvps'
    
    id = db.Column(db.String(50), primary_key=True)
    event_id = db.Column(db.String(50), db.ForeignKey('events.id', ondelete='CASCADE'), nullable=False)
    phone_number = db.Column(db.String(15), nullable=False)
    created_at = db.Column(db.DateTime, default=get_ist_now_naive)
    
    # Unique constraint on event_id + phone_number combination
    __table_args__ = (
        db.UniqueConstraint('event_id', 'phone_number', name='unique_event_phone'),
    )
    
    # Relationship to Event
    event = db.relationship('Event', backref='rsvps')
    
    def to_dict(self):
        return {
            'id': self.id,
            'event_id': self.event_id,
            'phone_number': self.phone_number,
            'created_at': format_ist_iso(ensure_ist_aware(self.created_at)) if self.created_at else None
        }

class MediaStats(db.Model):
    __tablename__ = 'media_stats'
    
    id = db.Column(db.String(50), primary_key=True, default='media_stats_singleton')
    photo_count = db.Column(db.Integer, default=0, nullable=False)
    video_count = db.Column(db.Integer, default=0, nullable=False)
    updated_at = db.Column(db.DateTime, default=get_ist_now_naive, onupdate=get_ist_now_naive)
    
    def to_dict(self):
        return {
            'photo_count': self.photo_count,
            'video_count': self.video_count,
            'total_count': self.photo_count + self.video_count,
            'updated_at': format_ist_iso(ensure_ist_aware(self.updated_at)) if self.updated_at else None
        }

# Import models from separate files
# These models have geographic access columns (district_ids, mandal_ids, etc.)
from app.models.news import NewsItem
from app.models.event import Event
from app.models.media import MediaItem
from app.models.document import Document
from app.models.member import Member
from app.models.role import Role
from app.models.parliamentary_constituency import ParliamentaryConstituency
from app.models.assembly_constituency import AssemblyConstituency
from app.models.activity import Activity
from app.models.cadre_level import CadreLevel
from app.models.voter import Voter
from app.models.scheme_beneficiary import SchemeBeneficiary
from app.models.scheme import Scheme