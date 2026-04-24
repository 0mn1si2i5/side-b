import logging

from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query
from sqlalchemy.orm import Session

from app.database import SessionLocal
from app.dependencies import verify_token_from_header
from app.services import room_service
from app.services.ws_manager import manager

logger = logging.getLogger(__name__)

router = APIRouter()


@router.websocket("/rooms/{room_id}")
async def ws_room(websocket: WebSocket, room_id: str, token: str | None = Query(None)):
    db: Session = SessionLocal()
    try:
        try:
            user = verify_token_from_header(
                f"Bearer {token}" if token else None, db
            )
        except Exception as e:
            logger.warning("WebSocket auth verification failed: %s", e)
            await websocket.close(code=4001)
            return

        if not room_service.is_room_member(db, room_id, user.id):
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
