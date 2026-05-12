"""
Diagnostic script — run this to understand why local news is not showing.
It checks:
  1. Whether the users table has the new location columns
  2. Which users have a district/mandal set (user table)
  3. Which members have a district/mandal set
  4. How many news items have geographic targeting vs "post to all"
  5. Cross-match: which news items would be visible to which users/members

Usage:
    python diagnose_local_news.py
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from dotenv import load_dotenv
load_dotenv()

from app import create_app, db

app = create_app()

with app.app_context():
    from sqlalchemy import inspect, text
    inspector = inspect(db.engine)

    print("\n" + "=" * 70)
    print("LOCAL NEWS DIAGNOSTIC")
    print("=" * 70)

    # ── 1. Check users table columns ─────────────────────────────────────────
    print("\n[1] USERS TABLE — location columns")
    user_cols = [c['name'] for c in inspector.get_columns('users')]
    for col in ['district_id', 'mandal_id', 'parliament_constituency_id', 'assembly_constituency_id']:
        status = "✓ exists" if col in user_cols else "✗ MISSING — run add_location_to_users.py"
        print(f"    {col}: {status}")

    # ── 2. Users with location set ────────────────────────────────────────────
    print("\n[2] USERS with location in users table")
    if 'district_id' in user_cols:
        rows = db.engine.execute(text(
            "SELECT phone, district_id, mandal_id FROM users "
            "WHERE district_id IS NOT NULL OR mandal_id IS NOT NULL LIMIT 20"
        )) if False else None
        with db.engine.connect() as conn:
            rows = conn.execute(text(
                "SELECT phone, district_id, mandal_id FROM users "
                "WHERE district_id IS NOT NULL OR mandal_id IS NOT NULL LIMIT 20"
            )).fetchall()
        if rows:
            for r in rows:
                print(f"    phone={r[0]}  district_id={r[1]}  mandal_id={r[2]}")
        else:
            print("    ⚠  No users have district_id/mandal_id set in the users table yet.")
            print("    → Users must update their Profile screen to set district & mandal.")
    else:
        print("    ✗ district_id column missing — run the migration first")

    # ── 3. Members with location set ─────────────────────────────────────────
    print("\n[3] MEMBERS with location (member table)")
    with db.engine.connect() as conn:
        rows = conn.execute(text(
            "SELECT phone, district_id, mandal_id FROM members "
            "WHERE district_id IS NOT NULL OR mandal_id IS NOT NULL LIMIT 20"
        )).fetchall()
    if rows:
        for r in rows:
            print(f"    phone={r[0]}  district_id={r[1]}  mandal_id={r[2]}")
    else:
        print("    ⚠  No members have district_id/mandal_id set.")

    # ── 4. News items — geographic targeting summary ──────────────────────────
    print("\n[4] NEWS ITEMS — geographic targeting")
    with db.engine.connect() as conn:
        total = conn.execute(text("SELECT COUNT(*) FROM news_items WHERE is_published = true")).scalar()
        post_to_all = conn.execute(text(
            "SELECT COUNT(*) FROM news_items WHERE is_published = true "
            "AND (district_ids IS NULL OR district_ids = '[]'::jsonb) "
            "AND (mandal_ids IS NULL OR mandal_ids = '[]'::jsonb) "
            "AND (assembly_constituency_ids IS NULL OR assembly_constituency_ids = '[]'::jsonb) "
            "AND (parliamentary_constituency_ids IS NULL OR parliamentary_constituency_ids = '[]'::jsonb)"
        )).scalar()
        targeted = total - post_to_all

    print(f"    Total published news items : {total}")
    print(f"    'Post to all' (state news) : {post_to_all}")
    print(f"    Location-targeted (local)  : {targeted}")

    if targeted == 0:
        print("\n    ⚠  PROBLEM FOUND: No news items have district/mandal targeting.")
        print("    → When posting news in the admin panel, you must select specific")
        print("      districts or mandals for the news to appear in the Local News tab.")
        print("    → News with no geographic restrictions only appears in State News tab.")
    else:
        # Show which districts have news
        print("\n    Districts that have targeted news:")
        with db.engine.connect() as conn:
            rows = conn.execute(text(
                "SELECT DISTINCT jsonb_array_elements_text(district_ids::jsonb) AS did "
                "FROM news_items WHERE is_published = true AND district_ids IS NOT NULL "
                "AND district_ids != '[]'::jsonb"
            )).fetchall()
        for r in rows:
            print(f"      district_id = {r[0]}")

    # ── 5. Cross-match ────────────────────────────────────────────────────────
    print("\n[5] CROSS-MATCH — which users/members would see local news")
    if targeted > 0:
        with db.engine.connect() as conn:
            # Get all district_ids used in targeted news
            news_districts = set(
                str(r[0]) for r in conn.execute(text(
                    "SELECT DISTINCT jsonb_array_elements_text(district_ids::jsonb) "
                    "FROM news_items WHERE is_published=true AND district_ids IS NOT NULL "
                    "AND district_ids != '[]'::jsonb"
                )).fetchall()
            )
            # Get members whose district matches
            if news_districts:
                district_list = ','.join(news_districts)
                matched = conn.execute(text(
                    f"SELECT phone, district_id FROM members "
                    f"WHERE district_id IN ({district_list}) LIMIT 10"
                )).fetchall()
                if matched:
                    print("    Members who WOULD see local news:")
                    for r in matched:
                        print(f"      phone={r[0]}  district_id={r[1]}")
                else:
                    print("    ⚠  No members are in the districts that have local news.")
                    print("    → Either assign members to these districts, or")
                    print("      create news targeted at the districts your members are in.")
    else:
        print("    (No targeted news to cross-match against)")

    print("\n" + "=" * 70)
    print("SUMMARY OF STEPS TO FIX LOCAL NEWS")
    print("=" * 70)
    print("""
  Step 1 — Make sure the columns exist in users table:
            python add_location_to_users.py

  Step 2 — Make sure users/members have a district set:
            • Cadre/Admin: their member record must have district_id set
            • Public users: they must open Profile screen and select their
              district and mandal, then tap Save

  Step 3 — Make sure news has district targeting:
            When creating news in the admin panel, select the target
            districts/mandals. News with NO district selected goes to
            State News tab only (visible to everyone). News with a district
            selected goes to Local News tab (visible to that district only).

  Step 4 — Restart Flask server after code changes.
""")
