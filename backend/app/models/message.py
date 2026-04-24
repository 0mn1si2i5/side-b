import uuid
from datetime import datetime, timezone

from sqlalchemy import String, DateTime, Text, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class Message(Base):
    __tablename__ = "messages"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    room_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("rooms.id", ondelete="CASCADE", name="fk_messages_room_id_rooms"), nullable=False, index=True
    )
    sender_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="SET NULL", name="fk_messages_sender_id_users"), nullable=False, index=True
    )
    content_type: Mapped[str] = mapped_column(String(20), nullable=False)
    text_content: Mapped[str | None] = mapped_column(Text, nullable=True)
    track_data: Mapped[str | None] = mapped_column(Text, nullable=True)
    reply_to_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("messages.id", ondelete="SET NULL", name="fk_messages_reply_to_id_messages"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(timezone.utc), index=True)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True, default=None)
