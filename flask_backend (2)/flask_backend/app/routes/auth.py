"""
Authentication Routes for Telangana Congress Communication App
Production-grade Flask-RESTX implementation with comprehensive error handling
"""

from flask import request, jsonify
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity
from flask_restx import Namespace, Resource, fields
from app.models import User, UserRole, Member
from app import db
from app.utils.auth_utils import generate_otp, store_otp, verify_otp, get_current_user
from app.utils.error_handling import validate_required_fields, validate_phone_number, validate_otp, log_api_call, APIError
from app.services.twilio_service import twilio_service
import uuid
from app.services.aws_service import aws_sns

# Create namespace for authentication
auth_ns = Namespace('auth', description='Authentication operations')

# Add error handler for APIError just after namespace definition
@auth_ns.errorhandler(APIError)
def handle_api_error(error):
    """Return a JSON response for APIError exceptions"""
    return {'message': error.message}, error.status_code

# Define models directly in the namespace
login_model = auth_ns.model('Login', {
    'phone': fields.String(required=True, description='Phone number', example='9876543210')
})

otp_model = auth_ns.model('OTP Verification', {
    'phone': fields.String(required=True, description='Phone number', example='9876543210'),
    'otp': fields.String(required=True, description='OTP code', example='123456')
})

constituency_ref_model = auth_ns.model('ConstituencyRef', {
    'id': fields.Integer(description='Constituency ID/Number'),
    'constituencyNumber': fields.Integer(description='Constituency Number'),
    'name_en': fields.String(description='Name in English'),
    'name_te': fields.String(description='Name in Telugu'),
    'state': fields.String(description='State')
})

user_model = auth_ns.model('User', {
    'id': fields.String(description='User ID'),
    'memberId': fields.String(description='12-digit alphanumeric member ID'),
    'phone': fields.String(description='Phone number'),
    'name': fields.String(description='User name'),
    'role': fields.String(description='User role (public, cadre, admin)'),
    'region': fields.String(description='User region'),
    'is_active': fields.Boolean(description='User active status'),
    'created_at': fields.String(description='Creation timestamp'),
    'updated_at': fields.String(description='Last update timestamp'),
    # Member fields
    'fullName': fields.String(description='Full Name'),
    'fatherName': fields.String(description='Father Name'),
    'dateOfBirth': fields.String(description='Date of Birth'),
    'gender': fields.String(description='Gender'),
    'aadharNumber': fields.String(description='Aadhar Number'),
    'epicNumber': fields.String(description='Voter ID (EPIC)'),
    'epicFileUrl': fields.String(description='EPIC File URL'),
    'profilePictureUrl': fields.String(description='Profile Picture URL'),
    'village': fields.String(description='Village'),
    'mandal': fields.String(description='Mandal'),
    'district': fields.String(description='District'),
    'parliamentConstituencyId': fields.Integer(description='Parliament Constituency ID'),
    'parliamentConstituencyRef': fields.Nested(constituency_ref_model, description='Parliament Constituency Details'),
    'assemblyConstituencyId': fields.Integer(description='Assembly Constituency ID'),
    'assemblyConstituencyRef': fields.Nested(constituency_ref_model, description='Assembly Constituency Details'),
    'fullAddress': fields.String(description='Full Address'),
    'partyDesignation': fields.String(description='Party Designation'),
    'cadreLevel': fields.Integer(description='Cadre hierarchy level (1-10)'),
    'cadreLevelRef': fields.Nested(auth_ns.model('CadreLevelRef', {
        'level': fields.Integer(description='Level number'),
        'nameEn': fields.String(description='Level name in English'),
        'nameTe': fields.String(description='Level name in Telugu'),
        'geographicScope': fields.String(description='Geographic scope'),
    }), description='Cadre level details', allow_null=True),
    'occupation': fields.String(description='Occupation'),
    'volunteerInterest': fields.Boolean(description='Volunteer Interest'),
    'hasInsurance': fields.Boolean(description='Has Insurance'),
    'insuranceNumber': fields.String(description='Insurance Number'),
    'status': fields.String(description='Member Status'),
})

