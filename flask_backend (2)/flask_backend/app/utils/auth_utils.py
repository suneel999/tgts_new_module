"""
Authentication Utilities for Telangana Congress Communication App
This module provides authentication and authorization utilities
"""

from flask_jwt_extended import get_jwt_identity, jwt_required
from app.models import User, UserRole
from app.utils.error_handling import APIError, create_error_response
import time

# Temporary OTP storage (in production, use Redis or database)
otp_storage = {}

def generate_otp():
    """Generate a 6-digit OTP"""
    import random
    return str(random.randint(100000, 999999))

def store_otp(phone, otp, expiry_minutes=5):
    """Store OTP with expiry time"""
    expiry_time = time.time() + (expiry_minutes * 60)
    otp_storage[phone] = {
        'otp': otp,
        'expiry': expiry_time
    }

def verify_otp(phone, otp):
    """Verify OTP and return if valid"""
    if phone not in otp_storage:
        raise APIError("OTP not found. Please request a new OTP.", 400)
    
    stored_data = otp_storage[phone]
    
    # Check if OTP has expired
    if time.time() > stored_data['expiry']:
        del otp_storage[phone]  # Clean up expired OTP
        raise APIError("OTP has expired. Please request a new OTP.", 400)
    
    # Verify OTP matches
    if stored_data['otp'] != otp:
        raise APIError("Invalid OTP.", 400)
    
    # OTP is valid, clean up storage
    del otp_storage[phone]
    return True

def get_current_user():
    """Get current authenticated user"""
    user_id = get_jwt_identity()
    if not user_id:
        raise APIError("Authentication required", 401)
    
    user = User.query.get(user_id)
    if not user:
        raise APIError("User not found", 404)
    
    return user

def require_auth():
    """Decorator to require authentication"""
    def decorator(func):
        def wrapper(*args, **kwargs):
            try:
                get_current_user()
                return func(*args, **kwargs)
            except APIError as e:
                return create_error_response(None, e.message, e.status_code)
        return wrapper
    return decorator

def require_role(required_role):
    """Decorator to require specific role"""
    def decorator(func):
        def wrapper(*args, **kwargs):
            try:
                user = get_current_user()
                if user.role != required_role and user.role != UserRole.ADMIN:
                    raise APIError(f"{required_role.value.title()} access required", 403)
                return func(*args, **kwargs)
            except APIError as e:
                return create_error_response(None, e.message, e.status_code)
        return wrapper
    return decorator

def require_admin():
    """Decorator to require admin access"""
    return require_role(UserRole.ADMIN)

def require_cadre_or_admin():
    """Decorator to require cadre or admin access"""
    def decorator(func):
        def wrapper(*args, **kwargs):
            try:
                user = get_current_user()
                if user.role not in [UserRole.CADRE, UserRole.ADMIN]:
                    raise APIError("Cadre or Admin access required", 403)
                return func(*args, **kwargs)
            except APIError as e:
                return create_error_response(None, e.message, e.status_code)
        return wrapper
    return decorator

def check_cadre_or_admin(user):
    """Check if user has cadre or admin access. Raises APIError if not."""
    if user.role not in [UserRole.CADRE, UserRole.ADMIN]:
        raise APIError("Cadre or Admin access required", 403)

def cleanup_expired_otps():
    """Clean up expired OTPs (call this periodically)"""
    current_time = time.time()
    expired_phones = [phone for phone, data in otp_storage.items() if current_time > data['expiry']]
    for phone in expired_phones:
        del otp_storage[phone]
    return len(expired_phones)


