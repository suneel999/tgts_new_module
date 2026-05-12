# TGTS Backend Deployment Guide

## Quick Start (EC2)

### 1. Install Dependencies
```bash
# Install Python dependencies
pip install -r requirements.txt

# Or if using virtual environment
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 2. Environment Setup
```bash
# Copy environment template
cp env_example.txt .env

# Edit .env with your configuration
nano .env
```

### 3. Database Setup (Option A: Direct Run)
```bash
# Run the application directly (database will be created automatically)
python3 app.py
```

### 4. Database Setup (Option B: With Migrations)
```bash
# Set Flask app environment variable
export FLASK_APP=app.py

# Initialize database migrations
flask db init

# Create initial migration
flask db migrate -m "Initial migration"

# Apply migrations
flask db upgrade

# Run the application
python3 app.py
```

## Running on Port 80

### Option A: Direct Run (Requires sudo)
```bash
# Run on port 80 (requires root privileges)
sudo python3 app.py
```

### Option B: Using Environment Variable
```bash
# Set port in environment
export PORT=80
python3 app.py
```

### Option C: Production with Gunicorn (Recommended)
```bash
# Install Gunicorn
pip install gunicorn

# Run with Gunicorn on port 80
sudo gunicorn --bind 0.0.0.0:80 app:app
```

## API Endpoints

- **Base URL**: `http://your-server` (port 80)
- **API Documentation**: `http://your-server/docs/`
- **Health Check**: `http://your-server/api/health`

## Default Configuration

The application now defaults to:
- **Port**: 80 (production ready)
- **Environment**: Production mode
- **Debug**: Disabled for security

## Key Features Fixed

✅ **Flask Application Factory Pattern**: Proper app initialization for Flask-Migrate
✅ **Missing Dependencies**: Added Flask-RESTX to requirements.txt
✅ **Database Integration**: SQLAlchemy with proper initialization
✅ **API Documentation**: Swagger UI available at `/docs/`
✅ **JWT Authentication**: Token-based authentication system
✅ **CORS Support**: Cross-origin resource sharing enabled

## Environment Variables

Required in `.env` file:
```
SECRET_KEY=your-secret-key-change-in-production
JWT_SECRET_KEY=jwt-secret-string-change-in-production
DATABASE_URL=sqlite:///telangana_congress.db
FLASK_ENV=development
FLASK_DEBUG=True
```

## Production Deployment

For production deployment:

1. Set `FLASK_ENV=production` and `FLASK_DEBUG=False`
2. Use a production database (PostgreSQL recommended)
3. Set strong secret keys
4. Use a WSGI server like Gunicorn
5. Set up reverse proxy with Nginx

## Troubleshooting

### Common Issues:

1. **"Failed to find Flask application"**: Make sure `FLASK_APP=app.py` is set
2. **"No such command 'db'"**: Install Flask-Migrate: `pip install Flask-Migrate`
3. **Import errors**: Make sure all dependencies are installed: `pip install -r requirements.txt`

### Quick Test:
```bash
# Test if the app can be imported
python3 -c "from app import create_app; print('✅ App factory works')"

# Test if app.py can be imported
python3 -c "import app; print('✅ app.py works')"
```
