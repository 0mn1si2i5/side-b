"""Integration tests for room endpoints."""

from fastapi.testclient import TestClient

from tests.conftest import auth_headers, register_user


def _create_dm_room(client: TestClient, token: str, other_username: str):
    return client.post("/api/rooms", json={
        "type": "direct",
        "memberUsernames": [other_username],
    }, headers=auth_headers(token))


def _create_group_room(client: TestClient, token: str, member_usernames: list[str], name: str = "Test Group"):
    return client.post("/api/rooms", json={
        "type": "group",
        "name": name,
        "memberUsernames": member_usernames,
    }, headers=auth_headers(token))


def test_create_dm_room(client: TestClient):
    user_a = register_user(client)
    user_b = register_user(client)
    token_a = user_a["token"]

    resp = _create_dm_room(client, token_a, user_b["user"]["username"])
    assert resp.status_code == 201
    room = resp.json()
    assert room["type"] == "direct"

    list_resp = client.get("/api/rooms", headers=auth_headers(token_a))
    assert list_resp.status_code == 200
    room_ids = [r["id"] for r in list_resp.json()]
    assert room["id"] in room_ids


def test_create_group_room(client: TestClient):
    user_a = register_user(client)
    user_b = register_user(client)
    token_a = user_a["token"]

    resp = _create_group_room(client, token_a, [user_b["user"]["username"]])
    assert resp.status_code == 201
    room = resp.json()
    assert room["type"] == "group"
    assert room["name"] == "Test Group"


def test_create_self_only_room(client: TestClient):
    user_a = register_user(client)
    token_a = user_a["token"]

    resp = client.post("/api/rooms", json={
        "type": "group",
        "memberUsernames": [],
    }, headers=auth_headers(token_a))
    assert resp.status_code == 201
    room = resp.json()
    assert room["type"] == "group"
    assert room["memberUsernames"] == [user_a["user"]["username"]]
    assert room["name"]


def test_leave_group_room(client: TestClient):
    user_a = register_user(client)
    user_b = register_user(client)
    token_a = user_a["token"]

    room_resp = _create_group_room(client, token_a, [user_b["user"]["username"]])
    room_id = room_resp.json()["id"]

    leave_resp = client.post(f"/api/rooms/{room_id}/leave", headers=auth_headers(token_a))
    assert leave_resp.status_code == 200

    list_resp = client.get("/api/rooms", headers=auth_headers(token_a))
    room_ids = [r["id"] for r in list_resp.json()]
    assert room_id not in room_ids


def test_cannot_leave_dm_room(client: TestClient):
    user_a = register_user(client)
    user_b = register_user(client)
    token_a = user_a["token"]

    room_resp = _create_dm_room(client, token_a, user_b["user"]["username"])
    room_id = room_resp.json()["id"]

    leave_resp = client.post(f"/api/rooms/{room_id}/leave", headers=auth_headers(token_a))
    assert leave_resp.status_code == 403


def test_dissolve_room(client: TestClient):
    user_a = register_user(client)
    user_b = register_user(client)
    token_a = user_a["token"]

    room_resp = _create_group_room(client, token_a, [user_b["user"]["username"]])
    room_id = room_resp.json()["id"]

    dissolve_resp = client.delete(f"/api/rooms/{room_id}", headers=auth_headers(token_a))
    assert dissolve_resp.status_code == 204

    get_resp = client.get(f"/api/rooms/{room_id}", headers=auth_headers(token_a))
    assert get_resp.status_code == 404

    list_resp = client.get("/api/rooms", headers=auth_headers(token_a))
    assert list_resp.status_code == 200
    room_ids = [r["id"] for r in list_resp.json()]
    assert room_id not in room_ids
