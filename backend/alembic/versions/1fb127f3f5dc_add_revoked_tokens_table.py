"""add_revoked_tokens_table

Revision ID: 1fb127f3f5dc
Revises: 67eec8747489
Create Date: 2026-04-25 03:34:04.535881

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '1fb127f3f5dc'
down_revision: Union[str, None] = '67eec8747489'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'revoked_tokens',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('token_hash', sa.String(64), nullable=False),
        sa.Column('revoked_at', sa.DateTime(), nullable=True),
    )
    op.create_index('ix_revoked_tokens_token_hash', 'revoked_tokens', ['token_hash'], unique=True)


def downgrade() -> None:
    op.drop_index('ix_revoked_tokens_token_hash', table_name='revoked_tokens')
    op.drop_table('revoked_tokens')