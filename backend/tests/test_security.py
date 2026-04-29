"""Security-focused integration tests: rate limiting, CORS, error sanitization, auth."""

import time

from starlette.websockets import WebSocketDisconnect
from fastapi.testclient import TestClient

from tests.conftest import auth_headers, register_user


def test_rate_limiting_login(client: TestClient):
    username = f"ratelimit_{int(time.time()*1000)}"
    client.post("/api/auth/register", json={
        "username": username,
        "password": "TestPass123!",
        "displayName": "Rate Limit",
        "avatarName": "avatar_1",
    })

    got_429 = False
    for _ in range(8):
        resp = client.post("/api/auth/login", json={
            "username": username,
            "password": "WrongPass!",
        })
        if resp.status_code == 429:
            got_429 = True
            break
    assert got_429, "Expected at least one 429 from rapid login attempts"


def test_cors_not_wildcard_with_credentials(client: TestClient):
    resp = client.options(
        "/health",
        headers={
            "Origin": "http://localhost:3000",
            "Access-Control-Request-Method": "GET",
        },
    )
    allow_origin = resp.headers.get("access-control-allow-origin", "")
    assert allow_origin != "*"
    assert "localhost" in allow_origin or allow_origin == "http://localhost:3000"


def test_error_sanitization(client: TestClient):
    resp = client.get("/api/auth/me")
    assert resp.status_code == 401
    body = resp.json()
    assert "traceback" not in str(body).lower()
    assert "stack" not in str(body).lower()


def test_invalid_token_returns_401(client: TestClient):
    headers = {"Authorization": "Bearer invalid.jwt.token"}
    resp = client.get("/api/auth/me", headers=headers)
    assert resp.status_code == 401

    headers_expired = {"Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZXN0IiwiZXhwIjoxfQ.fake"}
    resp2 = client.get("/api/auth/me", headers=headers_expired)
    assert resp2.status_code == 401


def test_websocket_rejects_missing_token(client: TestClient):
    try:
        with client.websocket_connect("/ws/rooms/not-a-room"):
            assert False, "WebSocket should reject missing token"
    except WebSocketDisconnect as exc:
        assert exc.code == 4001


def test_websocket_accepts_authorization_header_for_room_member(client: TestClient):
    user_a = register_user(client)
    user_b = register_user(client)
    room_resp = client.post(
        "/api/rooms",
        json={
            "type": "group",
            "name": "WS Test Room",
            "memberUsernames": [user_b["user"]["username"]],
        },
        headers=auth_headers(user_a["token"]),
    )
    assert room_resp.status_code == 201
    room_id = room_resp.json()["id"]

    with client.websocket_connect(
        f"/ws/rooms/{room_id.upper()}",
        headers=auth_headers(user_a["token"]),
    ) as websocket:
        message = websocket.receive_json()

    assert message == {"type": "connected", "data": {"roomId": room_id}}
