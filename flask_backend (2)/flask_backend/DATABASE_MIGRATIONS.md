# Database Migrations & Changes Summary

This document lists all database migration scripts and when to run them.

## ✅ Linux Compatibility

All scripts are **fully compatible with Linux**. They use:
- Standard Python 3 (works on all Linux distributions)
- Standard bash scripts (compatible with bash 4.0+)
- Standard SQLAlchemy and Flask-Migrate commands

## 📋 Complete List of Database Changes

### 1. Schema Migrations (Structure Changes)

#### A. Constituency ID Migration (UUID → Integer)
**File:** `migrate_constituencies_to_integer_ids.py`

**Purpose:** Converts constituency primary keys from UUID/string to Integer (`constituency_number`)

**When to run:**
- ✅ First-time deployment if database has old UUID-based constituency IDs
- ✅ Updating from older version that used UUID constituency IDs
- ❌ Skip if database already uses integer `constituency_number` as primary keys

**What it does:**
- Drops foreign key constraints
- Converts `parliamentary_constituencies.id` from UUID to `constituency_number` (Integer)
- Converts `assembly_constituencies.id` from UUID to `constituency_number` (Integer)
- Updates `members.parliament_constituency_id` to Integer
- Updates `members.assembly_constituency_id` to Integer
- Updates `assembly_constituencies.parliament_constituency_id` to Integer
- Drops old UUID `id` columns
- Re-adds foreign key constraints

**⚠️ Warning:** Destructive operation. Backup database first!

---

#### B. Add Constituency Columns to Members
**File:** `add_constituency_columns.py`

**Purpose:** Adds `parliament_constituency_id` and `assembly_constituency_id` columns to `members` table

**When to run:**
- ✅ Only if `members` table is missing these columns
- ❌ Skip if columns already exist (usually handled by `db.create_all()`)

**What it does:**
- Adds `parliament_constituency_id VARCHAR(50)` column
- Adds `assembly_constituency_id VARCHAR(50)` column
- Adds foreign key constraints

---

#### C. Optimize Constituency Columns
**File:** `optimize_constituency_columns.py`

**Purpose:** Optimizes VARCHAR sizes from VARCHAR(50) to VARCHAR(36) for UUID storage

**When to run:**
- ✅ Only if you want to optimize column sizes (optional)
- ❌ Skip if already optimized or using integer IDs

**What it does:**
- Changes `parliament_constituency_id` from VARCHAR(50) to VARCHAR(36)
- Changes `assembly_constituency_id` from VARCHAR(50) to VARCHAR(36)

---

#### D. Create RSVP Table
**File:** `create_rsvp_table.py`

**Purpose:** Creates the `event_rsvps` table for event RSVP functionality

**When to run:**
- ✅ Only if `event_rsvps` table doesn't exist
- ❌ Skip if table already exists (usually handled by `db.create_all()`)

**What it does:**
- Creates `event_rsvps` table with:
  - `id` (String(50), Primary Key)
  - `event_id` (String(50), Foreign Key to events.id)
  - `phone_number` (String(15))
  - `created_at` (DateTime)
  - Unique constraint on (event_id, phone_number)

---

### 2. Data Population Scripts (Reference Data)

#### A. Populate Parliamentary Constituencies
**File:** `populate_parliamentary_constituencies.py`

**Purpose:** Populates parliamentary constituencies data (17 constituencies)

**When to run:**
- ✅ First-time deployment with empty database
- ✅ If `parliamentary_constituencies` table is empty
- ❌ Skip if constituencies already exist

**What it does:**
- Inserts 17 parliamentary constituencies with:
  - `constituency_number` (Integer, Primary Key)
  - `name_en` (English name)
  - `name_te` (Telugu name, if available)
  - `state` (default: 'Telangana')

---

#### B. Populate Assembly Constituencies
**File:** `populate_assembly_constituencies.py`

**Purpose:** Populates assembly constituencies data (119 constituencies)

**When to run:**
- ✅ First-time deployment with empty database
- ✅ If `assembly_constituencies` table is empty
- ❌ Skip if constituencies already exist

**What it does:**
- Inserts 119 assembly constituencies with:
  - `constituency_number` (Integer, Primary Key)
  - `name_en` (English name)
  - `name_te` (Telugu name, if available)
  - `parliament_constituency_id` (Foreign Key)
  - `state` (default: 'Telangana')

---

#### C. Initialize Media Statistics
**File:** `initialize_media_stats.py`

**Purpose:** Initializes media statistics counters

**When to run:**
- ✅ First-time deployment
- ✅ After adding media stats feature
- ❌ Skip if media stats already initialized

