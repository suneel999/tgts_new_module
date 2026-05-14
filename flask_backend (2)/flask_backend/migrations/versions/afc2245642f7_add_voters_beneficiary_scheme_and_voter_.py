"""add voters beneficiary_scheme and voter_party

Revision ID: afc2245642f7
Revises: 
Create Date: 2026-05-14 14:00:43.317697

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


# revision identifiers, used by Alembic.
revision = 'afc2245642f7'
down_revision = None
branch_labels = None
depends_on = None


def _voters_column_names(connection):
    insp = inspect(connection)
    if 'voters' not in insp.get_table_names():
        return set()
    return {c['name'] for c in insp.get_columns('voters')}


def upgrade():
    """Add beneficiary_scheme / voter_party when missing (RDS MySQL, Postgres, SQLite)."""
    conn = op.get_bind()
    cols = _voters_column_names(conn)
    if 'beneficiary_scheme' not in cols:
        op.add_column(
            'voters',
            sa.Column('beneficiary_scheme', sa.String(length=500), nullable=True),
        )
    if 'voter_party' not in cols:
        op.add_column(
            'voters',
            sa.Column('voter_party', sa.String(length=10), nullable=True),
        )


def downgrade():
    conn = op.get_bind()
    cols = _voters_column_names(conn)
    if 'voter_party' in cols:
        op.drop_column('voters', 'voter_party')
    if 'beneficiary_scheme' in cols:
        op.drop_column('voters', 'beneficiary_scheme')