profile_update_model = auth_ns.model('Profile Update', {
    'name': fields.String(description='User name', example='John Doe'),
    'region': fields.String(description='User region', example='Hyderabad'),
    'fullName': fields.String(description='Full Name', example='John Doe'),
    'fatherName': fields.String(description='Father Name', example='Father Name'),
    'dateOfBirth': fields.String(description='Date of Birth (YYYY-MM-DD)', example='1990-01-01'),
    'gender': fields.String(description='Gender', example='male'),
    'aadharNumber': fields.String(description='Aadhar Number', example='123456789012'),
    'epicNumber': fields.String(description='Voter ID (EPIC)', example='ABC1234567'),
    'village': fields.String(description='Village', example='Village Name'),
    'mandal': fields.String(description='Mandal', example='Mandal Name'),
    'district': fields.String(description='District', example='District Name'),
    'parliamentConstituencyId': fields.Integer(description='Parliament Constituency ID', example=1),
    'assemblyConstituencyId': fields.Integer(description='Assembly Constituency ID', example=1),
    'fullAddress': fields.String(description='Full Address', example='Complete Address'),
    'partyDesignation': fields.String(description='Party Designation', example='Member'),
    'cadreLevel': fields.Integer(description='Cadre hierarchy level (1-10)', example=10),
    'occupation': fields.String(description='Occupation', example='Farmer'),
    'volunteerInterest': fields.Boolean(description='Volunteer Interest', example=True),
    'hasInsurance': fields.Boolean(description='Has Insurance', example=False),
    'insuranceNumber': fields.String(description='Insurance Number', example='INS123456'),
    'profilePictureUrl': fields.String(description='Profile Picture URL')
})

admin_login_model = auth_ns.model('Admin Login', {
    'username': fields.String(required=True, description='Admin username', example='admin'),
    'password': fields.String(required=True, description='Admin password', example='admin')
})

@auth_ns.route('/login')
class Login(Resource):
    @auth_ns.expect(login_model)
    @auth_ns.marshal_with(auth_ns.model('Login Response', {
        'message': fields.String,
        'otp': fields.String,
        'phone': fields.String
    }))
    @auth_ns.doc(
        summary='Send OTP to phone number',
        description='Sends a 6-digit OTP to the provided phone number for authentication',
        responses={
            200: 'OTP sent successfully',
            400: 'Invalid phone number format',
            500: 'Internal server error'
        }
    )
    def post(self):
        """Send OTP to phone number"""
        try:
            data = request.get_json()
            validate_required_fields(data, ['phone'])
            
            phone = data['phone']
            validate_phone_number(phone)
            
            log_api_call('/api/auth/login', 'POST')
            
            # Generate OTP
            otp = generate_otp()
            
            # Store OTP with expiry time (5 minutes from now)
            store_otp(phone, otp, expiry_minutes=5)
            
            # Send OTP via Twilio SMS
            sms_result = twilio_service.send_otp_sms(phone, otp)
            # sms_result = aws_sns.send_otp_sms(phone, otp)

            if sms_result['success']:
                # DEBUG: Print OTP to console for easy debugging in development
                # TODO: Remove this print statement before production deployment
                print(f"🔐 DEBUG OTP for {phone}: {otp}")
                
                return {
                    'message': 'OTP sent successfully via SMS',
                    'phone': phone,
                    'message_id': sms_result['message_id']
                }
            else:
                # If SMS fails, still return OTP for testing/fallback
                print(f"⚠️ SMS failed for {phone}: {sms_result['error']}")
                print(f"🔐 DEBUG OTP for {phone}: {otp}")
                
                return {
                    'message': 'OTP generated (SMS failed, check console for OTP)',
                    'otp': otp,  # Fallback for development/testing
                    'phone': phone,
                    'sms_error': sms_result['error']
                }
            
        except Exception as e:
            if isinstance(e, APIError):
                return jsonify({'error': e.message}), e.status_code
            else:
                return jsonify({'error': str(e)}), 400

