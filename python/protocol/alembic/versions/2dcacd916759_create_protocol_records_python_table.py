"""create protocol_records_python table

Revision ID: 2dcacd916759
Revises:
Create Date: 2017-08-03 08:28:14.104102

"""
from alembic import op
import sqlalchemy as sa

from sqlalchemy.dialects.postgresql import UUID as sa_uuid

# revision identifiers, used by Alembic.
revision = '2dcacd916759'
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'protocol_records_python',
        sa.Column('id',              sa.Integer,    primary_key = True),
        sa.Column('protocol_name',   sa.String(50), nullable    = False),
        sa.Column('group_uuid',      sa_uuid,       nullable    = False),
        sa.Column('instance_uuid',   sa_uuid,       nullable    = False),
        sa.Column('instance_count',  sa.Integer,    primary_key = True),
        sa.Column('instance_modulo', sa.Integer,    primary_key = True),
        sa.Column('boss_uuid',       sa_uuid,       nullable    = False),
        sa.Column('created_at',      sa.DateTime,   nullable    = False),
        sa.Column('updated_at',      sa.DateTime,   nullable    = False),
    )

    op.create_index(
        index_name = 'index_protocol_records_on_group_uuid_and_instance_modulo',
        table_name = 'protocol_records_python',
        columns    = ['group_uuid', 'instance_modulo'],
        unique     = True,
    )

    op.create_index(
        index_name = 'index_protocol_records_on_group_uuid',
        table_name = 'protocol_records_python',
        columns    = ['group_uuid'],
    )

    op.create_index(
        index_name = 'index_protocol_records_on_instance_uuid',
        table_name = 'protocol_records_python',
        columns    = ['instance_uuid'],
    )

def downgrade():
    op.drop_index(
        index_name = 'index_protocol_records_on_instance_uuid',
        table_name = 'protocol_records_python',
    )

    op.drop_index(
        index_name = 'index_protocol_records_on_group_uuid',
        table_name = 'protocol_records_python',
    )

    op.drop_index(
        index_name = 'index_protocol_records_on_group_uuid_and_instance_modulo',
        table_name = 'protocol_records_python',
    )

    op.drop_table('protocol_records_python')
