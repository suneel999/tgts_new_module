from app import db
from datetime import datetime
from sqlalchemy import JSON

class Document(db.Model):
    __tablename__ = 'documents'
    
    id = db.Column(db.String(50), primary_key=True)
    title_en = db.Column(db.String(200), nullable=False)
    title_te = db.Column(db.String(200), nullable=False)
    category = db.Column(db.String(50), nullable=False)
    file_url = db.Column(db.String(500), nullable=False)
    access_level = db.Column(db.String(20), nullable=False)  # JSON string of roles
    is_published = db.Column(db.Boolean, default=False)
    # Geographic access control
    district_ids = db.Column(JSON, nullable=True)
    mandal_ids = db.Column(JSON, nullable=True)
    assembly_constituency_ids = db.Column(JSON, nullable=True)
    parliamentary_constituency_ids = db.Column(JSON, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def to_dict(self):
        import json
        import os
        # Parse file info from URL
        file_type = 'pdf'  # default
        file_size = 0  # default
        
        # Ensure file_url is a valid string (not None or "None")
        file_url = self.file_url
        if file_url is None or file_url == 'None' or str(file_url).strip() == '':
            file_url = None
        else:
            file_url = str(file_url).strip()
            if file_url:
                ext = os.path.splitext(file_url)[1].lower()
                if ext:
                    file_type = ext[1:] if ext.startswith('.') else ext
        
        # Helper function to ensure geographic IDs are returned as arrays of numbers
        def normalize_geographic_ids(value):
            if value is None:
                return []
            if isinstance(value, str):
                # If it's a JSON string, parse it
                try:
                    parsed = json.loads(value)
                    if isinstance(parsed, list):
                        return [int(x) for x in parsed if x is not None and str(x).strip()]
                    return []
                except (json.JSONDecodeError, ValueError):
                    return []
            if isinstance(value, list):
                # Convert all items to integers, filtering out None/null values
                return [int(x) for x in value if x is not None and str(x).strip()]
            return []
        
        return {
            'id': self.id,
            'title_en': self.title_en,
            'title_te': self.title_te,
            'category': self.category,
            'file_url': file_url,  # Will be None if invalid
            'file_type': file_type,
            'file_size': file_size,
            'access_level': json.loads(self.access_level) if self.access_level else [],
            'is_published': self.is_published,
            'districtIds': normalize_geographic_ids(getattr(self, 'district_ids', None)),
            'mandalIds': normalize_geographic_ids(getattr(self, 'mandal_ids', None)),
            'assemblyConstituencyIds': normalize_geographic_ids(getattr(self, 'assembly_constituency_ids', None)),
            'parliamentaryConstituencyIds': normalize_geographic_ids(getattr(self, 'parliamentary_constituency_ids', None)),
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }
