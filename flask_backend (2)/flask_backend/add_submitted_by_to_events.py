"""
Migration: Add submitted_by_user_id column to events table.
Run once: python add_submitted_by_to_events.py
"""
import os
import psycopg2
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv('DATABASE_URL')
if not DATABASE_URL:
    raise RuntimeError('DATABASE_URL not set in .env')

conn = psycopg2.connect(DATABASE_URL)
cur = conn.cursor()

cur.execute("""
    ALTER TABLE events
    ADD COLUMN IF NOT EXISTS submitted_by_user_id VARCHAR(50);
""")

conn.commit()
cur.close()
conn.close()

print("Migration complete: submitted_by_user_id added to events table.")
