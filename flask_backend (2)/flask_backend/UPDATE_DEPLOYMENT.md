# Backend Deployment Update Guide

This guide covers the commands to run on your production server after pushing code updates.

## Quick Update Commands

After pushing your code to the repository, SSH into your server and run these commands:

### 1. Navigate to Backend Directory
```bash
cd /path/to/your/flask_backend
# Or if using the deployment script location:
cd /opt/telangana-congress-api
```

### 2. Pull Latest Code
```bash
git pull origin main
# Or if you're on a different branch:
git pull origin <your-branch-name>
```

### 3. Activate Virtual Environment (if using one)
```bash
source venv/bin/activate
# Or if using a different virtual environment:
source .venv/bin/activate
```

### 4. Update Python Dependencies
```bash
pip install -r requirements.txt --upgrade
```

### 5. Run Database Migrations (if any schema changes)
```bash
# Set Flask app environment variable
export FLASK_APP=app.py

# Create migration if you made model changes (only needed if you changed models)
# flask db migrate -m "Description of changes"

# Apply migrations
flask db upgrade
```

**Note:** If you haven't set up Flask-Migrate yet, you can skip migrations and the app will auto-create tables using `db.create_all()`.

### 5a. Run Database Schema Migrations (ONE-TIME, if needed)

**IMPORTANT:** These are one-time migrations that may be needed depending on your database state.

#### A. Constituency Migration (UUID → Integer IDs)

If your production database still has constituency tables with UUID/string primary keys:

```bash
python3 migrate_constituencies_to_integer_ids.py
```

**When to run:**
- ✅ First time deploying with old UUID-based constituency IDs
- ✅ Updating from older version that used UUID constituency IDs
- ❌ Skip if database already uses integer `constituency_number` as primary keys

**What it does:**
- Converts constituency primary keys from UUID/string to Integer (`constituency_number`)
- Updates all foreign key references in `members` table
- Drops old UUID `id` columns from constituency tables

#### B. Add Constituency Columns to Members (if missing)

If the `members` table doesn't have constituency foreign key columns:

```bash
python3 add_constituency_columns.py
```

**When to run:**
- ✅ Only if `members` table is missing `parliament_constituency_id` or `assembly_constituency_id` columns
- ❌ Skip if columns already exist (usually handled by `db.create_all()`)

#### C. Optimize Constituency Columns (optional)

Optimizes VARCHAR sizes for UUID storage (only needed if you had VARCHAR(50) for UUIDs):

```bash
python3 optimize_constituency_columns.py
```

**When to run:**
- ✅ Only if you want to optimize column sizes from VARCHAR(50) to VARCHAR(36)
- ❌ Skip if already optimized or using integer IDs

#### D. Create RSVP Table (if missing)

Creates the `event_rsvps` table for event RSVP functionality:

```bash
python3 create_rsvp_table.py
```

**When to run:**
- ✅ Only if `event_rsvps` table doesn't exist
- ❌ Skip if table already exists (usually handled by `db.create_all()`)

**Warning:** Backup your database before running any migration scripts!

### 5b. Populate Initial Data (ONE-TIME, if needed)

These scripts populate reference data. Run only if your database is empty or missing this data.

#### A. Populate Parliamentary Constituencies

```bash
python3 populate_parliamentary_constituencies.py
```

**When to run:**
- ✅ First-time deployment with empty database
- ✅ If parliamentary constituencies table is empty
- ❌ Skip if constituencies already exist

#### B. Populate Assembly Constituencies

```bash
python3 populate_assembly_constituencies.py
```

**When to run:**
- ✅ First-time deployment with empty database
- ✅ If assembly constituencies table is empty
- ❌ Skip if constituencies already exist

#### C. Initialize Media Statistics

Initializes media statistics counters:

```bash
python3 initialize_media_stats.py
```

**When to run:**
- ✅ First-time deployment
- ✅ After adding media stats feature
- ❌ Skip if media stats already initialized

### 6. Restart the Application

#### Option A: If using systemd service
```bash
sudo systemctl restart telangana-congress-api
# Check status
sudo systemctl status telangana-congress-api
```

