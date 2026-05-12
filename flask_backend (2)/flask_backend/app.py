from app import create_app, db
from datetime import datetime
import os
import sys

# Set UTF-8 encoding for Windows console
if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8')

app = create_app()

# Create tables and add sample data
with app.app_context():
    db.create_all()
    print("[OK] Database tables created/verified")

if __name__ == '__main__':
    # Get port from environment variable or default to 80
    port = int(os.getenv('PORT', 80))
    debug = os.getenv('FLASK_DEBUG', 'False').lower() == 'true'
    
    print(f"[*] Starting Telangana Congress API on port {port}")
    print(f"[*] API Documentation: http://localhost:{port}/docs/")
    print(f"[*] Health Check: http://localhost:{port}/api/health")
    
    # For production on port 80, we need to run as root or use sudo
    # Consider using a WSGI server like Gunicorn for production
    app.run(debug=debug, host='0.0.0.0', port=port)