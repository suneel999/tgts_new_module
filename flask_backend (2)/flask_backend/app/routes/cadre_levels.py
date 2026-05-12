"""
Cadre Levels Routes for Telangana Congress Communication App
Provides the list of predefined organizational hierarchy levels.
"""

from flask_restx import Namespace, Resource, fields
from app.models.cadre_level import CadreLevel
from app.utils.error_handling import log_api_call

# Create namespace for cadre levels
cadre_levels_ns = Namespace('cadre-levels', description='Cadre level hierarchy operations')

cadre_level_model = cadre_levels_ns.model('CadreLevel', {
    'level': fields.Integer(description='Hierarchy level (1=highest, 10=lowest)'),
    'nameEn': fields.String(description='Name in English'),
    'nameTe': fields.String(description='Name in Telugu'),
    'geographicScope': fields.String(description='Geographic scope (state, district, mandal, booth)')
})


@cadre_levels_ns.route('/')
class CadreLevelsList(Resource):
    @cadre_levels_ns.marshal_with(cadre_levels_ns.model('CadreLevelsResponse', {
        'cadreLevels': fields.List(fields.Nested(cadre_level_model)),
        'total': fields.Integer
    }))
    @cadre_levels_ns.doc(
        summary='Get all cadre levels',
        description='Returns the list of all predefined cadre levels in the organizational hierarchy, ordered from highest (1) to lowest (10).',
        responses={
            200: 'Cadre levels retrieved successfully',
            500: 'Internal server error'
        }
    )
    def get(self):
        """Get all cadre levels"""
        try:
            log_api_call('/api/cadre-levels/', 'GET')
            
            cadre_levels = CadreLevel.query.order_by(CadreLevel.level.asc()).all()
            
            return {
                'cadreLevels': [cl.to_dict() for cl in cadre_levels],
                'total': len(cadre_levels)
            }
        except Exception as e:
            cadre_levels_ns.abort(500, str(e))
