"""
MySQL Migration: Add submitted_by_user_id column and make Telugu fields nullable.
Run once: python migrate_events_mysql.py
"""
import os
import pymysql
from dotenv import load_dotenv
from urllib.parse import urlparse, unquote

load_dotenv()

DATABASE_URL = os.getenv('DATABASE_URL')
if not DATABASE_URL:
    raise RuntimeError('DATABASE_URL not set in .env')

# Parse MySQL URL: mysql+pymysql://user:pass@host:port/dbname
parsed = urlparse(DATABASE_URL.replace('mysql+pymysql://', 'mysql://'))
conn = pymysql.connect(
    host=parsed.hostname,
    port=parsed.port or 3306,
    user=unquote(parsed.username),
    password=unquote(parsed.password),
    database=parsed.path.lstrip('/'),
    charset='utf8mb4'
)

cur = conn.cursor()

# Check if submitted_by_user_id already exists
cur.execute("""
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'events'
      AND COLUMN_NAME = 'submitted_by_user_id'
""")
(col_exists,) = cur.fetchone()

if col_exists:
    print("SKIP: submitted_by_user_id already exists")
else:
    cur.execute("ALTER TABLE events ADD COLUMN submitted_by_user_id VARCHAR(50) NULL;")
    print("OK: submitted_by_user_id column added")

# Make Telugu fields nullable
nullable_migrations = [
    "ALTER TABLE events MODIFY COLUMN title_te VARCHAR(200) NULL;",
    "ALTER TABLE events MODIFY COLUMN description_te TEXT NULL;",
    "ALTER TABLE events MODIFY COLUMN location_te VARCHAR(200) NULL;",
]
for sql in nullable_migrations:
    try:
        cur.execute(sql)
        print(f"OK: {sql.strip()[:60]}")
    except Exception as e:
        print(f"SKIP: {e}")

conn.commit()
cur.close()
conn.close()
print("\nMigration complete.")
