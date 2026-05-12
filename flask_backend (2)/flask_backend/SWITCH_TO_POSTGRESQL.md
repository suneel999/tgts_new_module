# Switch from SQLite to PostgreSQL (AWS RDS)

## Current Situation

Your server is currently using **SQLite**, but you want to use **PostgreSQL on AWS RDS**.

## Quick Answer

**You don't need to run the constituency migration** - your database already uses `constituency_number` as the primary key (no UUID `id` column). The migration script is designed for databases that still have UUID columns.

## Steps to Switch to PostgreSQL

### 1. Check Current Database Status

```bash
cd /home/ec2-user/TGTS_Backend
python3 check_database.py
```

This will show you:
- Current database type (SQLite/PostgreSQL)
- Current schema structure
- What needs to be done

### 2. Update .env File with PostgreSQL Connection

Edit your `.env` file:

```bash
nano .env
```

Update the `DATABASE_URL` to point to your AWS RDS PostgreSQL:

```bash
# Replace with your actual AWS RDS endpoint
DATABASE_URL=postgresql://username:password@your-rds-endpoint.ap-south-1.rds.amazonaws.com:5432/TGTS
```

**Example from your env_example.txt:**
```bash
DATABASE_URL=postgresql://postgres:rootuser@tgtsdatabase-1.c3e20gio4dv0.ap-south-1.rds.amazonaws.com:5432/TGTS
```

### 3. Test PostgreSQL Connection

```bash
python3 -c "
from app import create_app, db
app = create_app()
with app.app_context():
    try:
        db.engine.connect()
        print('✅ PostgreSQL connection successful!')
    except Exception as e:
        print(f'❌ Connection failed: {e}')
"
```

### 4. Create Tables in PostgreSQL

The app will auto-create tables, but you can also use Flask-Migrate:

```bash
export FLASK_APP=app.py
flask db upgrade
```

Or let the app create them automatically (it does this on startup).

### 5. Migrate Data from SQLite to PostgreSQL (if needed)

If you have existing data in SQLite that you want to migrate:

```bash
# This script migrates media items
python3 migrate_to_postgres.py
```

**Note:** This script only migrates media items. For other data, you may need to:
- Export from SQLite
- Import to PostgreSQL
- Or start fresh if it's a new deployment

### 6. Populate Reference Data

Populate constituencies and other reference data:

```bash
# Populate parliamentary constituencies (17 constituencies)
python3 populate_parliamentary_constituencies.py

# Populate assembly constituencies (119 constituencies)
python3 populate_assembly_constituencies.py

# Initialize media statistics
python3 initialize_media_stats.py
```

### 7. Restart Your Application

```bash
sudo systemctl restart telangana-congress-api
# Or if using a different service name:
sudo systemctl restart your-service-name
```

### 8. Verify Everything Works

```bash
# Check health endpoint
curl http://localhost/api/health

# Check database connection
python3 check_database.py
```

## What You DON'T Need to Run

❌ **`migrate_constituencies_to_integer_ids.py`** - Your database already uses integer IDs
- The error showed "no such column: id" which means your tables already use `constituency_number` as primary key
- This migration is only for databases that still have UUID `id` columns

## Complete Switch Script

Here's a complete script to switch to PostgreSQL:

```bash
#!/bin/bash
# Switch from SQLite to PostgreSQL

set -e

echo "🔄 Switching to PostgreSQL..."

# 1. Check current status
echo "Step 1: Checking current database..."
python3 check_database.py

# 2. Update .env (you'll need to edit this manually)
echo ""
echo "Step 2: Please update .env file with PostgreSQL connection string"
echo "   Edit: nano .env"
echo "   Set: DATABASE_URL=postgresql://user:pass@rds-endpoint:5432/TGTS"
read -p "Press Enter after updating .env file..."

# 3. Test connection
echo ""
echo "Step 3: Testing PostgreSQL connection..."
python3 -c "
from app import create_app, db
app = create_app()
with app.app_context():
    try:
        db.engine.connect()
        print('✅ Connection successful!')
    except Exception as e:
        print(f'❌ Connection failed: {e}')
        exit(1)
"

# 4. Create tables
echo ""
echo "Step 4: Creating tables in PostgreSQL..."
export FLASK_APP=app.py
flask db upgrade || python3 -c "from app import create_app, db; app = create_app(); app.app_context().push(); db.create_all()"

# 5. Populate data
echo ""
echo "Step 5: Populating reference data..."
python3 populate_parliamentary_constituencies.py
python3 populate_assembly_constituencies.py
python3 initialize_media_stats.py

# 6. Restart service
echo ""
echo "Step 6: Restarting service..."
sudo systemctl restart telangana-congress-api || echo "⚠️  Update service name if different"

echo ""
echo "✅ Switch to PostgreSQL complete!"
echo "   Verify: curl http://localhost/api/health"
```

## Troubleshooting

### Connection Issues

If you can't connect to PostgreSQL:

1. **Check security groups** - Ensure your EC2 instance can access RDS
2. **Check RDS endpoint** - Verify the endpoint is correct
3. **Check credentials** - Verify username and password
4. **Check database name** - Ensure database `TGTS` exists in RDS

### Permission Issues

If you get permission errors:

```bash
# Make sure psycopg2 is installed
pip install psycopg2-binary

# Check if PostgreSQL client libraries are installed
python3 -c "import psycopg2; print('✅ psycopg2 installed')"
```

### Schema Issues

If tables don't exist:

```bash
# Force create all tables
python3 -c "
from app import create_app, db
app = create_app()
with app.app_context():
    db.create_all()
    print('✅ Tables created')
"
```

## Summary

1. ✅ **Check current status**: `python3 check_database.py`
2. ✅ **Update .env** with PostgreSQL connection string
3. ✅ **Test connection**
4. ✅ **Create tables**: `flask db upgrade` or `db.create_all()`
5. ✅ **Populate data**: Run population scripts
6. ✅ **Restart service**
7. ❌ **Skip**: `migrate_constituencies_to_integer_ids.py` (not needed)

Your database schema is already correct - you just need to switch the connection!

