from typing import Literal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from fastapi.responses import Response
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user
from app.main import limiter
from app.models.room import Room
from app.models.user import User
from app.services import room_service, message_service, user_service
from app.services.ws_manager import manager as ws_manager

router = APIRouter()


class CreateRoomRequest(BaseModel):
    name: str | None = None
    type: Literal["direct", "group"]
    memberUsernames: list[str]


class UpdateRoomRequest(BaseModel):
    name: str


class AddMemberRequest(BaseModel):
    username: str


class CreateMessageRequest(BaseModel):
    contentType: Literal["text", "song", "system"]
    textContent: str | None = None
    trackData: str | None = None
    replyToId: str | None = None


class AddEmojiRequest(BaseModel):
    emoji: str = Field(..., min_length=1, max_length=10)


class RoomResponse(BaseModel):
    id: str
    name: str | None
    type: str
    createdBy: str
    createdAt: str
    isActive: bool
    memberUsernames: list[str]

    class Config:
        from_attributes = True


class MemberResponse(BaseModel):
    id: str
    roomId: str
    userId: str
    joinedAt: str

    class Config:
        from_attributes = True


class MessageResponse(BaseModel):
    id: str
    roomId: str
    senderId: str
    senderName: str
    contentType: str
    textContent: str | None
    trackData: str | None
    replyToId: str | None
    createdAt: str

    class Config:
        from_attributes = True


class EmojiReactionResponse(BaseModel):
    id: str
    messageId: str
    userId: str
    emoji: str
    createdAt: str

    class Config:
        from_attributes = True


def _normalize_uuid_or_404(value: str, detail: str = "Resource not found") -> str:
    try:
        return str(UUID(value))
    except ValueError:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=detail)


def _room_to_response(room, db: Session) -> RoomResponse:
    members = room_service.get_room_members(db, room.id)
    member_user_ids = [m.user_id for m in members]
    member_usernames: list[str] = []
    for uid in member_user_ids:
        u = user_service.get_user_by_id(db, uid)
        if u:
            member_usernames.append(u.username)
    return RoomResponse(
        id=room.id,
        name=room.name,
        type=room.type,
        createdBy=room.created_by,
        createdAt=room.created_at.isoformat(),
        isActive=room.is_active,
        memberUsernames=member_usernames,
    )


def _member_to_response(member) -> MemberResponse:
    return MemberResponse(
        id=member.id,
        roomId=member.room_id,
        userId=member.user_id,
        joinedAt=member.joined_at.isoformat(),
    )


def _message_to_response(msg, db: Session) -> MessageResponse:
    sender = user_service.get_user_by_id(db, msg.sender_id)
    sender_name = sender.display_name if sender else "Unknown"
    return MessageResponse(
        id=msg.id,
        roomId=msg.room_id,
        senderId=msg.sender_id,
        senderName=sender_name,
        contentType=msg.content_type,
        textContent=msg.text_content,
        trackData=msg.track_data,
        replyToId=msg.reply_to_id,
        createdAt=msg.created_at.isoformat(),
    )


def _emoji_to_response(reaction) -> EmojiReactionResponse:
    return EmojiReactionResponse(
        id=reaction.id,
        messageId=reaction.message_id,
        userId=reaction.user_id,
        emoji=reaction.emoji,
        createdAt=reaction.created_at.isoformat(),
    )


def _require_membership(db: Session, room_id: str, user_id: str):
    if not room_service.is_room_member(db, room_id, user_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not a member of this room",
        )


def _require_message_in_room(db: Session, room_id: str, message_id: str):
    message = message_service.get_message_by_id(db, message_id)
    if message is None or message.room_id != room_id or message.deleted_at is not None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Message not found",
        )
    return message


@router.get("", response_model=list[RoomResponse])
def list_rooms(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    rooms = room_service.get_rooms_for_user(db, user.id)
    return [_room_to_response(r, db) for r in rooms]


@router.post("", response_model=RoomResponse, status_code=status.HTTP_201_CREATED)
def create_room(
    req: CreateRoomRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if req.type == "direct" and len(req.memberUsernames) != 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Direct rooms must have exactly one other member",
        )
    room = room_service.create_room(
        db=db,
        name=req.name,
        room_type=req.type,
        created_by=user.id,
        member_usernames=req.memberUsernames,
    )
    return _room_to_response(room, db)


@router.get("/{room_id}", response_model=RoomResponse)
def get_room(
    room_id: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    room_id = _normalize_uuid_or_404(room_id, "Room not found")
    room = room_service.get_room(db, room_id)
    if room is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Room not found"
        )
    _require_membership(db, room_id, user.id)
    return _room_to_response(room, db)


@router.put("/{room_id}", response_model=RoomResponse)
def update_room(
    room_id: str,
    req: UpdateRoomRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    room_id = _normalize_uuid_or_404(room_id, "Room not found")
    room = room_service.get_room(db, room_id)
    if room is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Room not found"
        )
    _require_membership(db, room_id, user.id)
    updated = room_service.rename_room(db, room_id, req.name)
    return _room_to_response(updated, db)


@router.delete("/{room_id}", status_code=status.HTTP_204_NO_CONTENT)
def dissolve_room(
    room_id: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    room_id = _normalize_uuid_or_404(room_id, "Room not found")
    room = room_service.get_room(db, room_id)
    if room is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Room not found"
        )
    _require_membership(db, room_id, user.id)
    room_service.dissolve_room(db, room_id)


@router.post("/{room_id}/leave")
@limiter.limit("10/minute")
def leave_room_endpoint(
    request: Request,
    room_id: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    room_id = _normalize_uuid_or_404(room_id, "Room not found or not a member")
    result = room_service.leave_room(db, room_id, user.id)
    if result is None:
        room = db.query(Room).filter(Room.id == room_id).first()
        if room and room.type == "direct":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Cannot leave direct rooms",
            )
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Room not found or not a member",
        )
    return {"detail": "Left room successfully"}