@auth_ns.route('/verify-otp')
class VerifyOTP(Resource):
    @auth_ns.expect(otp_model)
    @auth_ns.marshal_with(auth_ns.model('OTP Response', {
        'access_token': fields.String,
        'user': fields.Nested(user_model),
        'message': fields.String
    }))
    @auth_ns.doc(
        summary='Verify OTP and authenticate user',
        description='Verifies the OTP and creates/logs in the user, returning a JWT token',
        responses={
            200: 'Login successful',
            400: 'Invalid OTP or phone number',
            500: 'Internal server error'
        }
    )
    def post(self):
        """Verify OTP and create/login user"""
        data = request.get_json()
        
        # Validate required fields
        if not data or 'phone' not in data or 'otp' not in data:
            return {'message': 'Phone number and OTP are required'}, 400
        
        phone = data['phone']
        otp = data['otp']
        
        # Validate phone number format
        if not phone or len(phone) != 10 or not phone.isdigit():
            return {'message': 'Invalid phone number format. Must be 10 digits.'}, 400
        
        # Validate OTP format
        if not otp or len(otp) != 6 or not otp.isdigit():
            return {'message': 'Invalid OTP format. Must be 6 digits.'}, 400
        
        log_api_call('/api/auth/verify-otp', 'POST')
        
        # Verify OTP
        try:
            verify_otp(phone, otp)
        except APIError as e:
            return {'message': e.message}, e.status_code
        except Exception as e:
            return {'message': 'OTP verification failed'}, 400
        
        # Check if user exists
        user = User.query.filter_by(phone=phone).first()
        
        if not user:
            # Create new user
            user = User(
                id=str(uuid.uuid4()),
                phone=phone,
                name=f'User_{phone[-4:]}',  # Default name
                role=UserRole.PUBLIC
            )
            db.session.add(user)
            db.session.commit()
        
        # Get user data
        user_data = user.to_dict()
        
        # Check if user has membership and merge member data if exists
        from sqlalchemy.orm import selectinload
        member = Member.query.options(
            selectinload(Member.parliamentary_constituency_ref),
            selectinload(Member.assembly_constituency_ref),
            selectinload(Member.cadre_level_ref)
        ).filter_by(phone=user.phone).first()
        
        if member:
            # Merge member data into user data
            member_data = member.to_dict()
            # IMPORTANT: Preserve user's ID - don't let member's ID overwrite it
            user_id = user_data['id']
            user_data.update(member_data)
            user_data['id'] = user_id  # Restore user's ID after merge
            print(f"✅ verify-otp: User {user.phone} HAS membership - fullName={member_data.get('fullName')}, status={member_data.get('status')}")
        else:
            print(f"❌ verify-otp: User {user.phone} does NOT have membership")
        
        # Generate JWT token
        access_token = create_access_token(identity=user.id)
        
        return {
            'message': 'Login successful',
            'access_token': access_token,
            'user': user_data
        }

