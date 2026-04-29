import logging
from uuid import UUID

from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import verify_token_from_header
from app.services import room_service
from app.services.ws_manager import manager

logger = logging.getLogger(__name__)

router = APIRouter()


def _normalize_uuid(value: str) -> str:
    return str(UUID(value))


@router.websocket("/rooms/{room_id}")
async def ws_room(
    websocket: WebSocket,
    room_id: str,
    token: str | None = Query(None),
    db: Session = Depends(get_db),
):
    try:
        authorization = websocket.headers.get("authorization")
        if authorization is None and token:
            authorization = f"Bearer {token}"
        user = verify_token_from_header(authorization, db)
    except Exception as e:
        logger.warning("WebSocket auth verification failed: %s", e)
        await websocket.close(code=4001)
        return

    try:
        normalized_room_id = _normalize_uuid(room_id)
    except ValueError:
        await websocket.close(code=4008)
        return

    if not room_service.is_room_member(db, normalized_room_id, user.id):
        await websocket.close(code=4003)
        return

    await manager.connect(websocket, normalized_room_id)
    try:
        await websocket.send_json({"type": "connected", "data": {"roomId": normalized_room_id}})
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        pass
    finally:
        manager.disconnect(websocket, normalized_room_id)
