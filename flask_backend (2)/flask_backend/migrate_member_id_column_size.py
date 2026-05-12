"""
Migration script to change member_id column size from VARCHAR(12) to VARCHAR(14)
This is required for the new membership ID format: TS + 3-digit assembly + 9-digit counter

Run this script once to update the database schema:
    python3 migrate_member_id_column_size.py
"""

from app import create_app, db
from sqlalchemy import inspect, text
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def migrate_member_id_column():
    """Migrate member_id column from VARCHAR(12) to VARCHAR(14)"""
    app = create_app()
    
    with app.app_context():
        try:
            inspector = inspect(db.engine)
            
            # Check if members table exists
            if 'members' not in inspector.get_table_names():
                logger.error("Members table does not exist!")
                return False
            
            # Get existing columns
            columns = {col['name']: col for col in inspector.get_columns('members')}
            
            if 'member_id' not in columns:
                logger.warning("member_id column does not exist. It will be created by db.create_all()")
                return True
            
            # Check current column type
            existing_column = columns['member_id']
            existing_type = str(existing_column['type']).upper()
            
            logger.info(f"Current member_id column type: {existing_type}")
            
            # Check if migration is needed
            if 'VARCHAR(14)' in existing_type or 'CHARACTER VARYING(14)' in existing_type:
                logger.info("member_id column is already VARCHAR(14). No migration needed.")
                return True
            
            if 'VARCHAR(12)' not in existing_type and 'CHARACTER VARYING(12)' not in existing_type:
                logger.warning(f"member_id column has unexpected type: {existing_type}")
                logger.warning("Attempting to alter anyway...")
            
            # Perform migration
            logger.info("Altering member_id column from VARCHAR(12) to VARCHAR(14)...")
            
            with db.engine.connect() as conn:
                # Use ALTER COLUMN to change the size
                # PostgreSQL syntax
                conn.execute(text("""
                    ALTER TABLE members 
                    ALTER COLUMN member_id TYPE VARCHAR(14)
                """))
                conn.commit()
            
            logger.info("✓ Successfully altered member_id column to VARCHAR(14)")
            
            # Verify the change
            inspector = inspect(db.engine)
            columns = {col['name']: col for col in inspector.get_columns('members')}
            new_column = columns['member_id']
            new_type = str(new_column['type']).upper()
            logger.info(f"Verified: member_id column type is now {new_type}")
            
            return True
            
        except Exception as e:
            logger.error(f"Error migrating member_id column: {str(e)}", exc_info=True)
            db.session.rollback()
            return False

if __name__ == '__main__':
    logger.info("=" * 60)
    logger.info("Member ID Column Size Migration")
    logger.info("=" * 60)
    logger.info("This script will change member_id column from VARCHAR(12) to VARCHAR(14)")
    logger.info("")
    
    success = migrate_member_id_column()
    
    if success:
        logger.info("")
        logger.info("=" * 60)
        logger.info("Migration completed successfully!")
        logger.info("=" * 60)
    else:
        logger.error("")
        logger.error("=" * 60)
        logger.error("Migration failed! Please check the error messages above.")
        logger.error("=" * 60)
        exit(1)








