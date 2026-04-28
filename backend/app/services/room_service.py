from datetime import datetime, timezone

from sqlalchemy.orm import Session
from sqlalchemy import true

from app.models.room import Room
from app.models.room_member import RoomMember
from app.models.user import User


def get_rooms_for_user(db: Session, user_id: str) -> list[Room]:
    room_ids = (
        db.query(RoomMember.room_id)
        .filter(RoomMember.user_id == user_id, RoomMember.left_at.is_(None))
        .subquery()
    )
    return (
        db.query(Room)
        .filter(Room.id.in_(room_ids), Room.is_active.is_(true()))
        .order_by(Room.created_at.desc())
        .all()
    )


def create_room(
    db: Session,
    name: str | None,
    room_type: str,
    created_by: str,
    member_usernames: list[str],
) -> Room:
    if room_type == "direct":
        existing_dm = _find_existing_dm(db, created_by, member_usernames)
        if existing_dm:
            return existing_dm

    creator = db.query(User).filter(User.id == created_by).first()

    # New v1 room creation allows a self-only room first, then members can be invited later.
    if not name:
        if room_type == "direct" and member_usernames:
            other_user = db.query(User).filter(User.username == member_usernames[0]).first()
            if other_user:
                name = other_user.display_name or other_user.username
        if not name and creator:
            name = f"{creator.display_name or creator.username}的聊天室"

    room = Room(name=name, type=room_type, created_by=created_by)
    db.add(room)
    db.flush()

    all_usernames = set(member_usernames)
    if creator:
        all_usernames.add(creator.username)

    for username in all_usernames:
        user = db.query(User).filter(User.username == username).first()
        if user:
            member = RoomMember(room_id=room.id, user_id=user.id)
            db.add(member)

    db.commit()
    db.refresh(room)
    return room


def get_room(db: Session, room_id: str) -> Room | None:
    return db.query(Room).filter(Room.id == room_id, Room.is_active.is_(true())).first()


def rename_room(db: Session, room_id: str, name: str) -> Room | None:
    room = get_room(db, room_id)
    if room is None:
        return None
    room.name = name
    db.commit()
    db.refresh(room)
    return room


def dissolve_room(db: Session, room_id: str) -> Room | None:
    room = get_room(db, room_id)
    if room is None:
        return None
    room.is_active = False
    db.commit()
    db.refresh(room)
    return room


def leave_room(db: Session, room_id: str, user_id: str) -> RoomMember | None:
    room = db.query(Room).filter(Room.id == room_id).first()
    if room is None:
        return None
    if room.type == "direct":
        return None  # Cannot leave direct rooms
    member = (
        db.query(RoomMember)
        .filter(
            RoomMember.room_id == room_id,
            RoomMember.user_id == user_id,
            RoomMember.left_at.is_(None),
        )
        .first()
    )
    if member is None:
        return None
    member.left_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(member)
    return member


def add_member(db: Session, room_id: str, user_id: str) -> RoomMember | None:
    existing = (
        db.query(RoomMember)
        .filter(RoomMember.room_id == room_id, RoomMember.user_id == user_id)
        .first()
    )
    if existing:
        return existing
    member = RoomMember(room_id=room_id, user_id=user_id)
    db.add(member)
    db.commit()
    db.refresh(member)
    return member


def add_member_by_username(
    db: Session, room_id: str, username: str
) -> RoomMember | None:
    user = db.query(User).filter(User.username == username).first()
    if user is None:
        return None
    return add_member(db, room_id, user.id)


def get_room_members(db: Session, room_id: str) -> list[RoomMember]:
    return (
        db.query(RoomMember)
        .filter(RoomMember.room_id == room_id)
        .order_by(RoomMember.joined_at)
        .all()
    )


def is_room_member(db: Session, room_id: str, user_id: str) -> bool:
    return (
        db.query(RoomMember)
        .filter(
            RoomMember.room_id == room_id,
            RoomMember.user_id == user_id,
            RoomMember.left_at.is_(None),
        )
        .first()
        is not None
    )


def _find_existing_dm(
    db: Session, user_id: str, other_usernames: list[str]
) -> Room | None:
    other_user = db.query(User).filter(User.username == other_usernames[0]).first()
    if not other_user:
        return None

    my_rooms = (
        db.query(RoomMember.room_id)
        .filter(RoomMember.user_id == user_id, RoomMember.left_at.is_(None))
        .subquery()
    )
    other_rooms = (
        db.query(RoomMember.room_id)
        .filter(RoomMember.user_id == other_user.id, RoomMember.left_at.is_(None))
        .subquery()
    )

    return (
        db.query(Room)
        .filter(
            Room.id.in_(my_rooms),
            Room.id.in_(other_rooms),
            Room.type == "direct",
            Room.is_active.is_(true()),
        )
        .first()
    )
