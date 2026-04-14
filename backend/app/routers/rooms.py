from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.services import room_service, message_service
from app.services.ws_manager import manager as ws_manager

router = APIRouter()


class CreateRoomRequest(BaseModel):
    name: str | None = None
    type: str
    memberUsernames: list[str]


class UpdateRoomRequest(BaseModel):
    name: str


class AddMemberRequest(BaseModel):
    username: str


class CreateMessageRequest(BaseModel):
    contentType: str
    textContent: str | None = None
    trackData: str | None = None
    replyToId: str | None = None


class AddEmojiRequest(BaseModel):
    emoji: str


class RoomResponse(BaseModel):
    id: str
    name: str | None
    type: str
    createdBy: str
    createdAt: str
    isActive: bool

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


def _room_to_response(room) -> RoomResponse:
    return RoomResponse(
        id=room.id,
        name=room.name,
        type=room.type,
        createdBy=room.created_by,
        createdAt=room.created_at.isoformat(),
        isActive=room.is_active,
    )


def _member_to_response(member) -> MemberResponse:
    return MemberResponse(
        id=member.id,
        roomId=member.room_id,
        userId=member.user_id,
        joinedAt=member.joined_at.isoformat(),
    )


def _message_to_response(msg) -> MessageResponse:
    return MessageResponse(
        id=msg.id,
        roomId=msg.room_id,
        senderId=msg.sender_id,
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


@router.get("", response_model=list[RoomResponse])
def list_rooms(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    rooms = room_service.get_rooms_for_user(db, user.id)
    return [_room_to_response(r) for r in rooms]


@router.post("", response_model=RoomResponse, status_code=status.HTTP_201_CREATED)
def create_room(
    req: CreateRoomRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if req.type not in ("direct", "group"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Room type must be 'direct' or 'group'",
        )
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
    return _room_to_response(room)


@router.get("/{room_id}", response_model=RoomResponse)
def get_room(
    room_id: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    room = room_service.get_room(db, room_id)
    if room is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Room not found"
        )
    _require_membership(db, room_id, user.id)
    return _room_to_response(room)


@router.put("/{room_id}", response_model=RoomResponse)
def update_room(
    room_id: str,
    req: UpdateRoomRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    room = room_service.get_room(db, room_id)
    if room is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Room not found"
        )
    _require_membership(db, room_id, user.id)
    updated = room_service.rename_room(db, room_id, req.name)
    return _room_to_response(updated)


@router.delete("/{room_id}", status_code=status.HTTP_204_NO_CONTENT)
def dissolve_room(
    room_id: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    room = room_service.get_room(db, room_id)
    if room is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Room not found"
        )
    _require_membership(db, room_id, user.id)
    room_service.dissolve_room(db, room_id)


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
    limit: int = 50,
    before: str | None = None,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    room = room_service.get_room(db, room_id)
    if room is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Room not found"
        )
    _require_membership(db, room_id, user.id)
    messages = message_service.get_messages(db, room_id, limit=limit, before=before)
    return [_message_to_response(m) for m in messages]


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
    room = room_service.get_room(db, room_id)
    if room is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Room not found"
        )
    _require_membership(db, room_id, user.id)
    if req.contentType not in ("text", "song", "system"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Content type must be 'text', 'song', or 'system'",
        )
    msg = message_service.create_message(
        db=db,
        room_id=room_id,
        sender_id=user.id,
        content_type=req.contentType,
        text_content=req.textContent,
        track_data=req.trackData,
        reply_to_id=req.replyToId,
    )
    response = _message_to_response(msg)
    await ws_manager.broadcast_to_room(
        room_id, {"type": "new_message", "data": response.model_dump()}
    )
    return response


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
    room = room_service.get_room(db, room_id)
    if room is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Room not found"
        )
    _require_membership(db, room_id, user.id)
    reaction = message_service.add_emoji_reaction(db, message_id, user.id, req.emoji)
    response = _emoji_to_response(reaction)
    await ws_manager.broadcast_to_room(
        room_id, {"type": "emoji_reaction", "data": response.model_dump()}
    )
    return response
