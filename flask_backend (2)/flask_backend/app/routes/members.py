"""
Members Routes for Telangana Congress Communication App
Production-grade Flask-RESTX implementation with comprehensive error handling
"""

from flask import request, Response, make_response
from flask_restx import Namespace, Resource, fields
from flask_jwt_extended import jwt_required, verify_jwt_in_request, get_jwt_identity
from sqlalchemy.orm import joinedload
from app.models import Member, User, UserRole
from app import db
from app.utils.auth_utils import get_current_user, require_admin, require_cadre_or_admin
from app.utils.error_handling import validate_required_fields, log_api_call, APIError
from app.utils.timezone_utils import get_ist_now, parse_to_ist, ensure_ist_aware
from app.utils.geographic_access import get_user_geographic_info
from datetime import datetime
import uuid
import json

# Create namespace for members
members_ns = Namespace('members', description='Member management operations')

constituency_ref_model = members_ns.model('ConstituencyRef', {
    'id': fields.Integer(description='Constituency ID/Number'),
    'constituencyNumber': fields.Integer(description='Constituency Number'),
    'name_en': fields.String(description='Name in English'),
    'name_te': fields.String(description='Name in Telugu'),
    'state': fields.String(description='State')
})

# Define models directly in the namespace
member_model = members_ns.model('Member', {
    'id': fields.String(description='Member ID'),
    'memberId': fields.String(description='14-character membership ID (TS + 3-digit assembly + 9-digit counter)'),
    'fullName': fields.String(description='Full name'),
    'fatherName': fields.String(description='Father name'),
    'dateOfBirth': fields.String(description='Date of birth'),
    'gender': fields.String(description='Gender'),
    'phone': fields.String(description='Phone number'),
    'aadharNumber': fields.String(description='Aadhar number'),
    'epicNumber': fields.String(description='EPIC/Voter ID number'),
    'epicFileUrl': fields.String(description='EPIC card file URL'),
    'profilePictureUrl': fields.String(description='Profile picture URL'),
    'village': fields.String(description='Village'),
    'districtId': fields.Integer(description='District ID'),
    'mandalId': fields.Integer(description='Mandal ID'),
    'mandal': fields.String(description='Mandal name (derived from mandalId)'),
    'district': fields.String(description='District name (derived from districtId)'),
    'parliamentConstituencyId': fields.Integer(description='Parliament constituency ID'),
    'parliamentConstituencyRef': fields.Nested(constituency_ref_model, description='Parliament constituency details'),
    'assemblyConstituencyId': fields.Integer(description='Assembly constituency ID'),
    'assemblyConstituencyRef': fields.Nested(constituency_ref_model, description='Assembly constituency details'),
    'fullAddress': fields.String(description='Full address'),
    'partyDesignation': fields.String(description='Party designation'),
    'cadreLevel': fields.Integer(description='Cadre hierarchy level (1-10)'),
    'cadreLevelRef': fields.Raw(description='Cadre level details object'),
    'occupation': fields.String(description='Occupation'),
    'volunteerInterest': fields.Boolean(description='Volunteer interest'),
    'hasInsurance': fields.Boolean(description='Has insurance'),
    'insuranceNumber': fields.String(description='Insurance number'),
    'status': fields.String(description='Status'),
    'isActive': fields.Boolean(description='Is active'),
    'role': fields.String(description='Role of the member', default='public'),
    'createdAt': fields.String(description='Creation timestamp'),
    'updatedAt': fields.String(description='Last update timestamp')
})

member_create_model = members_ns.model('Member Create', {
    'fullName': fields.String(required=True, description='Full name'),
    'fatherName': fields.String(description='Father name'),
    'dateOfBirth': fields.String(description='Date of birth (YYYY-MM-DD)'),
    'gender': fields.String(description='Gender (male/female/other)'),
    'phone': fields.String(required=True, description='Phone number'),
    'aadharNumber': fields.String(description='Aadhar number'),
    'epicNumber': fields.String(description='EPIC/Voter ID number'),
    'epicFileUrl': fields.String(description='EPIC card file URL'),
    'profilePictureUrl': fields.String(description='Profile picture URL'),
    'village': fields.String(description='Village'),
    'districtId': fields.Integer(description='District ID'),
    'mandalId': fields.Integer(description='Mandal ID'),
    'parliamentConstituencyId': fields.Integer(description='Parliament constituency ID'),
    'assemblyConstituencyId': fields.Integer(description='Assembly constituency ID'),
    'fullAddress': fields.String(description='Full address'),
    'partyDesignation': fields.String(description='Party designation'),
    'occupation': fields.String(description='Occupation'),
    'volunteerInterest': fields.Boolean(description='Volunteer interest', default=False),
    'hasInsurance': fields.Boolean(description='Has insurance', default=False),
    'insuranceNumber': fields.String(description='Insurance number'),
    'role': fields.String(description='Role of the member', default='public')
})

