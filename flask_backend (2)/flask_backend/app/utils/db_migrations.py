"""
Database migration utilities
Automatically checks and adds missing columns on startup
"""

from app import db
from sqlalchemy import text
import logging

logger = logging.getLogger(__name__)


def _engine_dialect():
    return db.engine.dialect.name


def _is_mysql_family():
    return _engine_dialect() in ("mysql", "mariadb")


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
                        dialect = _engine_dialect()
                        with db.engine.connect() as conn:
                            if dialect == "postgresql":
                                conn.execute(text(f"""
                                    ALTER TABLE members 
                                    ALTER COLUMN {column_name} TYPE {column_def['type']}
                                """))
                            elif _is_mysql_family():
                                null_sql = "NULL" if column_def.get("nullable", True) else "NOT NULL"
                                conn.execute(text(f"""
                                    ALTER TABLE members 
                                    MODIFY COLUMN {column_name} {column_def['type']} {null_sql}
                                """))
                            else:
                                logger.warning(
                                    "Skipping member_id resize: unsupported dialect %s", dialect
                                )
                                raise RuntimeError(f"unsupported dialect: {dialect}")
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
                        # PostgreSQL allows inline REFERENCES; MySQL/MariaDB need plain INT + optional FK later.
                        if _engine_dialect() == "postgresql":
                            sql = (
                                "ALTER TABLE members ADD COLUMN cadre_level INTEGER "
                                "REFERENCES cadre_levels(level)"
                            )
                        elif _is_mysql_family():
                            sql = "ALTER TABLE members ADD COLUMN cadre_level INT NULL"
                        else:
                            sql = "ALTER TABLE members ADD COLUMN cadre_level INTEGER NULL"
                        conn.execute(text(sql))
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


def ensure_voter_columns():
    """
    Ensure beneficiary_scheme and voter_party exist on voters (MySQL/MariaDB + PostgreSQL).
    Also widen legacy beneficiary_scheme VARCHAR(50) -> VARCHAR(500) when needed.
    """
    try:
        inspector = db.inspect(db.engine)
        if 'voters' not in inspector.get_table_names():
            return

        dialect = _engine_dialect()
        columns_map = {col['name']: col for col in inspector.get_columns('voters')}

        additions = [
            ('beneficiary_scheme', 'VARCHAR(500)'),
            ('voter_party', 'VARCHAR(10)'),
        ]
        for col_name, col_type in additions:
            if col_name not in columns_map:
                try:
                    with db.engine.connect() as conn:
                        conn.execute(
                            text(f"ALTER TABLE voters ADD COLUMN {col_name} {col_type} NULL")
                        )
                        conn.commit()
                    logger.info("Added '%s' column to voters table", col_name)
                except Exception as e:
                    logger.error("Failed to add '%s' to voters: %s", col_name, e)

        # Refresh column info for widen check (avoid stale inspector cache)
        columns_map = {
            col['name']: col
            for col in db.inspect(db.engine).get_columns('voters')
        }
        if 'beneficiary_scheme' in columns_map:
            existing_type = str(columns_map['beneficiary_scheme']['type']).upper()
            if '(50)' in existing_type and '500' not in existing_type:
                try:
                    with db.engine.connect() as conn:
                        if dialect == 'postgresql':
                            conn.execute(
                                text(
                                    "ALTER TABLE voters ALTER COLUMN beneficiary_scheme TYPE VARCHAR(500)"
                                )
                            )
                        elif _is_mysql_family():
                            conn.execute(
                                text(
                                    "ALTER TABLE voters MODIFY COLUMN beneficiary_scheme VARCHAR(500) NULL"
                                )
                            )
                        else:
                            raise RuntimeError(f"unsupported dialect for widen: {dialect}")
                        conn.commit()
                    logger.info("Widened voters.beneficiary_scheme to VARCHAR(500)")
                except Exception as e:
                    logger.error("Failed to widen beneficiary_scheme on voters: %s", e)

    except Exception as e:
        logger.error(f"Error in ensure_voter_columns: {str(e)}")


def ensure_activities_columns():
    """
    Ensure activities.image_urls / video_urls exist.

    v2 used PostgreSQL TEXT[] migrations; production uses SQLAlchemy JSON (MySQL JSON /
    PostgreSQL JSONB) to match `Activity` model and RDS MySQL. This only ADDs missing columns.
    """
    try:
        inspector = db.inspect(db.engine)
        if 'activities' not in inspector.get_table_names():
            return

        dialect = _engine_dialect()
        columns = {c['name'] for c in inspector.get_columns('activities')}

        if dialect == 'postgresql':
            col_ddl = 'JSONB NULL'
        elif _is_mysql_family():
            col_ddl = 'JSON NULL'
        else:
            col_ddl = 'TEXT NULL'

        for col_name in ('image_urls', 'video_urls'):
            if col_name in columns:
                continue
            try:
                with db.engine.connect() as conn:
                    conn.execute(
                        text(f'ALTER TABLE activities ADD COLUMN {col_name} {col_ddl}')
                    )
                    conn.commit()
                logger.info("Added '%s' to activities table", col_name)
            except Exception as e:
                logger.error("Failed to add '%s' to activities: %s", col_name, e)
    except Exception as e:
        logger.error("Error in ensure_activities_columns: %s", e)


def ensure_all_columns():
    """
    Ensure all required columns exist in all tables.
    Call this function on app startup.
    """
    ensure_member_columns()
    ensure_cadre_level_columns()
    ensure_voter_columns()
    ensure_activities_columns()

