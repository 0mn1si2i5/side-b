import logging

from fastapi import WebSocket
from typing import Dict, List

logger = logging.getLogger(__name__)


class ConnectionManager:
    """Manages WebSocket connections grouped by room_id."""

    def __init__(self) -> None:
        self.active_connections: Dict[str, List[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, room_id: str) -> None:
        await websocket.accept()
        if room_id not in self.active_connections:
            self.active_connections[room_id] = []
        self.active_connections[room_id].append(websocket)

    def disconnect(self, websocket: WebSocket, room_id: str) -> None:
        if room_id in self.active_connections:
            self.active_connections[room_id] = [
                ws for ws in self.active_connections[room_id] if ws is not websocket
            ]
            if not self.active_connections[room_id]:
                del self.active_connections[room_id]

    async def broadcast_to_room(self, room_id: str, message: dict) -> None:
        """Send a JSON message to all connections in a room."""
        connections = self.active_connections.get(room_id, [])
        stale: List[WebSocket] = []
        for ws in connections:
            try:
                await ws.send_json(message)
            except Exception as e:
                logger.debug("WebSocket send failed: %s", e)
                stale.append(ws)
        for ws in stale:
            self.disconnect(ws, room_id)


manager = ConnectionManager()
