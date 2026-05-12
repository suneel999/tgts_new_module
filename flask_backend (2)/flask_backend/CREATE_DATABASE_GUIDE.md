# Creating the PostgreSQL Database on AWS RDS

## Problem
The error `FATAL: database "tgts" does not exist` means the database hasn't been created on your RDS instance yet.

## Solution Options

### Option 1: Use the Python Script (Recommended)

Run the provided script to automatically create the database:

```bash
cd /home/ec2-user/TGTS_Backend
python3 create_database.py
```

This script will:
1. Connect to the default `postgres` database on your RDS instance
2. Create the `tgts` database (or `TGTS` depending on your DATABASE_URL)
3. Test the connection

### Option 2: Create Database Manually using psql

If you have `psql` installed on your EC2 instance:

```bash
# Connect to RDS using psql
psql -h tgtsdatabase-1.c3e20gio4dv0.ap-south-1.rds.amazonaws.com \
     -U postgres \
     -d postgres

# Then run:
CREATE DATABASE tgts;

# Exit psql
\q
```

### Option 3: Create Database using Python (One-liner)

```bash
python3 -c "
import psycopg2
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT

# Connect to default postgres database
conn = psycopg2.connect(
    host='tgtsdatabase-1.c3e20gio4dv0.ap-south-1.rds.amazonaws.com',
    user='postgres',
    password='rootuser',
    database='postgres'
)
conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
cursor = conn.cursor()

# Create database
cursor.execute('CREATE DATABASE tgts')
print('Database created successfully!')

cursor.close()
conn.close()
"
```

## Important Notes

1. **Database Name Case**: PostgreSQL converts unquoted database names to lowercase. If your DATABASE_URL uses `TGTS`, it will be created as `tgts`. Both should work, but be consistent.

2. **Check Your DATABASE_URL**: Make sure your `.env` file has the correct format:
   ```bash
   DATABASE_URL=postgresql://postgres:rootuser@tgtsdatabase-1.c3e20gio4dv0.ap-south-1.rds.amazonaws.com:5432/tgts
   ```
   Note: Use lowercase `tgts` in the URL to match what PostgreSQL creates.

3. **Security Groups**: Ensure your EC2 instance's security group allows outbound connections to RDS on port 5432, and RDS security group allows inbound from your EC2 instance.

4. **After Creating Database**: Once the database is created, your Flask app will automatically create all tables when you run:
   ```bash
   python3 app.py
   ```

## Troubleshooting

### Connection Refused
- Check RDS security group allows inbound from EC2 security group
- Verify RDS instance is running
- Check network connectivity: `telnet tgtsdatabase-1.c3e20gio4dv0.ap-south-1.rds.amazonaws.com 5432`

### Authentication Failed
- Verify username and password in DATABASE_URL
- Check RDS master username and password

### Database Already Exists
- If you see "database already exists", you can skip creation
- Or drop and recreate if needed (⚠️ this will delete all data)