@members_ns.route('/')
class MembersList(Resource):
    @members_ns.doc(
        summary='Get all members',
        description='Retrieves a paginated list of all members (admin/cadre only)',
        params={
            'page': 'Page number (default: 1)',
            'per_page': 'Items per page (default: 20)',
            'status': 'Filter by status (pending/approved/rejected)',
            'district_id': 'Filter by district ID',
            'search': 'Search by name or phone'
        },
        responses={
            200: 'Members retrieved successfully',
            401: 'Authentication required',
            403: 'Admin or Cadre access required',
            500: 'Internal server error'
        }
    )
    def get(self):
        """Get all members (admin/cadre only) - filtered by user's geographic location"""
        try:
            # Check authentication
            verify_jwt_in_request(optional=False)
            current_user = get_current_user()
            log_api_call('/api/members/', 'GET', current_user.id)
            
            if current_user.role not in [UserRole.ADMIN, UserRole.CADRE]:
                members_ns.abort(403, 'Admin or Cadre access required')
            
            page = request.args.get('page', 1, type=int)
            per_page = min(request.args.get('per_page', 20, type=int), 100)
            status = request.args.get('status')
            district_id = request.args.get('district_id', type=int)
            mandal_id = request.args.get('mandal_id', type=int)
            parliament_constituency_id = request.args.get('parliament_constituency_id', type=int)
            assembly_constituency_id = request.args.get('assembly_constituency_id', type=int)
            search = request.args.get('search')
            
            # Get current user's geographic info
            user_geo_info = get_user_geographic_info(current_user)
            is_admin = user_geo_info.get('is_admin', False) or current_user.role == UserRole.ADMIN
            
            query = Member.query.options(joinedload(Member.role_details), joinedload(Member.cadre_level_ref))
            
            # Apply filters
            if status:
                query = query.filter_by(status=status)
            
            # Geographic filtering - admins see all, others see only their area
            if not is_admin:
                # Get user's geographic location
                user_district_id = user_geo_info.get('district_id')
                user_mandal_id = user_geo_info.get('mandal_id')
                user_parliament_id = user_geo_info.get('parliament_constituency_id')
                user_assembly_id = user_geo_info.get('assembly_constituency_id')
                
                # Build geographic filter: match district/mandal OR constituencies
                geographic_filters = []
                
                # District/Mandal group (AND logic within group)
                if user_district_id and user_mandal_id:
                    # User has both district and mandal - match both
                    geographic_filters.append(
                        db.and_(
                            Member.district_id == user_district_id,
                            Member.mandal_id == user_mandal_id
                        )
                    )
                elif user_district_id:
                    # User has only district - match district
                    geographic_filters.append(Member.district_id == user_district_id)
                elif user_mandal_id:
                    # User has only mandal - match mandal
                    geographic_filters.append(Member.mandal_id == user_mandal_id)
                
                # Constituencies group (AND logic within group)
                if user_parliament_id and user_assembly_id:
                    # User has both constituencies - match both
                    geographic_filters.append(
                        db.and_(
                            Member.parliament_constituency_id == user_parliament_id,
                            Member.assembly_constituency_id == user_assembly_id
                        )
                    )
                elif user_parliament_id:
                    # User has only parliamentary constituency
                    geographic_filters.append(Member.parliament_constituency_id == user_parliament_id)
                elif user_assembly_id:
                    # User has only assembly constituency
                    geographic_filters.append(Member.assembly_constituency_id == user_assembly_id)
                
                # Apply OR logic between groups (if user matches district/mandal OR constituencies)
                if geographic_filters:
                    query = query.filter(db.or_(*geographic_filters))
                else:
                    # User has no geographic info - return empty result
                    query = query.filter(False)
            
            # Manual filters (override geographic filter if admin explicitly specifies)
            if is_admin:
                if district_id:
                    query = query.filter_by(district_id=district_id)
                if mandal_id:
                    query = query.filter_by(mandal_id=mandal_id)
                if parliament_constituency_id:
                    query = query.filter_by(parliament_constituency_id=parliament_constituency_id)
                if assembly_constituency_id:
                    query = query.filter_by(assembly_constituency_id=assembly_constituency_id)
            
            if search:
                search_term = f'%{search}%'
                query = query.filter(
                    db.or_(
                        Member.full_name.ilike(search_term),
                        Member.phone.ilike(search_term),
                        Member.epic_number.ilike(search_term)
                    )
                )
            
            members = query.order_by(Member.created_at.desc()).paginate(
                page=page, per_page=per_page, error_out=False
            )
            
            # Return format matching frontend expectations
            response_data = {
                'data': [member.to_dict() for member in members.items],
                'page': page,
                'per_page': per_page,
                'total': members.total,
                'total_pages': members.pages
            }
            
            return Response(
                response=json.dumps(response_data),
                status=200,
                mimetype='application/json'
            )
            
        except Exception as e:
            members_ns.abort(500, str(e))
    
    @members_ns.expect(member_create_model)
    @members_ns.doc(
        summary='Create member',
        description='Creates a new member registration (public endpoint)',
        responses={
            201: 'Member created successfully',
            400: 'Validation error',
            409: 'Member with phone/Aadhar/EPIC already exists',
            500: 'Internal server error'
        }
    )
    def post(self):
        """Create member (public endpoint)"""
        try:
            log_api_call('/api/members/', 'POST')
            
            data = request.get_json()
            if not data:
                members_ns.abort(400, 'Request body is required')
            
            validate_required_fields(data, ['fullName', 'phone'])
            
            # Check for duplicate phone, Aadhar, or EPIC
            if Member.query.filter_by(phone=data['phone']).first():
                members_ns.abort(409, 'Member with this phone number already exists')
            
            if data.get('aadharNumber') and Member.query.filter_by(aadhar_number=data['aadharNumber']).first():
                members_ns.abort(409, 'Member with this Aadhar number already exists')
            
            if data.get('epicNumber') and Member.query.filter_by(epic_number=data['epicNumber']).first():
                members_ns.abort(409, 'Member with this EPIC number already exists')
            
            # Parse date of birth if provided
            date_of_birth = None
            if data.get('dateOfBirth'):
                try:
                    date_of_birth = datetime.strptime(data['dateOfBirth'], '%Y-%m-%d').date()
                except ValueError:
                    members_ns.abort(400, 'Invalid date format. Use YYYY-MM-DD')
            
            # Convert hasInsurance string to boolean if needed
            has_insurance = data.get('hasInsurance', False)
            if isinstance(has_insurance, str):
                has_insurance = has_insurance.lower() in ['true', 'yes', '1']

            # Resolve district_id: accept integer districtId OR string district name
            resolved_district_id = data.get('districtId')
            if resolved_district_id is None and data.get('district'):
                from app.models.district import District as DistrictModel
                d_obj = DistrictModel.query.filter(
                    db.or_(DistrictModel.name_en.ilike(data['district']), DistrictModel.name_te.ilike(data['district']))
                ).first()
                if d_obj:
                    resolved_district_id = d_obj.id

            # Resolve mandal_id: accept integer mandalId OR string mandal name
            resolved_mandal_id = data.get('mandalId')
            if resolved_mandal_id is None and data.get('mandal'):
                from app.models.mandal import Mandal as MandalModel
                m_obj = MandalModel.query.filter(
                    db.or_(MandalModel.name_en.ilike(data['mandal']), MandalModel.name_te.ilike(data['mandal']))
                ).first()
                if m_obj:
                    resolved_mandal_id = m_obj.id

            member = Member(
                id=str(uuid.uuid4()),
                full_name=data['fullName'],
                father_name=data.get('fatherName'),
                date_of_birth=date_of_birth,
                gender=data.get('gender'),
                phone=data['phone'],
                aadhar_number=data.get('aadharNumber'),
                epic_number=data.get('epicNumber'),
                epic_file_url=data.get('epicFileUrl'),
                village=data.get('village'),
                district_id=resolved_district_id,
                mandal_id=resolved_mandal_id,
                parliament_constituency_id=data.get('parliamentConstituencyId'),
                assembly_constituency_id=data.get('assemblyConstituencyId'),
                full_address=data.get('fullAddress'),
                party_designation=data.get('partyDesignation'),
                occupation=data.get('occupation'),
                volunteer_interest=data.get('volunteerInterest', False),
                has_insurance=has_insurance,
                insurance_number=data.get('insuranceNumber'),
                status='pending',
                role=data.get('role', 'public')
            )
            
            # Generate member_id using new format: TS + 3-digit assembly + 9-digit counter
            assembly_id = data.get('assemblyConstituencyId')
            generated_id = Member.generate_member_id(assembly_constituency_id=assembly_id)
            
            # Check for uniqueness (should be rare, but safety check)
            max_attempts = 10
            for attempt in range(max_attempts):
                existing = Member.query.filter_by(member_id=generated_id).first()
                if not existing:
                    member.member_id = generated_id
                    break
                # If collision, get next counter and try again
                if attempt < max_attempts - 1:
                    counter = Member.get_next_counter()
                    generated_id = Member.generate_member_id(assembly_constituency_id=assembly_id, counter=counter)
                else:
                    # Last attempt failed - this should be extremely rare
                    import logging
                    logger = logging.getLogger(__name__)
                    logger.warning(f"Failed to generate unique member_id after {max_attempts} attempts")
                    # Still assign the ID - database unique constraint will catch if truly duplicate
                    member.member_id = generated_id
            
            db.session.add(member)
            
            # Create or update User record for this member
            # Check if user already exists with this phone
            existing_user = User.query.filter_by(phone=data['phone']).first()
            if not existing_user:
                # Get region name from resolved district/mandal IDs
                region = None
                if resolved_district_id:
                    from app.models.district import District
                    district = District.query.get(resolved_district_id)
                    if district:
                        region = district.name_en
                elif resolved_mandal_id:
                    from app.models.mandal import Mandal
                    mandal = Mandal.query.get(resolved_mandal_id)
                    if mandal:
                        region = mandal.name_en

                user = User(
                    id=str(uuid.uuid4()),
                    phone=data['phone'],
                    name=data['fullName'],
                    role=UserRole.PUBLIC,
                    region=region,
                    is_active=True
                )
                db.session.add(user)
            else:
                # Update existing user's name if it's different
                if existing_user.name != data['fullName']:
                    existing_user.name = data['fullName']
                # Update region if available
                if resolved_district_id and not existing_user.region:
                    from app.models.district import District
                    district = District.query.get(resolved_district_id)
                    if district:
                        existing_user.region = district.name_en
                elif resolved_mandal_id and not existing_user.region:
                    from app.models.mandal import Mandal
                    mandal = Mandal.query.get(resolved_mandal_id)
                    if mandal:
                        existing_user.region = mandal.name_en
            
            db.session.commit()
            
            return member.to_dict(), 201
            
        except APIError as e:
            members_ns.abort(e.status_code, e.message)
        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.error(f"Error creating member: {str(e)}", exc_info=True)
            members_ns.abort(400, f'Failed to create member: {str(e)}')

