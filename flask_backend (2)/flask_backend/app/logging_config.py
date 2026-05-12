"""
Production Logging Configuration for Telangana Congress Communication App
Comprehensive logging setup for production monitoring and debugging
"""

import logging
import logging.handlers
import os
import sys
from datetime import datetime
import json
from app.utils.timezone_utils import get_ist_now, format_ist_iso

class JSONFormatter(logging.Formatter):
    """Custom JSON formatter for structured logging"""
    
    def format(self, record):
        log_entry = {
            'timestamp': format_ist_iso(get_ist_now()),
            'level': record.levelname,
            'logger': record.name,
            'message': record.getMessage(),
            'module': record.module,
            'function': record.funcName,
            'line': record.lineno
        }
        
        # Add extra fields if present
        if hasattr(record, 'user_id'):
            log_entry['user_id'] = record.user_id
        if hasattr(record, 'request_id'):
            log_entry['request_id'] = record.request_id
        if hasattr(record, 'ip_address'):
            log_entry['ip_address'] = record.ip_address
        if hasattr(record, 'endpoint'):
            log_entry['endpoint'] = record.endpoint
        if hasattr(record, 'method'):
            log_entry['method'] = record.method
        if hasattr(record, 'status_code'):
            log_entry['status_code'] = record.status_code
        if hasattr(record, 'response_time'):
            log_entry['response_time'] = record.response_time
        
        # Add exception info if present
        if record.exc_info:
            log_entry['exception'] = self.formatException(record.exc_info)
        
        return json.dumps(log_entry)

class ProductionLogger:
    """Production logging manager"""
    
    def __init__(self, app=None):
        self.app = app
        if app:
            self.init_app(app)
    
    def init_app(self, app):
        """Initialize logging for the Flask app"""
        
        # Get configuration
        log_level = getattr(app.config, 'LOG_LEVEL', 'INFO')
        log_file = getattr(app.config, 'LOG_FILE', 'app.log')
        
        # Create logs directory if it doesn't exist
        log_dir = os.path.dirname(log_file) if os.path.dirname(log_file) else '.'
        if not os.path.exists(log_dir):
            os.makedirs(log_dir)
        
        # Configure root logger
        root_logger = logging.getLogger()
        root_logger.setLevel(getattr(logging, log_level.upper()))
        
        # Remove existing handlers
        for handler in root_logger.handlers[:]:
            root_logger.removeHandler(handler)
        
        # Console handler for development
        if app.debug:
            console_handler = logging.StreamHandler(sys.stdout)
            console_handler.setLevel(logging.DEBUG)
            console_formatter = logging.Formatter(
                '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
            )
            console_handler.setFormatter(console_formatter)
            root_logger.addHandler(console_handler)
        
        # File handler for production
        file_handler = logging.handlers.RotatingFileHandler(
            log_file,
            maxBytes=10*1024*1024,  # 10MB
            backupCount=5
        )
        file_handler.setLevel(logging.INFO)
        json_formatter = JSONFormatter()
        file_handler.setFormatter(json_formatter)
        root_logger.addHandler(file_handler)
        
        # Error file handler
        error_file_handler = logging.handlers.RotatingFileHandler(
            f"{log_file}.error",
            maxBytes=10*1024*1024,  # 10MB
            backupCount=5
        )
        error_file_handler.setLevel(logging.ERROR)
        error_file_handler.setFormatter(json_formatter)
        root_logger.addHandler(error_file_handler)
        
        # Security log handler
        security_file_handler = logging.handlers.RotatingFileHandler(
            f"{log_file}.security",
            maxBytes=10*1024*1024,  # 10MB
            backupCount=10
        )
        security_file_handler.setLevel(logging.WARNING)
        security_file_handler.setFormatter(json_formatter)
        
        # Create security logger
        security_logger = logging.getLogger('security')
        security_logger.addHandler(security_file_handler)
        security_logger.setLevel(logging.WARNING)
        security_logger.propagate = False
        
        # API logger
        api_logger = logging.getLogger('api')
        api_logger.addHandler(file_handler)
        api_logger.setLevel(logging.INFO)
        api_logger.propagate = False
        
        # Database logger
        db_logger = logging.getLogger('sqlalchemy.engine')
        db_logger.setLevel(logging.WARNING)
        
        # Suppress noisy loggers
        logging.getLogger('werkzeug').setLevel(logging.WARNING)
        logging.getLogger('urllib3').setLevel(logging.WARNING)

def log_api_request(request, response, response_time, user_id=None):
    """Log API request details"""
    logger = logging.getLogger('api')
    
    # Extract request details
    request_id = getattr(g, 'request_id', None)
    ip_address = request.environ.get('HTTP_X_FORWARDED_FOR', request.remote_addr)
    
    # Log the request
    logger.info(
        f"API Request: {request.method} {request.path}",
        extra={
            'request_id': request_id,
            'user_id': user_id,
            'ip_address': ip_address,
            'endpoint': request.path,
            'method': request.method,
            'status_code': response.status_code,
            'response_time': response_time,
            'user_agent': request.headers.get('User-Agent', 'Unknown')
        }
    )

def log_security_event(event_type, details, ip_address=None, user_id=None):
    """Log security events"""
    logger = logging.getLogger('security')
    
    logger.warning(
        f"Security Event: {event_type}",
        extra={
            'event_type': event_type,
            'details': details,
            'ip_address': ip_address,
            'user_id': user_id,
            'timestamp': datetime.utcnow().isoformat()
        }
    )

def log_database_operation(operation, table, user_id=None, details=None):
    """Log database operations"""
    logger = logging.getLogger('database')
    
    logger.info(
        f"Database Operation: {operation} on {table}",
        extra={
            'operation': operation,
            'table': table,
            'user_id': user_id,
            'details': details,
            'timestamp': datetime.utcnow().isoformat()
        }
    )

def log_performance_metric(metric_name, value, unit='ms'):
    """Log performance metrics"""
    logger = logging.getLogger('performance')
    
    logger.info(
        f"Performance Metric: {metric_name} = {value}{unit}",
        extra={
            'metric_name': metric_name,
            'value': value,
            'unit': unit,
            'timestamp': datetime.utcnow().isoformat()
        }
    )

def log_error(error, context=None, user_id=None):
    """Log application errors"""
    logger = logging.getLogger('error')
    
    logger.error(
        f"Application Error: {str(error)}",
        extra={
            'error_type': type(error).__name__,
            'error_message': str(error),
            'context': context,
            'user_id': user_id,
            'timestamp': datetime.utcnow().isoformat()
        },
        exc_info=True
    )

# Initialize logger instance
production_logger = ProductionLogger()


