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

    resp = client.post(f"/api/rooms/{room_id.upper()}/messages", json={
        "contentType": "text",
        "textContent": "Hello, world!",
    }, headers=headers)
    assert resp.status_code == 201
    msg = resp.json()
    assert msg["contentType"] == "text"
    assert msg["textContent"] == "Hello, world!"

    list_resp = client.get(f"/api/rooms/{room_id.upper()}/messages", headers=headers)
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

    list_resp = client.get(f"/api/rooms/{room_id}/messages", headers=headers)
    assert list_resp.status_code == 200
    persisted = next(m for m in list_resp.json() if m["id"] == msg["id"])
    assert "Test Song" in persisted["trackData"]


def test_forwarded_song_message_persists_track_payload(client: TestClient):
    user_a, _, room_id = _setup_room(client)
    headers = auth_headers(user_a["token"])
    track_data = (
        '{"title":"Forwarded Song","artist_name":"Forward Artist",'
        '"source_platform":"Spotify","source_url":"https://open.spotify.com/track/test"}'
    )

    send_resp = client.post(f"/api/rooms/{room_id}/messages", json={
        "contentType": "song",
        "trackData": track_data,
    }, headers=headers)
    assert send_resp.status_code == 201
    message_id = send_resp.json()["id"]

    history_resp = client.get(f"/api/rooms/{room_id}/messages", headers=headers)
    assert history_resp.status_code == 200
    persisted = next(m for m in history_resp.json() if m["id"] == message_id)
    assert persisted["contentType"] == "song"
    assert "Forwarded Song" in persisted["trackData"]
    assert "source_platform" in persisted["trackData"]


def test_message_history_returns_oldest_to_newest(client: TestClient):
    user_a, _, room_id = _setup_room(client)
    headers = auth_headers(user_a["token"])

    first_resp = client.post(f"/api/rooms/{room_id}/messages", json={
        "contentType": "text",
        "textContent": "first",
    }, headers=headers)
    second_resp = client.post(f"/api/rooms/{room_id}/messages", json={
        "contentType": "text",
        "textContent": "second",
    }, headers=headers)
    third_resp = client.post(f"/api/rooms/{room_id}/messages", json={
        "contentType": "text",
        "textContent": "third",
    }, headers=headers)

    assert first_resp.status_code == 201
    assert second_resp.status_code == 201
    assert third_resp.status_code == 201

    history_resp = client.get(f"/api/rooms/{room_id}/messages?limit=3", headers=headers)
    assert history_resp.status_code == 200
    assert [m["textContent"] for m in history_resp.json()] == ["first", "second", "third"]


def test_send_reply_message_persists_reply_id(client: TestClient):
    user_a, _, room_id = _setup_room(client)
    headers = auth_headers(user_a["token"])

    parent_resp = client.post(f"/api/rooms/{room_id}/messages", json={
        "contentType": "text",
        "textContent": "Parent",
    }, headers=headers)
    parent_id = parent_resp.json()["id"]

    reply_resp = client.post(f"/api/rooms/{room_id}/messages", json={
        "contentType": "text",
        "textContent": "Reply",
        "replyToId": parent_id,
    }, headers=headers)
    assert reply_resp.status_code == 201
    assert reply_resp.json()["replyToId"] == parent_id

    list_resp = client.get(f"/api/rooms/{room_id}/messages", headers=headers)
    persisted = next(m for m in list_resp.json() if m["id"] == reply_resp.json()["id"])
    assert persisted["replyToId"] == parent_id


def test_reply_to_message_in_other_room_returns_404(client: TestClient):
    user_a = register_user(client)
    user_b = register_user(client)
    headers = auth_headers(user_a["token"])

    room_one = client.post("/api/rooms", json={
        "type": "group",
        "name": "Room One",
        "memberUsernames": [user_b["user"]["username"]],
    }, headers=headers).json()["id"]
    room_two = client.post("/api/rooms", json={
        "type": "group",
        "name": "Room Two",
        "memberUsernames": [user_b["user"]["username"]],
    }, headers=headers).json()["id"]

    parent = client.post(f"/api/rooms/{room_one}/messages", json={
        "contentType": "text",
        "textContent": "Wrong room parent",
    }, headers=headers).json()

    reply_resp = client.post(f"/api/rooms/{room_two}/messages", json={
        "contentType": "text",
        "textContent": "Invalid reply",
        "replyToId": parent["id"],
    }, headers=headers)
    assert reply_resp.status_code == 404


def test_non_member_cannot_read_or_write_messages(client: TestClient):
    user_a, _, room_id = _setup_room(client)
    outsider = register_user(client)
    outsider_headers = auth_headers(outsider["token"])

    read_resp = client.get(f"/api/rooms/{room_id}/messages", headers=outsider_headers)
    assert read_resp.status_code == 403

    write_resp = client.post(f"/api/rooms/{room_id}/messages", json={
        "contentType": "text",
        "textContent": "I should not be here",
    }, headers=outsider_headers)
    assert write_resp.status_code == 403


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


def test_emoji_reaction_is_idempotent(client: TestClient):
    user_a, _, room_id = _setup_room(client)
    headers = auth_headers(user_a["token"])

    msg_resp = client.post(f"/api/rooms/{room_id}/messages", json={
        "contentType": "text",
        "textContent": "React to me",
    }, headers=headers)
    msg_id = msg_resp.json()["id"]

    first = client.post(
        f"/api/rooms/{room_id}/messages/{msg_id}/reactions",
        json={"emoji": "🔥"},
        headers=headers,
    )
    second = client.post(
        f"/api/rooms/{room_id}/messages/{msg_id}/reactions",
        json={"emoji": "🔥"},
        headers=headers,
    )

    assert first.status_code == 201
    assert second.status_code == 201
    assert first.json()["id"] == second.json()["id"]


def test_reaction_to_message_in_other_room_returns_404(client: TestClient):
    user_a = register_user(client)
    user_b = register_user(client)
    headers = auth_headers(user_a["token"])

    room_one = client.post("/api/rooms", json={
        "type": "group",
        "name": "Room One",
        "memberUsernames": [user_b["user"]["username"]],
    }, headers=headers).json()["id"]
    room_two = client.post("/api/rooms", json={
        "type": "group",
        "name": "Room Two",
        "memberUsernames": [user_b["user"]["username"]],
    }, headers=headers).json()["id"]

    msg = client.post(f"/api/rooms/{room_one}/messages", json={
        "contentType": "text",
        "textContent": "Wrong room reaction",
    }, headers=headers).json()

    resp = client.post(
        f"/api/rooms/{room_two}/messages/{msg['id']}/reactions",
        json={"emoji": "👍"},
        headers=headers,
    )
    assert resp.status_code == 404