@router.post(
    "/{room_id}/members",
    response_model=MemberResponse,
    status_code=status.HTTP_201_CREATED,
)
def add_member(
    room_id: str,
    req: AddMemberRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    room_id = _normalize_uuid_or_404(room_id, "Room not found")
    room = room_service.get_room(db, room_id)
    if room is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Room not found"
        )
    _require_membership(db, room_id, user.id)
    member = room_service.add_member_by_username(db, room_id, req.username)
    if member is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User not found or already a member",
        )
    return _member_to_response(member)


@router.get("/{room_id}/members", response_model=list[MemberResponse])
def list_members(
    room_id: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    room_id = _normalize_uuid_or_404(room_id, "Room not found")
    room = room_service.get_room(db, room_id)
    if room is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Room not found"
        )
    _require_membership(db, room_id, user.id)
    members = room_service.get_room_members(db, room_id)
    return [_member_to_response(m) for m in members]


@router.get("/{room_id}/messages", response_model=list[MessageResponse])
def list_messages(
    room_id: str,
    limit: int = Query(default=50, le=200, ge=1),
    before: UUID | None = None,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    room_id = _normalize_uuid_or_404(room_id, "Room not found")
    room = room_service.get_room(db, room_id)
    if room is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Room not found"
        )
    _require_membership(db, room_id, user.id)
    messages = message_service.get_messages(db, room_id, limit=limit, before=str(before) if before else None)
    return [_message_to_response(m, db) for m in messages]


@router.post(
    "/{room_id}/messages",
    response_model=MessageResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_message(
    room_id: str,
    req: CreateMessageRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    room_id = _normalize_uuid_or_404(room_id, "Room not found")
    room = room_service.get_room(db, room_id)
    if room is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Room not found"
        )
    _require_membership(db, room_id, user.id)
    if req.replyToId is not None:
        req.replyToId = _normalize_uuid_or_404(req.replyToId, "Message not found")
        _require_message_in_room(db, room_id, req.replyToId)
    msg = message_service.create_message(
        db=db,
        room_id=room_id,
        sender_id=user.id,
        content_type=req.contentType,
        text_content=req.textContent,
        track_data=req.trackData,
        reply_to_id=req.replyToId,
    )
    response = _message_to_response(msg, db)
    await ws_manager.broadcast_to_room(
        room_id, {"type": "new_message", "data": response.model_dump()}
    )
    return response


@router.delete(
    "/{room_id}/messages/{message_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def delete_message(
    room_id: str,
    message_id: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    room_id = _normalize_uuid_or_404(room_id, "Room not found")
    message_id = _normalize_uuid_or_404(message_id, "Message not found")
    room = room_service.get_room(db, room_id)
    if room is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Room not found"
        )
    _require_membership(db, room_id, user.id)
    message = _require_message_in_room(db, room_id, message_id)
    if message.sender_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Can only delete your own messages",
        )
    message_service.soft_delete_message(db, message_id, user.id)
    await ws_manager.broadcast_to_room(
        room_id,
        {"type": "message_deleted", "data": {"messageId": message_id}},
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post(
    "/{room_id}/messages/{message_id}/reactions",
    response_model=EmojiReactionResponse,
    status_code=status.HTTP_201_CREATED,
)
async def add_emoji_reaction(
    room_id: str,
    message_id: str,
    req: AddEmojiRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    room_id = _normalize_uuid_or_404(room_id, "Room not found")
    message_id = _normalize_uuid_or_404(message_id, "Message not found")
    room = room_service.get_room(db, room_id)
    if room is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Room not found"
        )
    _require_membership(db, room_id, user.id)
    _require_message_in_room(db, room_id, message_id)
    reaction = message_service.add_emoji_reaction(db, message_id, user.id, req.emoji)
    response = _emoji_to_response(reaction)
    await ws_manager.broadcast_to_room(
        room_id, {"type": "emoji_reaction", "data": response.model_dump()}
    )
    return response
