from app import db
from app.utils.timezone_utils import get_ist_now_naive, ensure_ist_aware, format_ist_iso
from datetime import datetime
import random
import string

class Member(db.Model):
    __tablename__ = 'members'
    
    id = db.Column(db.String(50), primary_key=True)
    member_id = db.Column(db.String(14), unique=True, nullable=True)  # TS + 3-digit assembly + 9-digit counter
    
    # Personal Information
    full_name = db.Column(db.String(200), nullable=False)
    father_name = db.Column(db.String(200))
    date_of_birth = db.Column(db.Date)
    gender = db.Column(db.String(10))  # 'male', 'female', 'other'
    phone = db.Column(db.String(15), nullable=False)
    aadhar_number = db.Column(db.String(12), unique=True)
    epic_number = db.Column(db.String(20), unique=True)  # Voter ID
    epic_file_url = db.Column(db.String(500))  # URL to uploaded EPIC card file
    profile_picture_url = db.Column(db.String(500))  # URL to profile picture in S3
    
    # Address Information
    village = db.Column(db.String(200))
    # Integer foreign keys for districts and mandals
    district_id = db.Column(db.Integer, db.ForeignKey('districts.id'))
    mandal_id = db.Column(db.Integer, db.ForeignKey('mandals.id'))
    parliament_constituency_id = db.Column(db.Integer, db.ForeignKey('parliamentary_constituencies.constituency_number'))
    assembly_constituency_id = db.Column(db.Integer, db.ForeignKey('assembly_constituencies.constituency_number'))
    full_address = db.Column(db.Text)
    
    # Party Information
    party_designation = db.Column(db.String(200))  # Legacy free-text field, kept for backward compatibility
    cadre_level = db.Column(db.Integer, db.ForeignKey('cadre_levels.level'), nullable=True)
    occupation = db.Column(db.String(200))
    volunteer_interest = db.Column(db.Boolean, default=False)
    
    # Insurance Information
    has_insurance = db.Column(db.Boolean, default=False)
    insurance_number = db.Column(db.String(100))
    
    # Status
    status = db.Column(db.String(20), default='pending')  # 'pending', 'approved', 'rejected'
    is_active = db.Column(db.Boolean, default=True)
    role_id = db.Column(db.Integer, db.ForeignKey('roles.id'), default=1)
    role_details = db.relationship('Role', backref='members')
    cadre_level_ref = db.relationship('CadreLevel', backref='members', lazy='joined')

    @property
    def role(self):
        return self.role_details.name if self.role_details else 'public'

    @role.setter
    def role(self, value):
        if not value:
            return
        from app.models.role import Role
        role_entry = Role.query.filter_by(name=value).first()
        if role_entry:
            self.role_id = role_entry.id
        else:
            # Default to public (1)
            self.role_id = 1
    
    # Timestamps
    created_at = db.Column(db.DateTime, default=get_ist_now_naive)
    updated_at = db.Column(db.DateTime, default=get_ist_now_naive, onupdate=get_ist_now_naive)
    
    @staticmethod
    def get_next_counter():
        """
        Get the next counter value for membership ID generation.
        Queries existing member_ids in the new format and returns the next sequential number.
        Returns 1 if no members exist or if no valid IDs are found.
        """
        # Query all existing member_ids that match the new format (TS + 3 digits + 9 digits)
        existing_members = Member.query.filter(
            Member.member_id.isnot(None),
            Member.member_id.like('TS%')
        ).all()
        
        max_counter = 0
        for member in existing_members:
            if member.member_id and len(member.member_id) == 14 and member.member_id.startswith('TS'):
                try:
                    # Extract counter from format: TS + 3 digits + 9 digits
                    counter_str = member.member_id[5:]  # Skip 'TS' + 3 digits
                    counter = int(counter_str)
                    max_counter = max(max_counter, counter)
                except (ValueError, IndexError):
                    # Skip invalid formats
                    continue
        
        return max_counter + 1
    
    @staticmethod
    def generate_member_id(assembly_constituency_id=None, counter=None):
        """
        Generate a 14-character membership ID in the format:
        TS + 3-digit assembly number (zero-padded) + 9-digit counter (zero-padded)
        
        Format: TS{assembly_number:03d}{counter:09d}
        
        Args:
            assembly_constituency_id: Assembly constituency ID (integer). If None, uses 000.
            counter: Counter value (integer). If None, automatically gets next counter.
        
        Returns:
            str: 14-character membership ID (e.g., TS001000000001)
        """
        # Use assembly constituency ID or default to 000
        if assembly_constituency_id is None:
            assembly_number = 0
        else:
            assembly_number = int(assembly_constituency_id)
        
        # Ensure assembly number is within valid range (0-999)
        assembly_number = max(0, min(999, assembly_number))
        
        # Get counter if not provided
        if counter is None:
            counter = Member.get_next_counter()
        
        # Format: TS + 3-digit assembly + 9-digit counter
        member_id = f"TS{assembly_number:03d}{counter:09d}"
        
        return member_id
    
    def to_dict(self):
        # Get district and mandal names from relationships
        district_name = self.district_ref.name_en if self.district_ref else None
        mandal_name = self.mandal_ref.name_en if self.mandal_ref else None
        
        return {
            'id': self.id,
            'memberId': self.member_id,
            'fullName': self.full_name,
            'fatherName': self.father_name,
            'dateOfBirth': self.date_of_birth.isoformat() if self.date_of_birth else None,
            'gender': self.gender,
            'phone': self.phone,
            'aadharNumber': self.aadhar_number,
            'epicNumber': self.epic_number,
            'epicFileUrl': self.epic_file_url,
            'profilePictureUrl': self.profile_picture_url,
            'village': self.village,
            # Integer IDs
            'districtId': self.district_id,
            'mandalId': self.mandal_id,
            'districtRef': self.district_ref.to_dict() if self.district_ref else None,
            'mandalRef': self.mandal_ref.to_dict() if self.mandal_ref else None,
            # String fields for convenience (derived from relationships)
            'mandal': mandal_name,
            'district': district_name,
            'parliamentConstituencyId': self.parliament_constituency_id,
            'parliamentConstituencyRef': self.parliamentary_constituency_ref.to_dict() if self.parliamentary_constituency_ref else None,
            'assemblyConstituencyId': self.assembly_constituency_id,
            'assemblyConstituencyRef': self.assembly_constituency_ref.to_dict() if self.assembly_constituency_ref else None,
            'fullAddress': self.full_address,
            'partyDesignation': self.party_designation,
            'cadreLevel': self.cadre_level,
            'cadreLevelRef': self.cadre_level_ref.to_dict() if self.cadre_level_ref else None,
            'occupation': self.occupation,
            'volunteerInterest': self.volunteer_interest,
            'hasInsurance': self.has_insurance,
            'insuranceNumber': self.insurance_number,
            'status': self.status,
            'isActive': self.is_active,
            'role': self.role,
            'createdAt': format_ist_iso(ensure_ist_aware(self.created_at)) if self.created_at else None,
            'updatedAt': format_ist_iso(ensure_ist_aware(self.updated_at)) if self.updated_at else None
        }

