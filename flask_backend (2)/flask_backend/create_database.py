#!/usr/bin/env python3
"""
Script to create the PostgreSQL database on AWS RDS
This script connects to the default 'postgres' database and creates the 'tgts' database
"""
import os
import sys
import psycopg2
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT
from urllib.parse import urlparse
from dotenv import load_dotenv

load_dotenv()

def create_database():
    """Create the tgts database on RDS"""
    # Get DATABASE_URL from environment
    database_url = os.getenv('DATABASE_URL', '')
    
    if not database_url:
        print("❌ Error: DATABASE_URL not found in environment variables")
        print("Please set DATABASE_URL in your .env file")
        return False
    
    print("=" * 70)
    print("DATABASE CREATION SCRIPT")
    print("=" * 70)
    print(f"\nDatabase URL: {database_url}")
    
    # Parse the database URL
    try:
        parsed = urlparse(database_url)
        db_name = parsed.path.lstrip('/')  # Remove leading slash
        
        # PostgreSQL converts unquoted identifiers to lowercase
        # So "TGTS" becomes "tgts". We'll use lowercase for consistency
        db_name_lower = db_name.lower()
        
        # Create connection URL to default 'postgres' database
        # This is needed because you can't create a database while connected to it
        admin_url = f"{parsed.scheme}://{parsed.netloc}/postgres"
        
        print(f"\nTarget database name: {db_name_lower}")
        if db_name != db_name_lower:
            print(f"Note: PostgreSQL will convert '{db_name}' to '{db_name_lower}'")
        print(f"Connecting to default 'postgres' database to create '{db_name_lower}'...")
        
        # Connect to default postgres database
        conn = psycopg2.connect(admin_url)
        conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
        cursor = conn.cursor()
        
        # Check if database already exists (PostgreSQL stores names in lowercase)
        cursor.execute(
            "SELECT 1 FROM pg_database WHERE datname = %s",
            (db_name_lower,)
        )
        exists = cursor.fetchone()
        
        if exists:
            print(f"\n⚠️  Database '{db_name_lower}' already exists!")
            response = input(f"Do you want to drop and recreate it? (y/n): ")
            if response.lower() == 'y':
                # Terminate existing connections
                cursor.execute(f"""
                    SELECT pg_terminate_backend(pid)
                    FROM pg_stat_activity
                    WHERE datname = '{db_name_lower}' AND pid <> pg_backend_pid()
                """)
                cursor.execute(f"DROP DATABASE {db_name_lower}")
                print(f"✓ Dropped existing database '{db_name_lower}'")
            else:
                print("✓ Database already exists, skipping creation")
                cursor.close()
                conn.close()
                return True
        
        # Create the database (use lowercase, unquoted)
        print(f"\nCreating database '{db_name_lower}'...")
        cursor.execute(f"CREATE DATABASE {db_name_lower}")
        print(f"✓ Database '{db_name_lower}' created successfully!")
        
        cursor.close()
        conn.close()
        
        # Test connection to the new database
        # Update database URL to use lowercase name for testing
        test_url = database_url.replace(f"/{db_name}", f"/{db_name_lower}")
        print(f"\nTesting connection to '{db_name_lower}'...")
        test_conn = psycopg2.connect(test_url)
        test_conn.close()
        print(f"✓ Connection to '{db_name_lower}' successful!")
        
        # Warn if URL uses uppercase
        if db_name != db_name_lower:
            print(f"\n⚠️  Note: Your DATABASE_URL uses '{db_name}' but PostgreSQL created '{db_name_lower}'")
            print(f"   Update your .env file to use lowercase: .../{db_name_lower}")
        
        print("\n" + "=" * 70)
        print("✅ DATABASE CREATION COMPLETE")
        print("=" * 70)
        print(f"\nYou can now run your Flask app:")
        print("  python3 app.py")
        print("\nThe app will automatically create all necessary tables.")
        
        return True
        
    except psycopg2.OperationalError as e:
        print(f"\n❌ Connection error: {e}")
        print("\nTroubleshooting:")
        print("1. Check that your RDS instance is running")
        print("2. Verify the DATABASE_URL in your .env file")
        print("3. Ensure your EC2 security group allows connections to RDS (port 5432)")
        print("4. Check that RDS security group allows inbound connections from your EC2 instance")
        return False
    except psycopg2.Error as e:
        print(f"\n❌ Database error: {e}")
        return False
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == '__main__':
    success = create_database()
    sys.exit(0 if success else 1)

