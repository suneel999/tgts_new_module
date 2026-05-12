from app import db
from datetime import datetime
from sqlalchemy.dialects.postgresql import JSONB

class Event(db.Model):
    __tablename__ = 'events'
    
    id = db.Column(db.String(50), primary_key=True)
    title_en = db.Column(db.String(200), nullable=False)
    title_te = db.Column(db.String(200), nullable=True)
    description_en = db.Column(db.Text, nullable=False)
    description_te = db.Column(db.Text, nullable=True)
    event_date = db.Column(db.DateTime, nullable=False)
    event_time = db.Column(db.String(10), nullable=False)
    location_en = db.Column(db.String(200), nullable=False)
    location_te = db.Column(db.String(200), nullable=True)
    image_url = db.Column(db.String(500))
    rsvp_count = db.Column(db.Integer, default=0)
    is_published = db.Column(db.Boolean, default=False)
    access_level = db.Column(db.String(20), nullable=False, default='public')  # 'public', 'cadre', or 'admin'
    creator_cadre_level = db.Column(db.Integer, nullable=True)  # Cadre level of creator (1-10), for hierarchy-based visibility
    # Geographic access control
    district_ids = db.Column(JSONB, nullable=True)
    mandal_ids = db.Column(JSONB, nullable=True)
    assembly_constituency_ids = db.Column(JSONB, nullable=True)
    parliamentary_constituency_ids = db.Column(JSONB, nullable=True)
    submitted_by_user_id = db.Column(db.String(50), nullable=True)  # Set for user-submitted events pending review
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def to_dict(self, current_user=None):
        # Use getattr for backward compatibility with old records that don't have these columns
        # Check if current user has RSVP'd to this event
        user_has_rsvpd = False
        if current_user and current_user.phone:
            from app.models import EventRSVP
            existing_rsvp = EventRSVP.query.filter_by(
                event_id=self.id,
                phone_number=current_user.phone
            ).first()
            user_has_rsvpd = existing_rsvp is not None
        
        # Get access_level with backward compatibility
        access_level = getattr(self, 'access_level', 'public') or 'public'
        
        return {
            'id': self.id,
            'title': {
                'en': self.title_en,
                'te': self.title_te
            },
            'description': {
                'en': self.description_en,
                'te': self.description_te
            },
            'date': self.event_date.isoformat(),
            'time': self.event_time,
            'location': {
                'en': self.location_en,
                'te': self.location_te
            },
            'image': self.image_url,
            'rsvpCount': self.rsvp_count,
            'isPublished': self.is_published,
            'accessLevel': access_level,
            'creatorCadreLevel': getattr(self, 'creator_cadre_level', None),
            'userHasRsvpd': user_has_rsvpd,
            'districtIds': getattr(self, 'district_ids', None) or [],
            'mandalIds': getattr(self, 'mandal_ids', None) or [],
            'assemblyConstituencyIds': getattr(self, 'assembly_constituency_ids', None) or [],
            'parliamentaryConstituencyIds': getattr(self, 'parliamentary_constituency_ids', None) or [],
            'submittedByUserId': getattr(self, 'submitted_by_user_id', None),
        }