#### Option B: If using Gunicorn directly
```bash
# Find and kill the existing process
pkill -f gunicorn

# Start Gunicorn again
gunicorn -c wsgi.py wsgi:application
# Or if running in background:
nohup gunicorn -c wsgi.py wsgi:application > app.log 2>&1 &
```

#### Option C: If using Python directly (development/testing)
```bash
# Find and kill the existing process
pkill -f "python.*app.py"

# Start the app
python3 app.py
# Or in background:
nohup python3 app.py > app.log 2>&1 &
```

### 7. Verify the Update
```bash
# Check health endpoint
curl http://localhost/api/health

# Check logs for errors
tail -f app.log
# Or if using systemd:
sudo journalctl -u telangana-congress-api -f
```

## Linux Compatibility

✅ **The scripts are fully compatible with Linux!**

The `update_deployment.sh` script uses:
- Standard bash (`#!/bin/bash`) - works on all Linux distributions
- `systemctl` - standard on systemd-based Linux (Ubuntu 15.04+, Debian 8+, CentOS 7+, etc.)
- Standard Linux commands (`curl`, `grep`, `pgrep`, `pkill`)

**If you're using a non-systemd Linux distribution**, you may need to modify the service restart section to use your init system (SysV, Upstart, etc.).

## Complete Update Script

You can create a script to automate this process. Save this as `update_deployment.sh`:

```bash
#!/bin/bash
# Quick update script for production deployment

set -e  # Exit on error

echo "🔄 Starting deployment update..."

# Configuration
APP_DIR="/opt/telangana-congress-api"  # Change to your actual path
SERVICE_NAME="telangana-congress-api"  # Change to your service name

# Navigate to app directory
cd "$APP_DIR" || { echo "❌ Directory not found: $APP_DIR"; exit 1; }

# Pull latest code
echo "📥 Pulling latest code..."
git pull origin main

# Activate virtual environment if it exists
if [ -d "venv" ]; then
    echo "🐍 Activating virtual environment..."
    source venv/bin/activate
elif [ -d ".venv" ]; then
    echo "🐍 Activating virtual environment..."
    source .venv/bin/activate
fi

# Update dependencies
echo "📦 Updating dependencies..."
pip install -r requirements.txt --upgrade

# Run database migrations
echo "🗄️  Running database migrations..."
export FLASK_APP=app.py
flask db upgrade || echo "⚠️  Migration failed or not needed, continuing..."

# Restart service
echo "🔄 Restarting service..."
if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    sudo systemctl restart "$SERVICE_NAME"
    echo "✅ Service restarted"
else
    echo "⚠️  Service not found, you may need to restart manually"
fi

# Wait a moment for service to start
sleep 3

# Verify health
echo "🏥 Checking health..."
if curl -f -s http://localhost/api/health > /dev/null; then
    echo "✅ Deployment update successful!"
else
    echo "❌ Health check failed. Check logs:"
    echo "   sudo journalctl -u $SERVICE_NAME -n 50"
    exit 1
fi
```

Make it executable:
```bash
chmod +x update_deployment.sh
```

Run it:
```bash
./update_deployment.sh
```

## Manual Step-by-Step (First Time Setup)

If this is your first deployment, follow these steps:

### 1. Clone Repository (if not already cloned)
```bash
cd /opt
sudo git clone <your-repo-url> telangana-congress-api
cd telangana-congress-api/flask_backend
```

### 2. Set Up Virtual Environment
```bash
python3 -m venv venv
source venv/bin/activate
```

### 3. Install Dependencies
```bash
pip install -r requirements.txt
```

### 4. Set Up Environment Variables
```bash
cp env_production.txt .env
nano .env  # Edit with your production values
```

### 5. Initialize Database
```bash
export FLASK_APP=app.py
flask db init  # Only needed once
flask db migrate -m "Initial migration"
flask db upgrade

# OR if not using Flask-Migrate, tables will be auto-created:
# python3 -c "from app import create_app, db; app = create_app(); app.app_context().push(); db.create_all()"
```

### 5a. Run One-Time Migrations (if needed)
```bash
# If migrating from old UUID constituency IDs to integer IDs
python3 migrate_constituencies_to_integer_ids.py

# If members table is missing constituency columns
python3 add_constituency_columns.py

# Create RSVP table if missing
python3 create_rsvp_table.py
```

