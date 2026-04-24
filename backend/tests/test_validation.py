"""Tests for input validation (422 responses for invalid data)."""

from fastapi.testclient import TestClient

from tests.conftest import auth_headers, register_user


def _setup_room(client: TestClient, headers: dict) -> str:
    resp = client.post(
        "/api/rooms",
        json={"type": "group", "memberUsernames": []},
        headers=headers,
    )
    assert resp.status_code == 201, resp.text
    return resp.json()["id"]


def _send_message(client: TestClient, room_id: str, headers: dict) -> str:
    resp = client.post(
        f"/api/rooms/{room_id}/messages",
        json={"contentType": "text", "textContent": "hi"},
        headers=headers,
    )
    assert resp.status_code == 201, resp.text
    return resp.json()["id"]


# --- limit bounds ---

def test_limit_over_max_returns_422(client: TestClient):
    result = register_user(client)
    headers = auth_headers(result["token"])
    room_id = _setup_room(client, headers)
    r = client.get(f"/api/rooms/{room_id}/messages?limit=500", headers=headers)
    assert r.status_code == 422


def test_limit_under_min_returns_422(client: TestClient):
    result = register_user(client)
    headers = auth_headers(result["token"])
    room_id = _setup_room(client, headers)
    r = client.get(f"/api/rooms/{room_id}/messages?limit=0", headers=headers)
    assert r.status_code == 422


# --- before UUID validation ---

def test_before_not_uuid_returns_422(client: TestClient):
    result = register_user(client)
    headers = auth_headers(result["token"])
    room_id = _setup_room(client, headers)
    r = client.get(
        f"/api/rooms/{room_id}/messages?before=not-a-uuid", headers=headers
    )
    assert r.status_code == 422


# --- emoji length ---

def test_emoji_too_long_returns_422(client: TestClient):
    result = register_user(client)
    headers = auth_headers(result["token"])
    room_id = _setup_room(client, headers)
    msg_id = _send_message(client, room_id, headers)
    r = client.post(
        f"/api/rooms/{room_id}/messages/{msg_id}/reactions",
        json={"emoji": "a" * 11},
        headers=headers,
    )
    assert r.status_code == 422


# --- Literal types ---

def test_invalid_content_type_returns_422(client: TestClient):
    result = register_user(client)
    headers = auth_headers(result["token"])
    room_id = _setup_room(client, headers)
    r = client.post(
        f"/api/rooms/{room_id}/messages",
        json={"contentType": "invalid", "textContent": "hi"},
        headers=headers,
    )
    assert r.status_code == 422


def test_invalid_room_type_returns_422(client: TestClient):
    result = register_user(client)
    headers = auth_headers(result["token"])
    r = client.post(
        "/api/rooms",
        json={"type": "invalid", "memberUsernames": []},
        headers=headers,
    )
    assert r.status_code == 422


# --- auth field constraints ---

def test_username_pattern_violation_returns_422(client: TestClient):
    r = client.post(
        "/api/auth/register",
        json={
            "username": "bad user!",
            "password": "TestPass123!",
            "displayName": "Test",
            "avatarName": "avatar_1",
        },
    )
    assert r.status_code == 422


def test_displayname_too_short_returns_422(client: TestClient):
    r = client.post(
        "/api/auth/register",
        json={
            "username": "shortdn",
            "password": "TestPass123!",
            "displayName": "X",
            "avatarName": "avatar_1",
        },
    )
    assert r.status_code == 422