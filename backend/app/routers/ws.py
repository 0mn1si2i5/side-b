from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query
from sqlalchemy.orm import Session

from app.database import SessionLocal
from app.services import user_service, room_service
from app.services.ws_manager import manager

router = APIRouter()


def _authenticate_ws_token(token: str | None) -> str | None:
    """Verify JWT from query param. Returns user_id or None."""
    if not token:
        return None
    payload = user_service.verify_token(token)
    if payload is None:
        return None
    return payload.get("sub")


@router.websocket("/rooms/{room_id}")
async def ws_room(websocket: WebSocket, room_id: str, token: str | None = Query(None)):
    user_id = _authenticate_ws_token(token)
    if user_id is None:
        await websocket.close(code=4001)
        return

    db: Session = SessionLocal()
    try:
        if not room_service.is_room_member(db, room_id, user_id):
            await websocket.close(code=4003)
            return
    finally:
        db.close()

    await manager.connect(websocket, room_id)
    try:
        await websocket.send_json({"type": "connected", "data": {"roomId": room_id}})
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        pass
    finally:
        manager.disconnect(websocket, room_id)