### 5b. Populate Initial Data
```bash
# Populate constituency data
python3 populate_parliamentary_constituencies.py
python3 populate_assembly_constituencies.py

# Initialize media statistics
python3 initialize_media_stats.py
```

### 6. Test the Application
```bash
python3 app.py
# Test in another terminal:
curl http://localhost/api/health
```

### 7. Set Up Production Service (systemd)
```bash
# Use the deploy_production.sh script or manually create service
sudo ./deploy_production.sh
```

## Troubleshooting

### If migrations fail:
```bash
# Check current migration status
flask db current

# Check migration history
flask db history

# If needed, manually create tables
python3 -c "from app import create_app, db; app = create_app(); app.app_context().push(); db.create_all()"
```

### If constituency migration is needed:
```bash
# Check if your database has old UUID columns
python3 -c "
from app import create_app, db
from sqlalchemy import inspect
app = create_app()
with app.app_context():
    inspector = inspect(db.engine)
    pc_cols = [c['name'] for c in inspector.get_columns('parliamentary_constituencies')]
    ac_cols = [c['name'] for c in inspector.get_columns('assembly_constituencies')]
    if 'id' in pc_cols or 'id' in ac_cols:
        print('⚠️  Old UUID id columns found. Run: python3 migrate_constituencies_to_integer_ids.py')
    else:
        print('✅ Database already uses integer constituency IDs')
"

# Run the migration
python3 migrate_constituencies_to_integer_ids.py
```

### If service won't start:
```bash
# Check service logs
sudo journalctl -u telangana-congress-api -n 100

# Check if port is in use
sudo lsof -i :80

# Check Python/Flask errors
tail -f app.log
```

### If dependencies fail to install:
```bash
# Upgrade pip first
pip install --upgrade pip

# Install dependencies one by one to identify issues
pip install -r requirements.txt --no-cache-dir
```

### If database connection fails:
```bash
# Verify .env file has correct DATABASE_URL
cat .env | grep DATABASE_URL

# Test database connection
python3 -c "from app import create_app; app = create_app(); from app import db; db.engine.connect()"
```

## Environment Variables Checklist

Make sure your `.env` file on the server has these set:

```bash
# Required
SECRET_KEY=your-production-secret-key
JWT_SECRET_KEY=your-jwt-secret-key
DATABASE_URL=postgresql://user:password@host:5432/TGTS

# Optional but recommended
FLASK_ENV=production
FLASK_DEBUG=False
PORT=80
CORS_ORIGINS=https://yourdomain.com

# Service credentials (if using)
TWILIO_ACCOUNT_SID=...
TWILIO_AUTH_TOKEN=...
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
```

## Quick Reference

**For regular updates (after initial setup):**
```bash
cd /opt/telangana-congress-api/flask_backend
git pull
source venv/bin/activate  # if using venv
pip install -r requirements.txt --upgrade
flask db upgrade
# Only run this ONCE if migrating from UUID to integer constituency IDs:
# python3 migrate_constituencies_to_integer_ids.py
sudo systemctl restart telangana-congress-api
curl http://localhost/api/health
```

**For first-time deployment (includes all migrations):**
```bash
cd /opt/telangana-congress-api/flask_backend
git pull
source venv/bin/activate
pip install -r requirements.txt
export FLASK_APP=app.py

# Initialize database
flask db init  # Only first time
flask db migrate -m "Initial migration"
flask db upgrade

# One-time migrations (only if needed)
python3 migrate_constituencies_to_integer_ids.py  # If DB has old UUID columns
python3 add_constituency_columns.py  # If members table missing columns
python3 create_rsvp_table.py  # If RSVP table missing

# Populate initial data
python3 populate_parliamentary_constituencies.py
python3 populate_assembly_constituencies.py
python3 initialize_media_stats.py

# Restart service
sudo systemctl restart telangana-congress-api
curl http://localhost/api/health
```

**One-liner (if everything is set up):**
```bash
cd /opt/telangana-congress-api/flask_backend && git pull && source venv/bin/activate && pip install -r requirements.txt --upgrade && flask db upgrade && sudo systemctl restart telangana-congress-api && sleep 3 && curl http://localhost/api/health
```

