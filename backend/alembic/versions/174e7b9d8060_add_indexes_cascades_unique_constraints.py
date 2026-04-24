"""add_indexes_cascades_unique_constraints

Revision ID: 174e7b9d8060
Revises: 1fb127f3f5dc
Create Date: 2026-04-25 05:17:42.322495

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '174e7b9d8060'
down_revision: Union[str, None] = '1fb127f3f5dc'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # emoji_reactions: add indexes, unique constraint, add FKs with ondelete
    # Note: SQLite doesn't store FK constraint names, so drop_constraint(type_='foreignkey')
    # always fails. In batch mode, create_foreign_key adds the FK to the recreated table.
    # The old unnamed FKs (without ondelete) will also remain — duplicate FKs are harmless
    # in SQLite since FK enforcement requires PRAGMA foreign_keys = ON and CASCADE takes precedence.
    with op.batch_alter_table('emoji_reactions', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_emoji_reactions_message_id'), ['message_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_emoji_reactions_user_id'), ['user_id'], unique=False)
        batch_op.create_unique_constraint('uq_emoji_reaction_user_message', ['message_id', 'user_id', 'emoji'])
        batch_op.create_foreign_key('fk_emoji_reactions_message_id_messages', 'messages', ['message_id'], ['id'], ondelete='CASCADE')
        batch_op.create_foreign_key('fk_emoji_reactions_user_id_users', 'users', ['user_id'], ['id'], ondelete='CASCADE')

    # messages: add indexes, add FKs with ondelete
    with op.batch_alter_table('messages', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_messages_created_at'), ['created_at'], unique=False)
        batch_op.create_index(batch_op.f('ix_messages_room_id'), ['room_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_messages_sender_id'), ['sender_id'], unique=False)
        batch_op.create_foreign_key('fk_messages_room_id_rooms', 'rooms', ['room_id'], ['id'], ondelete='CASCADE')
        batch_op.create_foreign_key('fk_messages_sender_id_users', 'users', ['sender_id'], ['id'], ondelete='SET NULL')
        batch_op.create_foreign_key('fk_messages_reply_to_id_messages', 'messages', ['reply_to_id'], ['id'], ondelete='SET NULL')

    # revoked_tokens: add user_id column with FK, make revoked_at NOT NULL
    with op.batch_alter_table('revoked_tokens', schema=None) as batch_op:
        batch_op.add_column(sa.Column('user_id', sa.String(length=36), nullable=True))
        batch_op.alter_column('revoked_at',
               existing_type=sa.DATETIME(),
               nullable=False)
        batch_op.create_index(batch_op.f('ix_revoked_tokens_user_id'), ['user_id'], unique=False)
        batch_op.create_foreign_key('fk_revoked_tokens_user_id_users', 'users', ['user_id'], ['id'], ondelete='CASCADE')

    # room_members: add indexes, add FKs with ondelete
    with op.batch_alter_table('room_members', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_room_members_room_id'), ['room_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_room_members_user_id'), ['user_id'], unique=False)
        batch_op.create_foreign_key('fk_room_members_room_id_rooms', 'rooms', ['room_id'], ['id'], ondelete='CASCADE')
        batch_op.create_foreign_key('fk_room_members_user_id_users', 'users', ['user_id'], ['id'], ondelete='CASCADE')

    # rooms: add indexes, add FK with ondelete
    with op.batch_alter_table('rooms', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_rooms_created_by'), ['created_by'], unique=False)
        batch_op.create_index(batch_op.f('ix_rooms_is_active'), ['is_active'], unique=False)
        batch_op.create_foreign_key('fk_rooms_created_by_users', 'users', ['created_by'], ['id'], ondelete='CASCADE')


def downgrade() -> None:
    # rooms: remove indexes
    with op.batch_alter_table('rooms', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_rooms_is_active'))
        batch_op.drop_index(batch_op.f('ix_rooms_created_by'))

    # room_members: remove indexes
    with op.batch_alter_table('room_members', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_room_members_user_id'))
        batch_op.drop_index(batch_op.f('ix_room_members_room_id'))

    # revoked_tokens: remove user_id column, revert revoked_at to nullable
    with op.batch_alter_table('revoked_tokens', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_revoked_tokens_user_id'))
        batch_op.alter_column('revoked_at',
               existing_type=sa.DATETIME(),
               nullable=True)
        batch_op.drop_column('user_id')

    # messages: remove indexes
    with op.batch_alter_table('messages', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_messages_sender_id'))
        batch_op.drop_index(batch_op.f('ix_messages_room_id'))
        batch_op.drop_index(batch_op.f('ix_messages_created_at'))

    # emoji_reactions: remove indexes, unique constraint
    with op.batch_alter_table('emoji_reactions', schema=None) as batch_op:
        batch_op.drop_constraint('uq_emoji_reaction_user_message', type_='unique')
        batch_op.drop_index(batch_op.f('ix_emoji_reactions_user_id'))
        batch_op.drop_index(batch_op.f('ix_emoji_reactions_message_id'))