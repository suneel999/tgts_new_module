"""
Migration script to change constituency primary keys from UUID to Integer
This will use constituency_number as the primary key for both parliamentary and assembly constituencies
"""
import os
import sys
from pathlib import Path

# Add the parent directory to the path so we can import app
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import create_app, db
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def migrate_constituencies():
    """Migrate constituencies from UUID to Integer primary keys"""
    app = create_app()
    
    with app.app_context():
        try:
            from sqlalchemy import inspect, text
            
            print("Migrating constituencies to Integer IDs...")
            print("=" * 70)
            
            # Detect database type
            db_url = app.config.get('SQLALCHEMY_DATABASE_URI', '')
            is_sqlite = 'sqlite' in db_url.lower()
            is_postgres = 'postgresql' in db_url.lower() or 'postgres' in db_url.lower()
            
            print(f"Database Type: {'SQLite' if is_sqlite else 'PostgreSQL' if is_postgres else 'Unknown'}")
            
            with db.engine.connect() as conn:
                # Step 0: Check if migration is needed
                inspector = inspect(db.engine)
                
                # Check constituency tables
                if 'parliamentary_constituencies' not in inspector.get_table_names():
                    print("\n⚠️  parliamentary_constituencies table does not exist")
                    print("   Run db.create_all() or flask db upgrade first")
                    return
                
                pc_columns = inspector.get_columns('parliamentary_constituencies')
                pc_col_names = [c['name'] for c in pc_columns]
                
                # Check if already using integer constituency_number as primary key
                has_constituency_number_pk = any(
                    c['name'] == 'constituency_number' and c.get('primary_key') 
                    for c in pc_columns
                )
                
                if has_constituency_number_pk and 'id' not in pc_col_names:
                    print("\n✅ Migration not needed!")
                    print("   Database already uses 'constituency_number' as primary key")
                    print("   No UUID 'id' column found - schema is already correct")
                    return
                
                if 'id' not in pc_col_names:
                    print("\n⚠️  No 'id' column found in parliamentary_constituencies")
                    print("   Migration may not be needed - checking schema...")
                    # Continue to check other tables
                
                # Check if members table has foreign keys
                members_columns = inspector.get_columns('members')
                has_parliament_fk = any(c['name'] == 'parliament_constituency_id' for c in members_columns)
                has_assembly_fk = any(c['name'] == 'assembly_constituency_id' for c in members_columns)
                
                print("\nStep 1: Dropping foreign key constraints...")
                
                # SQLite doesn't support DROP CONSTRAINT - need different approach
                if is_sqlite:
                    print("  ℹ️  SQLite detected - foreign key constraints will be handled differently")
                    # SQLite doesn't support dropping constraints directly
                    # We'll need to recreate tables or use a workaround
                    print("  ⚠️  SQLite migration requires recreating tables")
                    print("  → Consider switching to PostgreSQL first, or use a different migration approach")
                    print("\n⚠️  This migration script is designed for PostgreSQL")
                    print("   For SQLite, you may need to:")
                    print("   1. Export data")
                    print("   2. Recreate tables with new schema")
                    print("   3. Import data")
                    print("   OR switch to PostgreSQL first")
                    return
                
                # PostgreSQL constraint dropping
                if has_parliament_fk:
                    try:
                        conn.execute(text("""
                            ALTER TABLE members 
                            DROP CONSTRAINT IF EXISTS fk_members_parliament_constituency;
                        """))
                        print("  ✓ Dropped parliament_constituency_id foreign key")
                    except Exception as e:
                        print(f"  ⚠ Could not drop parliament_constituency_id FK: {e}")
                
                if has_assembly_fk:
                    try:
                        conn.execute(text("""
                            ALTER TABLE members 
                            DROP CONSTRAINT IF EXISTS fk_members_assembly_constituency;
                        """))
                        print("  ✓ Dropped assembly_constituency_id foreign key")
                    except Exception as e:
                        print(f"  ⚠ Could not drop assembly_constituency_id FK: {e}")
                
                # Drop foreign key from assembly_constituencies to parliamentary_constituencies
                try:
                    conn.execute(text("""
                        ALTER TABLE assembly_constituencies 
                        DROP CONSTRAINT IF EXISTS assembly_constituencies_parliament_constituency_id_fkey;
                    """))
                    print("  ✓ Dropped assembly_constituencies parliament FK")
                except Exception as e:
                    print(f"  ⚠ Could not drop assembly_constituencies FK: {e}")
                
                conn.commit()
                
                # Step 2: Update members table - change foreign key columns to INTEGER
                print("\nStep 2: Updating members table foreign keys to INTEGER...")
                if has_parliament_fk:
                    # First, we need to map UUIDs to constituency numbers
                    # Get mapping of UUID to constituency_number
                    result = conn.execute(text("""
                        SELECT id, constituency_number 
                        FROM parliamentary_constituencies;
                    """))
                    uuid_to_number = {row[0]: row[1] for row in result}
                    
                    # Update members.parliament_constituency_id to use constituency_number
                    for uuid_id, const_number in uuid_to_number.items():
                        conn.execute(text("""
                            UPDATE members 
                            SET parliament_constituency_id = :const_number
                            WHERE parliament_constituency_id = :uuid_id;
                        """).bindparams(const_number=str(const_number), uuid_id=uuid_id))
                    
                    # Change column type to INTEGER (PostgreSQL syntax)
                    if is_postgres:
                        conn.execute(text("""
                            ALTER TABLE members 
                            ALTER COLUMN parliament_constituency_id TYPE INTEGER 
                            USING parliament_constituency_id::INTEGER;
                        """))
                    else:
                        # SQLite doesn't support ALTER COLUMN TYPE directly
                        print("  ⚠️  SQLite doesn't support ALTER COLUMN TYPE")
                        print("  → Migration requires PostgreSQL")
                        return
                    print("  ✓ Updated parliament_constituency_id to INTEGER")
                
                if has_assembly_fk:
                    # Get mapping of UUID to constituency_number for assembly
                    result = conn.execute(text("""
                        SELECT id, constituency_number 
                        FROM assembly_constituencies;
                    """))
                    uuid_to_number = {row[0]: row[1] for row in result}
                    
                    # Update members.assembly_constituency_id
                    for uuid_id, const_number in uuid_to_number.items():
                        conn.execute(text("""
                            UPDATE members 
                            SET assembly_constituency_id = :const_number
                            WHERE assembly_constituency_id = :uuid_id;
                        """).bindparams(const_number=str(const_number), uuid_id=uuid_id))
                    
                    # Change column type to INTEGER (PostgreSQL syntax)
                    if is_postgres:
                        conn.execute(text("""
                            ALTER TABLE members 
                            ALTER COLUMN assembly_constituency_id TYPE INTEGER 
                            USING assembly_constituency_id::INTEGER;
                        """))
                    else:
                        print("  ⚠️  SQLite doesn't support ALTER COLUMN TYPE")
                        return
                    print("  ✓ Updated assembly_constituency_id to INTEGER")
                
                conn.commit()
                
                # Step 3: Update assembly_constituencies.parliament_constituency_id
                print("\nStep 3: Updating assembly_constituencies foreign key...")
                # Get mapping
                result = conn.execute(text("""
                    SELECT id, constituency_number 
                    FROM parliamentary_constituencies;
                """))
                uuid_to_number = {row[0]: row[1] for row in result}
                
                # Update assembly_constituencies.parliament_constituency_id
                for uuid_id, const_number in uuid_to_number.items():
                    conn.execute(text("""
                        UPDATE assembly_constituencies 
                        SET parliament_constituency_id = :const_number
                        WHERE parliament_constituency_id = :uuid_id;
                    """).bindparams(const_number=str(const_number), uuid_id=uuid_id))
                
                # Change column type to INTEGER (PostgreSQL syntax)
                if is_postgres:
                    conn.execute(text("""
                        ALTER TABLE assembly_constituencies 
                        ALTER COLUMN parliament_constituency_id TYPE INTEGER 
                        USING parliament_constituency_id::INTEGER;
                    """))
                else:
                    print("  ⚠️  SQLite doesn't support ALTER COLUMN TYPE")
                    return
                print("  ✓ Updated assembly_constituencies.parliament_constituency_id to INTEGER")
                
                conn.commit()
                
                # Step 4: Change primary keys of constituency tables
                print("\nStep 4: Changing primary keys to INTEGER...")
                
                # For parliamentary_constituencies: drop old PK, make constituency_number the PK
                conn.execute(text("""
                    ALTER TABLE parliamentary_constituencies 
                    DROP CONSTRAINT IF EXISTS parliamentary_constituencies_pkey;
                """))
                conn.execute(text("""
                    ALTER TABLE parliamentary_constituencies 
                    ADD PRIMARY KEY (constituency_number);
                """))
                print("  ✓ Changed parliamentary_constituencies primary key to constituency_number")
                
                # For assembly_constituencies: drop old PK, make constituency_number the PK
                conn.execute(text("""
                    ALTER TABLE assembly_constituencies 
                    DROP CONSTRAINT IF EXISTS assembly_constituencies_pkey;
                """))
                conn.execute(text("""
                    ALTER TABLE assembly_constituencies 
                    ADD PRIMARY KEY (constituency_number);
                """))
                print("  ✓ Changed assembly_constituencies primary key to constituency_number")
                
                conn.commit()
                
                # Step 5: Re-add foreign key constraints
                print("\nStep 5: Re-adding foreign key constraints...")
                
                if has_parliament_fk:
                    conn.execute(text("""
                        ALTER TABLE members 
                        ADD CONSTRAINT fk_members_parliament_constituency 
                        FOREIGN KEY (parliament_constituency_id) 
                        REFERENCES parliamentary_constituencies(constituency_number);
                    """))
                    print("  ✓ Re-added parliament_constituency_id foreign key")
                
                if has_assembly_fk:
                    conn.execute(text("""
                        ALTER TABLE members 
                        ADD CONSTRAINT fk_members_assembly_constituency 
                        FOREIGN KEY (assembly_constituency_id) 
                        REFERENCES assembly_constituencies(constituency_number);
                    """))
                    print("  ✓ Re-added assembly_constituency_id foreign key")
                
                conn.execute(text("""
                    ALTER TABLE assembly_constituencies 
                    ADD CONSTRAINT fk_assembly_parliament_constituency 
                    FOREIGN KEY (parliament_constituency_id) 
                    REFERENCES parliamentary_constituencies(constituency_number);
                """))
                print("  ✓ Re-added assembly_constituencies parliament FK")
                
                conn.commit()
                
                # Step 6: Drop old UUID id columns (optional - we can keep them for reference)
                print("\nStep 6: Dropping old UUID id columns...")
                try:
                    conn.execute(text("""
                        ALTER TABLE parliamentary_constituencies 
                        DROP COLUMN IF EXISTS id;
                    """))
                    print("  ✓ Dropped parliamentary_constituencies.id column")
                except Exception as e:
                    print(f"  ⚠ Could not drop id column: {e}")
                
                try:
                    conn.execute(text("""
                        ALTER TABLE assembly_constituencies 
                        DROP COLUMN IF EXISTS id;
                    """))
                    print("  ✓ Dropped assembly_constituencies.id column")
                except Exception as e:
                    print(f"  ⚠ Could not drop id column: {e}")
                
                conn.commit()
            
            print("\n" + "=" * 70)
            print("✓ Migration completed successfully!")
            print("\nNote: Constituency IDs are now INTEGER (constituency_number)")
            print("      Foreign keys have been updated accordingly")
            
        except Exception as e:
            print(f"\n✗ Error during migration: {e}")
            import traceback
            traceback.print_exc()
            raise

if __name__ == '__main__':
    print("=" * 70)
    print("CONSTITUENCY ID MIGRATION")
    print("=" * 70)
    print("This will change constituency primary keys from UUID to INTEGER")
    print("Using constituency_number as the primary key")
    print("=" * 70)
    
    response = input("\n⚠️  This is a destructive operation. Continue? (yes/no): ")
    if response.lower() != 'yes':
        print("Migration cancelled.")
        sys.exit(0)
    
    migrate_constituencies()