@members_ns.route('/<member_id>')
class MemberDetail(Resource):
    @members_ns.doc(
        summary='Get specific member',
        description='Retrieves a specific member by ID (admin/cadre only)',
        params={'member_id': 'Member ID'},
        responses={
            200: 'Member retrieved successfully',
            401: 'Authentication required',
            403: 'Admin or Cadre access required',
            404: 'Member not found',
            500: 'Internal server error'
        }
    )
    def get(self, member_id):
        """Get specific member (admin/cadre only)"""
        try:
            verify_jwt_in_request(optional=False)
            current_user = get_current_user()
            log_api_call(f'/api/members/{member_id}', 'GET', current_user.id)
            
            if current_user.role not in [UserRole.ADMIN, UserRole.CADRE]:
                members_ns.abort(403, 'Admin or Cadre access required')
            
            member = Member.query.options(
                joinedload(Member.role_details),
                joinedload(Member.cadre_level_ref)
            ).get(member_id)
            if not member:
                members_ns.abort(404, 'Member not found')
            
            return member.to_dict()
            
        except Exception as e:
            members_ns.abort(404, str(e))
    
    @jwt_required()
    @members_ns.expect(member_create_model)
    @members_ns.doc(
        security='Bearer',
        summary='Update member',
        description='Updates a member (admin only)',
        params={'member_id': 'Member ID'},
        responses={
            200: 'Member updated successfully',
            400: 'Validation error',
            401: 'Authentication required',
            403: 'Admin access required',
            404: 'Member not found',
            500: 'Internal server error'
        }
    )
    def put(self, member_id):
        """Update member (admin only)"""
        try:
            current_user = get_current_user()
            log_api_call(f'/api/members/{member_id}', 'PUT', current_user.id)
            
            if current_user.role != UserRole.ADMIN:
                members_ns.abort(403, 'Admin access required')
            
            member = Member.query.options(
                joinedload(Member.role_details),
                joinedload(Member.cadre_level_ref)
            ).get(member_id)
            if not member:
                members_ns.abort(404, 'Member not found')
            
            # Store old phone to find associated user
            old_phone = member.phone
            
            data = request.get_json()
            if not data:
                members_ns.abort(400, 'Request body is required')
            
            # Update fields
            if 'fullName' in data:
                member.full_name = data['fullName']
            if 'fatherName' in data:
                member.father_name = data.get('fatherName')
            if 'dateOfBirth' in data:
                if data['dateOfBirth']:
                    try:
                        member.date_of_birth = datetime.strptime(data['dateOfBirth'], '%Y-%m-%d').date()
                    except ValueError:
                        members_ns.abort(400, 'Invalid date format. Use YYYY-MM-DD')
                else:
                    member.date_of_birth = None
            if 'gender' in data:
                member.gender = data.get('gender')
            if 'phone' in data:
                # Check for duplicate phone
                existing = Member.query.filter_by(phone=data['phone']).first()
                if existing and existing.id != member_id:
                    members_ns.abort(409, 'Member with this phone number already exists')
                member.phone = data['phone']
            if 'aadharNumber' in data:
                if data['aadharNumber']:
                    existing = Member.query.filter_by(aadhar_number=data['aadharNumber']).first()
                    if existing and existing.id != member_id:
                        members_ns.abort(409, 'Member with this Aadhar number already exists')
                member.aadhar_number = data.get('aadharNumber')
            if 'epicNumber' in data:
                if data['epicNumber']:
                    existing = Member.query.filter_by(epic_number=data['epicNumber']).first()
                    if existing and existing.id != member_id:
                        members_ns.abort(409, 'Member with this EPIC number already exists')
                member.epic_number = data.get('epicNumber')
            if 'epicFileUrl' in data:
                member.epic_file_url = data.get('epicFileUrl')
            if 'village' in data:
                member.village = data.get('village')
            # Resolve district_id: accept integer districtId OR string district name
            if 'districtId' in data:
                member.district_id = data.get('districtId')
            elif 'district' in data:
                district_name = data.get('district')
                if district_name:
                    from app.models.district import District as DistrictModel
                    d_obj = DistrictModel.query.filter(
                        db.or_(DistrictModel.name_en.ilike(district_name), DistrictModel.name_te.ilike(district_name))
                    ).first()
                    if d_obj:
                        member.district_id = d_obj.id
                else:
                    member.district_id = None

            # Resolve mandal_id: accept integer mandalId OR string mandal name
            if 'mandalId' in data:
                member.mandal_id = data.get('mandalId')
            elif 'mandal' in data:
                mandal_name = data.get('mandal')
                if mandal_name:
                    from app.models.mandal import Mandal as MandalModel
                    m_obj = MandalModel.query.filter(
                        db.or_(MandalModel.name_en.ilike(mandal_name), MandalModel.name_te.ilike(mandal_name))
                    ).first()
                    if m_obj:
                        member.mandal_id = m_obj.id
                else:
                    member.mandal_id = None

            if 'parliamentConstituencyId' in data:
                member.parliament_constituency_id = data.get('parliamentConstituencyId')
            if 'assemblyConstituencyId' in data:
                member.assembly_constituency_id = data.get('assemblyConstituencyId')
            if 'fullAddress' in data:
                member.full_address = data.get('fullAddress')
            if 'partyDesignation' in data:
                member.party_designation = data.get('partyDesignation')
            if 'cadreLevel' in data:
                cadre_level_val = data.get('cadreLevel')
                if cadre_level_val is not None:
                    try:
                        cadre_level_int = int(cadre_level_val)
                        if 1 <= cadre_level_int <= 10:
                            member.cadre_level = cadre_level_int
                        else:
                            members_ns.abort(400, 'Cadre level must be between 1 and 10')
                    except (ValueError, TypeError):
                        members_ns.abort(400, 'Invalid cadre level value')
                else:
                    member.cadre_level = None
            if 'occupation' in data:
                member.occupation = data.get('occupation')
            if 'volunteerInterest' in data:
                member.volunteer_interest = data.get('volunteerInterest', False)
            if 'hasInsurance' in data:
                has_insurance = data.get('hasInsurance', False)
                if isinstance(has_insurance, str):
                    has_insurance = has_insurance.lower() in ['true', 'yes', '1']
                member.has_insurance = has_insurance
            if 'insuranceNumber' in data:
                member.insurance_number = data.get('insuranceNumber')
            if 'status' in data:
                member.status = data.get('status')
            if 'isActive' in data:
                member.is_active = data.get('isActive')
            if 'role' in data:
                member.role = data.get('role', 'public')
            
            # Sync changes to User model
            user = User.query.filter_by(phone=old_phone).first()
            if user:
                # Update phone if changed
                if 'phone' in data and data['phone'] != old_phone:
                    user.phone = data['phone']
                
                # Update name if changed
                if 'fullName' in data:
                    user.name = data['fullName']
                
                # Update role if changed
                if 'role' in data:
                    try:
                        role_str = data['role'].lower()
                        # Map 'public' to UserRole.PUBLIC, etc.
                        user.role = UserRole(role_str)
                    except ValueError:
                        # If invalid role string, ignore or default to public
                        pass
                
                # Update region if district/mandal changed (use resolved IDs from member)
                if 'districtId' in data or 'district' in data:
                    if member.district_id:
                        from app.models.district import District
                        district = District.query.get(member.district_id)
                        if district:
                            user.region = district.name_en
                elif 'mandalId' in data or 'mandal' in data:
                    if member.mandal_id:
                        from app.models.mandal import Mandal
                        mandal = Mandal.query.get(member.mandal_id)
                        if mandal:
                            user.region = mandal.name_en
            
            # Generate member_id if it doesn't exist using new format: TS + 3-digit assembly + 9-digit counter
            if not member.member_id:
                assembly_id = member.assembly_constituency_id
                generated_id = Member.generate_member_id(assembly_constituency_id=assembly_id)
                
                # Check for uniqueness (should be rare, but safety check)
                max_attempts = 10
                for attempt in range(max_attempts):
                    existing = Member.query.filter_by(member_id=generated_id).first()
                    if not existing or existing.id == member.id:
                        member.member_id = generated_id
                        break
                    # If collision, get next counter and try again
                    if attempt < max_attempts - 1:
                        counter = Member.get_next_counter()
                        generated_id = Member.generate_member_id(assembly_constituency_id=assembly_id, counter=counter)
                    else:
                        # Last attempt failed - this should be extremely rare
                        import logging
                        logger = logging.getLogger(__name__)
                        logger.warning(f"Failed to generate unique member_id after {max_attempts} attempts")
                        # Still assign the ID - database unique constraint will catch if truly duplicate
                        member.member_id = generated_id

            db.session.commit()
            
            return member.to_dict()
            
        except APIError as e:
            members_ns.abort(e.status_code, e.message)
        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.error(f"Error updating member: {str(e)}", exc_info=True)
            members_ns.abort(400, f'Failed to update member: {str(e)}')

