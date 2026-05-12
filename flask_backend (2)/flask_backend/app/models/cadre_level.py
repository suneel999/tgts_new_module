from app import db


class CadreLevel(db.Model):
    __tablename__ = 'cadre_levels'
    
    level = db.Column(db.Integer, primary_key=True)  # 1=highest (PCC), 10=lowest (Booth)
    name_en = db.Column(db.String(100), nullable=False)
    name_te = db.Column(db.String(100), nullable=False)
    geographic_scope = db.Column(db.String(50), nullable=False)  # 'state', 'district', 'mandal', 'booth'
    
    def __repr__(self):
        return f'<CadreLevel {self.level}: {self.name_en}>'
    
    def to_dict(self):
        return {
            'level': self.level,
            'nameEn': self.name_en,
            'nameTe': self.name_te,
            'geographicScope': self.geographic_scope
        }


# Predefined cadre levels - seed data
CADRE_LEVELS_SEED = [
    {
        'level': 1,
        'name_en': 'Pradesh Congress Committee (PCC)',
        'name_te': 'ప్రదేశ్ కాంగ్రెస్ కమిటీ (PCC)',
        'geographic_scope': 'state'
    },
    {
        'level': 2,
        'name_en': 'PCC President',
        'name_te': 'PCC అధ్యక్షుడు',
        'geographic_scope': 'state'
    },
    {
        'level': 3,
        'name_en': 'PCC Working Committee',
        'name_te': 'PCC వర్కింగ్ కమిటీ',
        'geographic_scope': 'state'
    },
    {
        'level': 4,
        'name_en': 'PCC Vice Presidents',
        'name_te': 'PCC ఉపాధ్యక్షులు',
        'geographic_scope': 'state'
    },
    {
        'level': 5,
        'name_en': 'PCC General Secretaries',
        'name_te': 'PCC ప్రధాన కార్యదర్శులు',
        'geographic_scope': 'state'
    },
    {
        'level': 6,
        'name_en': 'PCC Secretaries',
        'name_te': 'PCC కార్యదర్శులు',
        'geographic_scope': 'state'
    },
    {
        'level': 7,
        'name_en': 'State-level Department/Cell Heads',
        'name_te': 'రాష్ట్ర స్థాయి విభాగం/సెల్ అధిపతులు',
        'geographic_scope': 'state'
    },
    {
        'level': 8,
        'name_en': 'District Congress Committees',
        'name_te': 'జిల్లా కాంగ్రెస్ కమిటీలు',
        'geographic_scope': 'district'
    },
    {
        'level': 9,
        'name_en': 'Block/Mandal Congress Committees',
        'name_te': 'బ్లాక్/మండల కాంగ్రెస్ కమిటీలు',
        'geographic_scope': 'mandal'
    },
    {
        'level': 10,
        'name_en': 'Booth-Level Committees',
        'name_te': 'బూత్ స్థాయి కమిటీలు',
        'geographic_scope': 'booth'
    },
]