**What it does:**
- Calculates and stores initial counts:
  - Published photos count
  - Published videos count
  - Total published media count

---

### 3. Maintenance Scripts (Optional)

#### A. Sync RSVP Counts
**File:** `sync_rsvp_counts.py`

**Purpose:** Syncs RSVP counts between `events.rsvp_count` and actual count in `event_rsvps` table

**When to run:**
- ✅ If RSVP counts are inconsistent
- ✅ After manual database changes
- ❌ Not required for regular deployments

**What it does:**
- Updates `events.rsvp_count` to match actual count in `event_rsvps` table

---

#### B. Migrate to PostgreSQL
**File:** `migrate_to_postgres.py`

**Purpose:** Migrates media items from SQLite to PostgreSQL

**When to run:**
- ✅ Only when switching from SQLite to PostgreSQL
- ✅ One-time migration
- ❌ Skip if already using PostgreSQL or not migrating

**What it does:**
- Reads media items from SQLite database
- Writes to PostgreSQL database
- Preserves all media item data

---

## 🚀 Deployment Checklist

### First-Time Deployment

```bash
# 1. Pull code
git pull origin main

# 2. Install dependencies
pip install -r requirements.txt

# 3. Set environment variables
cp env_production.txt .env
nano .env  # Edit with production values

# 4. Initialize database
export FLASK_APP=app.py
flask db init
flask db migrate -m "Initial migration"
flask db upgrade

# 5. Run schema migrations (if needed)
python3 migrate_constituencies_to_integer_ids.py  # If DB has old UUID columns
python3 add_constituency_columns.py  # If members table missing columns
python3 create_rsvp_table.py  # If RSVP table missing

# 6. Populate initial data
python3 populate_parliamentary_constituencies.py
python3 populate_assembly_constituencies.py
python3 initialize_media_stats.py

# 7. Restart service
sudo systemctl restart telangana-congress-api
```

### Regular Updates (After Initial Setup)

```bash
# 1. Pull code
git pull origin main

# 2. Update dependencies
pip install -r requirements.txt --upgrade

# 3. Run Flask migrations (if any)
export FLASK_APP=app.py
flask db upgrade

# 4. Restart service
sudo systemctl restart telangana-congress-api
```

## 🔍 How to Check What's Needed

### Check if constituency migration is needed:
```bash
python3 -c "
from app import create_app, db
from sqlalchemy import inspect
app = create_app()
with app.app_context():
    inspector = inspect(db.engine)
    try:
        pc_cols = [c['name'] for c in inspector.get_columns('parliamentary_constituencies')]
        ac_cols = [c['name'] for c in inspector.get_columns('assembly_constituencies')]
        if 'id' in pc_cols or 'id' in ac_cols:
            print('⚠️  Migration needed! Run: python3 migrate_constituencies_to_integer_ids.py')
        else:
            print('✅ Already using integer IDs')
    except Exception as e:
        print(f'Error: {e}')
"
```

### Check if constituencies are populated:
```bash
python3 -c "
from app import create_app, db
from app.models import ParliamentaryConstituency, AssemblyConstituency
app = create_app()
with app.app_context():
    pc_count = ParliamentaryConstituency.query.count()
    ac_count = AssemblyConstituency.query.count()
    print(f'Parliamentary constituencies: {pc_count} (expected: 17)')
    print(f'Assembly constituencies: {ac_count} (expected: 119)')
    if pc_count == 0:
        print('⚠️  Run: python3 populate_parliamentary_constituencies.py')
    if ac_count == 0:
        print('⚠️  Run: python3 populate_assembly_constituencies.py')
"
```

## ⚠️ Important Notes

1. **Always backup your database** before running migration scripts
2. **Test migrations on a staging environment** first
3. **Run migrations during maintenance windows** if possible
4. **Check logs** after running migrations to ensure success
5. **Most migrations are idempotent** - safe to run multiple times (they check if changes are needed)

## 📝 Summary

**Required for first-time deployment:**
- ✅ `populate_parliamentary_constituencies.py`
- ✅ `populate_assembly_constituencies.py`
- ✅ `initialize_media_stats.py`
- ✅ `create_rsvp_table.py` (or handled by `db.create_all()`)

**Required only if migrating from old schema:**
- ✅ `migrate_constituencies_to_integer_ids.py` (if DB has UUID columns)
- ✅ `add_constituency_columns.py` (if members table missing columns)

**Optional/Optimization:**
- ⚪ `optimize_constituency_columns.py` (optimization only)
- ⚪ `sync_rsvp_counts.py` (maintenance only)
- ⚪ `migrate_to_postgres.py` (only when switching databases)

