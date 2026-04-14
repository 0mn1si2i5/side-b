from sqlalchemy.orm import Session

from app.models.message import Message
from app.models.emoji_reaction import EmojiReaction


def get_messages(
    db: Session,
    room_id: str,
    limit: int = 50,
    before: str | None = None,
) -> list[Message]:
    q = db.query(Message).filter(Message.room_id == room_id)
    if before:
        before_msg = db.query(Message).filter(Message.id == before).first()
        if before_msg:
            q = q.filter(Message.created_at < before_msg.created_at)
    return q.order_by(Message.created_at.desc()).limit(limit).all()


def create_message(
    db: Session,
    room_id: str,
    sender_id: str,
    content_type: str,
    text_content: str | None = None,
    track_data: str | None = None,
    reply_to_id: str | None = None,
) -> Message:
    msg = Message(
        room_id=room_id,
        sender_id=sender_id,
        content_type=content_type,
        text_content=text_content,
        track_data=track_data,
        reply_to_id=reply_to_id,
    )
    db.add(msg)
    db.commit()
    db.refresh(msg)
    return msg


def add_emoji_reaction(
    db: Session, message_id: str, user_id: str, emoji: str
) -> EmojiReaction:
    existing = (
        db.query(EmojiReaction)
        .filter(
            EmojiReaction.message_id == message_id,
            EmojiReaction.user_id == user_id,
            EmojiReaction.emoji == emoji,
        )
        .first()
    )
    if existing:
        return existing
    reaction = EmojiReaction(message_id=message_id, user_id=user_id, emoji=emoji)
    db.add(reaction)
    db.commit()
    db.refresh(reaction)
    return reaction
