"""
Database migration utilities
Automatically checks and adds missing columns on startup
"""

from app import db
from sqlalchemy import text
import logging

logger = logging.getLogger(__name__)

def ensure_member_columns():
    """
    Ensure all required columns exist in the members table.
    This function is idempotent and can be run multiple times safely.
    """
    try:
        inspector = db.inspect(db.engine)
        
        # Check if members table exists
        if 'members' not in inspector.get_table_names():
            logger.warning("Members table does not exist. It will be created by db.create_all()")
            return
        
        # Get existing columns
        columns = {col['name']: col for col in inspector.get_columns('members')}
        
        # Define required columns with their types
        required_columns = {
            'profile_picture_url': {
                'type': 'VARCHAR(500)',
                'nullable': True
            },
            'member_id': {
                'type': 'VARCHAR(14)',
                'nullable': True
            }
            # Add more columns here as needed in the future
        }
        
        # Check and add missing columns, or alter existing ones if size changed
        added_columns = []
        altered_columns = []
        for column_name, column_def in required_columns.items():
            if column_name not in columns:
                try:
                    with db.engine.connect() as conn:
                        conn.execute(text(f"""
                            ALTER TABLE members 
                            ADD COLUMN {column_name} {column_def['type']}
                        """))
                        conn.commit()
                    added_columns.append(column_name)
                    logger.info(f"Added missing column '{column_name}' to members table")
                except Exception as e:
                    logger.error(f"Failed to add column '{column_name}': {str(e)}")
                    # Continue with other columns even if one fails
            else:
                # Column exists, check if we need to alter its size
                existing_column = columns[column_name]
                existing_type = str(existing_column['type']).upper()
                
                # Check if member_id column needs to be resized from VARCHAR(12) to VARCHAR(14)
                # Handle both VARCHAR(12) and CHARACTER VARYING(12) formats
                needs_resize = (
                    column_name == 'member_id' and 
                    ('VARCHAR(12)' in existing_type or 
                     'CHARACTER VARYING(12)' in existing_type or
                     'VARCHAR' in existing_type and '(12)' in existing_type)
                )
                
                if needs_resize:
                    try:
                        with db.engine.connect() as conn:
                            # Use ALTER COLUMN to change the size
                            conn.execute(text(f"""
                                ALTER TABLE members 
                                ALTER COLUMN {column_name} TYPE {column_def['type']}
                            """))
                            conn.commit()
                        altered_columns.append(column_name)
                        logger.info(f"Altered column '{column_name}' from {existing_type} to VARCHAR(14)")
                    except Exception as e:
                        logger.error(f"Failed to alter column '{column_name}': {str(e)}")
                        # Continue with other columns even if one fails
        
        if added_columns:
            logger.info(f"Successfully added {len(added_columns)} column(s) to members table: {', '.join(added_columns)}")
        if altered_columns:
            logger.info(f"Successfully altered {len(altered_columns)} column(s) in members table: {', '.join(altered_columns)}")
        if not added_columns and not altered_columns:
            logger.debug("All required columns exist in members table with correct types")
            
    except Exception as e:
        logger.error(f"Error checking/adding member columns: {str(e)}")
        # Don't raise - allow app to continue even if migration check fails

def ensure_cadre_level_columns():
    """
    Ensure cadre_level column exists in the members table,
    and creator_cadre_level exists in events and media_items tables.
    """
    try:
        inspector = db.inspect(db.engine)
        
        # Add cadre_level to members
        if 'members' in inspector.get_table_names():
            columns = {col['name'] for col in inspector.get_columns('members')}
            if 'cadre_level' not in columns:
                try:
                    with db.engine.connect() as conn:
                        conn.execute(text(
                            "ALTER TABLE members ADD COLUMN cadre_level INTEGER REFERENCES cadre_levels(level)"
                        ))
                        conn.commit()
                    logger.info("Added 'cadre_level' column to members table")
                except Exception as e:
                    logger.error(f"Failed to add cadre_level to members: {str(e)}")
        
        # Add creator_cadre_level to events
        if 'events' in inspector.get_table_names():
            columns = {col['name'] for col in inspector.get_columns('events')}
            if 'creator_cadre_level' not in columns:
                try:
                    with db.engine.connect() as conn:
                        conn.execute(text(
                            "ALTER TABLE events ADD COLUMN creator_cadre_level INTEGER"
                        ))
                        conn.commit()
                    logger.info("Added 'creator_cadre_level' column to events table")
                except Exception as e:
                    logger.error(f"Failed to add creator_cadre_level to events: {str(e)}")
        
        # Add creator_cadre_level to media_items
        if 'media_items' in inspector.get_table_names():
            columns = {col['name'] for col in inspector.get_columns('media_items')}
            if 'creator_cadre_level' not in columns:
                try:
                    with db.engine.connect() as conn:
                        conn.execute(text(
                            "ALTER TABLE media_items ADD COLUMN creator_cadre_level INTEGER"
                        ))
                        conn.commit()
                    logger.info("Added 'creator_cadre_level' column to media_items table")
                except Exception as e:
                    logger.error(f"Failed to add creator_cadre_level to media_items: {str(e)}")
        
    except Exception as e:
        logger.error(f"Error in ensure_cadre_level_columns: {str(e)}")


def ensure_all_columns():
    """
    Ensure all required columns exist in all tables.
    Call this function on app startup.
    """
    ensure_member_columns()
    ensure_cadre_level_columns()

