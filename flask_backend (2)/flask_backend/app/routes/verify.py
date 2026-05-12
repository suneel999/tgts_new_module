"""
Verification Routes for Telangana Congress Communication App
Public endpoints for member verification via QR code scanning
"""

from flask import current_app
from flask_restx import Namespace, Resource, fields
from sqlalchemy.orm import joinedload
from app.models import Member
from app.models.cadre_level import CadreLevel
from app import db

# Create namespace for verification
verify_ns = Namespace('verify', description='Public member verification operations')

# Response model for verification data (limited, non-sensitive fields)
verify_response_model = verify_ns.model('VerifyResponse', {
    'memberId': fields.String(description='14-character membership ID'),
    'fullName': fields.String(description='Full name'),
    'status': fields.String(description='Membership status (pending/approved/rejected)'),
    'profilePictureUrl': fields.String(description='Profile picture URL'),
    'partyDesignation': fields.String(description='Party designation'),
    'cadreLevel': fields.Integer(description='Cadre hierarchy level (1-10)'),
    'cadreLevelName': fields.String(description='Cadre level name in English'),
    'district': fields.String(description='District name'),
    'assemblyConstituency': fields.String(description='Assembly constituency name'),
    'isVerified': fields.Boolean(description='Whether the member is verified (approved)'),
})

verification_url_model = verify_ns.model('VerificationUrl', {
    'verificationBaseUrl': fields.String(description='Base URL of the admin frontend for verification pages'),
})


@verify_ns.route('/<string:member_id>')
@verify_ns.param('member_id', 'The 14-character membership ID (e.g., TS001000000001)')
class MemberVerification(Resource):
    @verify_ns.doc('verify_member', security=None)
    @verify_ns.response(200, 'Member verification data', verify_response_model)
    @verify_ns.response(404, 'Member not found')
    def get(self, member_id):
        """
        Public endpoint to verify a member by their membership ID.
        No authentication required - designed for QR code scanning.
        Returns limited, non-sensitive member information.
        """
        try:
            # Look up member by the TS-prefixed member_id
            member = Member.query.filter_by(member_id=member_id).first()

            if not member:
                return {
                    'message': 'Member not found',
                    'error': 'not_found'
                }, 404

            # Get district name from relationship
            district_name = None
            if member.district_ref:
                district_name = member.district_ref.name_en

            # Get assembly constituency name from relationship
            assembly_name = None
            if member.assembly_constituency_ref:
                assembly_name = member.assembly_constituency_ref.name_en

            # Get cadre level name from relationship
            cadre_level_name = None
            if member.cadre_level_ref:
                cadre_level_name = member.cadre_level_ref.name_en

            # Return only non-sensitive information
            return {
                'memberId': member.member_id,
                'fullName': member.full_name,
                'status': member.status,
                'profilePictureUrl': member.profile_picture_url,
                'partyDesignation': member.party_designation,
                'cadreLevel': member.cadre_level,
                'cadreLevelName': cadre_level_name,
                'district': district_name,
                'assemblyConstituency': assembly_name,
                'isVerified': member.status == 'approved',
            }, 200

        except Exception as e:
            current_app.logger.error(f"Error verifying member {member_id}: {str(e)}")
            return {
                'message': 'An error occurred while verifying the member',
                'error': 'internal_error'
            }, 500


@verify_ns.route('/settings/verification-url')
class VerificationUrl(Resource):
    @verify_ns.doc('get_verification_url', security=None)
    @verify_ns.response(200, 'Verification base URL', verification_url_model)
    def get(self):
        """
        Public endpoint to get the admin frontend base URL for verification pages.
        Used by the Flutter app to construct QR code URLs.
        """
        admin_url = current_app.config.get(
            'ADMIN_FRONTEND_URL',
            'https://main.d2i1qc8827fi7m.amplifyapp.com'
        )
        return {
            'verificationBaseUrl': admin_url
        }, 200