@members_ns.route('/initialize-ids')
class InitializeMemberIds(Resource):
    @jwt_required()
    @members_ns.doc(
        security='Bearer',
        summary='Initialize all membership IDs',
        description='Replaces all membership IDs for all members based on enrollment time. Admin only. Format: TS + 3-digit assembly + 9-digit counter. Existing IDs will be replaced.',
        responses={
            200: 'Membership IDs initialized successfully',
            401: 'Authentication required',
            403: 'Admin access required',
            500: 'Internal server error'
        }
    )
    def post(self):
        """Initialize all membership IDs based on enrollment time (admin only)"""
        try:
            current_user = get_current_user()
            log_api_call('/api/members/initialize-ids', 'POST', current_user.id)
            
            if current_user.role != UserRole.ADMIN:
                members_ns.abort(403, 'Admin access required')
            
            # Query all members ordered by enrollment time (created_at)
            members = Member.query.order_by(Member.created_at.asc()).all()
            
            if not members:
                return {
                    'message': 'No members found',
                    'total': 0,
                    'updated': 0,
                    'skipped': 0,
                    'errors': []
                }, 200
            
            updated_count = 0
            skipped_count = 0
            errors = []
            
            # Start counter from 1 - we're replacing all IDs based on enrollment order
            counter = 1
            
            # Process members in transaction
            try:
                for member in members:
                    try:
                        # Get assembly constituency ID or use 000 as default
                        assembly_id = member.assembly_constituency_id if member.assembly_constituency_id is not None else 0
                        
                        # Generate new membership ID
                        new_member_id = Member.generate_member_id(
                            assembly_constituency_id=assembly_id,
                            counter=counter
                        )
                        
                        # Check for uniqueness (shouldn't happen since we're generating sequentially, but safety check)
                        existing = Member.query.filter_by(member_id=new_member_id).first()
                        if existing and existing.id != member.id:
                            errors.append({
                                'member_id': member.id,
                                'name': member.full_name,
                                'error': f'Generated ID {new_member_id} already exists'
                            })
                            skipped_count += 1
                            continue
                        
                        # Replace member ID (even if it already exists)
                        old_member_id = member.member_id
                        member.member_id = new_member_id
                        updated_count += 1
                        counter += 1
                        
                    except Exception as e:
                        errors.append({
                            'member_id': member.id,
                            'name': member.full_name,
                            'error': str(e)
                        })
                        skipped_count += 1
                        continue
                
                # Commit all changes
                db.session.commit()
                
                return {
                    'message': 'Membership IDs initialized successfully',
                    'total': len(members),
                    'updated': updated_count,
                    'skipped': skipped_count,
                    'errors': errors
                }, 200
                
            except Exception as e:
                # Rollback on error
                db.session.rollback()
                raise e
                
        except APIError as e:
            members_ns.abort(e.status_code, e.message)
        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.error(f"Error initializing membership IDs: {str(e)}", exc_info=True)
            members_ns.abort(500, f'Failed to initialize membership IDs: {str(e)}')


