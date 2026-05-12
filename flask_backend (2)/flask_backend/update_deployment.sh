#!/bin/bash
# Quick update script for production deployment
# Run this script on your server after pushing code updates

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Configuration - UPDATE THESE FOR YOUR SETUP
APP_DIR="${APP_DIR:-$(pwd)}"  # Default to current directory, or set APP_DIR env var
SERVICE_NAME="${SERVICE_NAME:-telangana-congress-api}"  # Your systemd service name
USE_VENV="${USE_VENV:-true}"  # Set to false if not using virtual environment
VENV_PATH="${VENV_PATH:-venv}"  # Path to venv (venv or .venv)

echo "🔄 Starting deployment update..."
echo "📁 App directory: $APP_DIR"
echo "🔧 Service name: $SERVICE_NAME"

# Navigate to app directory
if [ ! -d "$APP_DIR" ]; then
    print_error "Directory not found: $APP_DIR"
    print_warning "Set APP_DIR environment variable or run from the flask_backend directory"
    exit 1
fi

cd "$APP_DIR" || exit 1

# Check if this is a git repository
if [ ! -d ".git" ]; then
    print_warning "Not a git repository. Skipping git pull."
    SKIP_GIT=true
fi

# Pull latest code
if [ "$SKIP_GIT" != "true" ]; then
    print_step "Pulling latest code from repository..."
    if git pull origin main 2>/dev/null || git pull origin master 2>/dev/null; then
        print_status "Code updated successfully"
    else
        print_warning "Git pull failed or no changes. Continuing..."
    fi
fi

# Activate virtual environment if it exists
if [ "$USE_VENV" = "true" ]; then
    if [ -d "$VENV_PATH" ]; then
        print_step "Activating virtual environment..."
        source "$VENV_PATH/bin/activate"
        print_status "Virtual environment activated"
    elif [ -d ".venv" ]; then
        print_step "Activating virtual environment..."
        source .venv/bin/activate
        print_status "Virtual environment activated"
    else
        print_warning "Virtual environment not found. Continuing without venv..."
    fi
fi

# Update dependencies
print_step "Updating Python dependencies..."
if pip install -r requirements.txt --upgrade --quiet; then
    print_status "Dependencies updated successfully"
else
    print_error "Failed to update dependencies"
    exit 1
fi

# Run database migrations
print_step "Running database migrations..."
export FLASK_APP=app.py
if command -v flask &> /dev/null; then
    if flask db upgrade 2>/dev/null; then
        print_status "Database migrations applied"
    else
        print_warning "Migration failed or not needed. This is OK if using db.create_all()"
    fi
else
    print_warning "Flask CLI not found. Skipping migrations."
fi

# Check if constituency migration is needed (one-time migration from UUID to Integer)
if [ -f "migrate_constituencies_to_integer_ids.py" ]; then
    print_step "Checking if constituency migration is needed..."
    # Check if old UUID columns exist (this is a simple check - you may want to enhance it)
    if python3 -c "
from app import create_app, db
from sqlalchemy import inspect
try:
    app = create_app()
    with app.app_context():
        inspector = inspect(db.engine)
        try:
            pc_cols = [c['name'] for c in inspector.get_columns('parliamentary_constituencies')]
            ac_cols = [c['name'] for c in inspector.get_columns('assembly_constituencies')]
            if 'id' in pc_cols or 'id' in ac_cols:
                exit(1)  # Migration needed
            else:
                exit(0)  # Already migrated
        except Exception:
            exit(0)  # Tables might not exist yet, skip
except Exception:
    exit(0)  # Skip if check fails
" 2>/dev/null; then
        print_status "Constituency tables already use integer IDs"
    else
        print_warning "⚠️  Old UUID constituency columns detected!"
        print_warning "You may need to run: python3 migrate_constituencies_to_integer_ids.py"
        print_warning "This is a ONE-TIME migration. Make sure to backup your database first!"
        if [ "${AUTO_RUN_CONSTITUENCY_MIGRATION:-false}" = "true" ]; then
            print_step "Running constituency migration (AUTO_RUN_CONSTITUENCY_MIGRATION=true)..."
            if python3 migrate_constituencies_to_integer_ids.py; then
                print_status "Constituency migration completed"
            else
                print_error "Constituency migration failed"
            fi
        fi
    fi
fi

# Restart service
print_step "Restarting application service..."
if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    if sudo systemctl restart "$SERVICE_NAME"; then
        print_status "Service restarted successfully"
    else
        print_error "Failed to restart service"
        exit 1
    fi
elif pgrep -f "gunicorn.*wsgi" > /dev/null; then
    print_warning "Gunicorn process found but no systemd service. Restarting manually..."
    pkill -f "gunicorn.*wsgi" || true
    sleep 2
    # Restart gunicorn (adjust command as needed)
    nohup gunicorn -c wsgi.py wsgi:application > app.log 2>&1 &
    print_status "Gunicorn restarted"
elif pgrep -f "python.*app.py" > /dev/null; then
    print_warning "Python app.py process found. Restarting manually..."
    pkill -f "python.*app.py" || true
    sleep 2
    nohup python3 app.py > app.log 2>&1 &
    print_status "Application restarted"
else
    print_warning "No running service found. You may need to start it manually."
fi

# Wait for service to start
print_step "Waiting for service to start..."
sleep 5

# Verify health
print_step "Verifying deployment..."
if curl -f -s http://localhost/api/health > /dev/null 2>&1; then
    print_status "✅ Deployment update successful!"
    print_status "Health check passed"
    
    # Show service status if using systemd
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo ""
        print_status "Service status:"
        sudo systemctl status "$SERVICE_NAME" --no-pager -l | head -n 10
    fi
else
    print_error "❌ Health check failed!"
    print_warning "The service may still be starting. Check logs:"
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo "   sudo journalctl -u $SERVICE_NAME -n 50"
    else
        echo "   tail -f app.log"
    fi
    exit 1
fi

echo ""
print_status "🎉 Update complete!"

