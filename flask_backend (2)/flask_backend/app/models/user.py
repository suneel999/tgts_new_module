from app import db
from datetime import datetime
from enum import Enum

class UserRole(Enum):
    PUBLIC = 'public'
    CADRE = 'cadre'
    ADMIN = 'admin'

class User(db.Model):
    __tablename__ = 'users'

    id = db.Column(db.String(50), primary_key=True)
    phone = db.Column(db.String(15), unique=True, nullable=False)
    name = db.Column(db.String(100), nullable=False)
    role = db.Column(db.Enum(UserRole), default=UserRole.PUBLIC)
    region = db.Column(db.String(100))
    enrollment_date = db.Column(db.DateTime, default=datetime.utcnow)
    is_active = db.Column(db.Boolean, default=True)
    fcm_token = db.Column(db.String(500))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Location fields for public users (non-members)
    district_id = db.Column(db.Integer, db.ForeignKey('districts.id'), nullable=True)
    mandal_id = db.Column(db.Integer, db.ForeignKey('mandals.id'), nullable=True)
    parliament_constituency_id = db.Column(
        db.Integer,
        db.ForeignKey('parliamentary_constituencies.constituency_number'),
        nullable=True,
    )
    assembly_constituency_id = db.Column(
        db.Integer,
        db.ForeignKey('assembly_constituencies.constituency_number'),
        nullable=True,
    )

    def to_dict(self):
        # Lazy-load refs to avoid circular import issues
        district_ref = None
        mandal_ref = None
        parliament_ref = None
        assembly_ref = None

        if self.district_id:
            from app.models.district import District
            d = District.query.get(self.district_id)
            if d:
                district_ref = {
                    'id': d.id,
                    'nameEn': d.name_en,
                    'nameTe': d.name_te or d.name_en,
                    'state': d.state,
                }

        if self.mandal_id:
            from app.models.mandal import Mandal
            m = Mandal.query.get(self.mandal_id)
            if m:
                mandal_ref = {
                    'id': m.id,
                    'districtId': m.district_id,
                    'nameEn': m.name_en,
                    'nameTe': m.name_te or m.name_en,
                }

        if self.parliament_constituency_id:
            from app.models.parliamentary_constituency import ParliamentaryConstituency
            p = ParliamentaryConstituency.query.get(self.parliament_constituency_id)
            if p:
                parliament_ref = p.to_dict()

        if self.assembly_constituency_id:
            from app.models.assembly_constituency import AssemblyConstituency
            a = AssemblyConstituency.query.get(self.assembly_constituency_id)
            if a:
                assembly_ref = a.to_dict()

        return {
            'id': self.id,
            'phone': self.phone,
            'name': self.name,
            'role': self.role.value,
            'region': self.region,
            'enrollmentDate': self.enrollment_date.isoformat() if self.enrollment_date else None,
            'isActive': self.is_active,
            'createdAt': self.created_at.isoformat(),
            'updatedAt': self.updated_at.isoformat(),
            # Location
            'districtId': self.district_id,
            'mandalId': self.mandal_id,
            'parliamentConstituencyId': self.parliament_constituency_id,
            'assemblyConstituencyId': self.assembly_constituency_id,
            'districtRef': district_ref,
            'mandalRef': mandal_ref,
            'parliamentConstituencyRef': parliament_ref,
            'assemblyConstituencyRef': assembly_ref,
            # Convenience string fields (derived from refs)
            'district': district_ref['nameEn'] if district_ref else None,
            'mandal': mandal_ref['nameEn'] if mandal_ref else None,
        }
