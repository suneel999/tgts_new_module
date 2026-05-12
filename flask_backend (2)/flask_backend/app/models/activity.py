from app import db
from datetime import datetime
from sqlalchemy.dialects.postgresql import JSONB, ARRAY
from sqlalchemy import String

class Activity(db.Model):
    __tablename__ = 'activities'
    
    id = db.Column(db.String(50), primary_key=True)
    user_id = db.Column(db.String(50), db.ForeignKey('users.id'), nullable=False)
    title_en = db.Column(db.String(200), nullable=False)
    title_te = db.Column(db.String(200), nullable=False)
    description_en = db.Column(db.Text, nullable=False)
    description_te = db.Column(db.Text, nullable=False)
    location = db.Column(db.String(200))
    image_urls = db.Column(ARRAY(String), nullable=True)  # Array of image URLs
    video_urls = db.Column(ARRAY(String), nullable=True)  # Array of video URLs
    created_at = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationship to User
    user = db.relationship('User', backref='activities', lazy='joined')
    
    def to_dict(self, current_user=None):
        """Convert activity to dictionary for API response"""
        # Get user information
        user_name = None
        user_designation = None
        user_role = 'public'
        
        user_cadre_level = None
        
        if self.user:
            user_name = self.user.name
            user_role = self.user.role.value if self.user.role else 'public'
            
            # Try to get designation and cadre level from Member if user has membership
            # Check if user has a member record by phone
            if hasattr(self.user, 'phone'):
                from app.models import Member
                member = Member.query.filter_by(phone=self.user.phone).first()
                if member:
                    if member.party_designation:
                        user_designation = member.party_designation
                    user_cadre_level = member.cadre_level
        
        return {
            'id': self.id,
            'userId': self.user_id,
            'userName': user_name,
            'userDesignation': user_designation,
            'userRole': user_role,
            'title': {
                'en': self.title_en,
                'te': self.title_te
            },
            'description': {
                'en': self.description_en,
                'te': self.description_te
            },
            'location': self.location,
            'imageUrls': self.image_urls if self.image_urls else [],
            'videoUrls': self.video_urls if self.video_urls else [],
            'creatorCadreLevel': user_cadre_level,
            'createdAt': self.created_at.isoformat() if self.created_at else None,
            'date': self.created_at.isoformat() if self.created_at else None,  # Alias for frontend compatibility
        }





