from app import db
from datetime import datetime
from sqlalchemy import JSON
import json

class MediaItem(db.Model):
    __tablename__ = 'media_items'
    
    id = db.Column(db.String(50), primary_key=True)
    type = db.Column(db.String(10), nullable=False)  # 'photo' or 'video'
    url = db.Column(db.String(500), nullable=False)  # S3 URL - keep this
    thumbnail_url = db.Column(db.String(500))
    title_en = db.Column(db.String(200), nullable=True, default='')
    title_te = db.Column(db.String(200), nullable=True, default='')
    is_published = db.Column(db.Boolean, default=False)
    access_level = db.Column(db.String(20), nullable=False, default='public')  # Single role: 'public', 'cadre', or 'admin'
    creator_cadre_level = db.Column(db.Integer, nullable=True)  # Cadre level of creator (1-10), for hierarchy-based visibility
    # Geographic access control
    district_ids = db.Column(JSON, nullable=True)
    mandal_ids = db.Column(JSON, nullable=True)
    assembly_constituency_ids = db.Column(JSON, nullable=True)
    parliamentary_constituency_ids = db.Column(JSON, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def to_dict(self):
        # Get access_level as single role string from database
        # Database stores: 'public', 'cadre', or 'admin' (single word, not JSON)
        # Use getattr to handle cases where column doesn't exist yet (backward compatibility)
        role_raw = getattr(self, 'access_level', None) or 'public'
        
        # Normalize to lowercase and ensure it's a valid role
        if isinstance(role_raw, str):
            role = role_raw.lower().strip()
            # Validate role (only allow valid roles)
            if role not in ['public', 'cadre', 'admin']:
                role = 'public'
        else:
            role = 'public'
        
        # Return as single-item array with actual role (NOT hierarchical)
        # The hierarchical access logic (who can see what) is handled in the API route filtering, not here
        # Example: if DB has 'cadre', return ['cadre'] NOT ['public', 'cadre']
        access_level_array = [role]
        
        return {
            'id': self.id,
            'type': self.type,
            'url': self.url,
            'thumbnail': self.thumbnail_url,
            'title': {
                'en': self.title_en,
                'te': self.title_te
            },
            'date': self.created_at.isoformat(),
            'isPublished': self.is_published,
            'access_level': access_level_array,  # Return actual role as single-item array: ['cadre'], ['admin'], or ['public']
            'access_level_role': role,  # Also return single role for efficiency
            'creatorCadreLevel': getattr(self, 'creator_cadre_level', None),
            'districtIds': getattr(self, 'district_ids', None) or [],
            'mandalIds': getattr(self, 'mandal_ids', None) or [],
            'assemblyConstituencyIds': getattr(self, 'assembly_constituency_ids', None) or [],
            'parliamentaryConstituencyIds': getattr(self, 'parliamentary_constituency_ids', None) or []
        }