@auth_ns.route('/profile')
class Profile(Resource):
    @auth_ns.marshal_with(user_model)
    @auth_ns.doc(
        security='Bearer',
        summary='Get current user profile',
        description='Retrieves the profile information of the currently authenticated user',
        responses={
            200: 'User profile retrieved successfully',
            401: 'Authentication required',
            404: 'User not found'
        }
    )
    @jwt_required()
    def get(self):
        """Get current user profile (requires authentication)"""
        try:
            log_api_call('/api/auth/profile', 'GET')
            user = get_current_user()
            user_data = user.to_dict()
            
            # Try to fetch member details using phone number
            # Eagerly load constituency relationships using selectinload for better performance
            from sqlalchemy.orm import selectinload
            member = Member.query.options(
                selectinload(Member.parliamentary_constituency_ref),
                selectinload(Member.assembly_constituency_ref),
                selectinload(Member.district_ref),
                selectinload(Member.mandal_ref),
                selectinload(Member.cadre_level_ref)
            ).filter_by(phone=user.phone).first()
            
            if member:
                print(f"🔵 Profile: Found member for phone {user.phone}")
                print(f"🔵 Profile: member.district_id = {member.district_id}, member.mandal_id = {member.mandal_id}")
                member_data = member.to_dict()
                print(f"🔵 Profile: member_data['districtId'] = {member_data.get('districtId')}, member_data['mandalId'] = {member_data.get('mandalId')}")
                # Merge member data into user data, keeping user data as primary for conflicting keys
                # IMPORTANT: Preserve user's ID - don't let member's ID overwrite it
                user_id = user_data['id']
                user_data.update(member_data)
                user_data['id'] = user_id  # Restore user's ID after merge
                print(f"🔵 Profile: After merge, user_data['districtId'] = {user_data.get('districtId')}, user_data['mandalId'] = {user_data.get('mandalId')}")
            else:
                print(f"⚠️ Profile: No member found for phone {user.phone}")
                
            return user_data
            
        except Exception as e:
            auth_ns.abort(401 if 'Authentication required' in str(e) else 404, str(e))
    
    @auth_ns.expect(profile_update_model)
    @auth_ns.marshal_with(user_model)
    @auth_ns.doc(
        security='Bearer',
        summary='Update user profile',
        description='Updates the profile information of the currently authenticated user',
        responses={
            200: 'Profile updated successfully',
            401: 'Authentication required',
            404: 'User not found'
        }
    )
    @jwt_required()
    def put(self):
        """Update user profile (requires authentication)"""
        try:
            log_api_call('/api/auth/profile', 'PUT')
            user = get_current_user()
            
            data = request.get_json()
            if not data:
                auth_ns.abort(400, 'Request body is required')
            
            # Update User model fields
            if 'name' in data:
                user.name = data['name']
            if 'region' in data:
                user.region = data['region']

            # Always persist location on the User row so public (non-member) users
            # also get local news filtered by district/mandal.
            if 'districtId' in data:
                user.district_id = data.get('districtId')
            if 'mandalId' in data:
                user.mandal_id = data.get('mandalId')
            if 'parliamentConstituencyId' in data:
                user.parliament_constituency_id = data.get('parliamentConstituencyId')
            if 'assemblyConstituencyId' in data:
                user.assembly_constituency_id = data.get('assemblyConstituencyId')

            # Try to find and update Member record if it exists
            member = Member.query.filter_by(phone=user.phone).first()
            
            # Update Member model fields if member exists
            if member:
                if 'fullName' in data:
                    member.full_name = data['fullName']
                if 'fatherName' in data:
                    member.father_name = data.get('fatherName')
                if 'dateOfBirth' in data:
                    if data['dateOfBirth']:
                        try:
                            from datetime import datetime
                            member.date_of_birth = datetime.strptime(data['dateOfBirth'], '%Y-%m-%d').date()
                        except ValueError:
                            auth_ns.abort(400, 'Invalid date format. Use YYYY-MM-DD')
                    else:
                        member.date_of_birth = None
                if 'gender' in data:
                    member.gender = data.get('gender')
                if 'aadharNumber' in data:
                    member.aadhar_number = data.get('aadharNumber')
                if 'epicNumber' in data:
                    member.epic_number = data.get('epicNumber')
                if 'village' in data:
                    member.village = data.get('village')
                if 'districtId' in data:
                    member.district_id = data.get('districtId')
                if 'mandalId' in data:
                    member.mandal_id = data.get('mandalId')
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
                        # Validate cadre level is between 1-10
                        try:
                            cadre_level_int = int(cadre_level_val)
                            if 1 <= cadre_level_int <= 10:
                                member.cadre_level = cadre_level_int
                            else:
                                auth_ns.abort(400, 'Cadre level must be between 1 and 10')
                        except (ValueError, TypeError):
                            auth_ns.abort(400, 'Invalid cadre level value')
                    else:
                        member.cadre_level = None
                if 'occupation' in data:
                    member.occupation = data.get('occupation')
                if 'volunteerInterest' in data:
                    member.volunteer_interest = data.get('volunteerInterest', False)
                if 'hasInsurance' in data:
                    member.has_insurance = data.get('hasInsurance', False)
                if 'insuranceNumber' in data:
                    member.insurance_number = data.get('insuranceNumber')
                if 'profilePictureUrl' in data:
                    member.profile_picture_url = data.get('profilePictureUrl')
                
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

            # Return updated user data with member data merged.
            # User ID and location fields take priority if member has no location.
            user_data = user.to_dict()
            if member:
                user_id = user_data['id']
                member_data = member.to_dict()
                # Member location takes priority for cadre/admin (their location is in members table)
                user_data.update(member_data)
                user_data['id'] = user_id
                # Fall back to user-level location if member has none
                if not user_data.get('districtId') and user.district_id:
                    user_data['districtId'] = user.district_id
                    user_data['districtRef'] = user_data.get('districtRef') or user.to_dict().get('districtRef')
                if not user_data.get('mandalId') and user.mandal_id:
                    user_data['mandalId'] = user.mandal_id
                    user_data['mandalRef'] = user_data.get('mandalRef') or user.to_dict().get('mandalRef')

            return user_data
            
        except Exception as e:
            auth_ns.abort(401 if 'Authentication required' in str(e) else 404, str(e))

