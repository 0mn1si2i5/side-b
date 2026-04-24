"""Integration tests for message endpoints."""

from fastapi.testclient import TestClient

from tests.conftest import auth_headers, register_user


def _setup_room(client: TestClient):
    user_a = register_user(client)
    user_b = register_user(client)
    room_resp = client.post("/api/rooms", json={
        "type": "group",
        "name": "Msg Test Room",
        "memberUsernames": [user_b["user"]["username"]],
    }, headers=auth_headers(user_a["token"]))
    return user_a, user_b, room_resp.json()["id"]


def test_send_text_message(client: TestClient):
    user_a, _, room_id = _setup_room(client)
    headers = auth_headers(user_a["token"])

    resp = client.post(f"/api/rooms/{room_id}/messages", json={
        "contentType": "text",
        "textContent": "Hello, world!",
    }, headers=headers)
    assert resp.status_code == 201
    msg = resp.json()
    assert msg["contentType"] == "text"
    assert msg["textContent"] == "Hello, world!"

    list_resp = client.get(f"/api/rooms/{room_id}/messages", headers=headers)
    assert list_resp.status_code == 200
    msg_ids = [m["id"] for m in list_resp.json()]
    assert msg["id"] in msg_ids


def test_send_song_message(client: TestClient):
    user_a, _, room_id = _setup_room(client)
    headers = auth_headers(user_a["token"])

    resp = client.post(f"/api/rooms/{room_id}/messages", json={
        "contentType": "song",
        "trackData": '{"title":"Test Song","artist":"Test Artist"}',
    }, headers=headers)
    assert resp.status_code == 201
    msg = resp.json()
    assert msg["contentType"] == "song"
    assert msg["trackData"] is not None


def test_delete_own_message(client: TestClient):
    user_a, _, room_id = _setup_room(client)
    headers = auth_headers(user_a["token"])

    msg_resp = client.post(f"/api/rooms/{room_id}/messages", json={
        "contentType": "text",
        "textContent": "Delete me",
    }, headers=headers)
    msg_id = msg_resp.json()["id"]

    del_resp = client.delete(
        f"/api/rooms/{room_id}/messages/{msg_id}", headers=headers
    )
    assert del_resp.status_code == 204

    list_resp = client.get(f"/api/rooms/{room_id}/messages", headers=headers)
    msg_ids = [m["id"] for m in list_resp.json()]
    assert msg_id not in msg_ids


def test_cannot_delete_others_message(client: TestClient):
    user_a, user_b, room_id = _setup_room(client)
    headers_a = auth_headers(user_a["token"])
    headers_b = auth_headers(user_b["token"])

    msg_resp = client.post(f"/api/rooms/{room_id}/messages", json={
        "contentType": "text",
        "textContent": "Not yours",
    }, headers=headers_a)
    msg_id = msg_resp.json()["id"]

    del_resp = client.delete(
        f"/api/rooms/{room_id}/messages/{msg_id}", headers=headers_b
    )
    assert del_resp.status_code == 403