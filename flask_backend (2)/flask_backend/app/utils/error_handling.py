"""
Error Handling Utilities for Telangana Congress Communication App
This module provides consistent error handling across all API endpoints
"""

from flask import jsonify
from flask_restx import Namespace
import traceback
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class APIError(Exception):
    """Custom API Exception"""
    def __init__(self, message, status_code=400, payload=None):
        super().__init__()
        self.message = message
        self.status_code = status_code
        self.payload = payload

def handle_api_error(error):
    """Handle API errors consistently"""
    logger.error(f"API Error: {error.message}")
    return jsonify({
        'error': error.message,
        'code': error.status_code,
        'payload': error.payload
    }), error.status_code

def handle_validation_error(error):
    """Handle validation errors"""
    logger.error(f"Validation Error: {str(error)}")
    return jsonify({
        'error': 'Validation failed',
        'details': str(error),
        'code': 400
    }), 400

def handle_database_error(error):
    """Handle database errors"""
    logger.error(f"Database Error: {str(error)}")
    return jsonify({
        'error': 'Database operation failed',
        'code': 500
    }), 500

def handle_unauthorized_error(error):
    """Handle unauthorized access errors"""
    logger.error(f"Unauthorized Error: {str(error)}")
    return jsonify({
        'error': 'Unauthorized access',
        'code': 401
    }), 401

def handle_not_found_error(error):
    """Handle not found errors"""
    logger.error(f"Not Found Error: {str(error)}")
    return jsonify({
        'error': 'Resource not found',
        'code': 404
    }), 404

def validate_required_fields(data, required_fields):
    """Validate required fields in request data"""
    missing_fields = [field for field in required_fields if field not in data or not data[field]]
    if missing_fields:
        raise APIError(f"Missing required fields: {', '.join(missing_fields)}", 400)

def validate_phone_number(phone):
    """Validate phone number format"""
    if not phone or len(phone) != 10 or not phone.isdigit():
        raise APIError("Invalid phone number format. Must be 10 digits.", 400)

def validate_otp(otp):
    """Validate OTP format"""
    if not otp or len(otp) != 6 or not otp.isdigit():
        raise APIError("Invalid OTP format. Must be 6 digits.", 400)

def log_api_call(endpoint, method, user_id=None):
    """Log API calls for monitoring"""
    logger.info(f"API Call: {method} {endpoint} - User: {user_id or 'Anonymous'}")

def create_error_response(namespace, message, status_code=400):
    """Create standardized error response for Flask-RESTX"""
    return namespace.abort(status_code, message)