@members_ns.route('/export/pdf')
class MemberExportPDF(Resource):
    @jwt_required()
    @members_ns.doc(
        security='Bearer',
        summary='Export voter list as PDF',
        description='Generate and download a paginated voter list PDF (admin/cadre only)',
        params={
            'status': 'Filter by status (pending/approved/rejected)',
            'district_id': 'Filter by district ID',
            'mandal_id': 'Filter by mandal ID',
            'parliament_constituency_id': 'Filter by parliament constituency ID',
            'assembly_constituency_id': 'Filter by assembly constituency ID',
            'search': 'Search by name, phone, or EPIC number',
        },
        responses={
            200: 'PDF generated successfully',
            401: 'Authentication required',
            403: 'Admin or Cadre access required',
            500: 'Internal server error',
        }
    )
    def get(self):
        """Generate and download voter list as PDF (admin/cadre only)"""
        try:
            verify_jwt_in_request(optional=False)
            current_user = get_current_user()
            log_api_call('/api/members/export/pdf', 'GET', current_user.id)

            if current_user.role not in [UserRole.ADMIN, UserRole.CADRE]:
                members_ns.abort(403, 'Admin or Cadre access required')

            status = request.args.get('status')
            district_id = request.args.get('district_id', type=int)
            mandal_id = request.args.get('mandal_id', type=int)
            parliament_constituency_id = request.args.get('parliament_constituency_id', type=int)
            assembly_constituency_id = request.args.get('assembly_constituency_id', type=int)
            search = request.args.get('search')

            user_geo_info = get_user_geographic_info(current_user)
            is_admin = user_geo_info.get('is_admin', False) or current_user.role == UserRole.ADMIN

            query = Member.query.options(
                joinedload(Member.role_details),
                joinedload(Member.cadre_level_ref)
            )

            if status:
                query = query.filter_by(status=status)

            # Geographic filtering — same logic as GET /
            if not is_admin:
                user_district_id = user_geo_info.get('district_id')
                user_mandal_id = user_geo_info.get('mandal_id')
                user_parliament_id = user_geo_info.get('parliament_constituency_id')
                user_assembly_id = user_geo_info.get('assembly_constituency_id')

                geographic_filters = []
                if user_district_id and user_mandal_id:
                    geographic_filters.append(db.and_(
                        Member.district_id == user_district_id,
                        Member.mandal_id == user_mandal_id
                    ))
                elif user_district_id:
                    geographic_filters.append(Member.district_id == user_district_id)
                elif user_mandal_id:
                    geographic_filters.append(Member.mandal_id == user_mandal_id)

                if user_parliament_id and user_assembly_id:
                    geographic_filters.append(db.and_(
                        Member.parliament_constituency_id == user_parliament_id,
                        Member.assembly_constituency_id == user_assembly_id
                    ))
                elif user_parliament_id:
                    geographic_filters.append(Member.parliament_constituency_id == user_parliament_id)
                elif user_assembly_id:
                    geographic_filters.append(Member.assembly_constituency_id == user_assembly_id)

                if geographic_filters:
                    query = query.filter(db.or_(*geographic_filters))
                else:
                    query = query.filter(False)
            else:
                if district_id:
                    query = query.filter_by(district_id=district_id)
                if mandal_id:
                    query = query.filter_by(mandal_id=mandal_id)
                if parliament_constituency_id:
                    query = query.filter_by(parliament_constituency_id=parliament_constituency_id)
                if assembly_constituency_id:
                    query = query.filter_by(assembly_constituency_id=assembly_constituency_id)

            if search:
                search_term = f'%{search}%'
                query = query.filter(db.or_(
                    Member.full_name.ilike(search_term),
                    Member.phone.ilike(search_term),
                    Member.epic_number.ilike(search_term)
                ))

            members = query.order_by(Member.created_at.desc()).all()

            # --- PDF generation ---
            from reportlab.lib.pagesizes import A4, landscape
            from reportlab.lib import colors
            from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
            from reportlab.lib.units import inch
            from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
            from io import BytesIO
            import pytz

            buffer = BytesIO()
            doc = SimpleDocTemplate(
                buffer,
                pagesize=landscape(A4),
                rightMargin=0.5 * inch,
                leftMargin=0.5 * inch,
                topMargin=0.5 * inch,
                bottomMargin=0.5 * inch,
            )

            styles = getSampleStyleSheet()
            title_style = ParagraphStyle(
                'VoterTitle',
                parent=styles['Heading1'],
                fontSize=16,
                spaceAfter=4,
                alignment=1,
            )
            meta_style = ParagraphStyle(
                'VoterMeta',
                parent=styles['Normal'],
                fontSize=9,
                spaceAfter=8,
                alignment=1,
                textColor=colors.HexColor('#555555'),
            )

            ist_now = datetime.now(pytz.timezone('Asia/Kolkata'))
            elements = [
                Paragraph('Telangana Congress — Voter List', title_style),
            ]

            meta_parts = [f"Generated: {ist_now.strftime('%d %B %Y, %I:%M %p IST')}"]
            if status:
                meta_parts.append(f"Status: {status.capitalize()}")
            elements.append(Paragraph(' | '.join(meta_parts), meta_style))
            elements.append(Paragraph(f'Total Records: {len(members)}', meta_style))
            elements.append(Spacer(1, 0.12 * inch))

            # Table
            headers = ['#', 'Member ID', 'Full Name', 'Phone', 'EPIC No.',
                       'Village', 'District', 'Assembly Constituency', 'Status']
            table_data = [headers]

            for i, member in enumerate(members, 1):
                district_name = (
                    getattr(member.district_ref, 'name_en', '') or ''
                    if getattr(member, 'district_ref', None) else ''
                )
                assembly_name = (
                    getattr(member.assembly_constituency_ref, 'name_en', '') or ''
                    if getattr(member, 'assembly_constituency_ref', None) else ''
                )
                table_data.append([
                    str(i),
                    member.member_id or '',
                    member.full_name or '',
                    member.phone or '',
                    member.epic_number or '',
                    member.village or '',
                    district_name,
                    assembly_name,
                    (member.status or '').capitalize(),
                ])

            col_widths = [
                0.35 * inch,  # #
                1.30 * inch,  # Member ID
                1.70 * inch,  # Full Name
                1.10 * inch,  # Phone
                1.10 * inch,  # EPIC No.
                1.00 * inch,  # Village
                1.20 * inch,  # District
                1.50 * inch,  # Assembly Constituency
                0.85 * inch,  # Status
            ]

            table = Table(table_data, colWidths=col_widths, repeatRows=1)
            table.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#006400')),
                ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
                ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
                ('FONTSIZE', (0, 0), (-1, 0), 8),
                ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
                ('FONTSIZE', (0, 1), (-1, -1), 7.5),
                ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#F2F8F5')]),
                ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#CCCCCC')),
                ('TOPPADDING', (0, 0), (-1, -1), 4),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
                ('LEFTPADDING', (0, 0), (-1, -1), 4),
                ('RIGHTPADDING', (0, 0), (-1, -1), 4),
            ]))

            elements.append(table)
            doc.build(elements)

            buffer.seek(0)
            pdf_bytes = buffer.getvalue()
            buffer.close()

            filename = f"voter_list_{ist_now.strftime('%Y%m%d_%H%M%S')}.pdf"
            resp = make_response(pdf_bytes)
            resp.headers['Content-Type'] = 'application/pdf'
            resp.headers['Content-Disposition'] = f'attachment; filename="{filename}"'
            resp.headers['Content-Length'] = str(len(pdf_bytes))
            return resp

        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.error(f"Error generating voter list PDF: {str(e)}", exc_info=True)
            members_ns.abort(500, f'Failed to generate PDF: {str(e)}')
