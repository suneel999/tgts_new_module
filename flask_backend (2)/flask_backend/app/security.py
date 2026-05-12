"""
Security Module for Telangana Congress Communication App
Production-grade security features and middleware
"""

from flask import request, jsonify, g
from functools import wraps
import time
import hashlib
import logging
from datetime import datetime, timedelta
from collections import defaultdict, deque
from app.utils.timezone_utils import get_ist_now, format_ist_iso

# Configure logging
logger = logging.getLogger(__name__)

class SecurityManager:
    """Production security manager"""
    
    def __init__(self):
        self.failed_attempts = defaultdict(list)
        self.blocked_ips = set()
        self.rate_limits = defaultdict(lambda: deque())
        self.max_attempts = 5
        self.block_duration = 300  # 5 minutes
        self.rate_limit_window = 60  # 1 minute
        self.max_requests_per_window = 100
        
    def is_ip_blocked(self, ip):
        """Check if IP is currently blocked"""
        if ip in self.blocked_ips:
            return True
        return False
    
    def record_failed_attempt(self, ip):
        """Record a failed authentication attempt"""
        current_time = time.time()
        self.failed_attempts[ip].append(current_time)
        
        # Clean old attempts (older than block_duration)
        cutoff_time = current_time - self.block_duration
        self.failed_attempts[ip] = [
            attempt for attempt in self.failed_attempts[ip] 
            if attempt > cutoff_time
        ]
        
        # Block IP if too many failed attempts
        if len(self.failed_attempts[ip]) >= self.max_attempts:
            self.blocked_ips.add(ip)
            logger.warning(f"IP {ip} blocked due to {len(self.failed_attempts[ip])} failed attempts")
            return True
        
        return False
    
    def check_rate_limit(self, ip):
        """Check if IP is within rate limits"""
        current_time = time.time()
        window_start = current_time - self.rate_limit_window
        
        # Clean old requests
        while self.rate_limits[ip] and self.rate_limits[ip][0] < window_start:
            self.rate_limits[ip].popleft()
        
        # Check if within limit
        if len(self.rate_limits[ip]) >= self.max_requests_per_window:
            return False
        
        # Record this request
        self.rate_limits[ip].append(current_time)
        return True
    
    def clear_failed_attempts(self, ip):
        """Clear failed attempts for successful authentication"""
        if ip in self.failed_attempts:
            del self.failed_attempts[ip]
        if ip in self.blocked_ips:
            self.blocked_ips.remove(ip)

# Global security manager instance
security_manager = SecurityManager()

def require_security_headers(f):
    """Decorator to add security headers"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        response = f(*args, **kwargs)
        
        # Add security headers
        security_headers = {
            'X-Content-Type-Options': 'nosniff',
            'X-Frame-Options': 'DENY',
            'X-XSS-Protection': '1; mode=block',
            'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
            'Content-Security-Policy': "default-src 'self'",
            'Referrer-Policy': 'strict-origin-when-cross-origin'
        }
        
        if hasattr(response, 'headers'):
            for header, value in security_headers.items():
                response.headers[header] = value
        
        return response
    return decorated_function

def rate_limit(max_requests=100, window=60):
    """Rate limiting decorator"""
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            client_ip = request.environ.get('HTTP_X_FORWARDED_FOR', request.remote_addr)
            
            if not security_manager.check_rate_limit(client_ip):
                logger.warning(f"Rate limit exceeded for IP: {client_ip}")
                return jsonify({
                    'message': 'Rate limit exceeded. Please try again later.',
                    'retry_after': window
                }), 429
            
            return f(*args, **kwargs)
        return decorated_function
    return decorator

def ip_blocking_check(f):
    """Decorator to check for blocked IPs"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        client_ip = request.environ.get('HTTP_X_FORWARDED_FOR', request.remote_addr)
        
        if security_manager.is_ip_blocked(client_ip):
            logger.warning(f"Blocked IP attempted access: {client_ip}")
            return jsonify({
                'message': 'Access denied. IP temporarily blocked.',
                'retry_after': security_manager.block_duration
            }), 403
        
        return f(*args, **kwargs)
    return decorated_function

def input_sanitization(f):
    """Decorator for input sanitization"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        # Sanitize request data
        if request.is_json:
            data = request.get_json()
            if data:
                sanitized_data = sanitize_input(data)
                request._cached_json = sanitized_data
        
        return f(*args, **kwargs)
    return decorated_function

def sanitize_input(data):
    """Sanitize input data"""
    if isinstance(data, dict):
        return {key: sanitize_input(value) for key, value in data.items()}
    elif isinstance(data, list):
        return [sanitize_input(item) for item in data]
    elif isinstance(data, str):
        # Remove potentially dangerous characters
        dangerous_chars = ['<', '>', '"', "'", '&', '\x00', '\r', '\n']
        for char in dangerous_chars:
            data = data.replace(char, '')
        return data.strip()
    else:
        return data

def generate_request_id():
    """Generate unique request ID for tracking"""
    timestamp = str(int(time.time() * 1000))
    random_part = hashlib.md5(str(time.time()).encode()).hexdigest()[:8]
    return f"{timestamp}_{random_part}"

def log_security_event(event_type, details, ip=None):
    """Log security events"""
    if not ip:
        ip = request.environ.get('HTTP_X_FORWARDED_FOR', request.remote_addr)
    
    log_entry = {
        'timestamp': format_ist_iso(get_ist_now()),
        'event_type': event_type,
        'ip': ip,
        'user_agent': request.headers.get('User-Agent', 'Unknown'),
        'details': details
    }
    
    logger.warning(f"Security Event: {log_entry}")

def validate_file_upload(file):
    """Validate uploaded files"""
    if not file:
        return False, "No file provided"
    
    # Check file size (1GB max)
    max_size = 1024 * 1024 * 1024
    if hasattr(file, 'content_length') and file.content_length > max_size:
        return False, "File too large (max 1GB)"
    
    # Check file extension
    allowed_extensions = {'txt', 'pdf', 'png', 'jpg', 'jpeg', 'gif', 'mp4', 'avi', 'mov'}
    if '.' not in file.filename:
        return False, "No file extension"
    
    extension = file.filename.rsplit('.', 1)[1].lower()
    if extension not in allowed_extensions:
        return False, f"File type {extension} not allowed"
    
    return True, "Valid file"

def create_security_response(message, status_code=400):
    """Create standardized security response"""
    return jsonify({
        'message': message,
        'timestamp': format_ist_iso(get_ist_now()),
        'status': 'error'
    }), status_code