@auth_ns.route('/upload-profile-picture')
class UploadProfilePicture(Resource):
    @jwt_required()
    @auth_ns.doc(
        security='Bearer',
        summary='Upload profile picture',
        description='Uploads a profile picture to S3 in the profile-pictures folder and returns the URL',
        responses={
            200: 'Profile picture uploaded successfully',
            400: 'Validation error',
            401: 'Authentication required',
            500: 'Internal server error'
        }
    )
    def post(self):
        """Upload profile picture (requires authentication)"""
        try:
            log_api_call('/api/auth/upload-profile-picture', 'POST')
            user = get_current_user()
            
            # Check if file is present
            if 'file' not in request.files:
                auth_ns.abort(400, 'No file provided. Make sure the form field is named "file"')
            
            file = request.files['file']
            if file.filename == '':
                auth_ns.abort(400, 'No file selected')
            
            # Validate file type (images only)
            from werkzeug.utils import secure_filename
            from app.services.s3_service import get_s3_service
            import os
            import uuid
            import logging
            
            logger = logging.getLogger(__name__)
            
            allowed_extensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp'}
            filename = secure_filename(file.filename)
            file_ext = os.path.splitext(filename)[1].lower()
            
            if file_ext not in allowed_extensions:
                auth_ns.abort(400, f'Invalid image format. Allowed: {", ".join(allowed_extensions)}')
            
            # Generate unique filename using IST
            from app.utils.timezone_utils import get_ist_now
            timestamp = get_ist_now().strftime('%Y%m%d_%H%M%S')
            unique_filename = f"{user.id}_{timestamp}_{uuid.uuid4().hex[:8]}{file_ext}"
            
            # Upload to S3 in profile-pictures folder
            s3_service = get_s3_service()
            file_url = s3_service.upload_file(file, unique_filename, folder='profile-pictures')
            
            # Update member's profile picture URL if member exists
            member = Member.query.filter_by(phone=user.phone).first()
            if member:
                # Delete old profile picture if it exists
                if member.profile_picture_url:
                    try:
                        s3_service.delete_file(member.profile_picture_url)
                    except Exception as e:
                        logger.warning(f"Failed to delete old profile picture: {str(e)}")
                
                member.profile_picture_url = file_url
                db.session.commit()
            
            return {
                'url': file_url,
                'filename': unique_filename,
                'message': 'Profile picture uploaded successfully'
            }, 200
            
        except APIError as e:
            # Handle APIError with proper status code
            auth_ns.abort(e.status_code, e.message)
        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.error(f"Error uploading profile picture: {str(e)}", exc_info=True)
            auth_ns.abort(500, f'Failed to upload profile picture: {str(e)}')

