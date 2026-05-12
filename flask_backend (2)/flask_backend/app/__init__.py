from flask import Flask, jsonify, request
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from flask_jwt_extended import JWTManager
from flask_cors import CORS
from flask_restx import Api
from werkzeug.exceptions import BadRequest, RequestEntityTooLarge
from datetime import timedelta
import os
import re
from dotenv import load_dotenv

# Initialize extensions
db = SQLAlchemy()
migrate = Migrate()
jwt = JWTManager()
cors = CORS()

def create_app():
    app = Flask(__name__)
    
    # Load environment variables
    load_dotenv()
    
    # Configuration
    app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'your-secret-key-here')
    # Default to local PostgreSQL TGTS database, or use environment variable
    app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('DATABASE_URL', 'postgresql://postgres:rootuser@localhost:5432/TGTS')
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    app.config['JWT_SECRET_KEY'] = os.getenv('JWT_SECRET_KEY', 'jwt-secret-string')
    app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(hours=24)
    
    # File upload configuration
    upload_folder = os.getenv('UPLOAD_FOLDER', 'uploads')
    # Convert to absolute path
    if not os.path.isabs(upload_folder):
        upload_folder = os.path.join(os.path.dirname(os.path.dirname(__file__)), upload_folder)
    app.config['UPLOAD_FOLDER'] = upload_folder
    app.config['MAX_CONTENT_LENGTH'] = 1024 * 1024 * 1024  # 1GB max file size
    app.config['PRESERVE_CONTEXT_ON_EXCEPTION'] = False
    
    # Create uploads directory if it doesn't exist
    os.makedirs(upload_folder, exist_ok=True)
    
    # Admin Frontend URL (for QR code verification links)
    app.config['ADMIN_FRONTEND_URL'] = os.getenv('ADMIN_FRONTEND_URL', 'https://admin.tgtccon2025.com')
    
    # AWS S3 configuration
    app.config['AWS_ACCESS_KEY_ID'] = os.getenv('AWS_ACCESS_KEY_ID')
    app.config['AWS_SECRET_ACCESS_KEY'] = os.getenv('AWS_SECRET_ACCESS_KEY')
    app.config['AWS_REGION'] = os.getenv('AWS_REGION', 'us-east-1')
    app.config['S3_BUCKET_NAME'] = os.getenv('S3_BUCKET_NAME', 'tgts-media')
    app.config['S3_USE_LOCAL_STORAGE'] = os.getenv('S3_USE_LOCAL_STORAGE', 'true').lower() == 'true'
    
    # Initialize extensions with app
    db.init_app(app)
    migrate.init_app(app, db)
    jwt.init_app(app)
    
    # Register JWT error handlers
    @jwt.expired_token_loader
    def expired_token_callback(jwt_header, jwt_payload):
        """Handle expired JWT tokens"""
        return jsonify({
            'message': 'Token has expired. Please login again.',
            'error': 'token_expired'
        }), 401
    
    @jwt.invalid_token_loader
    def invalid_token_callback(error):
        """Handle invalid JWT tokens"""
        return jsonify({
            'message': 'Invalid token. Please login again.',
            'error': 'invalid_token'
        }), 401
    
    @jwt.unauthorized_loader
    def missing_token_callback(error):
        """Handle missing JWT tokens"""
        return jsonify({
            'message': 'Authentication required. Please provide a valid token.',
            'error': 'authorization_required'
        }), 401
    
    @jwt.revoked_token_loader
    def revoked_token_callback(jwt_header, jwt_payload):
        """Handle revoked JWT tokens"""
        return jsonify({
            'message': 'Token has been revoked. Please login again.',
            'error': 'token_revoked'
        }), 401
    
    # Configure CORS to allow frontend access
    # Get CORS origins from environment variable or use defaults
    cors_origins_env = os.getenv('CORS_ORIGINS', '')
    
    # Default origins for local development
    default_origins = [
        "http://localhost:5173", 
        "http://localhost:5174", 
        "http://127.0.0.1:5173", 
        "http://127.0.0.1:5174"
    ]
    
    # Always allow AWS Amplify domains (production deployment)
    # Explicitly include common Amplify patterns
    amplify_origins = [
        "https://main.d2i1qc8827fi7m.amplifyapp.com",  # Current production domain
        re.compile(r'https://.*\.amplifyapp\.com'),  # All Amplify domains
    ]
    
    # Build allowed origins list
    if cors_origins_env:
        # Split by comma and add to origins list
        env_origins = [origin.strip() for origin in cors_origins_env.split(',') if origin.strip()]
        # Combine with defaults and Amplify origins, removing duplicates
        allowed_origins = list(dict.fromkeys(default_origins + env_origins)) + amplify_origins
    else:
        # If no env var set, use defaults + allow all Amplify domains for production
        allowed_origins = default_origins + amplify_origins
    
    # Configure CORS with allowed origins
    # Use a more permissive configuration to ensure OPTIONS requests work
    cors.init_app(app, resources={
        r"/api/*": {
            "origins": allowed_origins,
            "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"],
            "allow_headers": ["Content-Type", "Authorization", "X-Requested-With"],
            "expose_headers": ["Content-Type", "Authorization"],
            "supports_credentials": True,
            "max_age": 3600  # Cache preflight requests for 1 hour
        },
        r"/uploads/*": {
            "origins": allowed_origins,
            "methods": ["GET", "OPTIONS"],
            "supports_credentials": True
        },
        r"/*": {  # Fallback for any other routes
            "origins": allowed_origins,
            "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
            "allow_headers": ["Content-Type", "Authorization"],
            "supports_credentials": True
        }
    })
    
    # Create Flask-RESTX API instance
    api = Api(
        app,
        version='1.0.0',
        title='Telangana Congress Communication App API',
        description='A comprehensive API for the Telangana Congress Communication App',
        doc='/docs/',
        prefix='/api',
        authorizations={
            'Bearer': {
                'type': 'apiKey',
                'in': 'header',
                'name': 'Authorization',
                'description': 'JWT Authorization header using the Bearer scheme. Example: "Authorization: Bearer {token}"'
            }
        }
        # Removed security='Bearer' to allow public access to endpoints
        # Individual endpoints will specify if they need authentication
    )
    
    # Import and register Flask-RESTX namespaces
    from app.routes.auth import auth_ns
    from app.routes.news import news_ns
    from app.routes.events import events_ns
    from app.routes.media import media_ns
    from app.routes.documents import documents_ns
    from app.routes.users import users_ns
    from app.routes.admin import admin_ns
    from app.routes.members import members_ns
    from app.routes.constituencies import constituencies_ns
    from app.routes.assembly_constituencies import assembly_constituencies_ns
    from app.routes.districts import districts_ns
    from app.routes.mandals import mandals_ns
    from app.routes.activities import activities_ns
    from app.routes.verify import verify_ns
    from app.routes.cadre_levels import cadre_levels_ns
    from app.routes.voter_list import voter_list_ns
    from app.routes.scheme_beneficiaries import scheme_beneficiaries_ns
    from app.routes.schemes import schemes_ns

    # Add namespaces to API
    # Note: paths should not include '/api' prefix since API already has prefix='/api'
    api.add_namespace(auth_ns, path='/auth')
    api.add_namespace(news_ns, path='/news')
    api.add_namespace(events_ns, path='/events')
    api.add_namespace(media_ns, path='/media')
    api.add_namespace(documents_ns, path='/documents')
    api.add_namespace(users_ns, path='/users')
    api.add_namespace(admin_ns, path='/admin')
    api.add_namespace(members_ns, path='/members')
    api.add_namespace(constituencies_ns, path='/constituencies')
    api.add_namespace(assembly_constituencies_ns, path='/assembly-constituencies')
    api.add_namespace(districts_ns, path='/districts')
    api.add_namespace(mandals_ns, path='/mandals')
    api.add_namespace(activities_ns, path='/activities')
    api.add_namespace(verify_ns, path='/verify')
    api.add_namespace(cadre_levels_ns, path='/cadre-levels')
    api.add_namespace(voter_list_ns, path='/voter-list')
    api.add_namespace(scheme_beneficiaries_ns, path='/scheme-beneficiaries')
    api.add_namespace(schemes_ns, path='/schemes')
    
    # Basic routes
    @app.route('/')
    def index():
        from datetime import datetime
        return {
            'message': 'Telangana Congress Communication App API', 
            'version': '1.0.0', 
            'status': 'running'
        }
    
    @app.route('/api/health')
    def health_check():
        from app.utils.timezone_utils import get_ist_now, format_ist_iso
        return {
            'status': 'healthy', 
            'timestamp': format_ist_iso(get_ist_now()),
            'version': '1.0.0'
        }
    
    # Error handler for RequestEntityTooLarge (413) errors
    @app.errorhandler(RequestEntityTooLarge)
    def handle_request_entity_too_large(e):
        """Handle file size limit exceeded errors"""
        max_size_gb = app.config.get('MAX_CONTENT_LENGTH', 1024 * 1024 * 1024) / (1024 * 1024 * 1024)
        return jsonify({
            'message': f'File too large. Maximum file size is {max_size_gb:.1f}GB (1GB).',
            'error': 'file_too_large',
            'max_size': int(app.config.get('MAX_CONTENT_LENGTH', 1024 * 1024 * 1024)),
            'max_size_gb': max_size_gb
        }), 413
    
    # Error handler for BadRequest (400) errors
    @app.errorhandler(BadRequest)
    def handle_bad_request(e):
        """Handle BadRequest errors with better error messages"""
        # Check if this is a file upload request
        if request.path and '/upload' in request.path:
            # For upload endpoints, provide specific error message
            error_msg = str(e.description) if hasattr(e, 'description') else str(e)
            if 'could not understand' in error_msg.lower():
                return jsonify({
                    'message': 'Failed to parse request. Make sure you are sending multipart/form-data with the correct Content-Type header.',
                    'error': 'bad_request',
                    'details': 'The request must be sent as multipart/form-data with a "file" field for file uploads.'
                }), 400
        return jsonify({
            'message': str(e.description) if hasattr(e, 'description') else str(e),
            'error': 'bad_request'
        }), 400
    
    # Serve uploaded files
    @app.route('/uploads/<path:filename>')
    def serve_upload(filename):
        from flask import send_from_directory
        # Use the configured upload folder
        uploads_dir = app.config['UPLOAD_FOLDER']
        return send_from_directory(uploads_dir, filename)
    
    # Auto-create database tables on app initialization
    with app.app_context():
        # Import all models to ensure they're registered with SQLAlchemy
        from app.models import User, NewsItem, Event, MediaItem, Document, MediaStats, Member, Role, ParliamentaryConstituency, AssemblyConstituency, Activity, CadreLevel, Voter, SchemeBeneficiary, Scheme
        try:
            # Only create tables if database is accessible (skip if RDS is not reachable)
            db.create_all()
            print("[✓] Database tables created/verified successfully")

            # Auto-populate Roles
            if Role.query.first() is None:
                roles = [
                    Role(id=1, name='public', description='Public User'),
                    Role(id=2, name='cadre', description='Party Cadre'),
                    Role(id=3, name='admin', description='Administrator')
                ]
                for role in roles:
                    db.session.add(role)
                db.session.commit()
                print("[✓] Roles initialized successfully")
            
            # Auto-populate Cadre Levels
            if CadreLevel.query.first() is None:
                from app.models.cadre_level import CADRE_LEVELS_SEED
                for level_data in CADRE_LEVELS_SEED:
                    cadre_level = CadreLevel(**level_data)
                    db.session.add(cadre_level)
                db.session.commit()
                print("[✓] Cadre levels initialized successfully")
            
            # Check and add missing columns automatically
            from app.utils.db_migrations import ensure_all_columns
            ensure_all_columns()
            print("[✓] Database columns verified/updated successfully")
        except Exception as e:
            # Don't fail app startup if database is temporarily unavailable
            print(f"[⚠] Warning: Could not verify database tables: {e}")
            print("[⚠] App will continue, but database operations may fail until connection is restored")
    
    return app
