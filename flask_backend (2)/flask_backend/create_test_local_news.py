"""
Creates one test local news item targeted at a specific district.
Edit DISTRICT_ID below to match a real district ID from your districts table.

Usage:
    python create_test_local_news.py
"""
import os, sys, uuid
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dotenv import load_dotenv
load_dotenv()

from app import create_app, db

# ─── CONFIGURE THIS ───────────────────────────────────────────────────────────
DISTRICT_ID = None   # e.g. 1  — set to the district_id you want to test with
MANDAL_ID   = None   # e.g. 5  — optional, set to None to target whole district
# ──────────────────────────────────────────────────────────────────────────────

app = create_app()

with app.app_context():
    # Auto-pick the first district if not configured
    if DISTRICT_ID is None:
        from sqlalchemy import text
        with db.engine.connect() as conn:
            row = conn.execute(text("SELECT id, name_en FROM districts LIMIT 1")).fetchone()
        if row is None:
            print("✗ No districts found in the database. Add districts first.")
            sys.exit(1)
        DISTRICT_ID = row[0]
        print(f"Auto-selected district: id={row[0]}, name={row[1]}")

    from app.models.news import NewsItem
    item = NewsItem(
        id=str(uuid.uuid4()),
        title_en=f'Test Local News for District {DISTRICT_ID}',
        title_te=f'జిల్లా {DISTRICT_ID} కోసం పరీక్ష స్థానిక వార్త',
        description_en=(
            f'This is a test local news item targeted at district_id={DISTRICT_ID}. '
            'If you can see this in the Local News tab, the setup is working correctly.'
        ),
        description_te=(
            f'ఇది district_id={DISTRICT_ID} కు లక్ష్యంగా ఉన్న పరీక్ష స్థానిక వార్త. '
            'మీరు దీన్ని స్థానిక వార్తల ట్యాబ్‌లో చూడగలిగితే, సెటప్ సరిగ్గా పని చేస్తోంది.'
        ),
        category='Local',
        is_published=True,
        district_ids=[DISTRICT_ID],
        mandal_ids=[MANDAL_ID] if MANDAL_ID else None,
    )
    db.session.add(item)
    db.session.commit()
    print(f"\n✓ Created test local news item")
    print(f"  id          : {item.id}")
    print(f"  district_ids: {item.district_ids}")
    print(f"  mandal_ids  : {item.mandal_ids}")
    print(f"\nThis news will appear in the Local News tab for users whose")
    print(f"  district_id = {DISTRICT_ID}")
    if MANDAL_ID:
        print(f"  mandal_id   = {MANDAL_ID}")
    print(f"\nMake sure the user you are testing with has their district set to {DISTRICT_ID}")
    print("in their profile (Profile screen → select district → Save).")
