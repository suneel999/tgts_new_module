from app import db
import uuid
from app.utils.timezone_utils import get_ist_now_naive, ensure_ist_aware, format_ist_iso

SCHEME_CATEGORIES = [
    'welfare', 'agriculture', 'housing', 'women',
    'youth', 'education', 'health', 'other',
]


class Scheme(db.Model):
    __tablename__ = 'schemes'

    id             = db.Column(db.String(50), primary_key=True, default=lambda: str(uuid.uuid4()))
    title_en       = db.Column(db.String(200), nullable=False)
    title_te       = db.Column(db.String(200), nullable=False)
    description_en = db.Column(db.Text, nullable=False)
    description_te = db.Column(db.Text, nullable=False)
    category       = db.Column(db.String(50), nullable=False, default='welfare')
    image_url      = db.Column(db.String(500))
    eligibility_en = db.Column(db.Text)
    eligibility_te = db.Column(db.Text)
    benefits_en    = db.Column(db.Text)
    benefits_te    = db.Column(db.Text)
    apply_link     = db.Column(db.String(500))
    is_published   = db.Column(db.Boolean, default=False, nullable=False)
    created_at     = db.Column(db.DateTime, default=get_ist_now_naive)
    updated_at     = db.Column(db.DateTime, default=get_ist_now_naive, onupdate=get_ist_now_naive)

    def to_dict(self):
        return {
            'id':          self.id,
            'title':       {'en': self.title_en,       'te': self.title_te},
            'description': {'en': self.description_en, 'te': self.description_te},
            'category':    self.category,
            'imageUrl':    self.image_url or '',
            'eligibility': {'en': self.eligibility_en or '', 'te': self.eligibility_te or ''},
            'benefits':    {'en': self.benefits_en or '', 'te': self.benefits_te or ''},
            'applyLink':   self.apply_link or '',
            'isPublished': self.is_published,
            'createdAt':   format_ist_iso(ensure_ist_aware(self.created_at)) if self.created_at else None,
            'updatedAt':   format_ist_iso(ensure_ist_aware(self.updated_at)) if self.updated_at else None,
        }