@auth_ns.route('/logout')
class Logout(Resource):
    @auth_ns.doc(
        security='Bearer',
        summary='Logout user',
        description='Logs out the current user (client should remove token)',
        responses={
            200: 'Logout successful'
        }
    )
    def post(self):
        """Logout user (token will be invalidated on client side)"""
        try:
            log_api_call('/api/auth/logout', 'POST')
            return {'message': 'Logout successful'}
            
        except Exception as e:
            auth_ns.abort(500, str(e))

@auth_ns.route('/admin-login')
class AdminLogin(Resource):
    @auth_ns.expect(admin_login_model)
    @auth_ns.marshal_with(auth_ns.model('Admin Login Response', {
        'access_token': fields.String,
        'user': fields.Nested(user_model),
        'message': fields.String
    }))
    @auth_ns.doc(
        summary='Admin login with username and password',
        description='Authenticates admin user with username and password, returns JWT token',
        responses={
            200: 'Login successful',
            401: 'Invalid credentials',
            400: 'Missing credentials'
        }
    )
    def post(self):
        """Admin login with username and password"""
        try:
            data = request.get_json()
            if not data:
                return {'message': 'Username and password are required'}, 400
            
            username = data.get('username', '').strip()
            password = data.get('password', '').strip()
            
            if not username or not password:
                return {'message': 'Username and password are required'}, 400
            
            # Check credentials
            if username == 'admin' and password == 'admin':
                log_api_call('/api/auth/admin-login', 'POST')
                
                # Find or create admin user
                # Use a special phone number for admin user
                admin_phone = '0000000000'
                admin_user = User.query.filter_by(phone=admin_phone).first()
                
                if not admin_user:
                    # Create admin user if it doesn't exist
                    admin_user = User(
                        id=str(uuid.uuid4()),
                        phone=admin_phone,
                        name='Administrator',
                        role=UserRole.ADMIN,
                        is_active=True
                    )
                    db.session.add(admin_user)
                    db.session.commit()
                else:
                    # Ensure existing admin user has admin role
                    if admin_user.role != UserRole.ADMIN:
                        admin_user.role = UserRole.ADMIN
                        db.session.commit()
                
                # Generate JWT token
                access_token = create_access_token(identity=admin_user.id)
                
                return {
                    'message': 'Login successful',
                    'access_token': access_token,
                    'user': admin_user.to_dict()
                }
            else:
                return {'message': 'Invalid username or password'}, 401
                
        except Exception as e:
            print(f"Admin login error: {str(e)}")
            import traceback
            traceback.print_exc()
            return {'message': f'Login failed: {str(e)}'}, 400

@auth_ns.route('/refresh')
class RefreshToken(Resource):
    @auth_ns.doc(
        security='Bearer',
        summary='Refresh access token',
        description='Refreshes the current access token',
        responses={
            200: 'Token refreshed successfully',
            401: 'Authentication required'
        }
    )
    def post(self):
        """Refresh access token"""
        try:
            log_api_call('/api/auth/refresh', 'POST')
            user = get_current_user()
            
            # Generate new JWT token
            access_token = create_access_token(identity=user.id)
            
            return {
                'message': 'Token refreshed successfully',
                'access_token': access_token,
                'user': user.to_dict()
            }
            
        except Exception as e:
            auth_ns.abort(401, str(e))