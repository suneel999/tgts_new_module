from app import db
from datetime import datetime
from sqlalchemy import JSON

class NewsItem(db.Model):
    __tablename__ = 'news_items'
    
    id = db.Column(db.String(50), primary_key=True)
    title_en = db.Column(db.String(200), nullable=False)
    title_te = db.Column(db.String(200), nullable=False)
    description_en = db.Column(db.Text, nullable=False)
    description_te = db.Column(db.Text, nullable=False)
    image_url = db.Column(db.String(500))
    category = db.Column(db.String(50), nullable=False)
    is_published = db.Column(db.Boolean, default=False)
    # Geographic access control
    district_ids = db.Column(JSON, nullable=True)
    mandal_ids = db.Column(JSON, nullable=True)
    assembly_constituency_ids = db.Column(JSON, nullable=True)
    parliamentary_constituency_ids = db.Column(JSON, nullable=True)
    # Social media and external links
    links = db.Column(JSON, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def to_dict(self):
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
            'image': self.image_url,
            'category': self.category,
            'date': self.created_at.isoformat(),
            'isPublished': self.is_published,
            'districtIds': getattr(self, 'district_ids', None) or [],
            'mandalIds': getattr(self, 'mandal_ids', None) or [],
            'assemblyConstituencyIds': getattr(self, 'assembly_constituency_ids', None) or [],
            'parliamentaryConstituencyIds': getattr(self, 'parliamentary_constituency_ids', None) or [],
            'links': getattr(self, 'links', None) or []
        }
